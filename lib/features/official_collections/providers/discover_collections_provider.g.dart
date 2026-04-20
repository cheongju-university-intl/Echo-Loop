// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'discover_collections_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$discoverCollectionsHash() =>
    r'0b67e2f0c11c0710560b740f2b6f01bc59e2c20e';

/// Discover 页的合集列表 — 直接从本地 catalog 缓存读取。
///
/// 不再发任何 API；网络刷新由 `OfficialSyncService.syncAll` 统一负责，
/// 完成后通过 `ref.invalidate(cachedCatalogProvider)` 触发本 provider 重 build。
///
/// 返回 null 表示 catalog 还未首次加载（首次安装等待中），UI 显示 loading。
/// 返回空 list 表示已加载但无任何合集，UI 显示 empty。
///
/// Copied from [discoverCollections].
@ProviderFor(discoverCollections)
final discoverCollectionsProvider = Provider<List<CatalogCollection>?>.internal(
  discoverCollections,
  name: r'discoverCollectionsProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$discoverCollectionsHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef DiscoverCollectionsRef = ProviderRef<List<CatalogCollection>?>;
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
