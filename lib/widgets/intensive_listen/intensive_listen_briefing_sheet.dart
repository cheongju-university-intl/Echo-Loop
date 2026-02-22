/// 精听简报底部弹窗
///
/// 进入精听前显示，告知用户句子总数和操作提示。
/// 参照 blind_listen_briefing_sheet.dart 实现。
library;

import 'package:flutter/material.dart';
import '../../l10n/app_localizations.dart';
import '../../theme/app_theme.dart';

/// 显示精听简报底部弹窗
Future<void> showIntensiveListenBriefingSheet({
  required BuildContext context,
  required int sentenceCount,
  required VoidCallback onStartPractice,
}) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (context) => IntensiveListenBriefingSheet(
      sentenceCount: sentenceCount,
      onStartPractice: onStartPractice,
    ),
  );
}

/// 精听简报弹窗内容
class IntensiveListenBriefingSheet extends StatelessWidget {
  /// 句子总数
  final int sentenceCount;

  /// 开始练习回调
  final VoidCallback onStartPractice;

  const IntensiveListenBriefingSheet({
    super.key,
    required this.sentenceCount,
    required this.onStartPractice,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.l,
        AppSpacing.l,
        AppSpacing.l,
        AppSpacing.xl,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 拖拽指示条
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: theme.colorScheme.outlineVariant,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: AppSpacing.l),

          // 耳机图标
          Icon(Icons.hearing, size: 56, color: theme.colorScheme.primary),
          const SizedBox(height: AppSpacing.m),

          // 标题
          Text(
            l10n.intensiveListenBriefingTitle,
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),

          // 副标题
          Text(
            l10n.intensiveListenBriefingSubtitle,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: AppSpacing.l),

          // 练习提示
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(AppSpacing.m),
            decoration: BoxDecoration(
              color: theme.colorScheme.primaryContainer.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.lightbulb_outline,
                  color: theme.colorScheme.primary,
                  size: 20,
                ),
                const SizedBox(width: AppSpacing.s),
                Expanded(
                  child: Text(
                    l10n.intensiveListenBriefingTip,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurface,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.m),

          // 句子总数
          Text(
            l10n.intensiveListenBriefingSentenceCount(sentenceCount),
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: AppSpacing.l),

          // 开始练习按钮
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: () {
                Navigator.of(context).pop();
                onStartPractice();
              },
              icon: const Icon(Icons.play_arrow),
              label: Text(l10n.startPractice),
            ),
          ),
        ],
      ),
    );
  }
}
