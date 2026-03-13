/// AI 单词解析结果
///
/// 包含语境释义、常见搭配、用法要点和词族扩展四个可选字段。
/// AI 根据单词特征自适应返回，无价值字段为 null。
library;

/// AI 单词解析结果
class WordAnalysis {
  /// 语境释义
  final String? contextMeaning;

  /// 常见搭配
  final String? collocations;

  /// 用法要点
  final String? usage;

  /// 词族扩展
  final String? wordFamily;

  const WordAnalysis({
    this.contextMeaning,
    this.collocations,
    this.usage,
    this.wordFamily,
  });

  /// 从 API 响应 JSON 反序列化
  ///
  /// 期望格式：`{ "analysis": { "contextMeaning": "...", ... } }`
  factory WordAnalysis.fromJson(Map<String, dynamic> json) {
    final analysis = json['analysis'] as Map<String, dynamic>;
    return WordAnalysis(
      contextMeaning: analysis['contextMeaning'] as String?,
      collocations: analysis['collocations'] as String?,
      usage: analysis['usage'] as String?,
      wordFamily: analysis['wordFamily'] as String?,
    );
  }

  /// 序列化为 JSON（用于 SQLite 缓存存储）
  Map<String, dynamic> toJson() => {
    'analysis': {
      'contextMeaning': contextMeaning,
      'collocations': collocations,
      'usage': usage,
      'wordFamily': wordFamily,
    },
  };

  /// 是否所有字段均为 null
  bool get isEmpty =>
      contextMeaning == null &&
      collocations == null &&
      usage == null &&
      wordFamily == null;
}
