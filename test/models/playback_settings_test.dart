import 'package:flutter_test/flutter_test.dart';
import 'package:echo_loop/models/playback_settings.dart';

void main() {
  group('PlaybackSettings', () {
    group('默认值正确性', () {
      test('所有默认值符合预期', () {
        const settings = PlaybackSettings();

        expect(settings.loopWhole, isFalse);
        expect(settings.wholeLoopCount, 3);
        expect(settings.wholeInterval, const Duration(seconds: 3));
        expect(settings.loopSentence, isFalse);
        expect(settings.sentenceLoopCount, 3);
        expect(settings.sentenceInterval, const Duration(seconds: 2));
        expect(settings.playbackSpeed, 1.0);
        expect(settings.singleSentenceMode, isFalse);
        expect(settings.showTranscript, isTrue);
        expect(settings.isInfiniteWhole, isFalse);
        expect(settings.isInfiniteSentence, isFalse);
      });
    });

    group('toJson / fromJson 往返序列化', () {
      test('循环开关不持久化：往返后恒为关', () {
        const settings = PlaybackSettings(
          loopWhole: true,
          loopSentence: true,
          playbackSpeed: 1.5,
        );
        final restored = PlaybackSettings.fromJson(settings.toJson());

        // 开关不落盘，还原后一律为关
        expect(restored.loopWhole, isFalse);
        expect(restored.loopSentence, isFalse);
      });

      test('toJson 不含循环开关键，但含循环参数键', () {
        const settings = PlaybackSettings(loopWhole: true, loopSentence: true);
        final json = settings.toJson();

        expect(json.containsKey('loopWhole'), isFalse);
        expect(json.containsKey('loopSentence'), isFalse);
        expect(json.containsKey('wholeLoopCount'), isTrue);
        expect(json.containsKey('sentenceLoopCount'), isTrue);
        expect(json.containsKey('wholeInterval'), isTrue);
        expect(json.containsKey('sentenceInterval'), isTrue);
      });

      test('循环参数与其他偏好往返保留', () {
        const settings = PlaybackSettings(
          wholeLoopCount: 5,
          wholeInterval: Duration(seconds: 4),
          sentenceLoopCount: 2,
          sentenceInterval: Duration(seconds: 1),
          playbackSpeed: 1.5,
          singleSentenceMode: true,
          showTranscript: false,
        );
        final restored = PlaybackSettings.fromJson(settings.toJson());

        expect(restored.wholeLoopCount, settings.wholeLoopCount);
        expect(restored.wholeInterval, settings.wholeInterval);
        expect(restored.sentenceLoopCount, settings.sentenceLoopCount);
        expect(restored.sentenceInterval, settings.sentenceInterval);
        expect(restored.playbackSpeed, settings.playbackSpeed);
        expect(restored.singleSentenceMode, settings.singleSentenceMode);
        expect(restored.showTranscript, settings.showTranscript);
      });

      test('间隔以毫秒序列化', () {
        const settings = PlaybackSettings(
          wholeInterval: Duration(seconds: 5),
          sentenceInterval: Duration(seconds: 3),
        );
        final json = settings.toJson();
        expect(json['wholeInterval'], 5000);
        expect(json['sentenceInterval'], 3000);
      });

      test('循环次数 0（∞）作为参数往返保留', () {
        const settings = PlaybackSettings(
          wholeLoopCount: 0,
          sentenceLoopCount: 0,
        );
        final restored = PlaybackSettings.fromJson(settings.toJson());
        expect(restored.wholeLoopCount, 0);
        expect(restored.sentenceLoopCount, 0);
      });
    });

    group('旧字段兼容（开关不恢复，仅迁移参数）', () {
      test('旧 repeatMode=one 仅迁移单句循环参数，开关恒关', () {
        final settings = PlaybackSettings.fromJson({
          'repeatMode': 'one',
          'loopCount': 5,
          'pauseInterval': 4000,
        });
        expect(settings.sentenceLoopCount, 5);
        expect(settings.sentenceInterval, const Duration(seconds: 4));
        expect(settings.loopSentence, isFalse);
        expect(settings.loopWhole, isFalse);
      });

      test('旧 repeatMode=all 不再开启整篇循环', () {
        final settings = PlaybackSettings.fromJson({'repeatMode': 'all'});
        expect(settings.loopWhole, isFalse);
        expect(settings.loopSentence, isFalse);
      });

      test('旧 repeatMode=off 两者皆关', () {
        final settings = PlaybackSettings.fromJson({'repeatMode': 'off'});
        expect(settings.loopWhole, isFalse);
        expect(settings.loopSentence, isFalse);
      });

      test('更旧 loopEnabled=true 不再开启循环', () {
        final settings = PlaybackSettings.fromJson({'loopEnabled': true});
        expect(settings.loopSentence, isFalse);
        expect(settings.loopWhole, isFalse);
      });

      test('更旧 loopAudioEnabled=true 不再开启循环', () {
        final settings = PlaybackSettings.fromJson({'loopAudioEnabled': true});
        expect(settings.loopWhole, isFalse);
        expect(settings.loopSentence, isFalse);
      });

      test('迁移时旧 loopCount 超范围截断到 10', () {
        final settings = PlaybackSettings.fromJson({
          'repeatMode': 'one',
          'loopCount': 18,
        });
        expect(settings.sentenceLoopCount, 10);
      });

      test('仅含参数键的 JSON 被识别为新 schema，参数保留', () {
        final settings = PlaybackSettings.fromJson({
          'wholeLoopCount': 4,
          'sentenceLoopCount': 2,
        });
        expect(settings.wholeLoopCount, 4);
        expect(settings.sentenceLoopCount, 2);
        expect(settings.loopWhole, isFalse);
        expect(settings.loopSentence, isFalse);
      });
    });

    group('fromJson 范围校验', () {
      test('次数 = 0 解析为 0（∞ 语义）', () {
        final settings = PlaybackSettings.fromJson({'sentenceLoopCount': 0});
        expect(settings.sentenceLoopCount, 0);
      });

      test('次数 > 10 截断为 10', () {
        final settings = PlaybackSettings.fromJson({'wholeLoopCount': 100});
        expect(settings.wholeLoopCount, 10);
      });

      test('次数为负重置为默认 3', () {
        final settings = PlaybackSettings.fromJson({'sentenceLoopCount': -5});
        expect(settings.sentenceLoopCount, 3);
      });

      test('次数非 int 类型使用默认 3', () {
        final settings = PlaybackSettings.fromJson({'wholeLoopCount': 'abc'});
        expect(settings.wholeLoopCount, 3);
      });

      test('间隔负值截断为 0', () {
        final settings = PlaybackSettings.fromJson({'sentenceInterval': -1000});
        expect(settings.sentenceInterval, Duration.zero);
      });

      test('间隔 > 10 秒截断为 10 秒', () {
        final settings = PlaybackSettings.fromJson({'wholeInterval': 60000});
        expect(settings.wholeInterval, const Duration(seconds: 10));
      });
    });

    group('copyWith', () {
      test('部分字段覆盖', () {
        const settings = PlaybackSettings();
        final copied = settings.copyWith(
          loopSentence: true,
          playbackSpeed: 2.0,
        );

        expect(copied.loopSentence, isTrue);
        expect(copied.playbackSpeed, 2.0);
        // 未修改字段保持原值
        expect(copied.sentenceLoopCount, 3);
        expect(copied.loopWhole, isFalse);
        expect(copied.showTranscript, isTrue);
      });
    });
  });
}
