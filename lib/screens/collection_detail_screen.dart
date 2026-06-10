// 合集详情页面
//
// 展示合集中的音频列表，复用 AudioListView 和 AudioSortButton。
// 支持上传音频到合集。
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/audio_item.dart';
import '../providers/collection_provider.dart';
import '../providers/audio_library_provider.dart';
import '../providers/new_user_guide_provider.dart';
import '../l10n/app_localizations.dart';
import '../theme/app_theme.dart';
import '../providers/audio_list_settings_provider.dart';
import '../widgets/audio_list_view.dart';
import '../widgets/guide_flow.dart';
import '../widgets/import_audio_sheet.dart';

/// 合集详情页面 - 展示合集中的音频，支持上传音频
class CollectionDetailScreen extends ConsumerStatefulWidget {
  final String collectionId;

  const CollectionDetailScreen({super.key, required this.collectionId});

  @override
  ConsumerState<CollectionDetailScreen> createState() =>
      _CollectionDetailScreenState();
}

class _CollectionDetailScreenState
    extends ConsumerState<CollectionDetailScreen> {
  final _keyUpload = GlobalKey();

  /// 官方合集的排序状态，页面内独立持有（不走全局 audioListSettingsProvider，
  /// 避免污染资源库 / 用户自建合集的排序偏好）。首次打开默认「官方编排顺序」。
  AudioSortType _officialSort = AudioSortType.custom;

  /// 官方合集排序菜单的可选项
  static const _officialAllowedSorts = [
    AudioSortType.custom,
    AudioSortType.nameAsc,
    AudioSortType.nameDesc,
    AudioSortType.originalDateAsc,
    AudioSortType.originalDateDesc,
  ];

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final collectionState = ref.watch(collectionListProvider);
    ref.watch(audioLibraryProvider); // watch to rebuild when library changes

    final collection = collectionState.rawCollections
        .where((c) => c.id == widget.collectionId)
        .firstOrNull;
    if (collection == null) {
      return Scaffold(
        appBar: AppBar(),
        body: const Center(child: Text('Collection not found')),
      );
    }

    // 获取合集中的音频项（从 junction 表缓存中读取）
    final audioIds = collectionState.getAudioIds(widget.collectionId);
    final audioItems = audioIds
        .map((id) => ref.read(audioLibraryProvider.notifier).getItemById(id))
        .whereType<AudioItem>()
        .toList();

    final hasAudioItems = audioItems.isNotEmpty;

    final stepUpload = GuideStep(
      key: _keyUpload,
      description: l10n.guideCollectionUploadDescription,
    );

    return GuideFlowSequenceHost(
      flows: [
        GuideFlow(
          flowId: GuideFlowIds.collectionDetailUpload,
          shouldRun: true,
          steps: [stepUpload],
        ),
      ],
      child: Scaffold(
        appBar: AppBar(
          title: Text(collection.name),
          actions: [
            // 官方合集：独立 sort state + 5 项菜单（默认 / 名称×2 / 原始发布×2）
            // 用户合集：保持现状 —— 4 项默认菜单 + 全局 provider
            if (collection.isOfficial)
              AudioSortButton(
                allowedTypes: _officialAllowedSorts,
                current: _officialSort,
                onChanged: (t) => setState(() => _officialSort = t),
              )
            else
              const AudioSortButton(),
            // 官方合集禁止手动添加/删除音频，按钮隐藏
            if (!collection.isOfficial)
              GuideTarget(
                step: stepUpload,
                child: IconButton(
                  icon: const Icon(Icons.add),
                  onPressed: () => showImportAudioSheet(
                    context,
                    collectionId: collection.id,
                  ),
                ),
              ),
          ],
        ),
        body: AudioListView(
          items: audioItems,
          collectionId: widget.collectionId,
          guideFirstAudioMenu: hasAudioItems,
          guideLeadingItems: hasAudioItems,
          overrideSortType: collection.isOfficial ? _officialSort : null,
          emptyState: collection.isOfficial
              ? Center(
                  child: Text(
                    // 区分「已下架」vs「暂无音频」：前者是后端主动下线，后者
                    // 是合集刚建还没上内容，两种文案语义不同不能复用。
                    collection.isDeprecated
                        ? l10n.officialCollectionDeprecated
                        : l10n.officialCollectionEmpty,
                    textAlign: TextAlign.center,
                  ),
                )
              : _CollectionEmptyState(
                  l10n: l10n,
                  onAdd: () => showImportAudioSheet(
                    context,
                    collectionId: collection.id,
                  ),
                ),
        ),
      ),
    );
  }
}

/// 合集空状态视图
class _CollectionEmptyState extends StatelessWidget {
  final AppLocalizations l10n;
  final VoidCallback onAdd;

  const _CollectionEmptyState({required this.l10n, required this.onAdd});

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
          Text(l10n.emptyCollection, style: theme.textTheme.titleLarge),
          const SizedBox(height: AppSpacing.s),
          Text(
            l10n.tapToAddAudio,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: AppSpacing.l),
          FilledButton.icon(
            onPressed: onAdd,
            icon: const Icon(Icons.add),
            label: Text(l10n.addAudioToCollection),
          ),
        ],
      ),
    );
  }
}
