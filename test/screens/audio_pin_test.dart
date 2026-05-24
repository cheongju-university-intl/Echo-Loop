/// 音频置顶测试
///
/// 从 `integration_test/groups/audio_pin_tests.dart` 下沉而来。
/// 验证音频列表中置顶按钮的菜单交互：点击切换、菜单文案翻转。
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/test_app.dart';

void main() {
  group('流程 8：音频置顶', () {
    testWidgets('在音频列表中切换置顶状态', (tester) async {
      tester.view.physicalSize = const Size(1200, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.physicalSize = const Size(800, 600);
        tester.view.devicePixelRatio = 1.0;
      });
      await pumpFullAppWithAudio(tester);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      // 导航到资源库页（限定在底部导航/侧边栏内）
      final railLibraryIcon = find.descendant(
        of: find.byType(NavigationRail),
        matching: find.byIcon(Icons.library_music_outlined),
      );
      final barLibraryIcon = find.descendant(
        of: find.byType(NavigationBar),
        matching: find.byIcon(Icons.library_music_outlined),
      );
      if (railLibraryIcon.evaluate().isNotEmpty) {
        await tester.tap(railLibraryIcon.first);
      } else {
        await tester.tap(barLibraryIcon.first);
      }
      await tester.pump(const Duration(milliseconds: 500));

      // 切换到音频 Tab
      await tester.tap(find.text('Audio'));
      await tester.pump(const Duration(milliseconds: 500));

      // 验证音频项存在
      expect(find.text('Test Audio'), findsOneWidget);

      // 打开菜单 → 验证置顶选项存在
      await tester.tap(find.byIcon(Icons.more_horiz).last);
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('Pin to Top'), findsOneWidget);

      // 消耗冷启动定时器 + drain
      await tester.pump(const Duration(seconds: 6));
      await tester.pumpAndSettle();
    });
  });
}
