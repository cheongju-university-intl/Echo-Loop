// 合集归属编辑 BottomSheet
//
// Checkbox 多选方式编辑音频所属的合集，
// 支持底部"创建新合集"入口。
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/collection_provider.dart';
import '../l10n/app_localizations.dart';
import '../theme/app_theme.dart';

/// 合集归属编辑 BottomSheet
class EditCollectionMembershipSheet extends ConsumerStatefulWidget {
  /// 要编辑归属的音频 ID
  final String audioId;

  const EditCollectionMembershipSheet({super.key, required this.audioId});

  @override
  ConsumerState<EditCollectionMembershipSheet> createState() =>
      _EditCollectionMembershipSheetState();
}

class _EditCollectionMembershipSheetState
    extends ConsumerState<EditCollectionMembershipSheet> {
  /// 当前选中的合集 ID 集合
  late Set<String> _selectedIds;

  @override
  void initState() {
    super.initState();
    final collectionState = ref.read(collectionListProvider);
    final currentCollections =
        collectionState.audioToCollectionsMap[widget.audioId] ?? [];
    _selectedIds = Set<String>.from(currentCollections);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final collections = ref.watch(
      collectionListProvider.select((s) => s.collections),
    );

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.m),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 标题栏
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.m),
              child: Row(
                children: [
                  Text(
                    l10n.manageCollections,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Spacer(),
                  TextButton(onPressed: _onDone, child: Text(l10n.done)),
                ],
              ),
            ),
            const Divider(),
            // 合集列表
            if (collections.isEmpty)
              Padding(
                padding: const EdgeInsets.all(AppSpacing.l),
                child: Center(
                  child: Text(
                    l10n.noCollectionsYet,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              )
            else
              ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(context).size.height * 0.4,
                ),
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: collections.length,
                  itemBuilder: (context, index) {
                    final collection = collections[index];
                    final isSelected = _selectedIds.contains(collection.id);
                    return CheckboxListTile(
                      title: Text(collection.name),
                      value: isSelected,
                      onChanged: (value) {
                        setState(() {
                          if (value == true) {
                            _selectedIds.add(collection.id);
                          } else {
                            _selectedIds.remove(collection.id);
                          }
                        });
                      },
                    );
                  },
                ),
              ),
            const Divider(),
            // 创建新合集入口
            ListTile(
              leading: Icon(
                Icons.add_circle_outline,
                color: theme.colorScheme.primary,
              ),
              title: Text(
                l10n.createCollection,
                style: TextStyle(color: theme.colorScheme.primary),
              ),
              onTap: () => _showCreateCollectionDialog(context),
            ),
          ],
        ),
      ),
    );
  }

  /// 点击完成 — 批量更新合集归属
  Future<void> _onDone() async {
    await ref
        .read(collectionListProvider.notifier)
        .updateAudioCollectionMembership(widget.audioId, _selectedIds);
    if (mounted) {
      Navigator.pop(context);
    }
  }

  /// 创建新合集对话框
  void _showCreateCollectionDialog(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final controller = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.createCollection),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: InputDecoration(
            labelText: l10n.collectionName,
            hintText: l10n.enterCollectionName,
          ),
          onSubmitted: (_) => _createAndSelect(ctx, controller),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(l10n.cancel),
          ),
          ElevatedButton(
            onPressed: () => _createAndSelect(ctx, controller),
            child: Text(l10n.add),
          ),
        ],
      ),
    );
  }

  /// 创建合集并自动勾选
  Future<void> _createAndSelect(
    BuildContext dialogContext,
    TextEditingController controller,
  ) async {
    final name = controller.text.trim();
    if (name.isEmpty) return;

    await ref.read(collectionListProvider.notifier).createCollection(name);

    // 获取新创建的合集 ID
    final collections = ref.read(collectionListProvider).rawCollections;
    final newCollection = collections.lastWhere((c) => c.name == name);

    setState(() {
      _selectedIds.add(newCollection.id);
    });

    if (dialogContext.mounted) {
      Navigator.pop(dialogContext);
    }
  }
}
