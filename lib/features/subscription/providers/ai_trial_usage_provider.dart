/// 当前用户的 AI 免费试用次数（内存态，供同步读取）。
///
/// 从 [AiTrialUsageStore] 按当前 `userId` hydrate，随登录身份变化重载；
/// [AiTrialUsageNotifier.consume] 在一次免费试用消耗后自增并落盘。
/// 匿名用户不计数（未登录一律锁定，不消耗试用）。
library;

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../onboarding_survey/providers/onboarding_survey_provider.dart'
    show sharedPreferencesProvider;
import '../models/premium_feature.dart';
import '../services/ai_trial_usage_store.dart';
import 'subscription_identity.dart';

/// 试用计数持久化层入口。
final aiTrialUsageStoreProvider = Provider<AiTrialUsageStore>((ref) {
  return AiTrialUsageStore(ref.read(sharedPreferencesProvider));
});

/// 当前用户各 AI 功能的已用试用次数（同步可读）。
class AiTrialUsageNotifier extends Notifier<Map<PremiumFeature, int>> {
  @override
  Map<PremiumFeature, int> build() {
    // 随登录身份变化重载当前用户的计数。
    final userId = ref.watch(subscriptionIdentityProvider).userId;
    if (userId == null) return const {};
    return ref.read(aiTrialUsageStoreProvider).load(userId);
  }

  /// 消耗一次免费试用并落盘（匿名用户不计数）。
  void consume(PremiumFeature feature) {
    final userId = ref.read(subscriptionIdentityProvider).userId;
    if (userId == null) return;
    final next = Map<PremiumFeature, int>.from(state);
    next[feature] = (next[feature] ?? 0) + 1;
    state = next;
    unawaited(ref.read(aiTrialUsageStoreProvider).save(userId, next));
  }
}

/// 当前用户的 AI 试用计数 Provider。
final aiTrialUsageProvider =
    NotifierProvider<AiTrialUsageNotifier, Map<PremiumFeature, int>>(
      AiTrialUsageNotifier.new,
    );
