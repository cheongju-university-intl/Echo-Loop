/// 复述简报底部弹窗
///
/// 进入段落复述前显示，用户选择目标段落时长和段间停顿，
/// 复用 [showParagraphSelectionSheet] 通用组件。
library;

import 'package:flutter/material.dart';
import '../../database/enums.dart';
import '../../l10n/app_localizations.dart';
import '../../models/sentence.dart';
import '../common/paragraph_selection_sheet.dart';

/// 根据学习阶段计算段落复述的默认目标段落时长（秒）
///
/// - 首次学习 + 首轮复习 → 0（逐句）
/// - review1 + review2 → 10s
/// - review4 + review7 → 20s
/// - review14 + review28 → 30s
int retellDefaultSeconds(LearningStage? stage) {
  return switch (stage) {
    null || LearningStage.firstLearn || LearningStage.review0 => 0,
    LearningStage.review1 || LearningStage.review2 => 10,
    LearningStage.review4 || LearningStage.review7 => 20,
    _ => 30,
  };
}

/// 显示复述简报底部弹窗
///
/// [sentences] 完整句子列表（用于 DP 预览段落数）
/// [stageLabel] 可选的阶段名（如"第三轮复习"），显示在标题下方
/// [estimatedDurationText] 可选的预估时长文本，显示在说明下方
/// [onStartPractice] 点击"开始练习"时回调，传递选中的目标时长和停顿倍数
/// pauseMultiplier: -1.0 = 自动（智能模式），>0 = 段长倍数
Future<void> showRetellBriefingSheet({
  required BuildContext context,
  required List<Sentence> sentences,
  required void Function(Duration targetDuration, double pauseMultiplier)
      onStartPractice,
  int defaultSeconds = 30,
  String? stageLabel,
  String? estimatedDurationText,
}) {
  final l10n = AppLocalizations.of(context)!;
  return showParagraphSelectionSheet(
    context: context,
    icon: Icons.chat,
    title: l10n.retellBriefingTitle,
    subtitle: l10n.retellBriefingSubtitle,
    sentences: sentences,
    defaultSeconds: defaultSeconds,
    showPauseMultiplier: true,
    pauseMultiplierOptions: const [1.0, 2.0, 3.0, 4.0, 5.0],
    stageLabel: stageLabel,
    estimatedDurationText: estimatedDurationText,
    onStartPractice: onStartPractice,
  );
}
