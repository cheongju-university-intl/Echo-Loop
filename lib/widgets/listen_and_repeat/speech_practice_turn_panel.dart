/// 跟读回合状态面板（共享组件）
///
/// 录音状态面板：状态文字 + 录音按钮。
/// 跟读页面和难句补练页面共用。
/// 倒计时由 screen 层直接使用 [CountdownChip] 显示。
library;

import 'package:flutter/material.dart';
import '../../l10n/app_localizations.dart';
import '../../models/speech_practice_models.dart';
import '../../providers/listen_and_repeat_turn_controller_provider.dart';
import '../../theme/app_theme.dart';
import '../../widgets/listen_and_repeat/speech_record_button.dart';

/// 跟读回合状态面板。
///
/// 仅负责录音相关 UI（状态文字 + 录音按钮），
/// 不处理评估后倒计时（由 screen 层用 [CountdownChip] 直接显示）。
///
/// 错误提示（未检测到英语等）显示在录音按钮上方，红色文字，
/// 与复述页面的 `_buildStatusText` 行为一致。
class SpeechPracticeTurnPanel extends StatelessWidget {
  final AppLocalizations l10n;
  final ListenAndRepeatTurnState turnState;
  final bool isRecordingCurrent;
  final VoidCallback onRecordTap;

  /// 当前录音结果（用于显示错误提示）
  final SpeechPracticeAttempt? currentAttempt;

  const SpeechPracticeTurnPanel({
    super.key,
    required this.l10n,
    required this.turnState,
    required this.isRecordingCurrent,
    required this.onRecordTap,
    this.currentAttempt,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isProcessing = turnState.phase == ListenAndRepeatTurnPhase.processing;

    // 状态文字：优先显示错误提示（红色），其次显示录音阶段文字
    final (:text, :color) = _resolveStatusText(theme);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // 状态区：固定高度，显示当前状态文字
        SizedBox(
          height: 24,
          child: text != null
              ? Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (isProcessing)
                      Padding(
                        padding: const EdgeInsets.only(right: 6),
                        child: SizedBox(
                          width: 12,
                          height: 12,
                          child: CircularProgressIndicator(
                            strokeWidth: 1.5,
                            color: theme.colorScheme.onSurfaceVariant
                                .withValues(alpha: 0.6),
                          ),
                        ),
                      ),
                    Text(
                      text,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: color,
                        fontWeight: color == theme.colorScheme.error
                            ? FontWeight.w500
                            : null,
                      ),
                    ),
                  ],
                )
              : null,
        ),
        const SizedBox(height: AppSpacing.xs),
        // 录音按钮：processing 时禁用（灰显），其他阶段正常
        IgnorePointer(
          ignoring: isProcessing,
          child: Opacity(
            opacity: isProcessing ? 0.45 : 1.0,
            child: SpeechRecordButton(
              phase: switch (turnState.phase) {
                // idle / processing 显示蓝色待录音态
                // 只有 awaitingSpeech / speaking 才显示红色录音态
                ListenAndRepeatTurnPhase.idle ||
                ListenAndRepeatTurnPhase.processing =>
                  ListenAndRepeatTurnPhase.waitingForUser,
                final p => p,
              },
              onTap: onRecordTap,
            ),
          ),
        ),
      ],
    );
  }

  /// 解析状态文字和颜色。
  ///
  /// 与复述页面 `_buildStatusText` 行为一致：
  /// - 有错误结果 → 红色错误提示
  /// - 有正常结果且 idle → "点击开始录音"
  /// - 其他 → 按 phase 显示
  ({String? text, Color color}) _resolveStatusText(ThemeData theme) {
    final attempt = currentAttempt;
    final defaultColor = theme.colorScheme.onSurfaceVariant;

    // 评估结果中的错误提示
    if (attempt != null && attempt.hasFinalFeedback) {
      final isError =
          attempt.status == SpeechPracticeAttemptStatus.noEnglishDetected ||
          attempt.status == SpeechPracticeAttemptStatus.error ||
          attempt.status == SpeechPracticeAttemptStatus.permissionDenied ||
          attempt.status == SpeechPracticeAttemptStatus.unavailable;
      if (isError) {
        final errorText = switch (attempt.status) {
          SpeechPracticeAttemptStatus.noEnglishDetected =>
            l10n.listenAndRepeatRecognitionNoEnglish,
          SpeechPracticeAttemptStatus.permissionDenied =>
            l10n.listenAndRepeatTapToRecord,
          _ => attempt.errorMessage ?? l10n.listenAndRepeatAnalyzing,
        };
        return (text: errorText, color: theme.colorScheme.error);
      }
      // 正常结果且 idle：显示"点击录音"引导
      if (turnState.phase == ListenAndRepeatTurnPhase.idle) {
        return (
          text: l10n.listenAndRepeatTapToRecord,
          color: defaultColor.withValues(alpha: 0.5),
        );
      }
    }

    // 按 phase 显示
    final phaseText = switch (turnState.phase) {
      ListenAndRepeatTurnPhase.idle => l10n.listenAndRepeatTapToRecord,
      ListenAndRepeatTurnPhase.awaitingSpeech =>
        l10n.listenAndRepeatRecordingInProgress,
      ListenAndRepeatTurnPhase.speaking =>
        l10n.listenAndRepeatRecordingInProgress,
      ListenAndRepeatTurnPhase.processing => l10n.listenAndRepeatAnalyzing,
      ListenAndRepeatTurnPhase.waitingForUser =>
        l10n.listenAndRepeatTapToRecord,
      ListenAndRepeatTurnPhase.reviewCountdown => null,
    };
    return (text: phaseText, color: defaultColor);
  }
}
