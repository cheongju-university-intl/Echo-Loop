// audio_content_check 纯逻辑单元测试
//
// 只测纯函数 isWaveformSilent；evaluateAudioContent 依赖真机解码（just_audio /
// just_waveform），属平台相关，留集成/手动验证。

import 'package:flutter_test/flutter_test.dart';
import 'package:echo_loop/utils/audio_content_check.dart';

void main() {
  group('isWaveformSilent', () {
    test('全零样本判为静音', () {
      final samples = List<int>.filled(100, 0);
      expect(isWaveformSilent(samples, bits: 16), isTrue);
    });

    test('含接近满量程峰值的样本判为非静音', () {
      final samples = List<int>.filled(100, 0)..[50] = 30000; // 接近 32768
      expect(isWaveformSilent(samples, bits: 16), isFalse);
    });

    test('峰值低于阈值（满量程 3%）判为静音', () {
      // 16bit 满量程 32768，3% ≈ 983；取 500 < 阈值
      final samples = List<int>.filled(100, 0)..[10] = 500;
      expect(isWaveformSilent(samples, bits: 16), isTrue);
    });

    test('峰值刚好高于阈值判为非静音', () {
      // 32768 * 0.03 = 983.04，取 1000 > 阈值
      final samples = List<int>.filled(100, 0)..[10] = 1000;
      expect(isWaveformSilent(samples, bits: 16), isFalse);
    });

    test('负向峰值取绝对值同样生效', () {
      final samples = List<int>.filled(100, 0)..[10] = -30000;
      expect(isWaveformSilent(samples, bits: 16), isFalse);
    });

    test('空样本无法判定返回 false（不过度标记）', () {
      expect(isWaveformSilent(const [], bits: 16), isFalse);
    });

    test('8bit 满量程按 128 计算', () {
      // 8bit 满量程 128，3% ≈ 3.84；峰值 2 < 阈值 → 静音
      expect(isWaveformSilent([0, 2, -1], bits: 8), isTrue);
      // 峰值 100 > 阈值 → 非静音
      expect(isWaveformSilent([0, 100], bits: 8), isFalse);
    });

    test('自定义阈值生效', () {
      final samples = List<int>.filled(10, 0)..[0] = 5000; // 约 15% 满量程
      // 默认 3% → 非静音
      expect(isWaveformSilent(samples, bits: 16), isFalse);
      // 阈值提到 20% → 判为静音
      expect(isWaveformSilent(samples, bits: 16, threshold: 0.2), isTrue);
    });
  });
}
