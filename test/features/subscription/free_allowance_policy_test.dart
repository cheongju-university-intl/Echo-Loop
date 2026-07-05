import 'package:echo_loop/features/subscription/models/premium_feature.dart';
import 'package:echo_loop/features/subscription/services/free_allowance_policy.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('TrialAllowancePolicy', () {
    const feature = PremiumFeature.aiTranslation;

    test('limit 0（默认）→ 一律不放行', () {
      const policy = TrialAllowancePolicy(limits: {}, used: {});
      expect(policy.allows(feature), isFalse);
    });

    test('已用 < 配置次数 → 放行', () {
      const policy = TrialAllowancePolicy(
        limits: {feature: 3},
        used: {feature: 2},
      );
      expect(policy.allows(feature), isTrue);
    });

    test('已用 == 配置次数 → 不放行', () {
      const policy = TrialAllowancePolicy(
        limits: {feature: 3},
        used: {feature: 3},
      );
      expect(policy.allows(feature), isFalse);
    });

    test('已用 > 配置次数 → 不放行', () {
      const policy = TrialAllowancePolicy(
        limits: {feature: 1},
        used: {feature: 5},
      );
      expect(policy.allows(feature), isFalse);
    });

    test('无已用记录 + limit > 0 → 放行', () {
      const policy = TrialAllowancePolicy(limits: {feature: 1}, used: {});
      expect(policy.allows(feature), isTrue);
    });

    test('各功能额度互不影响', () {
      const policy = TrialAllowancePolicy(
        limits: {
          PremiumFeature.aiTranslation: 1,
          PremiumFeature.aiTranscription: 0,
        },
        used: {},
      );
      expect(policy.allows(PremiumFeature.aiTranslation), isTrue);
      expect(policy.allows(PremiumFeature.aiTranscription), isFalse);
    });
  });
}
