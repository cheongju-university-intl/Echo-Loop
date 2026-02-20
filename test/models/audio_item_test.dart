import 'package:flutter_test/flutter_test.dart';
import 'package:fluency/models/audio_item.dart';

void main() {
  group('AudioItem', () {
    final now = DateTime(2026, 1, 15, 10, 30);

    AudioItem createSample({
      String? transcriptPath = 'transcripts/test.srt',
      int totalDuration = 120,
    }) {
      return AudioItem(
        id: 'audio-1',
        name: '测试音频',
        audioPath: 'audios/test.mp3',
        transcriptPath: transcriptPath,
        addedDate: now,
        totalDuration: totalDuration,
      );
    }

    group('toJson / fromJson 往返序列化', () {
      test('完整字段往返一致', () {
        final item = createSample();
        final json = item.toJson();
        final restored = AudioItem.fromJson(json);

        expect(restored.id, item.id);
        expect(restored.name, item.name);
        expect(restored.audioPath, item.audioPath);
        expect(restored.transcriptPath, item.transcriptPath);
        expect(restored.addedDate, item.addedDate);
        expect(restored.totalDuration, item.totalDuration);
      });

      test('transcriptPath 为 null 时往返一致', () {
        final item = createSample(transcriptPath: null);
        final json = item.toJson();
        final restored = AudioItem.fromJson(json);

        expect(restored.transcriptPath, isNull);
      });
    });

    group('copyWith', () {
      test('部分字段覆盖', () {
        final item = createSample();
        final copied = item.copyWith(name: '新名称', totalDuration: 300);

        expect(copied.name, '新名称');
        expect(copied.totalDuration, 300);
        // 未修改的字段保持不变
        expect(copied.id, item.id);
        expect(copied.audioPath, item.audioPath);
        expect(copied.transcriptPath, item.transcriptPath);
        expect(copied.addedDate, item.addedDate);
      });

      test('不传参数时保持原值', () {
        final item = createSample();
        final copied = item.copyWith();

        expect(copied.id, item.id);
        expect(copied.name, item.name);
      });
    });

    group('hasTranscript', () {
      test('有 transcriptPath 时返回 true', () {
        final item = createSample(transcriptPath: 'transcripts/test.srt');
        expect(item.hasTranscript, isTrue);
      });

      test('transcriptPath 为 null 时返回 false', () {
        final item = createSample(transcriptPath: null);
        expect(item.hasTranscript, isFalse);
      });

      test('transcriptPath 为空字符串时返回 false', () {
        final item = createSample(transcriptPath: '');
        expect(item.hasTranscript, isFalse);
      });
    });

    test('fromJson 处理缺失 totalDuration 字段（默认 0）', () {
      final json = {
        'id': 'audio-1',
        'name': '测试',
        'audioPath': 'audios/test.mp3',
        'transcriptPath': null,
        'addedDate': now.toIso8601String(),
        // 无 totalDuration
      };
      final item = AudioItem.fromJson(json);
      expect(item.totalDuration, 0);
    });
  });
}
