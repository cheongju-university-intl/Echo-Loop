/// 精听播放器页面
///
/// 逐句精听界面，支持普通模式（文字遮盖）、标注模式（揭示文本）、
/// 标注重播模式（带字幕重播）。
///
/// 完成处理：所有句子播完 → 完成对话框 → completeCurrentSubStage → 退出
/// 退出处理：PopScope → 保存断点 → exitLearningMode → pop
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../database/providers.dart';
import '../l10n/app_localizations.dart';
import '../providers/learning_progress_provider.dart';
import '../providers/learning_session/intensive_listen_player_provider.dart';
import '../providers/learning_session/learning_session_provider.dart';
import '../providers/listening_practice/bookmark_manager.dart';
import '../theme/app_theme.dart';
import '../widgets/intensive_listen/intensive_listen_settings_sheet.dart';
import '../widgets/intensive_listen/sentence_annotation_card.dart';

/// 精听播放器页面
class IntensiveListenPlayerScreen extends ConsumerStatefulWidget {
  /// 合集 ID（用于返回导航，从独立音频路由进入时为 null）
  final String? collectionId;

  /// 音频项 ID
  final String audioItemId;

  const IntensiveListenPlayerScreen({
    super.key,
    this.collectionId,
    required this.audioItemId,
  });

  @override
  ConsumerState<IntensiveListenPlayerScreen> createState() =>
      _IntensiveListenPlayerScreenState();
}

class _IntensiveListenPlayerScreenState
    extends ConsumerState<IntensiveListenPlayerScreen> {
  bool _isShowingDialog = false;

  @override
  void initState() {
    super.initState();
    // 进入后自动开始播放
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(intensiveListenPlayerProvider.notifier).startPlaying();
    });
  }

  /// 处理退出（close 按钮 / 系统返回）
  ///
  /// 自由练习模式直接退出；正常学习模式弹出确认对话框，
  /// 确认后保存断点和难句，再退出。
  Future<void> _handleExit() async {
    final player = ref.read(intensiveListenPlayerProvider.notifier);
    await player.pause();
    if (!mounted) return;

    final session = ref.read(learningSessionProvider);
    if (session.isFreePlay) {
      await ref.read(learningSessionProvider.notifier).exitLearningMode();
      if (mounted) context.pop();
      return;
    }

    final l10n = AppLocalizations.of(context)!;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.exitIntensiveListenTitle),
        content: Text(l10n.exitIntensiveListenMessage),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(l10n.confirmExit),
          ),
        ],
      ),
    );

    if (confirm != true || !mounted) {
      // 用户取消退出 → 恢复播放（标注模式下不恢复，保持暂停状态）
      if (mounted) {
        final currentState = ref.read(intensiveListenPlayerProvider);
        if (!currentState.isAnnotationMode) {
          player.resume();
        }
      }
      return;
    }

    // 保存断点 + 难句
    await _saveSentenceProgress();
    await _saveDifficultSentences();

    await ref.read(learningSessionProvider.notifier).exitLearningMode();
    if (mounted) context.pop();
  }

  /// 保存精听断点进度
  Future<void> _saveSentenceProgress() async {
    final player = ref.read(intensiveListenPlayerProvider.notifier);
    await ref
        .read(learningProgressNotifierProvider.notifier)
        .saveIntensiveListenSentenceIndex(
          widget.audioItemId,
          player.currentIndex,
        );
  }

  /// 保存难句书签到数据库
  Future<void> _saveDifficultSentences() async {
    final playerState = ref.read(intensiveListenPlayerProvider);
    final player = ref.read(intensiveListenPlayerProvider.notifier);
    final bookmarkDao = ref.read(bookmarkDaoProvider);

    for (final index in playerState.difficultSentences) {
      if (index < player.sentences.length) {
        final sentence = player.sentences[index];
        await BookmarkManager.addBookmarkToDb(
          widget.audioItemId,
          sentence,
          dao: bookmarkDao,
        );
      }
    }
  }

  /// 处理播放完成
  Future<void> _handleCompleted() async {
    if (_isShowingDialog || !mounted) return;
    _isShowingDialog = true;

    final session = ref.read(learningSessionProvider);
    final playerState = ref.read(intensiveListenPlayerProvider);

    // 保存难句书签
    await _saveDifficultSentences();

    if (!mounted) {
      _isShowingDialog = false;
      return;
    }

    final l10n = AppLocalizations.of(context)!;

    // 自由练习模式直接退出
    if (session.isFreePlay) {
      await ref.read(learningSessionProvider.notifier).exitLearningMode();
      _isShowingDialog = false;
      if (mounted) context.pop();
      return;
    }

    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.intensiveListenCompleteTitle),
        content: Text(
          l10n.intensiveListenCompleteMessage(
            playerState.totalSentences,
            playerState.difficultSentences.length,
          ),
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(l10n.intensiveListenCompleteNext),
          ),
        ],
      ),
    );

    _isShowingDialog = false;
    if (!mounted) return;

    if (result == true) {
      try {
        // 清除断点（已完成）
        await ref
            .read(learningProgressNotifierProvider.notifier)
            .saveIntensiveListenSentenceIndex(widget.audioItemId, null);

        // 推进子步骤
        await ref
            .read(learningProgressNotifierProvider.notifier)
            .completeCurrentSubStage(widget.audioItemId);
      } catch (e) {
        debugPrint('精听完成处理出错: $e');
      }

      await ref.read(learningSessionProvider.notifier).exitLearningMode();
      if (mounted) context.pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);

    final playerState = ref.watch(intensiveListenPlayerProvider);
    final player = ref.read(intensiveListenPlayerProvider.notifier);

    // 监听完成状态
    ref.listen<IntensiveListenState>(intensiveListenPlayerProvider, (
      prev,
      next,
    ) {
      if (next.isCompleted && !(prev?.isCompleted ?? false)) {
        _handleCompleted();
      }
    });

    final currentSentence = player.currentSentence;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        _handleExit();
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(l10n.intensiveListenAppBarTitle),
          centerTitle: true,
          actions: [
            IconButton(
              icon: const Icon(Icons.tune),
              tooltip: l10n.intensiveListenSettings,
              onPressed: () {
                showIntensiveListenSettingsSheet(context: context);
              },
            ),
          ],
        ),
        body: Column(
          children: [
            // 进度条
            _ProgressSection(playerState: playerState, l10n: l10n),

            // 主体内容
            Expanded(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 300),
                child: playerState.isAnnotationReplay
                    ? _AnnotationReplayView(
                        key: const ValueKey('replay'),
                        text: currentSentence?.text ?? '',
                        l10n: l10n,
                      )
                    : playerState.isAnnotationMode
                    ? _AnnotationModeView(
                        key: const ValueKey('annotation'),
                        text: currentSentence?.text ?? '',
                        isDifficult: playerState.difficultSentences.contains(
                          playerState.currentSentenceIndex,
                        ),
                        l10n: l10n,
                        onContinue: () => player.exitAnnotationMode(),
                        onToggleDifficult: () =>
                            player.toggleDifficultSentence(),
                      )
                    : _NormalModeView(
                        key: const ValueKey('normal'),
                        playerState: playerState,
                        l10n: l10n,
                        theme: theme,
                        onPeek: () => player.toggleTextReveal(),
                        onCantUnderstand: () => player.enterAnnotationMode(),
                        sentenceText: currentSentence?.text,
                      ),
              ),
            ),

            // 底部播放控制
            _PlaybackControls(
              playerState: playerState,
              onPrevious: () => player.goToPrevious(),
              onNext: () => player.goToNext(),
              onPlayPause: () {
                if (playerState.isAnnotationMode) {
                  player.replayInAnnotationMode();
                } else if (playerState.isPlaying) {
                  player.pause();
                } else {
                  player.resume();
                }
              },
            ),
          ],
        ),
      ),
    );
  }
}

/// 顶部进度条区域
class _ProgressSection extends StatelessWidget {
  final IntensiveListenState playerState;
  final AppLocalizations l10n;

  const _ProgressSection({required this.playerState, required this.l10n});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final total = playerState.totalSentences;
    final current = playerState.currentSentenceIndex + 1;
    final progress = total > 0 ? current / total : 0.0;

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.m,
        vertical: AppSpacing.s,
      ),
      child: Column(
        children: [
          LinearProgressIndicator(
            value: progress,
            borderRadius: BorderRadius.circular(2),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            l10n.intensiveListenProgress(current, total),
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

/// 普通模式视图（文字遮盖 / 偷看）
class _NormalModeView extends StatelessWidget {
  final IntensiveListenState playerState;
  final AppLocalizations l10n;
  final ThemeData theme;
  final VoidCallback onPeek;
  final VoidCallback onCantUnderstand;
  final String? sentenceText;

  const _NormalModeView({
    super.key,
    required this.playerState,
    required this.l10n,
    required this.theme,
    required this.onPeek,
    required this.onCantUnderstand,
    this.sentenceText,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.l),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // 遮盖/偷看区域
          Expanded(
            child: Center(
              child: playerState.isTextRevealed && sentenceText != null
                  ? Text(
                      sentenceText!,
                      style: theme.textTheme.titleMedium?.copyWith(height: 1.6),
                      textAlign: TextAlign.center,
                    )
                  : _HiddenTextPlaceholder(),
            ),
          ),

          // 固定高度区域：播放遍数 或 间隔倒计时
          SizedBox(
            height: 64,
            child: Center(
              child: playerState.isPauseBetweenPlays
                  ? _PauseCountdownIndicator(
                      remaining: playerState.pauseRemaining,
                      total: playerState.pauseDuration,
                      isBetweenSentences: playerState.isPauseBetweenSentences,
                      l10n: l10n,
                    )
                  : Text(
                      l10n.intensiveListenPlayCount(
                        playerState.currentPlayCount,
                        playerState.settings.repeatCount,
                      ),
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
            ),
          ),

          const SizedBox(height: AppSpacing.l),

          // 操作按钮行
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              OutlinedButton.icon(
                onPressed: onPeek,
                icon: Icon(
                  playerState.isTextRevealed
                      ? Icons.visibility_off
                      : Icons.visibility,
                ),
                label: Text(
                  playerState.isTextRevealed
                      ? l10n.intensiveListenHideSubtitle
                      : l10n.intensiveListenPeek,
                ),
              ),
              const SizedBox(width: AppSpacing.m),
              FilledButton.tonal(
                onPressed: onCantUnderstand,
                child: Text(l10n.intensiveListenCantUnderstand),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// 隐藏文本占位（灰色线条）
class _HiddenTextPlaceholder extends StatelessWidget {
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
        // 占位灰色线条
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

/// 间隔倒计时指示器
class _PauseCountdownIndicator extends StatelessWidget {
  final Duration remaining;
  final Duration total;

  /// 是否是句间停顿（true=下一句，false=下一遍）
  final bool isBetweenSentences;
  final AppLocalizations l10n;

  const _PauseCountdownIndicator({
    required this.remaining,
    required this.total,
    required this.isBetweenSentences,
    required this.l10n,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final totalMs = total.inMilliseconds;
    final remainingMs = remaining.inMilliseconds;
    final progress = totalMs > 0 ? 1.0 - (remainingMs / totalMs) : 1.0;
    final seconds = (remainingMs / 1000).ceil();

    final label = isBetweenSentences
        ? l10n.intensiveListenPauseBetweenSentences(seconds)
        : l10n.intensiveListenPauseBetweenPlays(seconds);

    return Column(
      children: [
        Text(
          label,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: AppSpacing.s),
        SizedBox(
          width: 120,
          child: LinearProgressIndicator(
            value: progress.clamp(0.0, 1.0),
            borderRadius: BorderRadius.circular(2),
          ),
        ),
      ],
    );
  }
}

/// 标注模式视图
class _AnnotationModeView extends StatelessWidget {
  final String text;
  final bool isDifficult;
  final AppLocalizations l10n;
  final VoidCallback onContinue;
  final VoidCallback onToggleDifficult;

  const _AnnotationModeView({
    super.key,
    required this.text,
    required this.isDifficult,
    required this.l10n,
    required this.onContinue,
    required this.onToggleDifficult,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.l),
      child: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              child: SentenceAnnotationCard(
                text: text,
                isDifficult: isDifficult,
                onToggle: onToggleDifficult,
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.m),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: onContinue,
              child: Text(l10n.intensiveListenContinue),
            ),
          ),
        ],
      ),
    );
  }
}

/// 标注重播模式视图（带字幕重播中）
class _AnnotationReplayView extends StatelessWidget {
  final String text;
  final AppLocalizations l10n;

  const _AnnotationReplayView({
    super.key,
    required this.text,
    required this.l10n,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.all(AppSpacing.l),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 显示句子文本
            Text(
              text,
              style: theme.textTheme.titleMedium?.copyWith(height: 1.6),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.l),

            // 播放中指示器
            CircularProgressIndicator(strokeWidth: 2),
            const SizedBox(height: AppSpacing.s),
            Text(
              l10n.intensiveListenReplayingWithSubtitle,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 底部播放控制
class _PlaybackControls extends StatelessWidget {
  final IntensiveListenState playerState;
  final VoidCallback onPrevious;
  final VoidCallback onNext;
  final VoidCallback onPlayPause;

  const _PlaybackControls({
    required this.playerState,
    required this.onPrevious,
    required this.onNext,
    required this.onPlayPause,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    // 标注重播模式下播放按钮禁用（自动播放中，不应干预）
    final isPlayDisabled = playerState.isAnnotationReplay;

    // 上一句/下一句：标注模式和标注重播模式下都禁用
    final isNavDisabled =
        playerState.isAnnotationMode || playerState.isAnnotationReplay;

    return Container(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.l,
        AppSpacing.m,
        AppSpacing.l,
        AppSpacing.xl,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // 上一句
          IconButton(
            onPressed: isNavDisabled || playerState.currentSentenceIndex <= 0
                ? null
                : onPrevious,
            icon: const Icon(Icons.skip_previous, size: 32),
            color: theme.colorScheme.onSurface,
          ),
          const SizedBox(width: AppSpacing.l),

          // 播放/暂停
          GestureDetector(
            onTap: isPlayDisabled ? null : onPlayPause,
            child: Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: isPlayDisabled
                    ? theme.colorScheme.surfaceContainerHighest
                    : theme.colorScheme.primary,
                shape: BoxShape.circle,
                boxShadow: isPlayDisabled
                    ? null
                    : [
                        BoxShadow(
                          color: theme.colorScheme.primary.withValues(
                            alpha: 0.3,
                          ),
                          blurRadius: 16,
                          offset: const Offset(0, 4),
                        ),
                      ],
              ),
              child: Icon(
                playerState.isPlaying ? Icons.pause : Icons.play_arrow,
                size: 32,
                color: isPlayDisabled
                    ? theme.colorScheme.onSurfaceVariant
                    : theme.colorScheme.onPrimary,
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.l),

          // 下一句
          IconButton(
            onPressed:
                isNavDisabled ||
                    playerState.currentSentenceIndex >=
                        playerState.totalSentences - 1
                ? null
                : onNext,
            icon: const Icon(Icons.skip_next, size: 32),
            color: theme.colorScheme.onSurface,
          ),
        ],
      ),
    );
  }
}
