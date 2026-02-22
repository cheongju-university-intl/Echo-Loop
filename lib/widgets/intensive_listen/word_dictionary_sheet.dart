/// 词典占位底部弹窗
///
/// 点击标注模式中的单词时显示，当前为占位实现。
library;

import 'package:flutter/material.dart';
import '../../l10n/app_localizations.dart';
import '../../theme/app_theme.dart';

/// 显示词典底部弹窗
Future<void> showWordDictionarySheet({
  required BuildContext context,
  required String word,
}) {
  return showModalBottomSheet(
    context: context,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (context) => WordDictionarySheet(word: word),
  );
}

/// 词典弹窗内容
class WordDictionarySheet extends StatelessWidget {
  /// 查询的单词
  final String word;

  const WordDictionarySheet({super.key, required this.word});

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

          // 标题
          Text(
            l10n.intensiveListenWordDictTitle,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: AppSpacing.l),

          // 单词
          Text(
            word,
            style: theme.textTheme.headlineMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: theme.colorScheme.primary,
            ),
          ),
          const SizedBox(height: AppSpacing.l),

          // 占位内容
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(AppSpacing.l),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest.withValues(
                alpha: 0.5,
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              l10n.intensiveListenWordDictPlaceholder,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                fontStyle: FontStyle.italic,
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.l),
        ],
      ),
    );
  }
}
