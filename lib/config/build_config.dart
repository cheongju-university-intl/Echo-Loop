import 'package:flutter/foundation.dart';

/// 控制是否显示开发者选项。
///
/// 默认行为：
/// - Debug / Profile：显示
/// - Release：隐藏
///
/// 可通过 `--dart-define=SHOW_DEVELOPER_OPTIONS=true/false` 覆写。
const showDeveloperOptions = bool.fromEnvironment(
  'SHOW_DEVELOPER_OPTIONS',
  defaultValue: !kReleaseMode,
);
