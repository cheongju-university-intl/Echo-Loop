/// 语音识别设置页。
///
/// 管理本地离线语音识别功能的开关、模型下载、删除。
/// 仅在 Android 无 GMS 设备上有意义。
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../l10n/app_localizations.dart';
import '../providers/offline_asr_settings_provider.dart';
import '../services/asr/asr_model_manager.dart';

/// 语音识别设置页。
class AsrSettingsScreen extends ConsumerStatefulWidget {
  const AsrSettingsScreen({super.key});

  @override
  ConsumerState<AsrSettingsScreen> createState() => _AsrSettingsScreenState();
}

class _AsrSettingsScreenState extends ConsumerState<AsrSettingsScreen> {
  @override
  void initState() {
    super.initState();
    // 进入设置页时，如果已启用但模型未下载完成，自动恢复下载。
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final state = ref.read(offlineAsrSettingsProvider);
      if (state.enabled == true &&
          state.downloadStatus != AsrModelDownloadStatus.downloaded &&
          !state.isDownloading) {
        ref.read(offlineAsrSettingsProvider.notifier).retryDownload();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final ref = this.ref;
    final l10n = AppLocalizations.of(context)!;
    final state = ref.watch(offlineAsrSettingsProvider);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.speechRecognition)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // 说明卡片
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                l10n.speechRecognitionDescription,
                style: theme.textTheme.bodyMedium,
              ),
            ),
          ),
          const SizedBox(height: 16),

          // 开关 + 状态
          Card(
            child: Column(
              children: [
                SwitchListTile(
                  title: Text(l10n.localSpeechRecognition),
                  subtitle: _buildSubtitle(context, l10n, state),
                  value: state.enabled == true,
                  onChanged: state.isDownloading
                      ? null
                      : (value) => _onToggle(context, ref, l10n, value),
                ),

                // 下载进度条
                if (state.isDownloading)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        LinearProgressIndicator(value: state.downloadProgress),
                        const SizedBox(height: 4),
                        Text(
                          l10n.speechModelDownloading(
                            '${(state.downloadProgress * 100).toStringAsFixed(0)}%',
                          ),
                          style: theme.textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),

                // 下载失败
                if (state.downloadStatus == AsrModelDownloadStatus.failed)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.error_outline,
                          color: Colors.red,
                          size: 18,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            state.errorMessage ??
                                l10n.speechModelDownloadFailed,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: Colors.red,
                            ),
                          ),
                        ),
                        TextButton(
                          onPressed: () => ref
                              .read(offlineAsrSettingsProvider.notifier)
                              .retryDownload(),
                          child: Text(l10n.retryDownload),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),

          // 删除按钮
          if (state.canDelete) ...[
            const SizedBox(height: 16),
            Center(
              child: TextButton.icon(
                onPressed: () => _confirmDelete(context, ref, l10n, state),
                icon: const Icon(Icons.delete_outline, color: Colors.red),
                label: Text(
                  l10n.deleteModel(_formatBytes(state.localSizeBytes)),
                  style: const TextStyle(color: Colors.red),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget? _buildSubtitle(
    BuildContext context,
    AppLocalizations l10n,
    OfflineAsrSettingsState state,
  ) {
    final sizeText = state.localSizeBytes > 0
        ? _formatBytes(state.localSizeBytes)
        : _formatBytes(state.recommendedModel.fileSizeBytes);
    final modelLabel = _modelLabel(state.recommendedModel.id);

    final isReady =
        state.enabled == true &&
        state.downloadStatus == AsrModelDownloadStatus.downloaded;

    if (isReady) {
      return Text(
        '$modelLabel · ${l10n.speechModelReady(sizeText)}',
        style: const TextStyle(color: Colors.green),
      );
    }
    return Text('$modelLabel · ${l10n.speechModelSize(sizeText)}');
  }

  void _onToggle(
    BuildContext context,
    WidgetRef ref,
    AppLocalizations l10n,
    bool value,
  ) {
    final notifier = ref.read(offlineAsrSettingsProvider.notifier);
    final state = ref.read(offlineAsrSettingsProvider);

    if (value) {
      notifier.enable();
    } else {
      // 已下载时弹确认框。
      if (state.downloadStatus == AsrModelDownloadStatus.downloaded) {
        _confirmDisable(context, ref, l10n);
      } else {
        notifier.disable();
      }
    }
  }

  void _confirmDisable(
    BuildContext context,
    WidgetRef ref,
    AppLocalizations l10n,
  ) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.disableSpeechRecognitionTitle),
        content: Text(l10n.disableSpeechRecognitionMessage),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(ctx).pop();
            },
            child: Text(MaterialLocalizations.of(ctx).cancelButtonLabel),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              ref.read(offlineAsrSettingsProvider.notifier).disable();
            },
            child: Text(l10n.keepModel),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              ref.read(offlineAsrSettingsProvider.notifier).disableAndDelete();
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: Text(
              l10n.deleteModel(
                _formatBytes(
                  ref.read(offlineAsrSettingsProvider).localSizeBytes,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _confirmDelete(
    BuildContext context,
    WidgetRef ref,
    AppLocalizations l10n,
    OfflineAsrSettingsState state,
  ) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.deleteModelConfirmTitle),
        content: Text(
          l10n.deleteModelConfirmMessage(_formatBytes(state.localSizeBytes)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(MaterialLocalizations.of(ctx).cancelButtonLabel),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              ref.read(offlineAsrSettingsProvider.notifier).deleteModel();
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: Text(l10n.deleteModel(_formatBytes(state.localSizeBytes))),
          ),
        ],
      ),
    );
  }

  /// 模型 ID → 用户可见的简称。
  static String _modelLabel(String modelId) {
    if (modelId.contains('tiny')) return 'Fast';
    if (modelId.contains('base')) return 'Accurate';
    return '';
  }

  static String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(0)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(0)} MB';
  }
}
