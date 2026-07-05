/// 免费额度策略（C1）。
///
/// **计费 / 配额裁决的最终真相在后端**：客户端不参与计费决策，撞墙与否由被调用功能的
/// 后端响应（402 / 429 类）决定。本接口只承担「未解锁时，本地是否预测性放行」——
/// 至多用于体验节奏 / 提前给升级引导，不能当作可信的额度裁决。
///
/// 现有 `lib/features/usage/` 是**本地 UX 计数器**（只累加、不回退、无 user_id、无周期），
/// 严禁当作额度裁决基建（critic must-fix C1）。本地试用计数走专用的
/// [AiTrialUsageStore]（用户级、永久累计），仅作预测性额度。
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/premium_feature.dart';

/// 免费额度策略接口。
abstract class FreeAllowancePolicy {
  /// 在未持有 Premium 权益时，是否仍允许使用 [feature]（本地预测性判定）。
  bool allows(PremiumFeature feature);
}

/// 一律放行（保留供测试 / 特殊场景使用）。
class AlwaysAllowPolicy implements FreeAllowancePolicy {
  const AlwaysAllowPolicy();

  @override
  bool allows(PremiumFeature feature) => true;
}

/// 永久免费试用额度策略：已用次数 < 配置次数时放行。
///
/// 当前各功能配置次数均为 0（见 [kAiTrialLimits]），故对未订阅用户一律不放行
/// → 直接撞墙引导升级。后续调大次数即可放开试用，无需改调用点。
class TrialAllowancePolicy implements FreeAllowancePolicy {
  const TrialAllowancePolicy({required this.limits, required this.used});

  /// 各功能的永久试用次数上限。
  final Map<PremiumFeature, int> limits;

  /// 当前用户各功能的已用次数。
  final Map<PremiumFeature, int> used;

  @override
  bool allows(PremiumFeature feature) {
    final limit = limits[feature] ?? 0;
    final consumed = used[feature] ?? 0;
    return consumed < limit;
  }
}

/// 免费额度策略 Provider。
///
/// 额度裁决已上移到**后端**：各 AI 端点按「用户 + 功能 + 自然月」计数，超额返回 402。
/// 因此客户端不再本地预判额度，已登录的免费用户一律放行「发起请求」，由后端裁决；
/// 超额时客户端捕获 402 → 弹订阅（见 `sentence_ai_provider` 与转录流程）。
///
/// 保留 [TrialAllowancePolicy]（本地预测性额度）供后续订阅阶段按需复用；当前不启用。
final freeAllowancePolicyProvider = Provider<FreeAllowancePolicy>((ref) {
  return const AlwaysAllowPolicy();
});
