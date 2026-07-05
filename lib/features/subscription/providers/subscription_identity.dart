/// 订阅身份：从 Supabase session 派生出权益对账所需的最小身份信息。
///
/// 把 [SubscriptionController] 与 Supabase 的 `Session` 类型解耦——controller 只依赖
/// 这层轻量值对象，既符合「身份单一来源仍是 supabaseSessionProvider」，
/// 又让 controller 可在测试中通过 override 本 provider 注入身份与切换事件，
/// 无需构造完整 Session。
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/providers/auth_providers.dart';

/// 对账所需的用户身份快照。
class SubscriptionIdentity {
  /// Supabase user.id；匿名 / 未登录为 null。
  final String? userId;

  /// Supabase access token（用于后端鉴权）；未登录为 null。
  final String? accessToken;

  const SubscriptionIdentity({this.userId, this.accessToken});

  /// 匿名 / 未登录身份。
  static const SubscriptionIdentity anonymous = SubscriptionIdentity();

  /// 是否已登录。
  bool get isSignedIn => userId != null;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SubscriptionIdentity &&
          userId == other.userId &&
          accessToken == other.accessToken;

  @override
  int get hashCode => Object.hash(userId, accessToken);
}

/// 当前订阅身份（派生自 [supabaseSessionProvider]，身份单一来源不变）。
final subscriptionIdentityProvider = Provider<SubscriptionIdentity>((ref) {
  final session = ref.watch(supabaseSessionProvider).valueOrNull;
  if (session == null) return SubscriptionIdentity.anonymous;
  return SubscriptionIdentity(
    userId: session.user.id,
    accessToken: session.accessToken,
  );
});
