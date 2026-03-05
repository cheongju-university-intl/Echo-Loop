/// 可控倒计时控制器
///
/// 支持暂停/恢复/加速，替代 Timer + Future.delayed 的简单倒计时。
/// 倒计时结束时 [start] 返回的 Future 自动 complete。
///
/// 使用场景：精听/跟读/复述/难句补练的句间/遍间停顿。
library;

import 'dart:async';

/// 可控倒计时控制器
class CountdownController {
  Timer? _timer;
  Completer<void>? _completer;

  /// 总时长
  Duration _total = Duration.zero;

  /// 暂停前已累积的有效时间
  Duration _accumulated = Duration.zero;

  /// 当前运行段的起始时间
  DateTime? _runStart;

  /// 速度倍率（1.0=正常，10.0=快进）
  double _speed = 1.0;

  /// 是否暂停中
  bool _paused = false;

  /// 倒计时 tick 回调（每次 tick 传入剩余时间）
  void Function(Duration remaining)? _onTick;

  /// 是否有活跃的倒计时
  bool get isActive => _timer != null;

  /// 是否暂停中
  bool get isPaused => _paused;

  /// 当前速度倍率
  double get speed => _speed;

  /// 启动倒计时，返回在倒计时结束或取消时 complete 的 Future
  ///
  /// [total] 倒计时总时长
  /// [onTick] 每 100ms 回调一次，传入剩余时间
  Future<void> start(Duration total, void Function(Duration remaining) onTick) {
    cancel();
    _total = total;
    _accumulated = Duration.zero;
    _runStart = DateTime.now();
    _speed = 1.0;
    _paused = false;
    _onTick = onTick;
    _completer = Completer<void>();

    _timer = Timer.periodic(const Duration(milliseconds: 100), (_) => _tick());

    return _completer!.future;
  }

  /// 暂停倒计时
  void pause() {
    if (_paused || _runStart == null || !isActive) return;
    _saveCurrentRun();
    _paused = true;
  }

  /// 恢复倒计时
  void resume() {
    if (!_paused || !isActive) return;
    _runStart = DateTime.now();
    _paused = false;
  }

  /// 设置速度倍率（切换时保存当前进度）
  void setSpeed(double speed) {
    if (!isActive) return;
    if (!_paused) {
      _saveCurrentRun();
      _runStart = DateTime.now();
    }
    _speed = speed;
  }

  /// 取消倒计时（会 complete 返回的 Future，但不触发 onTick）
  void cancel() {
    _timer?.cancel();
    _timer = null;
    _onTick = null;
    if (_completer != null && !_completer!.isCompleted) {
      _completer!.complete();
    }
    _completer = null;
    _paused = false;
    _speed = 1.0;
    _runStart = null;
    _accumulated = Duration.zero;
  }

  /// 每 100ms 触发一次
  void _tick() {
    if (_paused || _runStart == null) return;

    final currentRun = DateTime.now().difference(_runStart!);
    final scaledCurrent = _scale(currentRun, _speed);
    final totalElapsed = _accumulated + scaledCurrent;
    final remaining = _total - totalElapsed;

    if (remaining <= Duration.zero) {
      _timer?.cancel();
      _timer = null;
      _onTick?.call(Duration.zero);
      _onTick = null;
      if (_completer != null && !_completer!.isCompleted) {
        _completer!.complete();
      }
      _completer = null;
      return;
    }
    _onTick?.call(remaining);
  }

  /// 保存当前运行段的已累积时间
  void _saveCurrentRun() {
    if (_runStart == null) return;
    final currentRun = DateTime.now().difference(_runStart!);
    _accumulated += _scale(currentRun, _speed);
  }

  /// 缩放 Duration
  static Duration _scale(Duration d, double factor) {
    return Duration(microseconds: (d.inMicroseconds * factor).round());
  }
}
