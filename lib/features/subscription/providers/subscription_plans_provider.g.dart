// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'subscription_plans_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$subscriptionPlansHash() => r'9b52ffc2b29bff27388b3b4f907610adace2f435';

/// 当前可购买的订阅套餐。
///
/// Copied from [subscriptionPlans].
@ProviderFor(subscriptionPlans)
final subscriptionPlansProvider =
    AutoDisposeFutureProvider<List<SubscriptionPlan>>.internal(
      subscriptionPlans,
      name: r'subscriptionPlansProvider',
      debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
          ? null
          : _$subscriptionPlansHash,
      dependencies: null,
      allTransitiveDependencies: null,
    );

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef SubscriptionPlansRef =
    AutoDisposeFutureProviderRef<List<SubscriptionPlan>>;
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
