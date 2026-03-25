/// 英语停用词集合
///
/// 用于关键词提取时过滤常见功能词，使提取结果更有意义。
/// 停用词为小写，匹配时需先去除标点再转小写。
library;

/// 去除首尾标点的正则
final _punctuationPattern = RegExp(r"^[^a-zA-Z']+|[^a-zA-Z']+$");

/// 判断单词是否为停用词
///
/// 去除首尾标点、转小写后与停用词集合匹配。
bool isStopword(String word) {
  final normalized = word.replaceAll(_punctuationPattern, '').toLowerCase();
  return englishStopwords.contains(normalized);
}

/// 英语停用词集合（小写）
///
/// 包含冠词、代词、be 动词、助动词、介词、连词、限定词、
/// 高频功能副词及常见缩写形式。
const Set<String> englishStopwords = {
  // ── 冠词 ──
  'a', 'an', 'the',

  // ── 代词 ──
  'i', 'me', 'my', 'mine', 'myself',
  'we', 'us', 'our', 'ours', 'ourselves',
  'you', 'your', 'yours', 'yourself', 'yourselves',
  'he', 'him', 'his', 'himself',
  'she', 'her', 'hers', 'herself',
  'it', 'its', 'itself',
  'they', 'them', 'their', 'theirs', 'themselves',

  // ── be 动词 ──
  'am', 'is', 'are', 'was', 'were', 'be', 'been', 'being',

  // ── 助动词 / 情态动词 ──
  'have', 'has', 'had', 'having',
  'do', 'does', 'did', 'doing',
  'will', 'would', 'shall', 'should',
  'can', 'could', 'may', 'might', 'must',
  'ought', 'need',

  // ── 助动词补充 ──
  'done',

  // ── 介词 ──
  'in', 'on', 'at', 'to', 'for', 'of', 'with', 'by',
  'from', 'about', 'into', 'through', 'during', 'before',
  'after', 'above', 'below', 'between', 'under', 'over',
  'out', 'off', 'up', 'down',
  'against', 'along', 'among', 'amongst', 'around',
  'upon', 'toward', 'towards', 'within', 'without',
  'across', 'behind', 'beyond', 'near',
  'onto', 'per', 'via', 'throughout', 'beside', 'besides',
  'past', 'unto', 'outside', 'inside',

  // ── 连词 ──
  'and', 'but', 'or', 'nor', 'so', 'yet',
  'if', 'because', 'as', 'until', 'while', 'although', 'though',
  'since', 'unless', 'whether', 'once',
  'whereas', 'whereby', 'wherever', 'whenever', 'whoever',
  'whatever', 'whichever', 'however', 'therefore', 'furthermore',
  'moreover', 'nevertheless', 'nonetheless', 'meanwhile',
  'thus', 'hence', 'thereby', 'therein', 'thereof',
  'thereafter', 'thereupon', 'herein', 'hereby',

  // ── 指示词 / 限定词 / 不定代词 ──
  'this', 'that', 'these', 'those',
  'all', 'each', 'every', 'both', 'some', 'any', 'few',
  'more', 'most', 'other', 'others', 'such', 'only', 'own', 'same',
  'no', 'not', 'none',
  'another', 'either', 'neither', 'several',
  'anybody', 'anyone', 'anything', 'anywhere',
  'everybody', 'everyone', 'everything', 'everywhere',
  'somebody', 'someone', 'something', 'somewhere',
  'nobody', 'nothing', 'nowhere',

  // ── 高频功能副词 ──
  'very', 'too', 'also', 'just', 'then', 'than', 'now',
  'here', 'there', 'when', 'where', 'how', 'what', 'which',
  'who', 'whom', 'whose', 'why',
  'again', 'further', 'already', 'always', 'never',
  'ever', 'often', 'sometimes', 'still', 'even',
  'quite', 'rather', 'perhaps', 'merely', 'nearly', 'hardly',
  'enough', 'instead', 'otherwise', 'anyway', 'indeed',
  'almost', 'altogether', 'apparently',
  'aside', 'away', 'forth', 'forward',
  'ago', 'ahead', 'apart',

  // ── 其他高频功能词 ──
  'get', 'got', 'gets', 'getting', 'gotten',
  'much', 'many', 'like',
  'well', 'back', 'way',
  'cannot', 'come', 'came', 'goes', 'went', 'gone',
  'make', 'made', 'take', 'took', 'taken',
  'give', 'gave', 'given', 'keep', 'kept',
  'say', 'said', 'tell', 'told',
  'seem', 'seemed', 'seems',
  'become', 'became', 'becomes',
  'let', 'put', 'use', 'used',

  // ── 否定缩写 ──
  "aren't", "can't", "couldn't", "didn't", "doesn't", "don't",
  "hadn't", "hasn't", "haven't", "isn't", "mightn't", "mustn't",
  "needn't", "shan't", "shouldn't", "wasn't", "weren't",
  "won't", "wouldn't",

  // ── 代词 / 助动词缩写 ──
  "he'd", "he'll", "he's",
  "she'd", "she'll", "she's",
  "it's", "it'd", "it'll",
  "i'd", "i'll", "i'm", "i've",
  "we'd", "we'll", "we're", "we've",
  "you'd", "you'll", "you're", "you've",
  "they'd", "they'll", "they're", "they've",
  "that's", "there's", "here's",
  "what's", "when's", "where's", "who's", "how's", "why's",
  "let's",
};
