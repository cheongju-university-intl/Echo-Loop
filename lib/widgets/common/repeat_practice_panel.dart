/// 跟读/复述页面共享的底部操作面板
///
/// 布局从上到下：
/// 1. 评分 badge（可选，点击播放录音）
/// 2. 中间区域（固定高度）：提示文本 / 倒计时+快进 / 录音按钮+状态标签 / 加载动画（互斥）
/// 3. 播放控制栏（上一个/播放暂停/下一个）
/// 4. 遍数 + 模式标签
///
/// 用于跟读、难句补练、收藏复习页面。
library;

import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import '../../models/speech_practice_models.dart';
import '../../providers/speech/speech_recording_controller.dart';
import '../../theme/app_theme.dart';
import 'playback_controls.dart';
import 'processing_indicator.dart';
import 'recording_button.dart' show RecordingButton, RecordingButtonMode;
import 'status_label.dart';
import '../practice/practice_play_count_label.dart';

/// 录音/倒计时区域固定高度（录音面板最高：24 状态 + 4 间距 + 56 按钮 + 16 底部 = 100）
const double kTurnAreaHeight = 100;

/// PlaybackControls 内部间距常量（prev 32 + gap 48 + center 56 + gap 48 = 184）
const double _kPlaybackLeftSpacing = 32 + 48 + 56 + 48;

/// next 按钮宽度
const double _kNavButtonSize = 32;

/// 跟读/复述页面共享的底部操作面板
class RepeatPracticePanel extends StatelessWidget {
  // ========== 评分 badge ==========

  /// 评分 badge（可选，显示在中间区域上方）
  final Widget? ratingBadge;

  // ========== 中间区域数据 ==========

  /// 提示文本（如 "先听再跟读"，播放中显示）
  final String? hintText;

  /// 是否显示倒计时
  final bool showCountdown;

  /// 是否处于停顿状态（录音/等待/倒计时）
  final bool isInPause;

  /// 录音状态
  final SpeechRecordingState turnState;

  /// 当前 promptId
  final String currentPromptId;

  /// 当前评估结果
  final SpeechPracticeAttempt? currentAttempt;

  /// 倒计时 widget（由调用方通过 Consumer 构建，监听各自的 provider）
  final Widget? countdownWidget;

  /// 快进按钮（可选）
  final Widget? fastForwardButton;

  /// 录音按钮点击回调
  final VoidCallback onRecordTap;

  // ========== 播放控制 ==========

  /// 是否可以返回上一个
  final bool canGoPrev;

  /// 是否为最后一个
  final bool isLast;

  /// 中间按钮图标（播放/暂停）
  final IconData centerIcon;

  /// 上一个回调
  final VoidCallback onPrevious;

  /// 下一个回调
  final VoidCallback onNext;

  /// 播放/暂停回调
  final VoidCallback onCenter;

  // ========== 遍数标签 ==========

  /// 预格式化的遍数文本
  final String playCountText;

  /// 是否为手动模式
  final bool isManualMode;

  /// 本地化
  final AppLocalizations l10n;

  /// 主题
  final ThemeData theme;

  const RepeatPracticePanel({
    super.key,
    this.ratingBadge,
    this.hintText,
    required this.showCountdown,
    required this.isInPause,
    required this.turnState,
    required this.currentPromptId,
    this.currentAttempt,
    this.countdownWidget,
    this.fastForwardButton,
    required this.onRecordTap,
    required this.canGoPrev,
    required this.isLast,
    required this.centerIcon,
    required this.onPrevious,
    required this.onNext,
    required this.onCenter,
    required this.playCountText,
    required this.isManualMode,
    required this.l10n,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(
        left: AppSpacing.l,
        right: AppSpacing.l,
        bottom: AppSpacing.m,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 评分 badge
          if (ratingBadge != null)
            Padding(
              padding: const EdgeInsets.only(
                top: AppSpacing.s,
                bottom: AppSpacing.xs,
              ),
              child: Center(child: ratingBadge),
            ),

          // 中间区域（固定高度，避免布局跳动）
          SizedBox(
            height: kTurnAreaHeight,
            child: _buildCenterArea(context),
          ),

          // 播放控制栏
          PlaybackControls(
            canGoPrev: canGoPrev,
            isLast: isLast,
            centerIcon: centerIcon,
            onPrevious: onPrevious,
            onNext: onNext,
            onCenter: onCenter,
          ),

          const SizedBox(height: AppSpacing.s),

          // 遍数 + 模式标签
          PracticePlayCountLabel(
            isManualMode: isManualMode,
            playCountText: playCountText,
            l10n: l10n,
            theme: theme,
          ),
        ],
      ),
    );
  }

  /// 构建中间区域内容（优先级：hintText > countdown > recording/processing > empty）
  Widget _buildCenterArea(BuildContext context) {
    // 播放中：显示提示文本
    if (hintText != null) {
      return Center(
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.headphones_rounded,
              size: 20,
              color: theme.colorScheme.onSurfaceVariant,
            ),
            const SizedBox(width: 6),
            Text(
              hintText!,
              style: theme.textTheme.titleSmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      );
    }

    // 倒计时中
    if (showCountdown && countdownWidget != null) {
      if (fastForwardButton != null) {
        return _buildCenterWithFastForward(countdownWidget!);
      }
      return countdownWidget!;
    }

    // 停顿中：录音按钮 / 加载动画
    if (isInPause) {
      return _buildRecordingArea(context);
    }

    return const SizedBox.shrink();
  }

  /// 录音区域（录音按钮+状态标签 / 评估加载动画）
  Widget _buildRecordingArea(BuildContext context) {
    final isRecordingCurrent = turnState.isRecordingPrompt(currentPromptId);
    final isProcessing = turnState.promptId == currentPromptId &&
        turnState.phase == SpeechRecordingPhase.processing;

    if (isProcessing) {
      return Center(
        child: ProcessingIndicator(text: l10n.listenAndRepeatAnalyzing),
      );
    }

    final mode = isRecordingCurrent
        ? switch (turnState.phase) {
            SpeechRecordingPhase.awaitingSpeech ||
            SpeechRecordingPhase.speaking =>
              RecordingButtonMode.recording,
            _ => RecordingButtonMode.idle,
          }
        : RecordingButtonMode.idle;

    final hasError = currentAttempt?.errorMessage != null;

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.m),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          StatusLabel(
            text: hasError
                ? currentAttempt!.errorMessage
                : switch (mode) {
                    RecordingButtonMode.idle => l10n.listenAndRepeatTapToRecord,
                    RecordingButtonMode.recording =>
                      l10n.listenAndRepeatRecordingInProgress,
                    RecordingButtonMode.disabled => null,
                  },
            color: hasError ? Theme.of(context).colorScheme.error : null,
            bold: hasError,
          ),
          const SizedBox(height: AppSpacing.xs),
          RecordingButton(
            mode: mode,
            onTap: onRecordTap,
          ),
        ],
      ),
    );
  }

  /// 倒计时居中 + 快进按钮与 PlaybackControls 的 next 按钮垂直对齐
  Widget _buildCenterWithFastForward(Widget countdown) {
    return Stack(
      alignment: Alignment.center,
      children: [
        countdown,
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const SizedBox(width: _kPlaybackLeftSpacing),
            SizedBox(
              width: _kNavButtonSize,
              height: _kNavButtonSize,
              child: fastForwardButton,
            ),
          ],
        ),
      ],
    );
  }
}
