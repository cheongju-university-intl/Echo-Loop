/// 音频置顶集成测试
///
/// 验证音频列表中置顶按钮的交互：点击切换、图标变化。
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/test_notifiers.dart';

/// 音频置顶相关集成测试
void audioPinTests() {
  group('流程 8：音频置顶', () {
    testWidgets('在音频列表中切换置顶状态', (tester) async {
      await tester.pumpWidget(createTestAppWithAudio());
      await tester.pumpAndSettle();

      // 导航到资源库页
      await tester.tap(find.byIcon(Icons.library_music_outlined));
      await tester.pumpAndSettle();

      // 切换到音频 Tab
      await tester.tap(find.text('Audio'));
      await tester.pumpAndSettle();

      // 验证音频项存在
      expect(find.text('Test Audio'), findsOneWidget);

      // 初始状态：push_pin_outlined 灰色图标
      expect(find.byIcon(Icons.push_pin_outlined), findsOneWidget);
      expect(find.byIcon(Icons.push_pin), findsNothing);

      // 点击置顶按钮
      await tester.tap(find.byIcon(Icons.push_pin_outlined));
      await tester.pumpAndSettle();

      // 验证置顶已切换为实心图钉
      expect(find.byIcon(Icons.push_pin), findsOneWidget);
      expect(find.byIcon(Icons.push_pin_outlined), findsNothing);

      // 再次点击取消置顶
      await tester.tap(find.byIcon(Icons.push_pin));
      await tester.pumpAndSettle();

      // 验证恢复为空心图钉
      expect(find.byIcon(Icons.push_pin_outlined), findsOneWidget);
      expect(find.byIcon(Icons.push_pin), findsNothing);
    });
  });
}
