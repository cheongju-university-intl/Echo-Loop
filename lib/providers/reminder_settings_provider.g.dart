// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'reminder_settings_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$reminderSettingsNotifierHash() =>
    r'9dca92bcdb9efd21b6062a7954137fcf9edca60e';

/// 提醒设置 Notifier
///
/// `build()` 返回默认值并异步从 SP 加载持久化数据。
/// 外部通过 [update] 更新设置，自动持久化并同步 state。
///
/// Copied from [ReminderSettingsNotifier].
@ProviderFor(ReminderSettingsNotifier)
final reminderSettingsNotifierProvider =
    NotifierProvider<ReminderSettingsNotifier, ReminderSettings>.internal(
      ReminderSettingsNotifier.new,
      name: r'reminderSettingsNotifierProvider',
      debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
          ? null
          : _$reminderSettingsNotifierHash,
      dependencies: null,
      allTransitiveDependencies: null,
    );

typedef _$ReminderSettingsNotifier = Notifier<ReminderSettings>;
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
