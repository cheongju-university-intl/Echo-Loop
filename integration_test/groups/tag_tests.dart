/// 标签管理集成测试
///
/// 验证标签的创建、关联音频、显示标签 chips、删除标签等管理流程。
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/test_notifiers.dart';

/// 标签管理相关集成测试
void tagTests() {
  group('流程 9：标签管理', () {
    testWidgets('创建标签并关联音频后显示彩色 chip', (tester) async {
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

      // 打开弹出菜单
      await tester.tap(find.byType(PopupMenuButton<String>));
      await tester.pumpAndSettle();

      // 点击"管理标签"
      await tester.tap(find.text('Manage Tags'));
      await tester.pumpAndSettle();

      // BottomSheet 应出现 — 显示空状态文本
      expect(find.text('No tags yet'), findsOneWidget);

      // 点击"创建标签"
      await tester.tap(find.text('Create Tag'));
      await tester.pumpAndSettle();

      // 输入标签名称
      await tester.enterText(find.byType(TextField), 'Business English');
      await tester.pumpAndSettle();

      // 点击添加按钮
      await tester.tap(find.text('Add'));
      await tester.pumpAndSettle();

      // 即时生效 — 标签自动创建并关联
      // 标签在 Sheet 列表中显示且自动勾选
      final checkbox = tester.widget<CheckboxListTile>(
        find.byType(CheckboxListTile),
      );
      expect(checkbox.value, isTrue);

      // 关闭 BottomSheet — 点击 Sheet 外部（屏幕顶部 scrim 区域）
      final size = tester.view.physicalSize / tester.view.devicePixelRatio;
      await tester.tapAt(Offset(size.width / 2, 10));
      await tester.pumpAndSettle();

      // 返回音频列表 — 应能看到彩色标签 chip
      expect(find.text('Business English'), findsOneWidget);
    });

    testWidgets('删除标签后从列表和音频中移除', (tester) async {
      await tester.pumpWidget(createTestAppWithAudio());
      await tester.pumpAndSettle();

      // 导航到资源库页 → 音频 Tab
      await tester.tap(find.byIcon(Icons.library_music_outlined));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Audio'));
      await tester.pumpAndSettle();

      // 打开管理标签 Sheet
      await tester.tap(find.byType(PopupMenuButton<String>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Manage Tags'));
      await tester.pumpAndSettle();

      // 先创建一个标签
      await tester.tap(find.text('Create Tag'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'ToDelete');
      await tester.pumpAndSettle();
      await tester.tap(find.text('Add'));
      await tester.pumpAndSettle();

      // 标签已创建且关联
      expect(find.text('ToDelete'), findsAtLeast(1));

      // 点击删除按钮
      await tester.tap(find.byIcon(Icons.delete_outline));
      await tester.pumpAndSettle();

      // 确认对话框应出现
      expect(find.text('Delete Tag'), findsOneWidget);

      // 确认删除
      await tester.tap(find.text('Delete'));
      await tester.pumpAndSettle();

      // Sheet 内标签消失，回到空状态
      expect(find.text('No tags yet'), findsOneWidget);

      // 关闭 BottomSheet
      final size = tester.view.physicalSize / tester.view.devicePixelRatio;
      await tester.tapAt(Offset(size.width / 2, 10));
      await tester.pumpAndSettle();

      // 音频列表上也不再有标签 chip
      expect(find.text('ToDelete'), findsNothing);
    });
  });
}
