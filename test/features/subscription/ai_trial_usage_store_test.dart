import 'package:echo_loop/features/subscription/models/premium_feature.dart';
import 'package:echo_loop/features/subscription/services/ai_trial_usage_store.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AiTrialUsageStore（内存）', () {
    test('空存储读取返回空', () {
      final store = AiTrialUsageStore.memory();
      expect(store.load('u1'), isEmpty);
    });

    test('写入后按用户读取', () async {
      final store = AiTrialUsageStore.memory();
      await store.save('u1', {
        PremiumFeature.aiTranslation: 2,
        PremiumFeature.aiTranscription: 1,
      });

      final loaded = store.load('u1');
      expect(loaded[PremiumFeature.aiTranslation], 2);
      expect(loaded[PremiumFeature.aiTranscription], 1);
    });

    test('用户间相互隔离', () async {
      final store = AiTrialUsageStore.memory();
      await store.save('u1', {PremiumFeature.aiAnalysis: 3});
      await store.save('u2', {PremiumFeature.aiAnalysis: 5});

      expect(store.load('u1')[PremiumFeature.aiAnalysis], 3);
      expect(store.load('u2')[PremiumFeature.aiAnalysis], 5);
      expect(store.load('u3'), isEmpty);
    });

    test('0 次不持久化（视为缺省）', () async {
      final store = AiTrialUsageStore.memory();
      await store.save('u1', {PremiumFeature.aiTranslation: 0});
      expect(store.load('u1'), isEmpty);
    });

    test('覆盖写：同用户重写整体替换', () async {
      final store = AiTrialUsageStore.memory();
      await store.save('u1', {PremiumFeature.aiTranslation: 2});
      await store.save('u1', {PremiumFeature.aiTranslation: 4});
      expect(store.load('u1')[PremiumFeature.aiTranslation], 4);
    });
  });
}
