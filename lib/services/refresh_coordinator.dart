import 'dart:async';

/// 通用刷新调度结果。
sealed class RefreshRun<R> {
  const RefreshRun();
}

/// 节流命中，本次没有执行真实刷新。
class RefreshThrottled<R> extends RefreshRun<R> {
  const RefreshThrottled();
}

/// 已执行真实刷新并返回业务结果。
class RefreshCompleted<R> extends RefreshRun<R> {
  final R result;

  const RefreshCompleted(this.result);
}

/// 按 key 统一处理刷新节流与 inflight 合并。
///
/// 本类只负责调度，不依赖 Riverpod / Dio / DB，也不理解业务结果。
/// 调用方负责提供最后刷新时间、真实刷新函数，以及如何应用刷新结果。
class RefreshCoordinator<K, R> {
  final DateTime Function() _now;
  final Map<K, Future<RefreshRun<R>>> _inflight = {};

  RefreshCoordinator({DateTime Function()? now}) : _now = now ?? DateTime.now;

  Future<RefreshRun<R>> run({
    required K key,
    required bool force,
    required DateTime? lastRefreshedAt,
    required Duration throttleWindow,
    required Future<R> Function() refresh,
  }) {
    final existing = _inflight[key];
    if (existing != null) return existing;

    if (!force && _isThrottled(lastRefreshedAt, throttleWindow)) {
      return Future.value(RefreshThrottled<R>());
    }

    final future = Future<R>.sync(
      refresh,
    ).then<RefreshRun<R>>(RefreshCompleted<R>.new);
    _inflight[key] = future;
    return future.whenComplete(() => _inflight.remove(key));
  }

  bool _isThrottled(DateTime? lastRefreshedAt, Duration throttleWindow) {
    if (lastRefreshedAt == null) return false;
    return _now().difference(lastRefreshedAt) < throttleWindow;
  }
}
