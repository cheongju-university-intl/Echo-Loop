// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'official_enrollment_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$officialEnrollmentHash() =>
    r'cc0d266f79ba439adead2a8cacae434b85a48fc8';

/// 加入/移除官方合集的业务入口。
///
/// 防重入：Repository.enroll 内部检查 `getByRemoteId`，命中已有则抛
/// [AlreadyEnrolledError]；DB 的 UNIQUE INDEX 作为并发兜底。
/// 成功后 invalidate `collectionListProvider` 让 Library 列表刷新。
///
/// Copied from [OfficialEnrollment].
@ProviderFor(OfficialEnrollment)
final officialEnrollmentProvider =
    NotifierProvider<OfficialEnrollment, void>.internal(
      OfficialEnrollment.new,
      name: r'officialEnrollmentProvider',
      debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
          ? null
          : _$officialEnrollmentHash,
      dependencies: null,
      allTransitiveDependencies: null,
    );

typedef _$OfficialEnrollment = Notifier<void>;
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
