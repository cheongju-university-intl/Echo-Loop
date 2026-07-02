/// 学习材料导出 PDF 的数据聚合器
///
/// 从数据库聚合一篇音频的全部导出内容：字幕句子、段落分组、收藏句标记、
/// 收藏词/意群及其释义（AI 词典缓存优先、本地词典兜底）、句子翻译与
/// AI 解析（只读已有缓存，不发起任何网络请求）。
///
/// 依赖经构造函数注入（DAO + 本地词典查询函数），纯 Dart 可用
/// drift 内存库直接测试。
library;

import 'dart:convert';

import '../../database/daos/audio_item_dao.dart';
import '../../database/daos/bookmark_dao.dart';
import '../../database/daos/saved_sense_group_dao.dart';
import '../../database/daos/saved_word_dao.dart';
import '../../database/daos/sentence_ai_cache_dao.dart';
import '../../models/dict_entry.dart';
import '../../models/dictionary/dictionary_entry.dart';
import '../../models/pdf_export/study_pdf_data.dart';
import '../../models/sentence.dart';
import '../../models/sentence_ai_result.dart';
import '../../services/subtitle_parser.dart';
import '../../utils/paragraph_grouping.dart';
import '../../utils/saved_text_index.dart';
import '../../utils/text_normalize.dart';
import '../../widgets/practice/sentence_word_selection.dart'
    show savedCharRanges, tokenizeSentence;

/// 本地词典查询函数签名（注入 `DictionaryService.instance.lookup`）
typedef LocalDictLookup = DictEntry? Function(String word);

/// 段落分组目标时长（与全文盲听默认粒度一致，仅影响版式段间距）
const _paragraphTargetDuration = Duration(seconds: 30);

/// 学习材料 PDF 数据聚合器
class StudyPdfLoader {
  final AudioItemDao _audioItemDao;
  final BookmarkDao _bookmarkDao;
  final SavedWordDao _savedWordDao;
  final SavedSenseGroupDao _savedSenseGroupDao;
  final SentenceAiCacheDao _aiCacheDao;
  final LocalDictLookup _localDictLookup;

  StudyPdfLoader({
    required AudioItemDao audioItemDao,
    required BookmarkDao bookmarkDao,
    required SavedWordDao savedWordDao,
    required SavedSenseGroupDao savedSenseGroupDao,
    required SentenceAiCacheDao aiCacheDao,
    required LocalDictLookup localDictLookup,
  }) : _audioItemDao = audioItemDao,
       _bookmarkDao = bookmarkDao,
       _savedWordDao = savedWordDao,
       _savedSenseGroupDao = savedSenseGroupDao,
       _aiCacheDao = aiCacheDao,
       _localDictLookup = localDictLookup;

  /// 聚合指定音频的导出数据
  ///
  /// [targetLanguage] 为 BCP 47 代码（来自用户母语设置），用于定位
  /// 翻译/解析/AI 词典的缓存条目。
  ///
  /// 音频不存在或无字幕时抛 [StateError]（UI 入口已按 hasTranscript
  /// 过滤，正常不应到达）。
  Future<StudyPdfDocument> load(
    String audioItemId, {
    required String targetLanguage,
  }) async {
    final audio = await _audioItemDao.getById(audioItemId);
    if (audio == null) {
      throw StateError('音频不存在: $audioItemId');
    }
    final srt = await _audioItemDao.getTranscriptSrt(audioItemId);
    if (srt == null || srt.isEmpty) {
      throw StateError('音频无字幕: $audioItemId');
    }
    final sentences = await SubtitleParser.parseSubtitleString(srt);
    if (sentences.isEmpty) {
      throw StateError('字幕解析为空: $audioItemId');
    }

    // 文本 → 句子索引的兜底匹配表（重复文本取首个）
    final textIndex = <String, int>{};
    for (final s in sentences) {
      textIndex.putIfAbsent(s.text.trim(), () => s.index);
    }

    // 收藏句索引集合
    final bookmarkedIndices = <int>{};
    for (final b in await _bookmarkDao.getByAudioId(audioItemId)) {
      final idx = _resolveSentenceIndex(
        storedIndex: b.sentenceIndex,
        storedText: b.sentenceText,
        sentences: sentences,
        textIndex: textIndex,
      );
      if (idx != null) bookmarkedIndices.add(idx);
    }

    // 收藏词/意群 → 按句子归组（词在前、意群在后，各自保持 DAO 升序）；
    // 无任何词典结果的条目不产出笔记（右栏不显示）
    final savedWords = await _savedWordDao.getByAudioId(audioItemId);
    final savedGroups = await _savedSenseGroupDao.getByAudioId(audioItemId);
    final notesBySentence = <int, List<StudyPdfVocabNote>>{};
    for (final w in savedWords) {
      final idx = _resolveSentenceIndex(
        storedIndex: w.sentenceIndex,
        storedText: w.sentenceText,
        sentences: sentences,
        textIndex: textIndex,
      );
      if (idx == null) continue;
      final note = await _buildVocabNote(
        term: w.word,
        lookupKey: w.word,
        targetLanguage: targetLanguage,
      );
      if (note != null) (notesBySentence[idx] ??= []).add(note);
    }
    for (final g in savedGroups) {
      final idx = _resolveSentenceIndex(
        storedIndex: g.sentenceIndex,
        storedText: g.sentenceText,
        sentences: sentences,
        textIndex: textIndex,
      );
      if (idx == null) continue;
      final note = await _buildVocabNote(
        term: g.displayText,
        lookupKey: g.phraseText,
        targetLanguage: targetLanguage,
      );
      if (note != null) (notesBySentence[idx] ??= []).add(note);
    }

    // 收藏命中索引：全音频收藏词/意群 → 每句命中字符区间
    // （与 App 正文橙色下划线同一套匹配逻辑，见 sentence_word_selection.dart）
    final savedIndex = SavedTextIndex.build(
      savedWords: {for (final w in savedWords) w.word},
      savedPhrases: {for (final g in savedGroups) g.phraseText},
    );

    // 逐句组装（翻译/解析只读缓存）
    final pdfSentences = <StudyPdfSentence>[];
    for (final s in sentences) {
      final translation = await _loadTranslation(s.text, targetLanguage);
      final analysis = await _loadAnalysis(s.text, targetLanguage);
      pdfSentences.add(
        StudyPdfSentence(
          index: s.index,
          text: s.text,
          isBookmarked: bookmarkedIndices.contains(s.index),
          savedRanges: savedIndex.isEmpty
              ? const []
              : savedCharRanges(s.text, tokenizeSentence(s.text), savedIndex),
          translation: translation,
          grammar: _nonEmptyOrNull(analysis?.grammar),
          vocabulary: _nonEmptyOrNull(analysis?.vocabulary),
          listening: _nonEmptyOrNull(analysis?.listening),
          vocabNotes: notesBySentence[s.index] ?? const [],
        ),
      );
    }

    // 段落分组：groupSentencesIntoParagraphs 按原句列表分组，
    // 再映射回已组装的 StudyPdfSentence（index 一一对应）
    final bySentenceIndex = {for (final p in pdfSentences) p.index: p};
    final paragraphs = groupSentencesIntoParagraphs(
      sentences,
      _paragraphTargetDuration,
    ).map((p) => p.map((s) => bySentenceIndex[s.index]!).toList()).toList();

    return StudyPdfDocument(title: audio.name, paragraphs: paragraphs);
  }

  /// 解析存储的句子归属（索引 + 文本双重校验，防字幕重解析后索引错位）
  ///
  /// 1. 索引有效且文本匹配（或无存储文本）→ 用索引；
  /// 2. 否则按文本精确匹配兜底；
  /// 3. 都失败返回 null（调用方丢弃该条目）。
  int? _resolveSentenceIndex({
    required int? storedIndex,
    required String? storedText,
    required List<Sentence> sentences,
    required Map<String, int> textIndex,
  }) {
    final trimmedText = storedText?.trim();
    if (storedIndex != null &&
        storedIndex >= 0 &&
        storedIndex < sentences.length) {
      if (trimmedText == null ||
          trimmedText.isEmpty ||
          sentences[storedIndex].text.trim() == trimmedText) {
        return storedIndex;
      }
    }
    if (trimmedText != null && trimmedText.isNotEmpty) {
      return textIndex[trimmedText];
    }
    return null;
  }

  /// 构建词汇笔记：AI 词典缓存优先，本地词典兜底
  ///
  /// [term] 用于展示（意群保留原始大小写），[lookupKey] 用于查询
  /// （收藏词为小写 lemma、意群为归一化 phraseText，与缓存键契约一致）。
  /// 两路词典均无结果时返回 null（右栏不显示该词条）。
  Future<StudyPdfVocabNote?> _buildVocabNote({
    required String term,
    required String lookupKey,
    required String targetLanguage,
  }) async {
    // AI 词典缓存：键 = hashText('词|目标语言')，与 ai_dictionary_source 契约一致
    final entry = await _loadCachedJson(
      hashText('$lookupKey|$targetLanguage'),
      'ai_dictionary',
      DictionaryEntry.fromJson,
    );
    if (entry != null && entry.meanings.isNotEmpty) {
      final glosses = <StudyPdfGloss>[];
      for (final m in entry.meanings) {
        final text = m.translation
            .where((t) => t.trim().isNotEmpty)
            .map((t) => t.trim())
            .join('；');
        if (text.isEmpty) continue;
        glosses.add(StudyPdfGloss(pos: m.partOfSpeech.trim(), text: text));
      }
      if (glosses.isNotEmpty) {
        final phonetic = entry.pronunciation.us.trim().isNotEmpty
            ? entry.pronunciation.us.trim()
            : entry.pronunciation.uk.trim();
        return StudyPdfVocabNote(
          term: term,
          phonetic: phonetic,
          glosses: glosses,
        );
      }
    }

    // 本地词典兜底（未就绪/未收录时返回 null → 不显示该词条）
    final local = _localDictLookup(lookupKey);
    if (local != null) {
      final glosses = (local.translation ?? '')
          .split('\n')
          .map((line) => line.trim())
          .where((line) => line.isNotEmpty)
          .map(_splitLocalGloss)
          .toList();
      if (glosses.isNotEmpty) {
        return StudyPdfVocabNote(
          term: term,
          phonetic: local.phonetic.trim(),
          glosses: glosses,
        );
      }
    }
    return null;
  }

  /// 本地词典行首词性剥离：`n. 生日` → pos `n.` + text `生日`
  ///
  /// 支持连写词性（如 `vt.vi.`）；无法识别时整行作为释义文本。
  StudyPdfGloss _splitLocalGloss(String line) {
    final match = RegExp(r'^((?:[a-z]+\.\s*)+)(.*)$').firstMatch(line);
    final text = match?.group(2)?.trim() ?? '';
    if (match == null || text.isEmpty) {
      return StudyPdfGloss(text: line);
    }
    return StudyPdfGloss(pos: match.group(1)!.trim(), text: text);
  }

  /// 读句子翻译缓存
  Future<String?> _loadTranslation(String text, String targetLanguage) async {
    final result = await _loadCachedJson(
      hashText(text),
      'translation:$targetLanguage',
      SentenceTranslation.fromJson,
    );
    return _nonEmptyOrNull(result?.translation);
  }

  /// 读句子解析缓存
  Future<SentenceAnalysis?> _loadAnalysis(String text, String targetLanguage) {
    return _loadCachedJson(
      hashText(text),
      'analysis:$targetLanguage',
      SentenceAnalysis.fromJson,
    );
  }

  /// 读缓存并反序列化；未命中或 JSON 损坏返回 null
  Future<T?> _loadCachedJson<T>(
    String hash,
    String type,
    T Function(Map<String, dynamic>) fromJson,
  ) async {
    final raw = await _aiCacheDao.getByHash(hash, type);
    if (raw == null) return null;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map<String, dynamic>) return fromJson(decoded);
    } catch (_) {
      // 损坏数据视作未命中
    }
    return null;
  }

  String? _nonEmptyOrNull(String? value) {
    final trimmed = value?.trim();
    return (trimmed == null || trimmed.isEmpty) ? null : trimmed;
  }
}
