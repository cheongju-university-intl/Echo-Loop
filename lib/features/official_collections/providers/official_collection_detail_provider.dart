import 'package:flutter_riverpod/flutter_riverpod.dart' show Ref;
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../data/official_catalog_service.dart';
import '../models/catalog.dart';

part 'official_collection_detail_provider.g.dart';

/// 详情页的合集详情 — 从本地 catalog 缓存按 remoteId 同步查找。
///
/// 不发网络；与 [discoverCollectionsProvider] 共享同一份 catalog。
///
/// 三种返回值：
/// - `null` 且 catalog 未初始化 → UI 显示 loading
/// - `null` 且 catalog 已初始化 → UI 显示 "合集不存在 / 已下架"
/// - 非 null → UI 渲染详情
@Riverpod(keepAlive: true)
CatalogCollection? officialCollectionDetail(Ref ref, String remoteId) {
  final catalog = ref.watch(cachedCatalogProvider);
  if (catalog == null) return null;
  for (final c in catalog.collections) {
    if (c.id == remoteId) return c;
  }
  return null;
}
