/// AI 免费试用次数的本地持久化层（用户级、永久累计）。
///
/// 按 `userId` + [PremiumFeature] 记录某用户某功能**已使用**的免费试用次数，
/// 永久累计、不随时间重置。仅做本地预测性计数（C1：最终配额裁决在后端，Phase 1）。
///
/// 存储形态：单个 JSON `{ userId: { featureName: count } }`。匿名用户不计数
/// （未登录一律锁定，不消耗试用，见 feature_access_provider 第一层）。
library;

import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../../services/app_logger.dart';
import '../models/premium_feature.dart';

/// AI 试用次数读写。只负责持久化，不含产品规则（额度判定在策略层）。
class AiTrialUsageStore {
  AiTrialUsageStore(this._prefs);

  /// 内存替身（测试用，无磁盘）。
  AiTrialUsageStore.memory() : _prefs = null;

  final SharedPreferences? _prefs;

  /// 内存态（无 SP 时）。
  Map<String, Map<String, int>> _memory = {};

  static const String _key = 'ai_trial_usage_v1';

  /// 读取某用户各功能的已用次数（缺省空）。
  Map<PremiumFeature, int> load(String userId) {
    final all = _readAll();
    final forUser = all[userId];
    if (forUser == null) return const {};
    final result = <PremiumFeature, int>{};
    for (final feature in PremiumFeature.values) {
      final count = forUser[feature.name];
      if (count is int && count > 0) result[feature] = count;
    }
    return result;
  }

  /// 将某用户的已用次数写盘（整体覆盖该用户分片）。
  Future<void> save(String userId, Map<PremiumFeature, int> counts) async {
    final all = _readAll();
    all[userId] = {
      for (final entry in counts.entries)
        if (entry.value > 0) entry.key.name: entry.value,
    };
    await _writeAll(all);
  }

  Map<String, Map<String, int>> _readAll() {
    final prefs = _prefs;
    if (prefs == null) return _deepCopy(_memory);
    final raw = prefs.getString(_key);
    if (raw == null || raw.isEmpty) return {};
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map) {
        final result = <String, Map<String, int>>{};
        decoded.forEach((userId, value) {
          if (userId is String && value is Map) {
            final inner = <String, int>{};
            value.forEach((k, v) {
              if (k is String && v is int) inner[k] = v;
            });
            result[userId] = inner;
          }
        });
        return result;
      }
    } catch (e) {
      AppLogger.log('AiTrialUsage', '解析失败，回退空: $e');
    }
    return {};
  }

  Future<void> _writeAll(Map<String, Map<String, int>> all) async {
    final prefs = _prefs;
    if (prefs == null) {
      _memory = _deepCopy(all);
      return;
    }
    await prefs.setString(_key, jsonEncode(all));
  }

  Map<String, Map<String, int>> _deepCopy(Map<String, Map<String, int>> src) {
    return {for (final e in src.entries) e.key: Map<String, int>.from(e.value)};
  }
}
