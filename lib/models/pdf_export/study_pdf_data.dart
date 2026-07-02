/// 学习材料导出 PDF 的数据模型
///
/// 由 `StudyPdfLoader` 聚合产出、`study_pdf_builder` 消费渲染。
/// 只含基础类型（String/int/bool/List），可安全跨 isolate 传递
/// （PDF 生成在 compute isolate 中执行）。
library;

/// 一份待导出的学习材料文档
class StudyPdfDocument {
  /// 文档标题（音频名称）
  final String title;

  /// 段落列表，每个段落是若干连续句子
  ///
  /// 分段复用 `groupSentencesIntoParagraphs` 的结果，用于版式上的段间距。
  final List<List<StudyPdfSentence>> paragraphs;

  const StudyPdfDocument({required this.title, required this.paragraphs});

  /// 文档内句子总数
  int get sentenceCount => paragraphs.fold(0, (sum, p) => sum + p.length);
}

/// 一个句子及其关联的笔记内容
class StudyPdfSentence {
  /// 句子在字幕中的索引
  final int index;

  /// 句子原文
  final String text;

  /// 是否为收藏句（导出时在句末加书签图标）
  final bool isBookmarked;

  /// 收藏词/词组/意群在句中命中的字符区间 [start, end) 列表
  ///
  /// 由 loader 用 `savedCharRanges` 计算（与 App 正文橙色下划线语义一致），
  /// builder 据此给命中片段加橙色下划线。int 记录可安全跨 isolate。
  final List<(int, int)> savedRanges;

  /// 句子翻译（缓存命中才有，否则为 null 不渲染）
  final String? translation;

  /// AI 解析：语法分析（缓存命中才有）
  final String? grammar;

  /// AI 解析：词汇分析（缓存命中才有）
  final String? vocabulary;

  /// AI 解析：听力分析（缓存命中才有）
  final String? listening;

  /// 该句关联的词汇笔记（收藏词 / 收藏意群），渲染在右栏
  final List<StudyPdfVocabNote> vocabNotes;

  const StudyPdfSentence({
    required this.index,
    required this.text,
    this.isBookmarked = false,
    this.savedRanges = const [],
    this.translation,
    this.grammar,
    this.vocabulary,
    this.listening,
    this.vocabNotes = const [],
  });

  /// 是否有任一 AI 解析字段（决定正文尾注标记与附录条目）
  bool get hasAnalysis =>
      grammar != null || vocabulary != null || listening != null;
}

/// 一条词汇笔记（收藏词或收藏意群）
class StudyPdfVocabNote {
  /// 词条展示文本（单词原形 / 意群原始大小写文本）
  final String term;

  /// 音标（AI 词典 us 优先，其次本地词典；无则空串不渲染）
  final String phonetic;

  /// 释义列表，每条一个 bullet
  ///
  /// AI 词典命中时为各义项「词性 + 目标语翻译」；
  /// 否则为本地词典 translation 按行拆分（行首词性剥入 [StudyPdfGloss.pos]）。
  /// loader 保证非空——无任何词典结果的收藏词不产出笔记。
  final List<StudyPdfGloss> glosses;

  const StudyPdfVocabNote({
    required this.term,
    this.phonetic = '',
    this.glosses = const [],
  });
}

/// 一条释义（词性与释义文本分离，词性渲染为斜体）
class StudyPdfGloss {
  /// 词性缩写（如 `n.` / `vt.`），无法解析时为空串不渲染
  final String pos;

  /// 释义文本（目标语翻译）
  final String text;

  const StudyPdfGloss({this.pos = '', required this.text});
}
