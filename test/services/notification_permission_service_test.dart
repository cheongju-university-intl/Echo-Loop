import 'package:echo_loop/analytics/analytics_service.dart';
import 'package:echo_loop/analytics/models/event_names.dart';
import 'package:echo_loop/services/notification_permission_service.dart';
import 'package:echo_loop/services/review_reminder_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:permission_handler/permission_handler.dart' as ph;
import 'package:shared_preferences/shared_preferences.dart';

class MockAnalyticsService extends Mock implements AnalyticsService {}

class MockReviewReminderService extends Mock implements ReviewReminderService {}

class FakeTrigger implements NotificationPromptTrigger {
  int triggerCount = 0;
  bool _showing = false;

  @override
  bool get isShowing => _showing;

  @override
  void trigger() {
    if (_showing) return;
    _showing = true;
    triggerCount++;
  }

  @override
  void onDialogClosed() {
    _showing = false;
  }
}

void main() {
  setUpAll(() {
    SharedPreferences.setMockInitialValues({});
  });

  late MockAnalyticsService analytics;
  late MockReviewReminderService reminderService;
  late FakeTrigger trigger;
  late SharedPreferences prefs;

  /// 构造 service：默认 reminderService.checkNotificationGranted 由
  /// `granted` 参数决定；request 由 `requestResult` 决定；
  /// `phStatus` 用于模拟 onUserAcceptedPrompt 之后的中断检测；
  /// `requestDelay` 模拟系统框停留耗时（用于耗时兜底判定）。
  Future<NotificationPermissionService> buildService({
    required bool granted,
    bool requestResult = true,
    ph.PermissionStatus phStatus = ph.PermissionStatus.granted,
    Duration requestDelay = const Duration(milliseconds: 1500),
    DateTime? now,
  }) async {
    when(
      () => reminderService.checkNotificationGranted(),
    ).thenAnswer((_) async => granted);
    when(
      () => reminderService.requestNotificationPermission(),
    ).thenAnswer((_) async {
      await Future<void>.delayed(requestDelay);
      return requestResult;
    });

    final service = NotificationPermissionService(
      prefs: prefs,
      analytics: analytics,
      trigger: trigger,
      reminderService: reminderService,
      phStatusReader: () async => phStatus,
    );
    if (now != null) {
      service.now = () => now;
    }
    return service;
  }

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    analytics = MockAnalyticsService();
    reminderService = MockReviewReminderService();
    trigger = FakeTrigger();

    when(() => analytics.track(any(), any())).thenAnswer((_) async {});
  });

  group('maybeTriggerPrompt 状态分支（基于 granted + SP system_requested）', () {
    test('granted → skip(already_granted)', () async {
      final service = await buildService(granted: true);

      await service.maybeTriggerPrompt();

      expect(trigger.triggerCount, 0);
      verify(
        () => analytics.track(
          Events.notificationPromptSkipped,
          {EventParams.reason: 'already_granted'},
        ),
      ).called(1);
    });

    test('granted=false + SP=true → skip(already_denied)', () async {
      await prefs.setBool('notification_system_requested', true);
      final service = await buildService(granted: false);

      await service.maybeTriggerPrompt();

      expect(trigger.triggerCount, 0);
      verify(
        () => analytics.track(
          Events.notificationPromptSkipped,
          {EventParams.reason: 'already_denied'},
        ),
      ).called(1);
    });

    test('granted=false + SP=false + 无历史 dismiss → trigger fired', () async {
      final service = await buildService(granted: false);

      await service.maybeTriggerPrompt();

      expect(trigger.triggerCount, 1);
      verifyNever(
        () => analytics.track(Events.notificationPromptSkipped, any()),
      );
    });

    test(
      'granted=false + SP=false + dismiss < 14 天 → skip(cooldown)',
      () async {
        final now = DateTime(2026, 5, 22, 12, 0);
        final lastShown = now.subtract(const Duration(days: 7));
        await prefs.setString('notification_prompt_last_action', 'dismiss');
        await prefs.setInt(
          'notification_prompt_last_shown_at',
          lastShown.millisecondsSinceEpoch,
        );
        final service = await buildService(granted: false, now: now);

        await service.maybeTriggerPrompt();

        expect(trigger.triggerCount, 0);
        verify(
          () => analytics.track(
            Events.notificationPromptSkipped,
            {EventParams.reason: 'cooldown'},
          ),
        ).called(1);
      },
    );

    test(
      'granted=false + SP=false + dismiss > 14 天 → 重新 trigger fired',
      () async {
        final now = DateTime(2026, 5, 22, 12, 0);
        final lastShown = now.subtract(const Duration(days: 15));
        await prefs.setString('notification_prompt_last_action', 'dismiss');
        await prefs.setInt(
          'notification_prompt_last_shown_at',
          lastShown.millisecondsSinceEpoch,
        );
        final service = await buildService(granted: false, now: now);

        await service.maybeTriggerPrompt();

        expect(trigger.triggerCount, 1);
      },
    );

    test('checkNotificationGranted 抛错 → 按 blocked 处理（保守不弹）', () async {
      when(
        () => reminderService.checkNotificationGranted(),
      ).thenAnswer((_) async => throw Exception('platform error'));
      final service = NotificationPermissionService(
        prefs: prefs,
        analytics: analytics,
        trigger: trigger,
        reminderService: reminderService,
        phStatusReader: () async => ph.PermissionStatus.denied,
      );

      await service.maybeTriggerPrompt();

      expect(trigger.triggerCount, 0);
      verify(
        () => analytics.track(
          Events.notificationPromptSkipped,
          {EventParams.reason: 'already_denied'},
        ),
      ).called(1);
    });
  });

  group('getCurrentState 派生状态机', () {
    test('granted=true → state granted', () async {
      final service = await buildService(granted: true);
      final s = await service.getCurrentState();
      expect(s, NotificationPermissionState.granted);
    });

    test('granted=false + SP=false → state canRequest', () async {
      final service = await buildService(granted: false);
      final s = await service.getCurrentState();
      expect(s, NotificationPermissionState.canRequest);
    });

    test('granted=false + SP=true → state blocked', () async {
      await prefs.setBool('notification_system_requested', true);
      final service = await buildService(granted: false);
      final s = await service.getCurrentState();
      expect(s, NotificationPermissionState.blocked);
    });

    test('granted=true + SP=true → state granted（从系统设置回开后）', () async {
      // 模拟：用户曾经走过系统流程被拒绝（SP=true），后来去系统设置开启
      await prefs.setBool('notification_system_requested', true);
      final service = await buildService(granted: true);
      final s = await service.getCurrentState();
      expect(s, NotificationPermissionState.granted);
    });

    test(
      'Android 13+ 首装：granted=false + ph=denied + SP=false → state canRequest'
      '（POST_NOTIFICATIONS 还没问，应该弹）',
      () async {
        final service = await buildService(
          granted: false,
          phStatus: ph.PermissionStatus.denied,
        );
        final s = await service.getCurrentState();
        expect(s, NotificationPermissionState.canRequest);
      },
    );

    test(
      'iOS 首装：granted=false + ph=denied(notDetermined) + SP=false → state canRequest',
      () async {
        final service = await buildService(
          granted: false,
          phStatus: ph.PermissionStatus.denied,
        );
        final s = await service.getCurrentState();
        expect(s, NotificationPermissionState.canRequest);
      },
    );

    test('granted=false + ph=permanentlyDenied → state blocked（跨平台通用）', () async {
      final service = await buildService(
        granted: false,
        phStatus: ph.PermissionStatus.permanentlyDenied,
      );
      final s = await service.getCurrentState();
      expect(s, NotificationPermissionState.blocked);
    });

    test('granted=false + ph=restricted → state blocked（家长控制）', () async {
      final service = await buildService(
        granted: false,
        phStatus: ph.PermissionStatus.restricted,
      );
      final s = await service.getCurrentState();
      expect(s, NotificationPermissionState.blocked);
    });
  });

  group('onUserAcceptedPrompt / onUserDismissedPrompt', () {
    test('onUserAccepted granted → SP system_requested=true, 埋点 granted',
        () async {
      final service = await buildService(granted: false, requestResult: true);

      final granted = await service.onUserAcceptedPrompt();

      expect(granted, isTrue);
      verify(
        () => analytics.track(
          Events.notificationPromptResult,
          {EventParams.action: 'grant'},
        ),
      ).called(1);
      verify(
        () => analytics.track(
          Events.notificationSystemResult,
          {EventParams.status: 'granted'},
        ),
      ).called(1);
      expect(
        prefs.getString('notification_prompt_last_action'),
        equals('grant'),
      );
      expect(prefs.getInt('notification_prompt_last_shown_at'), isNotNull);
      expect(
        prefs.getBool('notification_system_requested'),
        isTrue,
        reason: '调用过系统授权 API 后应记录 SP 兜底标志',
      );
      verify(() => reminderService.requestNotificationPermission()).called(1);
    });

    test(
      'onUserAccepted denied + ph status=permanentlyDenied → SP=true',
      () async {
        final service = await buildService(
          granted: false,
          requestResult: false,
          phStatus: ph.PermissionStatus.permanentlyDenied,
        );

        final granted = await service.onUserAcceptedPrompt();

        expect(granted, isFalse);
        verify(
          () => analytics.track(
            Events.notificationSystemResult,
            {EventParams.status: 'denied'},
          ),
        ).called(1);
        expect(
          prefs.getBool('notification_system_requested'),
          isTrue,
          reason: '用户明确拒绝（permanentlyDenied）→ 记录 SP',
        );
      },
    );

    test(
      'onUserAccepted denied + ph=denied(notDetermined) 立刻关闭 → SP 不变（中断）',
      () async {
        // 模拟 iOS：系统授权框出现后用户立刻关闭 app
        final service = await buildService(
          granted: false,
          requestResult: false,
          phStatus: ph.PermissionStatus.denied,
          requestDelay: const Duration(milliseconds: 50),
        );

        await service.onUserAcceptedPrompt();

        expect(
          prefs.getBool('notification_system_requested'),
          isNull,
          reason: '系统授权框未真正决策时不应写 SP',
        );
      },
    );

    test(
      'onUserAccepted denied + ph=denied(notDetermined) + 手势 dismiss（耗时较长）→ SP 不变',
      () async {
        // 关键 case：用户看到了弹窗，停留了几秒后用手势上滑 dismiss
        // requestPermissions 返回 false 但系统状态仍是 notDetermined
        // 旧版用 800ms 耗时兜底会误判成"已决策"，这里验证不再发生
        final service = await buildService(
          granted: false,
          requestResult: false,
          phStatus: ph.PermissionStatus.denied,
          requestDelay: const Duration(milliseconds: 1500),
        );

        await service.onUserAcceptedPrompt();

        expect(
          prefs.getBool('notification_system_requested'),
          isNull,
          reason: '手势 dismiss 未真正决策，banner 应保持黄色不变红',
        );
      },
    );

    test(
      'onUserAccepted denied + ph status=restricted → SP=true',
      () async {
        final service = await buildService(
          granted: false,
          requestResult: false,
          phStatus: ph.PermissionStatus.restricted,
        );

        await service.onUserAcceptedPrompt();

        expect(
          prefs.getBool('notification_system_requested'),
          isTrue,
          reason: 'restricted (家长控制) 也算系统已决策',
        );
      },
    );

    test(
      'onUserAccepted granted + ph status=denied → 仍写 SP（以 plugin granted 为准）',
      () async {
        final service = await buildService(
          granted: false,
          requestResult: true,
          phStatus: ph.PermissionStatus.denied,
        );

        final granted = await service.onUserAcceptedPrompt();

        expect(granted, isTrue);
        expect(
          prefs.getBool('notification_system_requested'),
          isTrue,
          reason: 'plugin 返回 granted=true 就足够证明用户决定了',
        );
      },
    );

    test('onUserDismissed 埋点 + 持久化 dismiss, 不调系统 API', () async {
      final service = await buildService(granted: false);

      await service.onUserDismissedPrompt();

      verify(
        () => analytics.track(
          Events.notificationPromptResult,
          {EventParams.action: 'dismiss'},
        ),
      ).called(1);
      expect(
        prefs.getString('notification_prompt_last_action'),
        equals('dismiss'),
      );
      verifyNever(() => reminderService.requestNotificationPermission());
      expect(
        prefs.getBool('notification_system_requested'),
        isNull,
        reason: 'dismiss 不调系统 API，不该写 SP system_requested',
      );
    });
  });
}
