/// 遮盖句子 Tile
///
/// 段落内单个句子的显示组件，支持多种渲染模式：
/// - 按 displayMode 显示关键词/全部显示/全部隐藏（listening 和 retelling 通用）
/// - listening 阶段当前播放句高亮
///
/// 每个词独立渲染（Wrap 子元素数量恒定，切换模式时布局不跳动），
/// 连续遮盖词通过溢出绘制桥接色块实现视觉连续。
library;

import 'package:flutter/material.dart';
import '../../l10n/app_localizations.dart';
import '../../models/retell_settings.dart';
import '../../models/sentence.dart';
import '../../theme/app_theme.dart';
import '../../utils/keyword_extraction.dart';
import '../guide_flow.dart';

/// 句子编号点击区 key 前缀（供 widget test 精准点击，避免点到文本本身）。
@visibleForTesting
const String kMaskedSentenceNumberHitAreaKeyPrefix =
    'masked-sentence-number-hit-area';

/// 句子主体点击区 key 前缀（供 widget test 精准点击，避免受内部文本布局影响）。
@visibleForTesting
const String kMaskedSentenceBodyHitAreaKeyPrefix =
    'masked-sentence-body-hit-area';

/// 句子收藏按钮 key 前缀（供 widget test 精准点击右侧收藏热区）。
@visibleForTesting
const String kMaskedSentenceBookmarkHitAreaKeyPrefix =
    'masked-sentence-bookmark-hit-area';

/// Wrap 子元素间距（px）— 模拟自然空格宽度
const _wordSpacing = 4.0;

/// 遮盖句子 Tile
///
/// 三个独立点击区：
/// - **编号区**（左侧 48dp 宽，撑满 tile 全高）：`onPlayFromTap`，点击从该句开播。
///   当前播放句的编号位置渲染 ▶ play_arrow 图标，提示"点击=播放"。
/// - **主体区**（中间 Expanded）：`onDetailTap`，点击进入句子讲解页。
/// - **收藏区**（右侧独立按钮）：`onBookmarkTap`，直接收藏/取消收藏。
class MaskedSentenceTile extends StatelessWidget {
  /// 句子数据
  final Sentence sentence;

  /// 文本显示模式
  final RetellDisplayMode displayMode;

  /// 该句的关键词词索引集合
  final Set<int> keywordIndices;

  /// 是否为当前播放中的句子
  final bool isPlayingSentence;

  /// 是否已收藏
  final bool isBookmarked;

  /// 点击编号区回调：从该句开始播放
  final VoidCallback? onPlayFromTap;

  /// 点击主体（文本/书签）区回调：进入句子讲解页
  final VoidCallback? onDetailTap;

  /// 点击右侧收藏按钮回调：直接切换收藏状态
  final VoidCallback? onBookmarkTap;

  /// 新手引导：编号区 GuideStep（非空时包 GuideTarget 高亮编号区）
  final GuideStep? numberAreaGuideStep;

  /// 新手引导：主体区 GuideStep（非空时包 GuideTarget 高亮文本区）
  final GuideStep? bodyAreaGuideStep;

  const MaskedSentenceTile({
    super.key,
    required this.sentence,
    required this.displayMode,
    required this.keywordIndices,
    required this.isPlayingSentence,
    this.isBookmarked = false,
    this.onPlayFromTap,
    this.onDetailTap,
    this.onBookmarkTap,
    this.numberAreaGuideStep,
    this.bodyAreaGuideStep,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      decoration: BoxDecoration(
        color: isPlayingSentence
            ? theme.colorScheme.primaryContainer.withValues(alpha: 0.3)
            : null,
        border: Border(
          left: BorderSide(
            color: isPlayingSentence
                ? theme.colorScheme.primary
                : Colors.transparent,
            width: 3,
          ),
        ),
      ),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _wrapWithGuide(
              numberAreaGuideStep,
              _SentenceNumberHitArea(
                key: ValueKey(
                  '$kMaskedSentenceNumberHitAreaKeyPrefix-${sentence.index}',
                ),
                displayNumber: sentence.index + 1,
                isPlayingSentence: isPlayingSentence,
                theme: theme,
                onTap: onPlayFromTap,
              ),
            ),
            Expanded(
              child: _wrapWithGuide(
                bodyAreaGuideStep,
                _SentenceBodyHitArea(
                  key: ValueKey(
                    '$kMaskedSentenceBodyHitAreaKeyPrefix-${sentence.index}',
                  ),
                  theme: theme,
                  onTap: onDetailTap,
                  child: _buildMaskedText(theme, tokenize(sentence.text)),
                ),
              ),
            ),
            _SentenceBookmarkHitArea(
              key: ValueKey(
                '$kMaskedSentenceBookmarkHitAreaKeyPrefix-${sentence.index}',
              ),
              theme: theme,
              isBookmarked: isBookmarked,
              onTap: onBookmarkTap,
            ),
          ],
        ),
      ),
    );
  }

  Widget _wrapWithGuide(GuideStep? step, Widget child) =>
      step == null ? child : GuideTarget(step: step, child: child);

  /// 构建遮盖文本
  Widget _buildMaskedText(ThemeData theme, List<String> words) {
    if (words.isEmpty) return const SizedBox.shrink();

    // 按显示模式渲染（listening 和 retelling 阶段统一逻辑）
    final shouldMask = switch (displayMode) {
      RetellDisplayMode.keywordsOnly => (int idx) => !keywordIndices.contains(
        idx,
      ),
      RetellDisplayMode.showAll => (int idx) => false,
      RetellDisplayMode.hideAll => (int idx) => true,
    };

    return Wrap(
      spacing: _wordSpacing,
      runSpacing: 2,
      children: _buildWordWidgets(words, shouldMask, theme),
    );
  }

  /// 构建独立词组件列表
  ///
  /// 每个词独立渲染，保证所有模式下 Wrap children 数量一致。
  /// 连续遮盖词通过溢出绘制桥接色块实现视觉连续。
  List<Widget> _buildWordWidgets(
    List<String> words,
    bool Function(int index) shouldMask,
    ThemeData theme,
  ) {
    return [
      for (var i = 0; i < words.length; i++)
        _WordBlock(
          text: words[i],
          isMasked: shouldMask(i),
          isPrevMasked: i > 0 && shouldMask(i) && shouldMask(i - 1),
          isNextMasked:
              i < words.length - 1 && shouldMask(i) && shouldMask(i + 1),
          theme: theme,
        ),
    ];
  }
}

/// 编号点击区
///
/// 固定 40dp 宽，给正文释放更多横向空间，同时保留独立播放热区。
/// 当前播放句渲染 ▶ play_arrow（与正在播放视觉绑定），否则渲染数字。
class _SentenceNumberHitArea extends StatelessWidget {
  final int displayNumber;
  final bool isPlayingSentence;
  final VoidCallback? onTap;
  final ThemeData theme;

  const _SentenceNumberHitArea({
    super.key,
    required this.displayNumber,
    required this.isPlayingSentence,
    required this.theme,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final inner = SizedBox(
      width: 40,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.s),
        child: Center(
          child: isPlayingSentence
              ? Icon(
                  Icons.play_arrow,
                  size: 20,
                  color: theme.colorScheme.primary,
                )
              : Text(
                  '$displayNumber',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
        ),
      ),
    );

    if (onTap == null) return inner;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        // 背景在外层 AnimatedContainer 上，splash 会被遮挡，仅用 highlight 反馈
        splashColor: Colors.transparent,
        highlightColor: theme.colorScheme.primary.withValues(alpha: 0.12),
        child: inner,
      ),
    );
  }
}

/// 主体点击区（文本）
///
/// 撑满剩余宽度，撑满 tile 全高。点击进入句子讲解页。
class _SentenceBodyHitArea extends StatelessWidget {
  final ThemeData theme;
  final VoidCallback? onTap;
  final Widget child;

  const _SentenceBodyHitArea({
    super.key,
    required this.theme,
    required this.child,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final inner = Padding(
      padding: const EdgeInsets.only(
        left: AppSpacing.xs,
        right: AppSpacing.s,
        top: AppSpacing.s,
        bottom: AppSpacing.s,
      ),
      child: child,
    );

    if (onTap == null) return inner;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        splashColor: Colors.transparent,
        highlightColor: theme.colorScheme.primary.withValues(alpha: 0.08),
        child: inner,
      ),
    );
  }
}

/// 收藏按钮点击区
///
/// 视觉上收窄为句子右侧的轻量标记，不与句子文本竞争注意力；
/// 交互上仍保持独立热区，避免和中间文本进讲解混在一起。
class _SentenceBookmarkHitArea extends StatelessWidget {
  final ThemeData theme;
  final bool isBookmarked;
  final VoidCallback? onTap;

  const _SentenceBookmarkHitArea({
    super.key,
    required this.theme,
    required this.isBookmarked,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final semanticLabel = isBookmarked
        ? l10n.intensiveListenMarkedDifficult
        : l10n.intensiveListenNotDifficult;
    final iconColor = isBookmarked
        ? Colors.amber
        : theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.28);

    final inner = SizedBox(
      width: 38,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.s),
        child: Center(
          child: Icon(
            isBookmarked ? Icons.bookmark : Icons.bookmark_border,
            size: 14,
            color: iconColor,
            semanticLabel: semanticLabel,
          ),
        ),
      ),
    );

    if (onTap == null) return inner;
    return Semantics(
      button: true,
      label: semanticLabel,
      child: Tooltip(
        message: semanticLabel,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            splashColor: Colors.transparent,
            highlightColor: theme.colorScheme.primary.withValues(alpha: 0.03),
            child: inner,
          ),
        ),
      ),
    );
  }
}

/// 统一词块：可见或遮盖，统一 padding 保证等高
///
/// 遮盖模式下，通过 [isPrevMasked]/[isNextMasked] 控制：
/// - 连接侧圆角置零
/// - 向后溢出绘制桥接色块，填充 Wrap spacing 间隙
class _WordBlock extends StatelessWidget {
  final String text;
  final bool isMasked;
  final bool isPrevMasked;
  final bool isNextMasked;
  final ThemeData theme;

  const _WordBlock({
    required this.text,
    required this.isMasked,
    required this.theme,
    this.isPrevMasked = false,
    this.isNextMasked = false,
  });

  @override
  Widget build(BuildContext context) {
    final maskColor = theme.colorScheme.surfaceContainerHighest;

    final child = Container(
      padding: const EdgeInsets.symmetric(vertical: 1),
      decoration: isMasked
          ? BoxDecoration(
              color: maskColor,
              borderRadius: BorderRadius.horizontal(
                left: isPrevMasked ? Radius.zero : const Radius.circular(3),
                right: isNextMasked ? Radius.zero : const Radius.circular(3),
              ),
            )
          : null,
      child: Text(
        text,
        style: theme.textTheme.bodyMedium?.copyWith(
          color: isMasked ? Colors.transparent : null,
        ),
      ),
    );

    // 连续遮盖词：向右溢出绘制桥接色块填充 Wrap spacing
    if (isMasked && isNextMasked) {
      return Stack(
        clipBehavior: Clip.none,
        children: [
          child,
          Positioned(
            right: -_wordSpacing,
            top: 0,
            bottom: 0,
            width: _wordSpacing,
            child: ColoredBox(color: maskColor),
          ),
        ],
      );
    }

    return child;
  }
}
