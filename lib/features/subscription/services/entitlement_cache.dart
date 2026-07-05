/// 权益本地缓存（secure_storage）。
///
/// entitlement 真相在后端，本地只缓存「最近一次对账结果」用于离线兜底与冷启动 seed。
/// 用 [FlutterSecureStorage] 而非 SharedPreferences，是为了抗 root / 越狱用户直接篡改
/// 解锁（防破解）。缓存仅作乐观兜底，联网后一律以在线权威源覆盖（见对账逻辑 C4）。
library;

import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../models/entitlement.dart';

/// 缓存键（带版本号，未来结构变更可平滑升级）。
const _entitlementCacheKey = 'entitlement_cache_v1';

/// 带元信息的缓存快照。
class CachedEntitlement {
  /// 缓存归属的用户 ID（Supabase user.id，匿名为 null）。
  ///
  /// 与当前登录用户不一致时缓存视为无效（防止上个账号的权益泄漏给新账号）。
  final String? userId;

  /// 权益快照。
  final Entitlement entitlement;

  /// 落盘时刻（UTC）。用于判断缓存是否在新鲜窗口内（C4）。
  final DateTime cachedAt;

  const CachedEntitlement({
    required this.userId,
    required this.entitlement,
    required this.cachedAt,
  });

  Map<String, dynamic> toJson() => {
    'userId': userId,
    'entitlement': entitlement.toJson(),
    'cachedAt': cachedAt.toIso8601String(),
  };

  factory CachedEntitlement.fromJson(Map<String, dynamic> json) {
    final rawEntitlement = json['entitlement'];
    if (rawEntitlement is! Map) {
      throw const FormatException('缺少 entitlement 字段');
    }
    final rawCachedAt = json['cachedAt'];
    final cachedAt = rawCachedAt is String
        ? DateTime.tryParse(rawCachedAt)
        : null;
    if (cachedAt == null) {
      throw const FormatException('cachedAt 非法');
    }
    return CachedEntitlement(
      userId: json['userId'] is String ? json['userId'] as String : null,
      entitlement: Entitlement.fromJson(
        Map<String, dynamic>.from(rawEntitlement),
      ),
      cachedAt: cachedAt,
    );
  }
}

/// 权益缓存读写。副作用（secure_storage）通过构造注入，便于测试替换。
class EntitlementCache {
  EntitlementCache({
    FlutterSecureStorage storage = const FlutterSecureStorage(),
  }) : _storage = storage;

  final FlutterSecureStorage _storage;

  /// 读取缓存。无缓存或解析失败时返回 null（解析失败回退「未知」，绝不抛出 / 崩溃，C5）。
  Future<CachedEntitlement?> read() async {
    String? raw;
    try {
      raw = await _storage.read(key: _entitlementCacheKey);
    } catch (_) {
      // secure_storage 读失败（如平台异常）：当作无缓存处理。
      return null;
    }
    if (raw == null || raw.isEmpty) return null;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return null;
      return CachedEntitlement.fromJson(Map<String, dynamic>.from(decoded));
    } catch (_) {
      // 缓存损坏：当作无缓存，回退到在线源。
      return null;
    }
  }

  /// 写入缓存。
  Future<void> write(CachedEntitlement cached) async {
    await _storage.write(
      key: _entitlementCacheKey,
      value: jsonEncode(cached.toJson()),
    );
  }

  /// 清除缓存（登出 / 切换用户时调用）。
  Future<void> clear() async {
    await _storage.delete(key: _entitlementCacheKey);
  }
}

/// 权益缓存 Provider（测试可 override 注入内存 / mock secure_storage）。
final entitlementCacheProvider = Provider<EntitlementCache>((ref) {
  return EntitlementCache();
});
