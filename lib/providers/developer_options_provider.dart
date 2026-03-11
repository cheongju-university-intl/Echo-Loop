import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../config/build_config.dart';

/// 开发者选项显隐 Provider。
///
/// 通过单独的 Provider 包装编译期常量，便于 Widget 测试中按场景覆盖。
final showDeveloperOptionsProvider = Provider<bool>((ref) {
  return showDeveloperOptions;
});
