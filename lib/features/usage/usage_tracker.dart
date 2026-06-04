import '../../analytics/analytics_service.dart';
import '../../services/app_logger.dart';
import 'usage_counter_store.dart';
import 'usage_counters.dart';
import 'usage_event.dart';

/// 统一使用统计入口。
///
/// 本地计数不受 analytics consent 影响；远端上报仍由 [AnalyticsService]
/// 自己处理 consent 和异常，避免统计失败影响主业务。
class UsageTracker {
  UsageTracker({
    required UsageCounterStore store,
    required AnalyticsService analytics,
  }) : _store = store,
       _analytics = analytics;

  final UsageCounterStore _store;
  final AnalyticsService _analytics;

  UsageCounters loadCounters() => _store.loadCounters();

  Future<void> record(
    UsageEvent event, {
    Map<String, Object>? analyticsParams,
  }) async {
    try {
      final next = _store.loadCounters().increment(event);
      await _store.saveCounters(next);
    } catch (e) {
      AppLogger.log('Usage', 'Failed to record local counter: $e');
    }
    await _analytics.track(event.analyticsName, analyticsParams);
  }

  Future<void> resetForTests() => _store.resetForTests();
}
