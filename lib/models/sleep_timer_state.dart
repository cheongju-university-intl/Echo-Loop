/// 睡眠定时器（定时停止）的运行态模型。
///
/// 这是**一次性**的内存运行态，不持久化、不进 [PlaybackSettings]：到点暂停播放后
/// 即清空，下次进入页面不会自动恢复。
library;

/// 定时器预设时长（分钟），Apple Podcasts 标准档位。
const List<int> sleepTimerPresets = [5, 10, 15, 30, 45, 60];

/// 睡眠定时器运行态。
///
/// [remaining] 为剩余时长；`null` 表示未激活（无定时）。激活后由 provider 每秒
/// 按墙钟刷新，归零时触发暂停并清空。
class SleepTimerState {
  /// 剩余时长。`null`=未激活。
  final Duration? remaining;

  /// 当前生效的预设分钟数；未激活时为 `null`。
  ///
  /// 单独存这个字段是为了让 UI 能稳定标记当前档位，而不是用剩余时间反推档位。
  final int? presetMinutes;

  const SleepTimerState({this.remaining, this.presetMinutes});

  /// 是否有定时器正在运行。
  bool get isActive => remaining != null;
}
