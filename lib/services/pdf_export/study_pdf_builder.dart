/// 学习材料 PDF 渲染器（学术论文风格版式）
///
/// 纯函数式 builder：`StudyPdfBuildRequest`（文档数据 + 字体字节）→ PDF 字节。
/// 顶层函数 [buildStudyPdfBytes] 可直接作为 `compute` 入口在 isolate 中执行
/// （字体解析 + 子集化是数百 ms 级 CPU 开销，不能占用主 isolate）。
///
/// 版式设计（简洁克制，无彩色底色块）：
/// - 正文左栏（flex 5）句子 + 右栏（flex 2）词汇旁注，学术旁注比例；
/// - 收藏词/意群 = 橙色细下划线（与 App 正文视觉语言一致；pdf 包无
///   dotted 下划线，用细实线近似）；收藏句 = 句末小书签图标；
/// - 翻译弱化为句下灰色小字；AI 解析集中在文末「附录 · 句子解析」，
///   正文句末只留尾注式标记 [n]；
/// - 首页标题居中 + ECHO LOOP 品牌行，次页起 running header。
///
/// 版式约束（pdf 包 MultiPage 语义）：
/// - 只有顶层兄弟块之间可以断页，单个 widget 超一页高会直接抛异常；
///   因此「句子行 / 翻译块 / 附录条目各字段」各自是 MultiPage 的直接 child。
/// - `maxPages` 默认 20，长文必须显式调大。
library;

import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../models/pdf_export/study_pdf_data.dart';
import '../../widgets/practice/sentence_word_selection.dart'
    show charMaskFromRanges, splitByMask;

/// PDF 生成请求（compute 入口参数，只含可跨 isolate 的类型）
class StudyPdfBuildRequest {
  /// 文档数据
  final StudyPdfDocument document;

  /// 英文正文字体（NotoSans-Regular，TrueType）
  final Uint8List latinRegular;

  /// 英文粗体字体（NotoSans-Bold）
  final Uint8List latinBold;

  /// 英文斜体字体（NotoSans-Italic，词性渲染用）
  final Uint8List latinItalic;

  /// CJK 回退字体（NotoSansSC-Regular）
  final Uint8List cjkRegular;

  /// 应用图标 PNG 字节（96px 小图，品牌角标用；null 则只渲染品牌文字）
  final Uint8List? appIconPng;

  /// 导出日期（yyyy-MM-dd，由调用方生成，isolate 内不取时钟）
  final String exportDate;

  const StudyPdfBuildRequest({
    required this.document,
    required this.latinRegular,
    required this.latinBold,
    required this.latinItalic,
    required this.cjkRegular,
    this.appIconPng,
    required this.exportDate,
  });
}

// ---------- 版式常量（固定浅色系，与 App 主题无关） ----------

/// 正文色
const _inkColor = PdfColor.fromInt(0xFF1A1A1A);

/// 弱化文字色（翻译/音标/页眉页脚/日期）
const _mutedColor = PdfColor.fromInt(0xFF757575);

/// 收藏标记橙（= App 浅色 `Colors.orange.shade400`，收藏词下划线 + 书签图标）
const _savedMarkColor = PdfColor.fromInt(0xFFFFA726);

/// 词汇笔记词条色
const _vocabTermColor = PdfColor.fromInt(0xFF2B4C7E);

/// 分隔线色
const _hairlineColor = PdfColors.grey400;

/// 品牌字样（首页标题上方 + 次页起 running header）
const _brandText = 'ECHO LOOP';

/// 正文左右栏 flex 比例（学术旁注版式，左栏 ~71%）
const _bodyFlex = 5;
const _notesFlex = 2;

/// 左右栏间距
const _columnGap = 16.0;

/// 单个文本字段的字符数硬上限（防脏数据把单块撑超一页高度抛异常）
///
/// 左栏宽约 350pt，8.5pt 字号一页约可容 5000 字符，取 3000 留足余量。
const _maxFieldChars = 3000;

/// 书签图标（Material bookmark 形状，收藏句句末标记）
const _bookmarkSvg =
    '<svg viewBox="0 0 24 24"><path d="M6 2h12v20l-6-5-6 5z" fill="#FFA726"/></svg>';

/// 生成学习材料 PDF 字节（compute 入口）
Future<Uint8List> buildStudyPdfBytes(StudyPdfBuildRequest request) async {
  final latin = pw.Font.ttf(ByteData.sublistView(request.latinRegular));
  final latinBold = pw.Font.ttf(ByteData.sublistView(request.latinBold));
  final latinItalic = pw.Font.ttf(ByteData.sublistView(request.latinItalic));
  final cjk = pw.Font.ttf(ByteData.sublistView(request.cjkRegular));

  final doc = pw.Document(
    theme: pw.ThemeData.withFont(
      base: latin,
      bold: latinBold,
      italic: latinItalic,
      fontFallback: [cjk],
    ),
  );

  final title = _sanitize(request.document.title);
  final appIcon = request.appIconPng == null
      ? null
      : pw.MemoryImage(request.appIconPng!);
  doc.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.symmetric(horizontal: 42, vertical: 48),
      maxPages: 400,
      header: (context) => context.pageNumber == 1
          ? pw.SizedBox()
          : _runningHeader(title, appIcon),
      footer: (context) => pw.Align(
        alignment: pw.Alignment.center,
        child: pw.Text(
          '${context.pageNumber} / ${context.pagesCount}',
          style: const pw.TextStyle(fontSize: 8, color: _mutedColor),
        ),
      ),
      build: (context) => _buildBlocks(request, appIcon),
    ),
  );

  return doc.save();
}

/// 品牌角标：应用图标 + `ECHO LOOP` 文字（图标缺失时只渲染文字）
pw.Widget _brandMark(pw.ImageProvider? appIcon, {double iconSize = 11}) {
  return pw.Row(
    mainAxisSize: pw.MainAxisSize.min,
    crossAxisAlignment: pw.CrossAxisAlignment.center,
    children: [
      if (appIcon != null) ...[
        pw.Image(appIcon, width: iconSize, height: iconSize),
        pw.SizedBox(width: 3),
      ],
      pw.Text(
        _brandText,
        style: const pw.TextStyle(
          fontSize: 7.5,
          letterSpacing: 2,
          color: _mutedColor,
        ),
      ),
    ],
  );
}

/// 组装 MultiPage 顶层块列表（块间可断页）：标题 → 正文 → 附录
List<pw.Widget> _buildBlocks(
  StudyPdfBuildRequest request,
  pw.ImageProvider? appIcon,
) {
  final document = request.document;

  // 尾注编号：按正文出现顺序给「有解析的句子」分配 [1..n]，
  // 正文句末标记与附录条目共用同一映射
  final noteNumbers = <int, int>{};
  for (final paragraph in document.paragraphs) {
    for (final sentence in paragraph) {
      if (sentence.hasAnalysis) {
        noteNumbers[sentence.index] = noteNumbers.length + 1;
      }
    }
  }

  final blocks = <pw.Widget>[
    _titleBlock(document.title, request.exportDate, appIcon),
    pw.SizedBox(height: 18),
  ];

  for (final paragraph in document.paragraphs) {
    for (final sentence in paragraph) {
      blocks.addAll(_sentenceBlocks(sentence, noteNumbers[sentence.index]));
    }
    // 段间距（明显大于行高，最后一段之后多余的间距无碍观感）
    blocks.add(pw.SizedBox(height: 14));
  }

  if (noteNumbers.isNotEmpty) {
    blocks.addAll(_appendixBlocks(document, noteNumbers));
  }
  return blocks;
}

/// 次页起的 running header：左品牌角标、右文档标题 + 底部 hairline
pw.Widget _runningHeader(String title, pw.ImageProvider? appIcon) {
  return pw.Container(
    margin: const pw.EdgeInsets.only(bottom: 12),
    padding: const pw.EdgeInsets.only(bottom: 4),
    decoration: const pw.BoxDecoration(
      border: pw.Border(
        bottom: pw.BorderSide(width: 0.5, color: _hairlineColor),
      ),
    ),
    child: pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      crossAxisAlignment: pw.CrossAxisAlignment.center,
      children: [
        _brandMark(appIcon, iconSize: 9),
        pw.Text(
          title,
          style: const pw.TextStyle(fontSize: 7, color: _mutedColor),
        ),
      ],
    ),
  );
}

/// 首页标题块：右上角品牌角标（图标+文字，不显眼）→ 标题居中 → 日期居中 → 分隔线
pw.Widget _titleBlock(
  String title,
  String exportDate,
  pw.ImageProvider? appIcon,
) {
  return pw.Container(
    width: double.infinity,
    padding: const pw.EdgeInsets.only(bottom: 10),
    decoration: const pw.BoxDecoration(
      border: pw.Border(
        bottom: pw.BorderSide(width: 0.5, color: _hairlineColor),
      ),
    ),
    child: pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.center,
      children: [
        pw.Align(
          alignment: pw.Alignment.centerRight,
          child: _brandMark(appIcon),
        ),
        pw.SizedBox(height: 6),
        pw.Text(
          _sanitize(title),
          textAlign: pw.TextAlign.center,
          style: pw.TextStyle(
            fontSize: 16,
            fontWeight: pw.FontWeight.bold,
            color: _inkColor,
          ),
        ),
        pw.SizedBox(height: 5),
        pw.Text(
          exportDate,
          style: const pw.TextStyle(fontSize: 8, color: _mutedColor),
        ),
      ],
    ),
  );
}

/// 一个句子展开成的顶层块序列：左栏（句子 + 弱化翻译）+ 右栏词汇旁注
///
/// 翻译与句子同在左栏 Column 内紧邻排列（若作为独立顶层块，会被
/// 右栏词汇列的高度推到 Row 之后，句子与翻译之间出现大空隙）。
/// [noteNumber] 为该句的附录尾注编号（无解析时为 null 不加标记）。
List<pw.Widget> _sentenceBlocks(StudyPdfSentence sentence, int? noteNumber) {
  return [
    pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Expanded(
          flex: _bodyFlex,
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              _sentenceText(sentence, noteNumber),
              if (sentence.translation != null)
                _translationText(sentence.translation!),
            ],
          ),
        ),
        pw.SizedBox(width: _columnGap),
        pw.Expanded(flex: _notesFlex, child: _vocabColumn(sentence.vocabNotes)),
      ],
    ),
    pw.SizedBox(height: 4),
  ];
}

/// 句子正文：正常字体颜色；收藏词/意群命中片段加橙色细下划线；
/// 收藏句句末加书签图标；有解析的句子加尾注标记 [n]
pw.Widget _sentenceText(StudyPdfSentence sentence, int? noteNumber) {
  final text = _sanitize(sentence.text);
  final baseStyle = const pw.TextStyle(
    fontSize: 10.5,
    lineSpacing: 3,
    color: _inkColor,
  );

  // 收藏命中掩码按原文长度构建；_sanitize 只做等长替换 + 尾部截断，
  // splitByMask 对越界索引视为未命中，截断不会引起区间错位
  final mask = charMaskFromRanges(sentence.text.length, sentence.savedRanges);
  final spans = <pw.InlineSpan>[
    for (final (start, end, saved) in splitByMask(0, text.length, mask))
      pw.TextSpan(
        text: text.substring(start, end),
        style: saved
            ? baseStyle.copyWith(
                decoration: pw.TextDecoration.underline,
                decorationColor: _savedMarkColor,
                decorationThickness: 1,
              )
            : baseStyle,
      ),
    if (sentence.isBookmarked)
      pw.WidgetSpan(
        child: pw.Padding(
          padding: const pw.EdgeInsets.only(left: 3),
          child: pw.SvgImage(svg: _bookmarkSvg, width: 6.5, height: 8.5),
        ),
      ),
    if (noteNumber != null)
      pw.TextSpan(
        text: ' [$noteNumber]',
        style: const pw.TextStyle(fontSize: 6.5, color: _mutedColor),
      ),
  ];

  return pw.Padding(
    padding: const pw.EdgeInsets.symmetric(vertical: 2),
    child: pw.RichText(text: pw.TextSpan(style: baseStyle, children: spans)),
  );
}

/// 右栏词汇笔记列（无笔记时占位保持左栏宽度恒定）
pw.Widget _vocabColumn(List<StudyPdfVocabNote> notes) {
  if (notes.isEmpty) return pw.SizedBox();
  return pw.Column(
    crossAxisAlignment: pw.CrossAxisAlignment.start,
    children: [
      for (final note in notes)
        pw.Container(
          margin: const pw.EdgeInsets.only(bottom: 4),
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.RichText(
                text: pw.TextSpan(
                  children: [
                    pw.TextSpan(
                      text: _sanitize(note.term),
                      style: pw.TextStyle(
                        fontSize: 9,
                        fontWeight: pw.FontWeight.bold,
                        color: _vocabTermColor,
                      ),
                    ),
                    if (note.phonetic.isNotEmpty)
                      pw.TextSpan(
                        text: '  /${_sanitize(note.phonetic)}/',
                        style: const pw.TextStyle(
                          fontSize: 8,
                          color: _mutedColor,
                        ),
                      ),
                  ],
                ),
              ),
              for (final gloss in note.glosses)
                pw.Padding(
                  padding: const pw.EdgeInsets.only(left: 4, top: 1),
                  child: pw.RichText(
                    text: pw.TextSpan(
                      style: const pw.TextStyle(
                        fontSize: 8,
                        lineSpacing: 2,
                        color: _inkColor,
                      ),
                      children: [
                        const pw.TextSpan(text: '· '),
                        // 词性斜体（弱化色），与释义文本分离
                        if (gloss.pos.isNotEmpty)
                          pw.TextSpan(
                            text: '${_sanitize(gloss.pos)} ',
                            style: pw.TextStyle(
                              fontStyle: pw.FontStyle.italic,
                              color: _mutedColor,
                            ),
                          ),
                        pw.TextSpan(text: _sanitize(gloss.text)),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
    ],
  );
}

/// 句子下方的翻译：无底色灰色小字（弱化）
pw.Widget _translationText(String text) {
  return pw.Padding(
    padding: const pw.EdgeInsets.only(top: 1, bottom: 2),
    child: pw.Text(
      _sanitize(text),
      style: const pw.TextStyle(
        fontSize: 9,
        lineSpacing: 2.5,
        color: _mutedColor,
      ),
    ),
  );
}

/// 附录「句子解析」：另起一页，逐条 [n] 句子原文 + 语法/词汇/听力
///
/// 条目内各字段是独立顶层块，长解析可跨页断行。
List<pw.Widget> _appendixBlocks(
  StudyPdfDocument document,
  Map<int, int> noteNumbers,
) {
  final blocks = <pw.Widget>[
    pw.NewPage(),
    pw.Container(
      padding: const pw.EdgeInsets.only(bottom: 6),
      decoration: const pw.BoxDecoration(
        border: pw.Border(
          bottom: pw.BorderSide(width: 0.5, color: _hairlineColor),
        ),
      ),
      child: pw.Text(
        '附录 · 句子解析',
        style: pw.TextStyle(
          fontSize: 12,
          fontWeight: pw.FontWeight.bold,
          color: _inkColor,
        ),
      ),
    ),
    pw.SizedBox(height: 12),
  ];

  for (final paragraph in document.paragraphs) {
    for (final sentence in paragraph) {
      final number = noteNumbers[sentence.index];
      if (number == null) continue;
      blocks.add(
        pw.RichText(
          text: pw.TextSpan(
            style: const pw.TextStyle(
              fontSize: 9.5,
              lineSpacing: 2.5,
              color: _inkColor,
            ),
            children: [
              pw.TextSpan(
                text: '[$number]  ',
                style: pw.TextStyle(
                  fontWeight: pw.FontWeight.bold,
                  color: _mutedColor,
                ),
              ),
              pw.TextSpan(text: _sanitize(sentence.text)),
            ],
          ),
        ),
      );
      if (sentence.grammar != null) {
        blocks.add(_analysisField('语法', sentence.grammar!));
      }
      if (sentence.vocabulary != null) {
        blocks.add(_analysisField('词汇', sentence.vocabulary!));
      }
      if (sentence.listening != null) {
        blocks.add(_analysisField('听力', sentence.listening!));
      }
      blocks.add(pw.SizedBox(height: 10));
    }
  }
  return blocks;
}

/// 附录条目里的一个解析字段：粗体标签 + 正文，无底色
pw.Widget _analysisField(String label, String text) {
  return pw.Padding(
    padding: const pw.EdgeInsets.only(left: 14, top: 3),
    child: pw.RichText(
      text: pw.TextSpan(
        style: const pw.TextStyle(
          fontSize: 8.5,
          lineSpacing: 2.5,
          color: _inkColor,
        ),
        children: [
          pw.TextSpan(
            text: '$label  ',
            style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
          ),
          pw.TextSpan(text: _sanitize(text)),
        ],
      ),
    ),
  );
}

/// 文本清洗：剔除控制字符（如 SentenceAnalysis.fieldSeparator U+001F），
/// 并截断超长字段防单块超一页高度抛异常。
///
/// 控制字符替换为空格保持等长（收藏命中掩码按原文偏移计算，不能错位）。
String _sanitize(String text) {
  var cleaned = text.replaceAll(RegExp(r'[\x00-\x1F\x7F]'), ' ');
  if (cleaned.length > _maxFieldChars) {
    cleaned = '${cleaned.substring(0, _maxFieldChars)}…';
  }
  return cleaned;
}
