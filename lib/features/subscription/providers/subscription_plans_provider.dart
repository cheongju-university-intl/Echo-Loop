/// 可购买套餐列表 Provider。
///
/// 从 [PurchaseService]（RevenueCat）拉取当前 Offering 的套餐，价格为平台本地化价格。
/// Paywall 用 `ref.watch` 消费其 AsyncValue（loading / error / data 三态）。
library;

import 'package:flutter_riverpod/flutter_riverpod.dart' show Ref;
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../models/subscription_plan.dart';
import '../services/revenuecat_purchase_service.dart';

part 'subscription_plans_provider.g.dart';

/// 当前可购买的订阅套餐。
@riverpod
Future<List<SubscriptionPlan>> subscriptionPlans(Ref ref) async {
  return ref.watch(purchaseServiceProvider).fetchPlans();
}
