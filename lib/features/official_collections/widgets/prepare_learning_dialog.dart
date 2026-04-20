import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../l10n/app_localizations.dart';
import '../download/download_progress.dart';
import '../download/official_download_notifier.dart';

/// 官方合集音频下载前的准备对话框。
///
/// 非阻塞（barrierDismissible=true）；右上角 × 和弹窗外点击都关闭 dialog，
/// 下载任务**不会**被关闭动作取消——「取消下载」需要显式点底部按钮。
///
/// 按 state 渲染 action：
/// - [DownloadInProgress] 同一 audioItem → 底部仅一个「取消下载」；关闭不影响后台下载
/// - [DownloadFailed]                   → 底部仅一个「重试」
/// - [DownloadIdle]                     → 无按钮；listen 回调会自动 pop
class PrepareLearningDialog extends ConsumerWidget {
  final String audioItemId;

  const PrepareLearningDialog({super.key, required this.audioItemId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final progress = ref.watch(officialDownloadProvider);

    // 成功（Idle）或任务对应不上了 → 关闭 dialog
    ref.listen<DownloadProgress>(officialDownloadProvider, (prev, next) {
      if (next is DownloadIdle) {
        if (Navigator.of(context).canPop()) {
          Navigator.of(context).pop();
        }
      }
    });

    final isFailed = progress is DownloadFailed;
    final isCurrent =
        progress is DownloadInProgress && progress.audioItemId == audioItemId;

    return AlertDialog(
      title: Row(
        children: [
          Expanded(child: Text(l10n.preparingLearningMaterial)),
          IconButton(
            icon: const Icon(Icons.close),
            tooltip: l10n.cancel,
            onPressed: () => Navigator.of(context).pop(),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
            visualDensity: VisualDensity.compact,
          ),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(l10n.downloadingAudioAndSubtitle),
          const SizedBox(height: 12),
          if (isCurrent) ...[
            LinearProgressIndicator(
              value: progress.progress < 0 ? null : progress.progress,
            ),
            const SizedBox(height: 6),
            Text(
              _formatBytes(progress.receivedBytes, progress.totalBytes),
              style: theme.textTheme.bodySmall,
            ),
          ] else if (isFailed)
            Text(
              l10n.downloadFailed(progress.displayName),
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.error,
              ),
            )
          else
            const LinearProgressIndicator(), // 兜底不定态
        ],
      ),
      actions: [
        if (isCurrent)
          TextButton(
            // cancel() 会把 state 切回 Idle，触发 ref.listen 自动 pop dialog；
            // 这里不要再手动 pop，否则会把下层页面也一起 pop 掉。
            onPressed: () =>
                ref.read(officialDownloadProvider.notifier).cancel(),
            child: Text(
              l10n.downloadCancel,
              style: TextStyle(color: theme.colorScheme.error),
            ),
          )
        else if (isFailed)
          TextButton(
            onPressed: () async {
              // Failed 不是 InProgress，start() 会直接重新启动；state 从 Failed
              // 跳到 InProgress，不会经过 Idle，所以 listen 不会误 pop dialog。
              await ref.read(officialDownloadProvider.notifier).start(
                audioItemId: audioItemId,
                displayName: progress.displayName,
              );
            },
            child: Text(l10n.retryDownload),
          ),
      ],
    );
  }

  String _formatBytes(int? received, int? total) {
    if (received == null) return '';
    String fmt(int? b) {
      if (b == null) return '—';
      if (b < 1024) return '$b B';
      if (b < 1024 * 1024) return '${(b / 1024).toStringAsFixed(1)} KB';
      return '${(b / 1024 / 1024).toStringAsFixed(1)} MB';
    }

    return '${fmt(received)} / ${fmt(total)}';
  }
}
