/// Flutter 测试全局配置
///
/// 设置统一的测试窗口大小，避免布局溢出错误。
/// 注册 ShowcaseView 控制器，解决 GuideTarget 测试失败。
library;

import 'dart:async';
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:showcaseview/showcaseview.dart';

/// 测试窗口尺寸（模拟平板/手机横向尺寸）
const _kTestWindowSize = Size(1200, 800);

Future<void> testExecutable(FutureOr<void> testMain()) async {
  final binding = TestWidgetsFlutterBinding.ensureInitialized();

  // 设置测试窗口大小
  binding.window.physicalSizeTestValue = _kTestWindowSize;
  binding.window.devicePixelRatioTestValue = 1.0;

  // 注册 ShowcaseView 控制器（测试环境全局一次）
  // ignore: unused_local_variable
  final showcase = ShowcaseView.register();

  await testMain();
}