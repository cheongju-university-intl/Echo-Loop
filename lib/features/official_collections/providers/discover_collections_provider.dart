import 'package:flutter_riverpod/flutter_riverpod.dart' show Ref;
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../data/official_catalog_service.dart';
import '../models/catalog.dart';

part 'discover_collections_provider.g.dart';

/// Discover 页的合集列表 — 直接从本地 catalog 缓存读取。
///
/// 不再发任何 API；网络刷新由 `OfficialSyncService.syncAll` 统一负责，
/// 完成后通过 `ref.invalidate(cachedCatalogProvider)` 触发本 provider 重 build。
///
/// 返回 null 表示 catalog 还未首次加载（首次安装等待中），UI 显示 loading。
/// 返回空 list 表示已加载但无任何合集，UI 显示 empty。
@Riverpod(keepAlive: true)
List<CatalogCollection>? discoverCollections(Ref ref) {
  final catalog = ref.watch(cachedCatalogProvider);
  if (catalog == null) {
    final svc = ref.read(officialCatalogServiceProvider);
    return svc.hasInitialized ? const <CatalogCollection>[] : null;
  }
  return catalog.collections;
}
