/// 后端权益仓库接口。
///
/// 查询后端权威权益（后端经 RevenueCat webhook 落库，绑定 Supabase user_id）。
/// Dio 实现（带 `Authorization: Bearer <accessToken>`，参照
/// `lib/services/transcription_api_client.dart`）留待 Phase 1，
/// 届时新增 `BackendEntitlementRepository implements EntitlementRepository`
/// 替换 [StubEntitlementRepository]。
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/entitlement.dart';

/// 后端权益仓库抽象。
abstract class EntitlementRepository {
  /// 查询后端权威权益。
  ///
  /// - 返回非空：后端确认的权益（active 或 [Entitlement.free]）。
  /// - 返回 **null**：未能获取（离线 / 错误 / 后端未就绪），调用方据此走缓存兜底，
  ///   **不可**把「获取失败」误判为「无权益」。
  Future<Entitlement?> fetchRemote({
    required String userId,
    required String accessToken,
  });
}

/// Phase 0 占位实现：后端尚未就绪，恒返回 null（触发缓存兜底 / 未知态）。
class StubEntitlementRepository implements EntitlementRepository {
  const StubEntitlementRepository();

  @override
  Future<Entitlement?> fetchRemote({
    required String userId,
    required String accessToken,
  }) async {
    return null;
  }
}

/// 后端权益仓库 Provider（测试 / Phase 1 可 override）。
final entitlementRepositoryProvider = Provider<EntitlementRepository>((ref) {
  return const StubEntitlementRepository();
});
