import 'dart:convert';

import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:echo_loop/database/app_database.dart';
import 'package:echo_loop/models/dict_entry.dart';
import 'package:echo_loop/services/pdf_export/study_pdf_loader.dart';
import 'package:echo_loop/utils/text_normalize.dart';

/// 创建内存数据库用于测试
AppDatabase _createTestDb() {
  return AppDatabase(
    NativeDatabase.memory(
      setup: (db) => db.execute('PRAGMA foreign_keys = ON'),
    ),
  );
}

/// 三句测试字幕（句间静音小，30s 目标分组为单段）
const _testSrt = '''
1
00:00:00,000 --> 00:00:03,000
Hello world.

2
00:00:03,500 --> 00:00:06,000
This is a test.

3
00:00:06,500 --> 00:00:09,000
Goodbye now.
''';

void main() {
  late AppDatabase db;

  setUp(() {
    db = _createTestDb();
  });

  tearDown(() async {
    await db.close();
  });

  /// 插入测试音频（带字幕）
  Future<void> insertAudio({String id = 'audio-1', String? srt = _testSrt}) {
    final now = DateTime.now();
    return db.audioItemDao.upsert(
      AudioItemsCompanion(
        id: Value(id),
        name: const Value('Test Audio'),
        audioPath: const Value('test.mp3'),
        addedDate: Value(now),
        updatedAt: Value(now),
        transcriptSrt: Value(srt),
      ),
    );
  }

  /// 构建 loader（本地词典默认查不到）
  StudyPdfLoader buildLoader({DictEntry? Function(String)? localDictLookup}) {
    return StudyPdfLoader(
      audioItemDao: db.audioItemDao,
      bookmarkDao: db.bookmarkDao,
      savedWordDao: db.savedWordDao,
      savedSenseGroupDao: db.savedSenseGroupDao,
      aiCacheDao: db.sentenceAiCacheDao,
      localDictLookup: localDictLookup ?? (_) => null,
    );
  }

  group('StudyPdfLoader 基础组装', () {
    test('解析字幕并分段，缓存全空时导出纯文章', () async {
      await insertAudio();

      final doc = await buildLoader().load('audio-1', targetLanguage: 'zh-CN');

      expect(doc.title, 'Test Audio');
      expect(doc.sentenceCount, 3);
      final all = doc.paragraphs.expand((p) => p).toList();
      expect(all.map((s) => s.text).toList(), [
        'Hello world.',
        'This is a test.',
        'Goodbye now.',
      ]);
      for (final s in all) {
        expect(s.isBookmarked, false);
        expect(s.translation, isNull);
        expect(s.grammar, isNull);
        expect(s.vocabNotes, isEmpty);
      }
    });

    test('音频不存在 / 无字幕时抛 StateError', () async {
      expect(
        () => buildLoader().load('missing', targetLanguage: 'zh-CN'),
        throwsStateError,
      );

      await insertAudio(id: 'no-srt', srt: null);
      expect(
        () => buildLoader().load('no-srt', targetLanguage: 'zh-CN'),
        throwsStateError,
      );
    });
  });

  group('收藏句标记', () {
    test('索引命中直接标记', () async {
      await insertAudio();
      await db.bookmarkDao.addBookmark(
        BookmarksCompanion.insert(
          audioItemId: 'audio-1',
          sentenceIndex: 1,
          sentenceText: 'This is a test.',
          startTime: 3.5,
          endTime: 6.0,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
      );

      final doc = await buildLoader().load('audio-1', targetLanguage: 'zh-CN');
      final all = doc.paragraphs.expand((p) => p).toList();
      expect(all.map((s) => s.isBookmarked).toList(), [false, true, false]);
    });

    test('索引错位时按文本兜底匹配', () async {
      await insertAudio();
      // 索引指向第 0 句，文本却是第 2 句 → 应落到第 2 句
      await db.bookmarkDao.addBookmark(
        BookmarksCompanion.insert(
          audioItemId: 'audio-1',
          sentenceIndex: 0,
          sentenceText: 'Goodbye now.',
          startTime: 0,
          endTime: 3.0,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
      );

      final doc = await buildLoader().load('audio-1', targetLanguage: 'zh-CN');
      final all = doc.paragraphs.expand((p) => p).toList();
      expect(all.map((s) => s.isBookmarked).toList(), [false, false, true]);
    });

    test('索引越界且文本不匹配时丢弃', () async {
      await insertAudio();
      await db.bookmarkDao.addBookmark(
        BookmarksCompanion.insert(
          audioItemId: 'audio-1',
          sentenceIndex: 99,
          sentenceText: 'Not in transcript.',
          startTime: 0,
          endTime: 1.0,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
      );

      final doc = await buildLoader().load('audio-1', targetLanguage: 'zh-CN');
      final all = doc.paragraphs.expand((p) => p).toList();
      expect(all.every((s) => !s.isBookmarked), true);
    });
  });

  group('翻译与解析缓存', () {
    test('缓存命中填充翻译与解析三字段', () async {
      await insertAudio();
      final hash = hashText('This is a test.');
      await db.sentenceAiCacheDao.upsert(
        hash,
        'translation:zh-CN',
        jsonEncode({'translation': '这是一个测试。'}),
      );
      await db.sentenceAiCacheDao.upsert(
        hash,
        'analysis:zh-CN',
        jsonEncode({
          'analysis': {
            'grammar': '主系表结构',
            'vocabulary': 'test 测试',
            'listening': 'this is 连读',
          },
        }),
      );

      final doc = await buildLoader().load('audio-1', targetLanguage: 'zh-CN');
      final s = doc.paragraphs.expand((p) => p).toList()[1];
      expect(s.translation, '这是一个测试。');
      expect(s.grammar, '主系表结构');
      expect(s.vocabulary, 'test 测试');
      expect(s.listening, 'this is 连读');
    });

    test('targetLanguage 隔离：zh-CN 缓存不命中 en 查询', () async {
      await insertAudio();
      await db.sentenceAiCacheDao.upsert(
        hashText('This is a test.'),
        'translation:zh-CN',
        jsonEncode({'translation': '这是一个测试。'}),
      );

      final doc = await buildLoader().load('audio-1', targetLanguage: 'en');
      final s = doc.paragraphs.expand((p) => p).toList()[1];
      expect(s.translation, isNull);
    });

    test('坏 JSON 视作未命中不抛异常', () async {
      await insertAudio();
      final hash = hashText('This is a test.');
      await db.sentenceAiCacheDao.upsert(hash, 'translation:zh-CN', '{broken');
      await db.sentenceAiCacheDao.upsert(hash, 'analysis:zh-CN', '[]');

      final doc = await buildLoader().load('audio-1', targetLanguage: 'zh-CN');
      final s = doc.paragraphs.expand((p) => p).toList()[1];
      expect(s.translation, isNull);
      expect(s.grammar, isNull);
    });
  });

  group('词汇笔记', () {
    test('AI 词典缓存命中：义项转 bullet、us 音标优先', () async {
      await insertAudio();
      await db.savedWordDao.saveWord(
        word: 'test',
        audioItemId: 'audio-1',
        sentenceIndex: 1,
        sentenceText: 'This is a test.',
      );
      await db.sentenceAiCacheDao.upsert(
        hashText('test|zh-CN'),
        'ai_dictionary',
        jsonEncode({
          'headword': 'test',
          'pronunciation': {'uk': 'test-uk', 'us': 'test-us'},
          'meanings': [
            {
              'partOfSpeech': 'n.',
              'translation': ['测试', '考验'],
            },
            {
              'partOfSpeech': 'v.',
              'translation': ['检测'],
            },
          ],
        }),
      );

      final doc = await buildLoader().load('audio-1', targetLanguage: 'zh-CN');
      final s = doc.paragraphs.expand((p) => p).toList()[1];
      expect(s.vocabNotes.length, 1);
      final note = s.vocabNotes.first;
      expect(note.term, 'test');
      expect(note.phonetic, 'test-us');
      expect(note.glosses.map((g) => (g.pos, g.text)).toList(), [
        ('n.', '测试；考验'),
        ('v.', '检测'),
      ]);
    });

    test('AI 未命中时本地词典兜底（词性剥入 pos），两者皆无时不显示词条', () async {
      await insertAudio();
      await db.savedWordDao.saveWord(
        word: 'test',
        audioItemId: 'audio-1',
        sentenceIndex: 1,
        sentenceText: 'This is a test.',
      );
      await db.savedWordDao.saveWord(
        word: 'unknown',
        audioItemId: 'audio-1',
        sentenceIndex: 0,
        sentenceText: 'Hello world.',
      );

      final doc = await buildLoader().load('audio-1', targetLanguage: 'zh-CN');
      // 本地词典只认识 test
      final doc2 = await buildLoader(
        localDictLookup: (word) => word == 'test'
            ? const DictEntry(
                word: 'test',
                phonetic: 'test',
                translation: 'n. 测试\nvt. 检测',
              )
            : null,
      ).load('audio-1', targetLanguage: 'zh-CN');

      // 无任何词典结果时词条不出现在右栏
      for (final s in doc.paragraphs.expand((p) => p)) {
        expect(s.vocabNotes, isEmpty);
      }
      final all2 = doc2.paragraphs.expand((p) => p).toList();
      final testNote = all2[1].vocabNotes.single;
      expect(testNote.glosses.map((g) => (g.pos, g.text)).toList(), [
        ('n.', '测试'),
        ('vt.', '检测'),
      ]);
      expect(testNote.phonetic, 'test');
      // unknown 两路皆无 → 被过滤
      expect(all2[0].vocabNotes, isEmpty);
    });

    test('收藏意群用 displayText 展示、phraseText 查询，词在前意群在后', () async {
      await insertAudio();
      await db.savedWordDao.saveWord(
        word: 'world',
        audioItemId: 'audio-1',
        sentenceIndex: 0,
        sentenceText: 'Hello world.',
      );
      await db.savedSenseGroupDao.saveSenseGroup(
        phraseText: 'hello world',
        displayText: 'Hello world',
        audioItemId: 'audio-1',
        sentenceIndex: 0,
        sentenceText: 'Hello world.',
      );
      await db.sentenceAiCacheDao.upsert(
        hashText('hello world|zh-CN'),
        'ai_dictionary',
        jsonEncode({
          'meanings': [
            {
              'partOfSpeech': '',
              'translation': ['你好世界'],
            },
          ],
        }),
      );

      // world 走本地词典（无本地结果会被过滤，见上一用例）
      final doc = await buildLoader(
        localDictLookup: (word) => word == 'world'
            ? const DictEntry(word: 'world', phonetic: '', translation: '世界')
            : null,
      ).load('audio-1', targetLanguage: 'zh-CN');
      final notes = doc.paragraphs.expand((p) => p).toList()[0].vocabNotes;
      expect(notes.length, 2);
      expect(notes[0].term, 'world');
      expect(notes[1].term, 'Hello world');
      expect(notes[1].glosses.single.pos, '');
      expect(notes[1].glosses.single.text, '你好世界');
    });

    test('收藏词/意群命中区间：全音频索引逐句匹配，与词典结果无关', () async {
      await insertAudio();
      // 无任何词典结果（词条会被右栏过滤），但下划线区间仍应计算
      await db.savedWordDao.saveWord(
        word: 'test',
        audioItemId: 'audio-1',
        sentenceIndex: 1,
        sentenceText: 'This is a test.',
      );
      await db.savedSenseGroupDao.saveSenseGroup(
        phraseText: 'hello world',
        displayText: 'Hello world',
        audioItemId: 'audio-1',
        sentenceIndex: 0,
        sentenceText: 'Hello world.',
      );

      final doc = await buildLoader().load('audio-1', targetLanguage: 'zh-CN');
      final all = doc.paragraphs.expand((p) => p).toList();
      // 'Hello world.' 命中意群（修边去句号）
      expect(all[0].savedRanges, [(0, 11)]);
      // 'This is a test.' 命中收藏词 test
      expect(all[1].savedRanges, [(10, 14)]);
      expect(all[2].savedRanges, isEmpty);
      // 右栏词条因无词典结果被过滤
      expect(all.every((s) => s.vocabNotes.isEmpty), true);
    });

    test('其他音频的收藏词不出现', () async {
      await insertAudio();
      await insertAudio(id: 'audio-2');
      await db.savedWordDao.saveWord(
        word: 'other',
        audioItemId: 'audio-2',
        sentenceIndex: 0,
        sentenceText: 'Hello world.',
      );

      final doc = await buildLoader().load('audio-1', targetLanguage: 'zh-CN');
      expect(
        doc.paragraphs.expand((p) => p).every((s) => s.vocabNotes.isEmpty),
        true,
      );
    });
  });
}
