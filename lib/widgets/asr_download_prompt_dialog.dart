/// 录音页面入口弹窗：引导用户下载本地语音识别模型。
///
/// 两种场景：
/// 1. 首次引导（未设置 + 未 dismiss）
/// 2. 模型修复（已启用但模型不完整）
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../l10n/app_localizations.dart';
import '../providers/offline_asr_settings_provider.dart';
import '../services/asr/asr_model_manager.dart';

/// 检查是否需要弹窗，需要则弹出并等待用户操作。
/// 弹窗结束后，如果 ASR 已就绪，后台加载引擎（不阻塞 UI）。
///
/// 在所有需要录音的页面 initState 中调用。
Future<void> checkAndShowAsrPrompt(BuildContext context, WidgetRef ref) async {
  final needsLocal = ref.read(needsLocalAsrProvider);
  if (!needsLocal) return;

  final state = ref.read(offlineAsrSettingsProvider);

  if (state.isDownloading) {
    // 其他页面已触发下载（如设置页），显示进度等待完成。
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const _DownloadProgressDialog(),
    );
  } else if (state.needsRepairPrompt) {
    // 已启用但模型不完整，自动恢复下载并显示进度。
    ref.read(offlineAsrSettingsProvider.notifier).retryDownload();
    if (context.mounted) {
      await showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (_) => const _DownloadProgressDialog(),
      );
    }
  } else if (state.needsPrompt) {
    await _showFirstTimeDialog(context, ref);
  }

  // 弹窗流程结束后，后台加载引擎（不阻塞 UI）。
  _ensureEngineLoaded(ref);
}

/// 退出录音页面时卸载引擎，释放内存。
///
/// 在所有需要录音的页面 dispose 中调用。
void unloadAsrEngine(WidgetRef ref) {
  final needsLocal = ref.read(needsLocalAsrProvider);
  if (!needsLocal) return;

  final notifier = ref.read(offlineAsrSettingsProvider.notifier);
  notifier.unloadEngine();
}

/// 后台加载引擎（fire-and-forget，不阻塞 UI）。
void _ensureEngineLoaded(WidgetRef ref) {
  final state = ref.read(offlineAsrSettingsProvider);
  if (state.enabled == true &&
      state.downloadStatus == AsrModelDownloadStatus.downloaded &&
      !state.engineReady) {
    // fire-and-forget：不 await，让 UI 继续。
    ref.read(offlineAsrSettingsProvider.notifier).loadEngine();
  }
}

/// 场景 1：首次引导弹窗。
Future<void> _showFirstTimeDialog(BuildContext context, WidgetRef ref) async {
  final state = ref.read(offlineAsrSettingsProvider);
  final sizeText = _formatBytes(state.recommendedModel.fileSizeBytes);

  final result = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => _FirstTimePromptDialog(sizeText: sizeText),
  );

  final notifier = ref.read(offlineAsrSettingsProvider.notifier);
  notifier.dismissPrompt();

  if (result == true) {
    // 用户选择下载。
    if (context.mounted) {
      await _showDownloadProgressDialog(context, ref);
    }
  }
}

/// 下载进度弹窗（阻塞式）。
Future<void> _showDownloadProgressDialog(
  BuildContext context,
  WidgetRef ref,
) async {
  final notifier = ref.read(offlineAsrSettingsProvider.notifier);

  // 触发下载。
  notifier.enable();

  await showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => const _DownloadProgressDialog(),
  );
}

String _formatBytes(int bytes) {
  if (bytes < 1024) return '$bytes B';
  if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(0)} KB';
  return '${(bytes / (1024 * 1024)).toStringAsFixed(0)} MB';
}

// ---------------------------------------------------------------------------
// 首次引导弹窗
// ---------------------------------------------------------------------------

class _FirstTimePromptDialog extends ConsumerWidget {
  final String sizeText;
  const _FirstTimePromptDialog({required this.sizeText});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;

    return AlertDialog(
      title: Text(l10n.speechRecognitionRequiredTitle),
      content: Text(l10n.speechRecognitionRequiredMessage(sizeText)),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: Text(l10n.notNow),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(true),
          child: Text(l10n.downloadAndEnable),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// 下载进度弹窗
// ---------------------------------------------------------------------------

class _DownloadProgressDialog extends ConsumerWidget {
  const _DownloadProgressDialog();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final state = ref.watch(offlineAsrSettingsProvider);

    // 下载完成或引擎就绪 → 自动关闭弹窗。
    if (state.isFullyReady ||
        (state.downloadStatus == AsrModelDownloadStatus.downloaded)) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (context.mounted) Navigator.of(context).pop();
      });
    }

    final sizeText = _formatBytes(state.recommendedModel.fileSizeBytes);
    final isFailed = state.downloadStatus == AsrModelDownloadStatus.failed;

    return AlertDialog(
      title: Text(
        isFailed ? l10n.speechModelDownloadFailed : l10n.downloadingSpeechModel,
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!isFailed)
            Text(
              l10n.speechRecognitionRequiredMessage(sizeText),
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          if (state.isDownloading) ...[
            const SizedBox(height: 16),
            LinearProgressIndicator(value: state.downloadProgress),
            const SizedBox(height: 8),
            Text(
              '${(state.downloadProgress * 100).toStringAsFixed(0)}%',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
          if (isFailed && state.errorMessage != null) ...[
            const SizedBox(height: 8),
            Text(
              state.errorMessage!,
              style: const TextStyle(color: Colors.red),
            ),
          ],
        ],
      ),
      actions: [
        if (state.downloadStatus == AsrModelDownloadStatus.failed) ...[
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(l10n.later),
          ),
          FilledButton(
            onPressed: () =>
                ref.read(offlineAsrSettingsProvider.notifier).retryDownload(),
            child: Text(l10n.retryDownload),
          ),
        ],
      ],
    );
  }
}
