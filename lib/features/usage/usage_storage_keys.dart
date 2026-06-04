/// SharedPreferences keys for local usage statistics.
///
/// 所有 usage 相关 key 必须以 [prefix] 开头，方便调试、备份和测试清理。
abstract final class UsageStorageKeys {
  static const prefix = 'usage_';

  static const counters = '${prefix}counters_v1';
  static const promptState = '${prefix}prompt_state_v1';
  static const lastRecordedAtMs = '${prefix}last_recorded_at_ms';
}
