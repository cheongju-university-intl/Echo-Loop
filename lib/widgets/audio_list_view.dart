// 音频列表视图
//
// 展示资源库中所有音频项，支持排序。
// 使用 AudioListTile 渲染每一项。
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/audio_item.dart';
import '../providers/audio_library_provider.dart';
import '../providers/audio_list_settings_provider.dart';
import '../l10n/app_localizations.dart';
import '../theme/app_theme.dart';
import '../widgets/add_audio_dialog.dart';
import 'audio_list_tile.dart';
import 'edit_collection_membership_sheet.dart';

/// 音频列表视图 — 用于资源库的"音频"Tab
class AudioListView extends ConsumerWidget {
  const AudioListView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final audioItems = ref.watch(
      audioLibraryProvider.select((s) => s.audioItems),
    );
    final settings = ref.watch(audioListSettingsProvider);

    // 排序
    final sortedItems = _sortItems(audioItems, settings.sortType);

    if (sortedItems.isEmpty) {
      return _EmptyState(l10n: l10n);
    }

    return ListView.builder(
      padding: const EdgeInsets.all(8),
      itemCount: sortedItems.length,
      itemBuilder: (context, index) {
        final item = sortedItems[index];
        return AudioListTile(
          audioItem: item,
          onManageCollections: () {
            _showManageCollectionsSheet(context, item.id);
          },
          onDelete: () {
            _confirmDeleteAudio(context, ref, item);
          },
        );
      },
    );
  }

  /// 按排序类型排序音频列表
  List<AudioItem> _sortItems(List<AudioItem> items, AudioSortType sortType) {
    final sorted = List<AudioItem>.from(items);
    switch (sortType) {
      case AudioSortType.nameAsc:
        sorted.sort((a, b) => a.name.compareTo(b.name));
      case AudioSortType.nameDesc:
        sorted.sort((a, b) => b.name.compareTo(a.name));
      case AudioSortType.dateAsc:
        sorted.sort((a, b) => a.addedDate.compareTo(b.addedDate));
      case AudioSortType.dateDesc:
        sorted.sort((a, b) => b.addedDate.compareTo(a.addedDate));
    }
    return sorted;
  }

  /// 显示合集归属编辑 BottomSheet
  void _showManageCollectionsSheet(BuildContext context, String audioId) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => EditCollectionMembershipSheet(audioId: audioId),
    );
  }

  /// 确认删除音频
  void _confirmDeleteAudio(
    BuildContext context,
    WidgetRef ref,
    AudioItem item,
  ) {
    final l10n = AppLocalizations.of(context)!;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        icon: Icon(
          Icons.warning_amber_rounded,
          color: Theme.of(ctx).colorScheme.error,
          size: 32,
        ),
        title: Text(l10n.deleteAudio),
        content: Text(l10n.deleteAudioConfirm(item.name)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () {
              ref.read(audioLibraryProvider.notifier).removeAudioItem(item.id);
              Navigator.pop(ctx);
            },
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(ctx).colorScheme.error,
              foregroundColor: Theme.of(ctx).colorScheme.onError,
            ),
            child: Text(l10n.delete),
          ),
        ],
      ),
    );
  }
}

/// 空状态视图
class _EmptyState extends StatelessWidget {
  final AppLocalizations l10n;

  const _EmptyState({required this.l10n});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.library_music_outlined,
            size: 64,
            color: theme.colorScheme.outline,
          ),
          const SizedBox(height: AppSpacing.m),
          Text(l10n.noAudioItems, style: theme.textTheme.titleLarge),
          const SizedBox(height: AppSpacing.s),
          Text(
            l10n.noAudioItemsHint,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: AppSpacing.l),
          FilledButton.icon(
            onPressed: () {
              showDialog(
                context: context,
                builder: (context) => const AddAudioDialog(),
              );
            },
            icon: const Icon(Icons.add),
            label: Text(l10n.addAudio),
          ),
        ],
      ),
    );
  }
}
