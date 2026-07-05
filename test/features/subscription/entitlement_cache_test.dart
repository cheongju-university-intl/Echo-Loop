import 'dart:convert';

import 'package:echo_loop/features/subscription/models/entitlement.dart';
import 'package:echo_loop/features/subscription/services/entitlement_cache.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockSecureStorage extends Mock implements FlutterSecureStorage {}

void main() {
  late _MockSecureStorage storage;
  late EntitlementCache cache;

  setUp(() {
    storage = _MockSecureStorage();
    cache = EntitlementCache(storage: storage);
  });

  CachedEntitlement sample() => CachedEntitlement(
    userId: 'u1',
    entitlement: const Entitlement(isPremium: true, productId: 'pro_yearly'),
    cachedAt: DateTime.utc(2026, 6, 22, 12),
  );

  test('write 后 read 往返一致', () async {
    String? written;
    when(
      () => storage.write(
        key: any(named: 'key'),
        value: any(named: 'value'),
      ),
    ).thenAnswer((invocation) async {
      written = invocation.namedArguments[const Symbol('value')] as String;
    });
    when(
      () => storage.read(key: any(named: 'key')),
    ).thenAnswer((_) async => written);

    final original = sample();
    await cache.write(original);
    final restored = await cache.read();

    expect(restored, isNotNull);
    expect(restored!.userId, original.userId);
    expect(restored.entitlement, original.entitlement);
    expect(restored.cachedAt, original.cachedAt);
  });

  test('无缓存 → read 返回 null', () async {
    when(
      () => storage.read(key: any(named: 'key')),
    ).thenAnswer((_) async => null);
    expect(await cache.read(), isNull);
  });

  test('损坏的 JSON → read 返回 null，不抛异常（C5）', () async {
    when(
      () => storage.read(key: any(named: 'key')),
    ).thenAnswer((_) async => '{ not valid json');
    expect(await cache.read(), isNull);
  });

  test('结构缺失 entitlement 字段 → read 返回 null', () async {
    when(() => storage.read(key: any(named: 'key'))).thenAnswer(
      (_) async =>
          jsonEncode({'userId': 'u1', 'cachedAt': '2026-06-22T12:00:00Z'}),
    );
    expect(await cache.read(), isNull);
  });

  test('storage 读异常 → read 返回 null 而非崩溃', () async {
    when(
      () => storage.read(key: any(named: 'key')),
    ).thenThrow(Exception('boom'));
    expect(await cache.read(), isNull);
  });

  test('clear 调用 storage.delete', () async {
    when(() => storage.delete(key: any(named: 'key'))).thenAnswer((_) async {});
    await cache.clear();
    verify(() => storage.delete(key: any(named: 'key'))).called(1);
  });
}
