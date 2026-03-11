import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'settings_provider.dart';

/// 当前时间读取函数类型。
typedef NowGetter = DateTime Function();

/// 统一的当前时间 Provider。
///
/// 正常模式使用系统时间；开启时光机后返回开发者选择的调试时间，
/// 便于验证复习解锁与任务调度逻辑。
/// 测试中可 override 为固定时间。
final nowProvider = Provider<NowGetter>((ref) {
  final timeMachineDateTime = ref.watch(
    appSettingsProvider.select((s) => s.timeMachineDateTime),
  );
  if (timeMachineDateTime != null) {
    return () => timeMachineDateTime;
  }
  return DateTime.now;
});
