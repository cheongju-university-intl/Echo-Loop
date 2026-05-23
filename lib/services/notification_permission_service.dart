/// 通知权限请求时机协调器。
///
/// 价值锚点（首次完成 sub_stage、首次收藏等）调用 [maybeTriggerPrompt]，
/// 由本服务统一判断是否要弹 in-app pre-prompt。
///
/// 状态机（[NotificationPermissionState]）由两个真值派生：
///
/// | `checkNotificationGranted` | `system_requested` SP | 状态 |
/// |---------|---------|------|
/// | true | -（不关心） | granted |
/// | false | false | canRequest（首次安装 / 用户没走过系统流程） |
/// | false | true | blocked（用户已走过系统流程但当前未授权 → 跳设置） |
///
/// 「真值源」用 `flutter_local_notifications` 的
/// `checkPermissions()` / `requestPermissions()` 走系统底层 API，
/// 不依赖 permission_handler（permission_handler 在 iOS / macOS 上
/// `status` 跟 `request()` 偶发不一致，导致状态机错位）。
library;

import 'package:permission_handler/permission_handler.dart' as ph;
import 'package:shared_preferences/shared_preferences.dart';

import '../analytics/analytics_service.dart';
import '../analytics/models/event_names.dart';
import 'app_logger.dart';
import 'review_reminder_service.dart';

const String _logTag = 'NotifPerm';

/// pre-prompt 已弹过的冷却天数，期满后允许在新锚点重新弹一次
const int _redismissCooldownDays = 14;

/// 触发 pre-prompt 显示的"接口"，由 Provider 层注入 Riverpod Notifier。
abstract class NotificationPromptTrigger {
  /// 请求显示 pre-prompt。若已在显示中应自行 no-op。
  void trigger();

  /// dialog 关闭后调用，解除并发保护。
  void onDialogClosed();

  /// 当前是否正在显示 dialog。
  bool get isShowing;
}

/// 判定 pre-prompt 是否要弹时考虑的精确权限状态。
enum NotificationPermissionState {
  /// 系统已授权（含 provisional / limited）
  granted,

  /// 还可以弹系统授权框：用户尚未走过系统授权流程（iOS notDetermined / Android 首次）
  canRequest,

  /// 用户已走过系统流程但当前未授权 → 不再弹 pre-prompt，引导跳系统设置
  blocked,
}

class NotificationPermissionService {
  NotificationPermissionService({
    required SharedPreferences prefs,
    required AnalyticsService analytics,
    required NotificationPromptTrigger trigger,
    required ReviewReminderService reminderService,
    Future<ph.PermissionStatus> Function()? phStatusReader,
  }) : _prefs = prefs,
       _analytics = analytics,
       _trigger = trigger,
       _reminderService = reminderService,
       _phStatusReader =
           phStatusReader ?? (() => ph.Permission.notification.status);

  /// 上次 pre-prompt 展示时间（millisSinceEpoch）。
  static const String _spKeyLastShownAt = 'notification_prompt_last_shown_at';

  /// 上次用户对 pre-prompt 的动作（'grant' / 'dismiss'）。
  static const String _spKeyLastAction = 'notification_prompt_last_action';

  /// 用户是否已经走过系统授权流程至少一次。
  /// 一旦为 true，后续若系统层面仍未 granted → 视为 blocked（跳设置而非再弹 prompt）。
  static const String _spKeySystemRequested =
      'notification_system_requested';

  static const String _actionGrant = 'grant';
  static const String _actionDismiss = 'dismiss';

  final SharedPreferences _prefs;
  final AnalyticsService _analytics;
  final NotificationPromptTrigger _trigger;
  final ReviewReminderService _reminderService;

  /// 辅助判断"用户是否真的做出决定"。仅用于区分「用户拒绝」vs
  /// 「系统框出现后被中断（关闭 app 等）」的边缘 case。
  /// permission_handler 在用户决策后 status 会反映 permanentlyDenied；
  /// 决策前打断则 status 仍是 denied (iOS = notDetermined 的映射)。
  final Future<ph.PermissionStatus> Function() _phStatusReader;

  /// 注入测试时间的钩子，默认走真实时钟。
  DateTime Function() now = DateTime.now;

  /// 读取当前权限状态。UI 层（reminder_settings_screen）必须走这个方法。
  Future<NotificationPermissionState> getCurrentState() => _readState();

  /// 价值锚点调用入口：每次"用户产生学习成果 / 首次收藏"时调用，
  /// 由本服务决定是否真的弹 pre-prompt。
  Future<void> maybeTriggerPrompt() async {
    AppLogger.log(_logTag, 'maybeTriggerPrompt: called from anchor');
    final state = await _readState();

    switch (state) {
      case NotificationPermissionState.granted:
        AppLogger.log(_logTag, 'maybeTriggerPrompt: skip (already_granted)');
        _trackSkipped('already_granted');
        return;
      case NotificationPermissionState.blocked:
        AppLogger.log(_logTag, 'maybeTriggerPrompt: skip (already_denied)');
        _trackSkipped('already_denied');
        return;
      case NotificationPermissionState.canRequest:
        if (_isInCooldown()) {
          final lastShown = _prefs.getInt(_spKeyLastShownAt) ?? 0;
          AppLogger.log(
            _logTag,
            'maybeTriggerPrompt: skip (cooldown) '
            'lastShownAt=${DateTime.fromMillisecondsSinceEpoch(lastShown)} '
            'lastAction=${_prefs.getString(_spKeyLastAction)}',
          );
          _trackSkipped('cooldown');
          return;
        }
        AppLogger.log(
          _logTag,
          'maybeTriggerPrompt: triggering pre-prompt '
          '(showing=${_trigger.isShowing})',
        );
        _trigger.trigger();
    }
  }

  /// 用户在 pre-prompt 点"开启"后调用，串联系统授权 + 持久化 + 埋点。
  ///
  /// 返回值：系统是否真的授权成功。
  ///
  /// **被中断的处理**：iOS 系统授权框出现后用户**手势 dismiss**（上滑、点框外）
  /// 或**关闭 app**，`requestNotificationPermission` 会返回 false，但系统层面
  /// `UNAuthorizationStatus` 仍是 `notDetermined`（用户没真正决策）。此时**不应**
  /// 写 SP `system_requested`，否则下次启动会误判 blocked、banner 错误地变红色。
  ///
  /// 判定「用户是否真的做了决定」**完全依赖 permission_handler.status**：
  /// - `granted/limited` → 用户允许（请求结果也会是 true）
  /// - `permanentlyDenied/restricted` → 用户**明确**拒绝（按 Don't Allow）
  /// - 其他（`denied` = iOS notDetermined 的映射）→ **未决策**（手势 dismiss / 关闭 app）
  ///   不论 request 耗时多长都视为中断，保持 SP 不变
  ///
  /// 注：旧版本曾用"request 耗时 ≥ 800ms"做兜底，但会把"看了弹窗但手势上滑"
  /// 误判成已决策，导致 banner 错误变红。已移除，完全信任 phStatus。
  Future<bool> onUserAcceptedPrompt() async {
    AppLogger.log(_logTag, 'onUserAccepted: requesting system permission');
    _analytics.track(Events.notificationPromptResult, const {
      EventParams.action: _actionGrant,
    });
    await _persistAction(_actionGrant);

    final stopwatch = Stopwatch()..start();
    final granted = await _reminderService.requestNotificationPermission();
    stopwatch.stop();
    final elapsedMs = stopwatch.elapsedMilliseconds;

    final phStatus = await _safeReadPhStatus();
    final reallyDecided = granted ||
        phStatus.isPermanentlyDenied ||
        phStatus.isRestricted;

    if (reallyDecided) {
      await _prefs.setBool(_spKeySystemRequested, true);
      AppLogger.log(
        _logTag,
        'onUserAccepted: granted=$granted phStatus=$phStatus '
        'elapsed=${elapsedMs}ms -> user decided, SP system_requested=true',
      );
    } else {
      AppLogger.log(
        _logTag,
        'onUserAccepted: granted=$granted phStatus=$phStatus '
        'elapsed=${elapsedMs}ms -> NOT decided (gesture-dismissed / interrupted), '
        'SP unchanged',
      );
    }

    _analytics.track(Events.notificationSystemResult, {
      EventParams.status: granted ? 'granted' : 'denied',
    });
    return granted;
  }

  /// 安全读取 permission_handler 的 PermissionStatus。失败按 denied 处理
  /// （保守不写 SP）。
  Future<ph.PermissionStatus> _safeReadPhStatus() async {
    try {
      return await _phStatusReader();
    } catch (e) {
      AppLogger.log(_logTag, 'onUserAccepted: phStatus read ERROR: $e');
      return ph.PermissionStatus.denied;
    }
  }

  /// 用户在 pre-prompt 点"暂不"时调用。
  Future<void> onUserDismissedPrompt() async {
    AppLogger.log(_logTag, 'onUserDismissed: dismissed by user');
    _analytics.track(Events.notificationPromptResult, const {
      EventParams.action: _actionDismiss,
    });
    await _persistAction(_actionDismiss);
  }

  /// 读当前通知系统授权状态。失败时按 `blocked` 处理（保守不弹）。
  ///
  /// 真值源：`flutter_local_notifications.checkPermissions` (iOS / macOS)
  /// 或 `areNotificationsEnabled` (Android)，跨平台 fresh fetch。
  ///
  /// 状态判定（granted=false 时）：
  /// 1. `permission_handler.status` 是 `permanentlyDenied / restricted` →
  ///    系统已明确拒绝 → **blocked**
  /// 2. SP `system_requested=true`：app 内走过 pre-prompt 流程且用户已决策 →
  ///    **blocked**（用 SP 而不是 ph.denied 来判定，因为后者在不同平台/
  ///    Android 版本语义不一致）
  /// 3. 都不是 → 用户从没走过授权流程 → **canRequest**
  ///
  /// 边缘 case：Android <13 用户在系统设置直接关闭通知（不走 app），
  /// 第一次读状态会显示 canRequest（黄色）；点 Turn On 后 SP=true
  /// 自然变 blocked（红色）。多一次无效点击，但 Android 13+ 正常路径优先。
  Future<NotificationPermissionState> _readState() async {
    final bool granted;
    try {
      granted = await _reminderService.checkNotificationGranted();
    } catch (e) {
      AppLogger.log(_logTag, 'getCurrentState ERROR: $e (fallback blocked)');
      return NotificationPermissionState.blocked;
    }
    if (granted) {
      AppLogger.log(_logTag, 'getCurrentState: granted=true -> granted');
      return NotificationPermissionState.granted;
    }

    final phStatus = await _safeReadPhStatus();
    final systemRequested = _prefs.getBool(_spKeySystemRequested) ?? false;

    final bool blocked = phStatus.isPermanentlyDenied ||
        phStatus.isRestricted ||
        systemRequested;

    final state = blocked
        ? NotificationPermissionState.blocked
        : NotificationPermissionState.canRequest;
    AppLogger.log(
      _logTag,
      'getCurrentState: granted=false phStatus=$phStatus '
      'SP_system_requested=$systemRequested -> ${state.name}',
    );
    return state;
  }

  bool _isInCooldown() {
    final lastAction = _prefs.getString(_spKeyLastAction);
    if (lastAction != _actionDismiss) return false;
    final lastShown = _prefs.getInt(_spKeyLastShownAt) ?? 0;
    final elapsedMs = now().millisecondsSinceEpoch - lastShown;
    final cooldownMs = _redismissCooldownDays * 24 * 3600 * 1000;
    return elapsedMs < cooldownMs;
  }

  Future<void> _persistAction(String action) async {
    await _prefs.setString(_spKeyLastAction, action);
    await _prefs.setInt(
      _spKeyLastShownAt,
      now().millisecondsSinceEpoch,
    );
  }

  void _trackSkipped(String reason) {
    _analytics.track(Events.notificationPromptSkipped, {
      EventParams.reason: reason,
    });
  }
}
