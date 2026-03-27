/// 练习页面共享的普通模式视图（盲听 — 文字遮盖/偷看）
///
/// 布局：
/// - 上方：难句/收藏标记行
/// - 中间（Expanded）：隐藏占位 / 偷看文本，整个区域可点击切换字幕显示
/// - 中间下方：偷看字幕标签（提示用户可点击）
/// - 底部固定区：听不懂按钮（居中，与跟读录音按钮同位置） + 倒计时
///
/// 手动模式下隐藏倒计时。
/// 用于难句补练和收藏复习。
library;

import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import '../../providers/learning_session/review_difficult_practice_provider.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common/countdown_chip.dart';
import '../../widgets/common/tappable_wrapper.dart';

/// 普通模式视图（文字遮盖 / 偷看）
class PracticeNormalModeView extends StatelessWidget {
  /// 播放状态
  final ReviewDifficultPracticeState playerState;

  /// 本地化
  final AppLocalizations l10n;

  /// 主题
  final ThemeData theme;

  /// 切换偷看字幕
  final VoidCallback onPeekToggle;

  /// 听不懂（进入跟读模式）
  final VoidCallback onCantUnderstand;

  /// 切换标记（难句/收藏）
  final VoidCallback onToggleMark;

  /// 当前句子是否已标记为难句/收藏
  final bool isDifficult;

  /// 暂停/恢复倒计时
  final VoidCallback onPauseCountdown;

  /// 当前句子文本
  final String? sentenceText;

  /// 点击单词查词回调（null 时不启用逐词点击）
  final void Function(String word)? onWordTap;

  const PracticeNormalModeView({
    super.key,
    required this.playerState,
    required this.l10n,
    required this.theme,
    required this.onPeekToggle,
    required this.onCantUnderstand,
    required this.onToggleMark,
    this.isDifficult = true,
    required this.onPauseCountdown,
    this.sentenceText,
    this.onWordTap,
  });

  @override
  Widget build(BuildContext context) {
    final isRevealed = playerState.isTextRevealed;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.l),
      child: Column(
        children: [
          const SizedBox(height: AppSpacing.s),

          // 难句/收藏标记行
          TappableWrapper(
            onTap: onToggleMark,
            feedbackType: TapFeedback.opacity,
            pressedOpacity: 0.4,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Flexible(
                  child: Text(
                    isDifficult
                        ? l10n.intensiveListenMarkedDifficult
                        : l10n.intensiveListenNotDifficult,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.outline.withValues(alpha: 0.6),
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: AppSpacing.xs),
                Icon(
                  isDifficult ? Icons.bookmark : Icons.bookmark_border,
                  color: isDifficult ? Colors.amber : Colors.grey,
                  size: 18,
                ),
              ],
            ),
          ),

          // 字幕区域（整个区域可点击切换字幕）
          Expanded(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: onPeekToggle,
              child: Stack(
                children: [
                  Align(
                    alignment: const Alignment(0, -0.4),
                    child: isRevealed && sentenceText != null
                        ? GestureDetector(
                            onTap: () {}, // 拦截文字区域点击，不冒泡到偷看切换
                            child: onWordTap != null
                                ? _TappableText(
                                    text: sentenceText!,
                                    style: theme.textTheme.bodyLarge
                                            ?.copyWith(height: 1.6) ??
                                        const TextStyle(),
                                    onWordTap: onWordTap!,
                                  )
                                : Text(
                                    sentenceText!,
                                    style: theme.textTheme.bodyLarge
                                        ?.copyWith(height: 1.6),
                                    textAlign: TextAlign.left,
                                  ),
                          )
                        : const _HiddenTextPlaceholder(),
                  ),
                  Align(
                    alignment: const Alignment(0, 0.55),
                    child: _PeekLabel(
                      isRevealed: isRevealed,
                      l10n: l10n,
                      theme: theme,
                    ),
                  ),
                ],
              ),
            ),
          ),

          // 底部固定区：倒计时 + 按钮行
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // 倒计时（固定 56 高度占位，避免字幕区跳动）
              SizedBox(
                height: 56,
                child:
                    (playerState.isPauseBetweenPlays &&
                        !playerState.settings.isManualMode)
                    ? CountdownChip(
                        remaining: playerState.pauseRemaining,
                        total: playerState.pauseDuration,
                        isPaused: playerState.isCountdownPaused,
                        onTap: onPauseCountdown,
                      )
                    : null,
              ),
              const SizedBox(height: AppSpacing.m),
              // 取消标记 + 听不懂按钮（并排，统一 tonal 风格）
              SizedBox(
                height: 48,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    TextButton(
                      onPressed: onToggleMark,
                      style: TextButton.styleFrom(
                        foregroundColor: theme.colorScheme.onSurfaceVariant,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 12,
                        ),
                      ),
                      child: Text(
                        isDifficult
                            ? l10n.practiceRemoveMark
                            : l10n.practiceAddMark,
                        style: theme.textTheme.titleSmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.m),
                    FilledButton.tonal(
                      onPressed: onCantUnderstand,
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 28,
                          vertical: 12,
                        ),
                      ),
                      child: Text(
                        l10n.intensiveListenCantUnderstand,
                        style: theme.textTheme.titleSmall,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: AppSpacing.l),
        ],
      ),
    );
  }
}

/// 偷看字幕标签（字幕区下方，提示可点击）
class _PeekLabel extends StatelessWidget {
  final bool isRevealed;
  final AppLocalizations l10n;
  final ThemeData theme;

  const _PeekLabel({
    required this.isRevealed,
    required this.l10n,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          isRevealed
              ? Icons.visibility_off_outlined
              : Icons.visibility_outlined,
          size: 14,
          color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
        ),
        const SizedBox(width: 4),
        Text(
          isRevealed ? l10n.intensiveListenPeek : l10n.intensiveListenPeek,
          style: theme.textTheme.labelSmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
          ),
        ),
      ],
    );
  }
}

/// 去除单词两端的标点符号
String _cleanWord(String word) => word.replaceAll(
  RegExp(
    r'[.,!?;:\-—…、，。！？；："""'
    '()]',
  ),
  '',
);

/// 逐词可点击的文本（Wrap 布局，点击单词触发查词）
class _TappableText extends StatelessWidget {
  final String text;
  final TextStyle style;
  final void Function(String word) onWordTap;

  const _TappableText({
    required this.text,
    required this.style,
    required this.onWordTap,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = text.split(RegExp(r'\s+'));
    return Wrap(
      alignment: WrapAlignment.start,
      children: tokens.map((token) {
        final clean = _cleanWord(token);
        if (clean.isEmpty) return Text('$token ', style: style);
        return GestureDetector(
          onTap: () => onWordTap(clean),
          child: Text('$token ', style: style),
        );
      }).toList(),
    );
  }
}

/// 隐藏文本占位（灰色线条）
class _HiddenTextPlaceholder extends StatelessWidget {
  const _HiddenTextPlaceholder();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          Icons.hearing,
          size: 48,
          color: theme.colorScheme.primary.withValues(alpha: 0.3),
        ),
        const SizedBox(height: AppSpacing.l),
        for (int i = 0; i < 3; i++) ...[
          Container(
            width: 200 - i * 40,
            height: 8,
            margin: const EdgeInsets.symmetric(vertical: 4),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
        ],
      ],
    );
  }
}
