/// 订阅权益运行态（State）。
///
/// State 可包含 Model（[Entitlement]），但 Model 不依赖 State。
/// 这是 App 内权益的唯一对外快照，UI 只读 `SubscriptionController.state`。
library;

import '../models/entitlement.dart';

/// 权益状态机的三态。
enum EntitlementStatus {
  /// 未知 / 待校验。冷启动首帧、离线且缓存过期、对账尚未完成时的中间态。
  ///
  /// **不可等同于 free**：付费用户冷启动瞬间若按 free 渲染会闪现付费墙（C5）。
  unknown,

  /// 已确认无 Premium 权益。
  free,

  /// 已确认持有有效付费会员权益（当前单一等级 = Plus）。
  ///
  /// 命名用 premium 泛指「已付费」，不代表某个 Pro 档位；将来加 Plus/Pro 分级时
  /// 档位由独立维度表达，此枚举仍只区分 付费 / 免费 / 未知。
  premium,
}

/// 不可变权益运行态。
class EntitlementState {
  /// 当前权益状态。
  final EntitlementStatus status;

  /// 权益详情快照（[status] 为 unknown 时可为 null）。
  final Entitlement? entitlement;

  /// 是否为陈旧数据（来自本地缓存、尚未被在线权威源确认）。
  ///
  /// 失败不静默吞：在线对账失败时保留上次结果并置 [isStale]，供 UI 提示 / 重试。
  final bool isStale;

  /// 最近一次对账的错误描述（成功时为 null）。
  final String? error;

  const EntitlementState({
    required this.status,
    this.entitlement,
    this.isStale = false,
    this.error,
  });

  /// 未知中间态（冷启动初始值）。
  const EntitlementState.unknown()
    : status = EntitlementStatus.unknown,
      entitlement = null,
      isStale = false,
      error = null;

  /// 已确认的免费态。
  const EntitlementState.free()
    : status = EntitlementStatus.free,
      entitlement = Entitlement.free,
      isStale = false,
      error = null;

  /// 是否解锁付费权益（仅 premium 态为真；unknown / free 均为否）。
  bool get isActive => status == EntitlementStatus.premium;

  EntitlementState copyWith({
    EntitlementStatus? status,
    Entitlement? entitlement,
    bool clearEntitlement = false,
    bool? isStale,
    String? error,
    bool clearError = false,
  }) {
    return EntitlementState(
      status: status ?? this.status,
      entitlement: clearEntitlement ? null : entitlement ?? this.entitlement,
      isStale: isStale ?? this.isStale,
      error: clearError ? null : error ?? this.error,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is EntitlementState &&
          status == other.status &&
          entitlement == other.entitlement &&
          isStale == other.isStale &&
          error == other.error;

  @override
  int get hashCode => Object.hash(status, entitlement, isStale, error);
}
