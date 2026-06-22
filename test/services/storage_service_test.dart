import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:echo_loop/models/playback_settings.dart';
import 'package:echo_loop/services/storage_service.dart';

void main() {
  group('StorageService', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('保存并读取全文 / 收藏两套独立设置', () async {
      await StorageService.saveSettings(
        const ListeningPracticeSettingsStore(
          full: PlaybackSettings(
            playbackSpeed: 1.25,
            showTranscript: true,
            singleSentenceMode: false,
            wholeLoopCount: 4,
          ),
          bookmark: PlaybackSettings(
            playbackSpeed: 0.8,
            showTranscript: false,
            singleSentenceMode: true,
            sentenceLoopCount: 6,
          ),
        ),
      );

      final loaded = await StorageService.loadSettings();
      expect(loaded.full.playbackSpeed, 1.25);
      expect(loaded.full.showTranscript, isTrue);
      expect(loaded.full.singleSentenceMode, isFalse);
      expect(loaded.full.wholeLoopCount, 4);

      expect(loaded.bookmark.playbackSpeed, 0.8);
      expect(loaded.bookmark.showTranscript, isFalse);
      expect(loaded.bookmark.singleSentenceMode, isTrue);
      expect(loaded.bookmark.loopSentence, isTrue);
      expect(loaded.bookmark.sentenceLoopCount, 1);
      expect(loaded.bookmark.sentenceInterval, const Duration(seconds: 1));
    });

    test('兼容旧单份设置 schema：升级后复制成两份', () async {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        'playback_settings',
        json.encode(
          const PlaybackSettings(
            playbackSpeed: 1.5,
            singleSentenceMode: true,
            showTranscript: false,
            sentenceLoopCount: 5,
          ).toJson(),
        ),
      );

      final loaded = await StorageService.loadSettings();
      expect(loaded.full.playbackSpeed, 1.5);
      expect(loaded.bookmark.playbackSpeed, 1.5);
      expect(loaded.full.singleSentenceMode, isTrue);
      expect(loaded.bookmark.singleSentenceMode, isTrue);
      expect(loaded.full.showTranscript, isFalse);
      expect(loaded.bookmark.showTranscript, isFalse);
      expect(loaded.full.sentenceLoopCount, 5);
      expect(loaded.bookmark.loopSentence, isTrue);
      expect(loaded.bookmark.sentenceLoopCount, 1);
      expect(loaded.bookmark.sentenceInterval, const Duration(seconds: 1));
    });
  });
}
