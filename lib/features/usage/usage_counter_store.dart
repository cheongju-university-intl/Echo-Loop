import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../services/app_logger.dart';
import 'usage_counters.dart';
import 'usage_storage_keys.dart';

/// 本地 usage counter 持久化层。
///
/// 只负责读写 SharedPreferences，不上报 analytics，也不包含产品规则判断。
class UsageCounterStore {
  UsageCounterStore(this._prefs);

  UsageCounterStore.memory() : _prefs = null;

  final SharedPreferences? _prefs;
  UsageCounters _memoryCounters = const UsageCounters();

  UsageCounters loadCounters() {
    final prefs = _prefs;
    if (prefs == null) return _memoryCounters;

    final raw = prefs.getString(UsageStorageKeys.counters);
    if (raw == null || raw.isEmpty) return const UsageCounters();
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map<String, Object?>) {
        return UsageCounters.fromJson(decoded);
      }
      if (decoded is Map) {
        return UsageCounters.fromJson(Map<String, Object?>.from(decoded));
      }
    } catch (e) {
      AppLogger.log('Usage', 'Failed to decode counters: $e');
    }
    return const UsageCounters();
  }

  Future<void> saveCounters(UsageCounters counters) async {
    final prefs = _prefs;
    if (prefs == null) {
      _memoryCounters = counters;
      return;
    }

    await prefs.setString(UsageStorageKeys.counters, jsonEncode(counters));
    await prefs.setInt(
      UsageStorageKeys.lastRecordedAtMs,
      DateTime.now().millisecondsSinceEpoch,
    );
  }

  Future<void> resetForTests() async {
    final prefs = _prefs;
    if (prefs == null) {
      _memoryCounters = const UsageCounters();
      return;
    }

    final keys = prefs
        .getKeys()
        .where((key) => key.startsWith(UsageStorageKeys.prefix))
        .toList();
    for (final key in keys) {
      await prefs.remove(key);
    }
  }
}
