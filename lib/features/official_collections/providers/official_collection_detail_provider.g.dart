// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'official_collection_detail_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$officialCollectionDetailHash() =>
    r'2043edf91b6713f6bd9569c0518c510542ca6420';

/// Copied from Dart SDK
class _SystemHash {
  _SystemHash._();

  static int combine(int hash, int value) {
    // ignore: parameter_assignments
    hash = 0x1fffffff & (hash + value);
    // ignore: parameter_assignments
    hash = 0x1fffffff & (hash + ((0x0007ffff & hash) << 10));
    return hash ^ (hash >> 6);
  }

  static int finish(int hash) {
    // ignore: parameter_assignments
    hash = 0x1fffffff & (hash + ((0x03ffffff & hash) << 3));
    // ignore: parameter_assignments
    hash = hash ^ (hash >> 11);
    return 0x1fffffff & (hash + ((0x00003fff & hash) << 15));
  }
}

/// 详情页的合集详情 — 从本地 catalog 缓存按 remoteId 同步查找。
///
/// 不发网络；与 [discoverCollectionsProvider] 共享同一份 catalog。
///
/// 三种返回值：
/// - `null` 且 catalog 未初始化 → UI 显示 loading
/// - `null` 且 catalog 已初始化 → UI 显示 "合集不存在 / 已下架"
/// - 非 null → UI 渲染详情
///
/// Copied from [officialCollectionDetail].
@ProviderFor(officialCollectionDetail)
const officialCollectionDetailProvider = OfficialCollectionDetailFamily();

/// 详情页的合集详情 — 从本地 catalog 缓存按 remoteId 同步查找。
///
/// 不发网络；与 [discoverCollectionsProvider] 共享同一份 catalog。
///
/// 三种返回值：
/// - `null` 且 catalog 未初始化 → UI 显示 loading
/// - `null` 且 catalog 已初始化 → UI 显示 "合集不存在 / 已下架"
/// - 非 null → UI 渲染详情
///
/// Copied from [officialCollectionDetail].
class OfficialCollectionDetailFamily extends Family<CatalogCollection?> {
  /// 详情页的合集详情 — 从本地 catalog 缓存按 remoteId 同步查找。
  ///
  /// 不发网络；与 [discoverCollectionsProvider] 共享同一份 catalog。
  ///
  /// 三种返回值：
  /// - `null` 且 catalog 未初始化 → UI 显示 loading
  /// - `null` 且 catalog 已初始化 → UI 显示 "合集不存在 / 已下架"
  /// - 非 null → UI 渲染详情
  ///
  /// Copied from [officialCollectionDetail].
  const OfficialCollectionDetailFamily();

  /// 详情页的合集详情 — 从本地 catalog 缓存按 remoteId 同步查找。
  ///
  /// 不发网络；与 [discoverCollectionsProvider] 共享同一份 catalog。
  ///
  /// 三种返回值：
  /// - `null` 且 catalog 未初始化 → UI 显示 loading
  /// - `null` 且 catalog 已初始化 → UI 显示 "合集不存在 / 已下架"
  /// - 非 null → UI 渲染详情
  ///
  /// Copied from [officialCollectionDetail].
  OfficialCollectionDetailProvider call(String remoteId) {
    return OfficialCollectionDetailProvider(remoteId);
  }

  @override
  OfficialCollectionDetailProvider getProviderOverride(
    covariant OfficialCollectionDetailProvider provider,
  ) {
    return call(provider.remoteId);
  }

  static const Iterable<ProviderOrFamily>? _dependencies = null;

  @override
  Iterable<ProviderOrFamily>? get dependencies => _dependencies;

  static const Iterable<ProviderOrFamily>? _allTransitiveDependencies = null;

  @override
  Iterable<ProviderOrFamily>? get allTransitiveDependencies =>
      _allTransitiveDependencies;

  @override
  String? get name => r'officialCollectionDetailProvider';
}

/// 详情页的合集详情 — 从本地 catalog 缓存按 remoteId 同步查找。
///
/// 不发网络；与 [discoverCollectionsProvider] 共享同一份 catalog。
///
/// 三种返回值：
/// - `null` 且 catalog 未初始化 → UI 显示 loading
/// - `null` 且 catalog 已初始化 → UI 显示 "合集不存在 / 已下架"
/// - 非 null → UI 渲染详情
///
/// Copied from [officialCollectionDetail].
class OfficialCollectionDetailProvider extends Provider<CatalogCollection?> {
  /// 详情页的合集详情 — 从本地 catalog 缓存按 remoteId 同步查找。
  ///
  /// 不发网络；与 [discoverCollectionsProvider] 共享同一份 catalog。
  ///
  /// 三种返回值：
  /// - `null` 且 catalog 未初始化 → UI 显示 loading
  /// - `null` 且 catalog 已初始化 → UI 显示 "合集不存在 / 已下架"
  /// - 非 null → UI 渲染详情
  ///
  /// Copied from [officialCollectionDetail].
  OfficialCollectionDetailProvider(String remoteId)
    : this._internal(
        (ref) => officialCollectionDetail(
          ref as OfficialCollectionDetailRef,
          remoteId,
        ),
        from: officialCollectionDetailProvider,
        name: r'officialCollectionDetailProvider',
        debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
            ? null
            : _$officialCollectionDetailHash,
        dependencies: OfficialCollectionDetailFamily._dependencies,
        allTransitiveDependencies:
            OfficialCollectionDetailFamily._allTransitiveDependencies,
        remoteId: remoteId,
      );

  OfficialCollectionDetailProvider._internal(
    super._createNotifier, {
    required super.name,
    required super.dependencies,
    required super.allTransitiveDependencies,
    required super.debugGetCreateSourceHash,
    required super.from,
    required this.remoteId,
  }) : super.internal();

  final String remoteId;

  @override
  Override overrideWith(
    CatalogCollection? Function(OfficialCollectionDetailRef provider) create,
  ) {
    return ProviderOverride(
      origin: this,
      override: OfficialCollectionDetailProvider._internal(
        (ref) => create(ref as OfficialCollectionDetailRef),
        from: from,
        name: null,
        dependencies: null,
        allTransitiveDependencies: null,
        debugGetCreateSourceHash: null,
        remoteId: remoteId,
      ),
    );
  }

  @override
  ProviderElement<CatalogCollection?> createElement() {
    return _OfficialCollectionDetailProviderElement(this);
  }

  @override
  bool operator ==(Object other) {
    return other is OfficialCollectionDetailProvider &&
        other.remoteId == remoteId;
  }

  @override
  int get hashCode {
    var hash = _SystemHash.combine(0, runtimeType.hashCode);
    hash = _SystemHash.combine(hash, remoteId.hashCode);

    return _SystemHash.finish(hash);
  }
}

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
mixin OfficialCollectionDetailRef on ProviderRef<CatalogCollection?> {
  /// The parameter `remoteId` of this provider.
  String get remoteId;
}

class _OfficialCollectionDetailProviderElement
    extends ProviderElement<CatalogCollection?>
    with OfficialCollectionDetailRef {
  _OfficialCollectionDetailProviderElement(super.provider);

  @override
  String get remoteId => (origin as OfficialCollectionDetailProvider).remoteId;
}

// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
