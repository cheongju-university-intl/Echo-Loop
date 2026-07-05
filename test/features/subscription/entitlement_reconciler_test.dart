import 'package:echo_loop/features/subscription/models/entitlement.dart';
import 'package:echo_loop/features/subscription/services/entitlement_cache.dart';
import 'package:echo_loop/features/subscription/services/entitlement_reconciler.dart';
import 'package:echo_loop/features/subscription/state/entitlement_state.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final now = DateTime.utc(2026, 6, 22, 12);
  const proRemote = Entitlement(isPremium: true, productId: 'pro_yearly');

  CachedEntitlement cache(Entitlement ent, {Duration age = Duration.zero}) {
    return CachedEntitlement(
      userId: 'u1',
      entitlement: ent,
      cachedAt: now.subtract(age),
    );
  }

  group('在线权威源存在 → 直接覆盖、非陈旧', () {
    test('远端 active → pro', () {
      final state = reconcileEntitlement(
        remote: proRemote,
        cached: null,
        now: now,
      );
      expect(state.status, EntitlementStatus.premium);
      expect(state.isStale, isFalse);
    });

    test('远端 free → free（即便缓存仍是 active，C4 退款覆盖）', () {
      final state = reconcileEntitlement(
        remote: Entitlement.free,
        cached: cache(proRemote),
        now: now,
      );
      expect(state.status, EntitlementStatus.free);
      expect(state.isStale, isFalse);
    });

    test('远端 pro 但已过期 → free', () {
      final expired = Entitlement(
        isPremium: true,
        expiresAt: now.subtract(const Duration(days: 1)),
      );
      final state = reconcileEntitlement(
        remote: expired,
        cached: null,
        now: now,
      );
      expect(state.status, EntitlementStatus.free);
    });
  });

  group('离线（remote == null）→ 缓存乐观兜底带时效', () {
    test('新鲜缓存 active → pro 且 isStale', () {
      final state = reconcileEntitlement(
        remote: null,
        cached: cache(proRemote, age: const Duration(hours: 1)),
        now: now,
      );
      expect(state.status, EntitlementStatus.premium);
      expect(state.isStale, isTrue);
    });

    test('新鲜缓存 free → free 且 isStale', () {
      final state = reconcileEntitlement(
        remote: null,
        cached: cache(Entitlement.free, age: const Duration(hours: 1)),
        now: now,
      );
      expect(state.status, EntitlementStatus.free);
      expect(state.isStale, isTrue);
    });

    test('缓存超过新鲜窗口 → unknown（待校验）', () {
      final state = reconcileEntitlement(
        remote: null,
        cached: cache(proRemote, age: const Duration(hours: 25)),
        now: now,
      );
      expect(state.status, EntitlementStatus.unknown);
      expect(state.isStale, isTrue);
    });

    test('无缓存 → unknown（待校验）', () {
      final state = reconcileEntitlement(remote: null, cached: null, now: now);
      expect(state.status, EntitlementStatus.unknown);
    });
  });
}
