/// ASR 引擎端到端集成测试。
///
/// 使用已下载的 Whisper Tiny.en int8 模型对测试 WAV 文件做转录，
/// 验证 sherpa-onnx 引擎的完整流程：初始化 → 转录 → 结果校验。
///
/// 运行方式：flutter test integration_test/asr_engine_test.dart -d macos
library;

import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'package:fluency/services/asr/offline_asr_engine.dart';
import 'package:fluency/services/asr/sherpa_onnx_engine.dart';

/// 测试 WAV 固件路径（运行时从 asset 复制到 sandbox tmp）。
late String _testWav;

const _whisperTinyModel = AsrModelInfo(
  id: 'whisper-tiny-en-int8',
  displayName: 'Whisper Tiny.en',
  type: AsrModelType.whisper,
  fileSizeBytes: 0,
);

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  late String modelDir;
  late bool modelExists;

  setUpAll(() async {
    final appDir = await getApplicationSupportDirectory();
    modelDir = '${appDir.path}/asr-models/whisper-tiny-en-int8';
    modelExists = Directory(modelDir).existsSync();

    // 下载测试 WAV 到 sandbox tmp（避免打包进 release 产物）。
    final tmpDir = await getTemporaryDirectory();
    final wavDest = File(p.join(tmpDir.path, '8k.wav'));
    if (!wavDest.existsSync()) {
      final client = HttpClient();
      final request = await client.getUrl(
        Uri.parse(
          'https://huggingface.co/csukuangfj/sherpa-onnx-whisper-tiny.en'
          '/resolve/main/test_wavs/8k.wav',
        ),
      );
      final response = await request.close();
      final sink = wavDest.openWrite();
      await response.pipe(sink);
      client.close();
    }
    _testWav = wavDest.path;
  });

  group('SherpaOnnxEngine 端到端', () {
    testWidgets('Whisper Tiny 转录 8k.wav', (tester) async {
      if (!modelExists) {
        markTestSkipped('模型未下载：$modelDir');
        return;
      }
      if (!File(_testWav).existsSync()) {
        markTestSkipped('测试 WAV 不存在：$_testWav');
        return;
      }

      final engine = SherpaOnnxEngine();

      // 初始化（加载模型，首次较慢）。
      await engine.initialize(
        AsrModelConfig(model: _whisperTinyModel, modelDir: modelDir),
      );
      expect(engine.isReady, isTrue);

      // 第一次转录。
      final result1 = await engine.transcribe(_testWav);
      debugPrint('[ASR Test] text="${result1.text}"');
      debugPrint(
        '[ASR Test] inferenceTime=${result1.inferenceTime.inMilliseconds}ms',
      );

      expect(result1.text, isNotEmpty);
      expect(result1.text.toLowerCase(), contains('hester'));
      expect(result1.inferenceTime.inMilliseconds, greaterThan(0));

      // 第二次转录（Recognizer 已驻留，应更快）。
      final result2 = await engine.transcribe(_testWav);
      debugPrint(
        '[ASR Test] second run: ${result2.inferenceTime.inMilliseconds}ms',
      );

      expect(result2.text, isNotEmpty);
      expect(result2.text.toLowerCase(), contains('hester'));

      await engine.dispose();
      expect(engine.isReady, isFalse);
    });
  });
}

/// 标记测试跳过（集成测试中无法用 skip 参数）。
void markTestSkipped(String reason) {
  debugPrint('SKIPPED: $reason');
}
