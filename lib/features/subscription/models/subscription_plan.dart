/// 订阅套餐展示 DTO。
///
/// 这是 Paywall UI 唯一依赖的套餐数据结构，**刻意不暴露 RevenueCat 的
/// Offering / Package / StoreProduct 类型**。RevenueCat 实现（Phase 2）负责把
/// RC 的商品模型映射成本 DTO，从而把定价展示层与第三方 SDK 隔离，
/// 降低未来迁移成本（critic warning）。
library;

/// 订阅周期。
enum SubscriptionPeriod {
  /// 月订。
  monthly,

  /// 年订（主推）。
  yearly,

  /// 终身买断（一次性，P1）。
  lifetime,
}

/// 从商品 ID 字符串**启发式**推断订阅周期，判不出返回 null。
///
/// 仅作兜底：周期的权威来源是平台的 packageType（购买时可得），已解析出的周期会存进
/// [Entitlement.period]。本函数用于两处退化场景——① 商品 ID 未在当前 offering 里
/// （拿不到 packageType）；② 会员态离线且无缓存周期。命名不规范的商品 ID（如 `p1y`）
/// 可能判不出，返回 null 由 UI 显示兜底文案。
SubscriptionPeriod? subscriptionPeriodFromProductId(String? productId) {
  if (productId == null || productId.isEmpty) return null;
  final id = productId.toLowerCase();
  if (id.contains('year') || id.contains('annual')) {
    return SubscriptionPeriod.yearly;
  }
  if (id.contains('month')) return SubscriptionPeriod.monthly;
  if (id.contains('life')) return SubscriptionPeriod.lifetime;
  return null;
}

/// 单个可购买套餐的展示信息。
class SubscriptionPlan {
  /// 套餐标识（映射到平台商品 ID / RC package）。
  final String planId;

  /// 展示标题（如「年度会员」）。
  final String title;

  /// 本地化价格字符串（含币种符号，**必须来自平台 SDK，禁止硬编码**）。
  final String priceString;

  /// 订阅周期。
  final SubscriptionPeriod period;

  /// 是否提供免费试用。
  final bool hasFreeTrial;

  /// 免费试用天数（[hasFreeTrial] 为 false 时为 0）。
  final int trialDays;

  const SubscriptionPlan({
    required this.planId,
    required this.title,
    required this.priceString,
    required this.period,
    this.hasFreeTrial = false,
    this.trialDays = 0,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SubscriptionPlan &&
          planId == other.planId &&
          title == other.title &&
          priceString == other.priceString &&
          period == other.period &&
          hasFreeTrial == other.hasFreeTrial &&
          trialDays == other.trialDays;

  @override
  int get hashCode =>
      Object.hash(planId, title, priceString, period, hasFreeTrial, trialDays);
}
