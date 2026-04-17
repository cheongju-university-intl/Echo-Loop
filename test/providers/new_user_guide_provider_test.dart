import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fluency/providers/new_user_guide_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('GuideRegistry', () {
    test('每个 flow 独立保存 seen 状态', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final registry = GuideRegistry(prefs: prefs);

      expect(await registry.isSeen('library'), isFalse);
      expect(await registry.isSeen('learning_plan_no_transcript'), isFalse);

      await registry.markSeen('library');

      expect(await registry.isSeen('library'), isTrue);
      expect(await registry.isSeen('learning_plan_no_transcript'), isFalse);
    });

    test('reset 只清除指定 flow', () async {
      SharedPreferences.setMockInitialValues({
        'guide_v1_library_seen': true,
        'guide_v1_collection_detail_seen': true,
      });
      final prefs = await SharedPreferences.getInstance();
      final registry = GuideRegistry(prefs: prefs);

      await registry.reset('library');

      expect(await registry.isSeen('library'), isFalse);
      expect(await registry.isSeen('collection_detail'), isTrue);
    });
  });

  group('GuideController', () {
    test('按 flow 内 step 顺序推进并只标记当前 flow seen', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final registry = GuideRegistry(prefs: prefs);
      final container = ProviderContainer(
        overrides: [guideRegistryProvider.overrideWithValue(registry)],
      );
      addTearDown(container.dispose);

      final controller = container.read(guideControllerProvider.notifier);
      final started = await controller.startFlow(
        flowId: 'learning_plan_no_transcript',
        targetIds: const ['add_subtitle', 'ai_transcription'],
      );

      expect(started, isTrue);
      expect(
        container.read(guideControllerProvider).activeTargetId,
        'add_subtitle',
      );

      await controller.advanceActiveFlow();
      expect(
        container.read(guideControllerProvider).activeTargetId,
        'ai_transcription',
      );

      await controller.advanceActiveFlow();
      expect(container.read(guideControllerProvider).isActive, isFalse);
      expect(await registry.isSeen('learning_plan_no_transcript'), isTrue);
      expect(await registry.isSeen('learning_plan_with_transcript'), isFalse);
    });

    test('中途 completeActiveFlow 标记已看并清空（兜底路径依赖）', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final registry = GuideRegistry(prefs: prefs);
      final container = ProviderContainer(
        overrides: [guideRegistryProvider.overrideWithValue(registry)],
      );
      addTearDown(container.dispose);

      final controller = container.read(guideControllerProvider.notifier);
      await controller.startFlow(
        flowId: 'stuck_flow',
        targetIds: const ['step1', 'step2', 'step3'],
      );
      expect(
        container.read(guideControllerProvider).activeTargetId,
        'step1',
      );

      // 在第一步就 complete（模拟 target 起不来的兜底场景）
      await controller.completeActiveFlow();

      expect(container.read(guideControllerProvider).isActive, isFalse);
      expect(await registry.isSeen('stuck_flow'), isTrue);
    });

    test('已 seen 的 flow 不再启动', () async {
      SharedPreferences.setMockInitialValues({'guide_v1_library_seen': true});
      final prefs = await SharedPreferences.getInstance();
      final registry = GuideRegistry(prefs: prefs);
      final container = ProviderContainer(
        overrides: [guideRegistryProvider.overrideWithValue(registry)],
      );
      addTearDown(container.dispose);

      final started = await container
          .read(guideControllerProvider.notifier)
          .startFlow(flowId: 'library', targetIds: const ['create']);

      expect(started, isFalse);
      expect(container.read(guideControllerProvider).isActive, isFalse);
    });
  });
}
