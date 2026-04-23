import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';

import 'package:fluency/models/word_timestamp.dart';
import 'package:fluency/services/native_audio_decoder.dart';
import 'package:fluency/services/subtitle_auto_align_service.dart';
import 'package:fluency/utils/srt_generator.dart';

class _FakeNativeAudioDecoder implements NativeAudioDecoder {
  final bool supported;
  final DecodedAudioData? decodedAudioData;
  final Object? error;
  final bool neverComplete;

  const _FakeNativeAudioDecoder({
    required this.supported,
    this.decodedAudioData,
    this.error,
    this.neverComplete = false,
  });

  @override
  bool get isSupported => supported;

  @override
  Future<DecodedAudioData?> decode(String audioPath) async {
    if (neverComplete) {
      return Completer<DecodedAudioData?>().future;
    }
    if (error != null) {
      throw error!;
    }
    return decodedAudioData;
  }
}

void main() {
  group('SubtitleAutoAlignService', () {
    test('遇到句边界附近静音时会微调句子起止时间', () async {
      final samples = Float32List(2000);
      for (var i = 100; i < 900; i++) {
        samples[i] = 0.5;
      }
      for (var i = 1100; i < 1900; i++) {
        samples[i] = 0.5;
      }

      final service = SubtitleAutoAlignService(
        decoder: _FakeNativeAudioDecoder(
          supported: true,
          decodedAudioData: DecodedAudioData(
            samples: samples,
            sampleRate: 1000,
          ),
        ),
      );

      final result = await service.alignIfPossible(
        audioPath: '/tmp/test.m4a',
        sentences: const [
          TranscriptSentence(
            text: 'Hello',
            startTime: Duration(milliseconds: 200),
            endTime: Duration(milliseconds: 800),
            startWordIndex: 0,
            endWordIndex: 0,
          ),
          TranscriptSentence(
            text: 'World',
            startTime: Duration(milliseconds: 1200),
            endTime: Duration(milliseconds: 1800),
            startWordIndex: 1,
            endWordIndex: 1,
          ),
        ],
        words: const [
          WordTimestamp(
            word: 'Hello',
            startTime: Duration(milliseconds: 250),
            endTime: Duration(milliseconds: 750),
            confidence: 0.9,
          ),
          WordTimestamp(
            word: 'World',
            startTime: Duration(milliseconds: 1250),
            endTime: Duration(milliseconds: 1750),
            confidence: 0.9,
          ),
        ],
      );

      expect(result, hasLength(2));
      expect(result[0].startTime, const Duration(milliseconds: 50));
      expect(result[0].endTime, const Duration(milliseconds: 1000));
      expect(result[1].startTime, const Duration(milliseconds: 1000));
      expect(result[1].endTime, const Duration(milliseconds: 1950));
    });

    test('候选区间不足 300ms 时即使未检测到静音也在中点切分', () async {
      final samples = Float32List(2000);
      for (var i = 0; i < samples.length; i++) {
        samples[i] = 0.5;
      }

      final service = SubtitleAutoAlignService(
        decoder: _FakeNativeAudioDecoder(
          supported: true,
          decodedAudioData: DecodedAudioData(
            samples: samples,
            sampleRate: 1000,
          ),
        ),
      );

      final result = await service.alignIfPossible(
        audioPath: '/tmp/test.m4a',
        sentences: const [
          TranscriptSentence(
            text: 'Hello',
            startTime: Duration(milliseconds: 200),
            endTime: Duration(milliseconds: 800),
            startWordIndex: 0,
            endWordIndex: 0,
          ),
          TranscriptSentence(
            text: 'World',
            startTime: Duration(milliseconds: 1000),
            endTime: Duration(milliseconds: 1800),
            startWordIndex: 1,
            endWordIndex: 1,
          ),
        ],
        words: const [
          WordTimestamp(
            word: 'Hello',
            startTime: Duration(milliseconds: 250),
            endTime: Duration(milliseconds: 750),
            confidence: 0.9,
          ),
          WordTimestamp(
            word: 'World',
            startTime: Duration(milliseconds: 1050),
            endTime: Duration(milliseconds: 1750),
            confidence: 0.9,
          ),
        ],
      );

      expect(result, hasLength(2));
      expect(result[0].endTime, const Duration(milliseconds: 900));
      expect(result[1].startTime, const Duration(milliseconds: 900));
    });

    test('解码器不支持时直接回退原始句边界', () async {
      final original = const [
        TranscriptSentence(
          text: 'Hello world',
          startTime: Duration(milliseconds: 200),
          endTime: Duration(milliseconds: 800),
          startWordIndex: 0,
          endWordIndex: 1,
        ),
      ];
      final service = SubtitleAutoAlignService(
        decoder: const _FakeNativeAudioDecoder(supported: false),
      );

      final result = await service.alignIfPossible(
        audioPath: '/tmp/test.m4a',
        sentences: original,
        words: const [
          WordTimestamp(
            word: 'Hello',
            startTime: Duration(milliseconds: 250),
            endTime: Duration(milliseconds: 500),
            confidence: 0.9,
          ),
          WordTimestamp(
            word: 'world',
            startTime: Duration(milliseconds: 520),
            endTime: Duration(milliseconds: 760),
            confidence: 0.9,
          ),
        ],
      );

      expect(result, same(original));
    });

    test('原生解码失败时只回退原始句边界', () async {
      final original = const [
        TranscriptSentence(
          text: 'Hello world',
          startTime: Duration(milliseconds: 200),
          endTime: Duration(milliseconds: 800),
          startWordIndex: 0,
          endWordIndex: 1,
        ),
      ];
      final service = SubtitleAutoAlignService(
        decoder: const _FakeNativeAudioDecoder(
          supported: true,
          error: NativeAudioDecoderException('decodeFailed', 'boom'),
        ),
      );

      final result = await service.alignIfPossible(
        audioPath: '/tmp/test.m4a',
        sentences: original,
        words: const [
          WordTimestamp(
            word: 'Hello',
            startTime: Duration(milliseconds: 250),
            endTime: Duration(milliseconds: 500),
            confidence: 0.9,
          ),
          WordTimestamp(
            word: 'world',
            startTime: Duration(milliseconds: 520),
            endTime: Duration(milliseconds: 760),
            confidence: 0.9,
          ),
        ],
      );

      expect(result, same(original));
    });

    test('原生解码卡住超过硬超时时回退原始句边界', () async {
      final original = const [
        TranscriptSentence(
          text: 'Hello world',
          startTime: Duration(milliseconds: 200),
          endTime: Duration(milliseconds: 800),
          startWordIndex: 0,
          endWordIndex: 1,
        ),
      ];
      final service = SubtitleAutoAlignService(
        decoder: const _FakeNativeAudioDecoder(
          supported: true,
          neverComplete: true,
        ),
        timeoutForDuration: (_) => const Duration(milliseconds: 10),
      );

      final result = await service.alignIfPossible(
        audioPath: '/tmp/test.m4a',
        sentences: original,
        words: const [
          WordTimestamp(
            word: 'Hello',
            startTime: Duration(milliseconds: 250),
            endTime: Duration(milliseconds: 500),
            confidence: 0.9,
          ),
          WordTimestamp(
            word: 'world',
            startTime: Duration(milliseconds: 520),
            endTime: Duration(milliseconds: 760),
            confidence: 0.9,
          ),
        ],
      );

      expect(result, same(original));
    });

    test('缺少可用词边界时直接回退原始句边界', () async {
      final original = const [
        TranscriptSentence(
          text: 'Hello world',
          startTime: Duration(milliseconds: 200),
          endTime: Duration(milliseconds: 800),
        ),
      ];
      final service = SubtitleAutoAlignService(
        decoder: _FakeNativeAudioDecoder(
          supported: true,
          decodedAudioData: DecodedAudioData(
            samples: Float32List(100),
            sampleRate: 1000,
          ),
        ),
      );

      final result = await service.alignIfPossible(
        audioPath: '/tmp/test.m4a',
        sentences: original,
        words: const [
          WordTimestamp(
            word: 'Hello',
            startTime: Duration(milliseconds: 250),
            endTime: Duration(milliseconds: 500),
            confidence: 0.9,
          ),
        ],
      );

      expect(result, same(original));
    });
  });
}
