// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'transcription_task_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$transcriptionFileOpsHash() =>
    r'919f16ed565c84e292f4f4eca0fa667f71528450';

/// 文件操作 Provider（测试时可覆盖）
///
/// Copied from [transcriptionFileOps].
@ProviderFor(transcriptionFileOps)
final transcriptionFileOpsProvider = Provider<TranscriptionFileOps>.internal(
  transcriptionFileOps,
  name: r'transcriptionFileOpsProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$transcriptionFileOpsHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef TranscriptionFileOpsRef = ProviderRef<TranscriptionFileOps>;
String _$transcriptionTaskManagerHash() =>
    r'0372270be70afdc5f48b2dd4038e28a7d93c78e4';

/// 转录任务管理器
///
/// keepAlive: 弹窗关闭后任务仍在后台运行。
/// state: Map<String, TranscriptionTaskState>  (audioId → state)
///
/// Copied from [TranscriptionTaskManager].
@ProviderFor(TranscriptionTaskManager)
final transcriptionTaskManagerProvider =
    NotifierProvider<
      TranscriptionTaskManager,
      Map<String, TranscriptionTaskState>
    >.internal(
      TranscriptionTaskManager.new,
      name: r'transcriptionTaskManagerProvider',
      debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
          ? null
          : _$transcriptionTaskManagerHash,
      dependencies: null,
      allTransitiveDependencies: null,
    );

typedef _$TranscriptionTaskManager =
    Notifier<Map<String, TranscriptionTaskState>>;
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
