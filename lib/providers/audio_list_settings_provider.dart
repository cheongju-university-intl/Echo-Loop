// 音频列表排序设置 Provider
//
// 管理音频视图的排序方式，独立于 audioLibraryProvider。
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'audio_list_settings_provider.g.dart';

/// 音频排序方式
///
/// - [custom]：保持调用方传入的顺序（官方合集按 junction sortOrder 的情况下用）
/// - [nameAsc] / [nameDesc]：按名称升降
/// - [dateAsc] / [dateDesc]：按 `addedDate`（本地添加时间）升降 —— 用户自建场景
/// - [originalDateAsc] / [originalDateDesc]：按 `originalDate`（官方原始发布日期）升降
enum AudioSortType {
  custom,
  nameAsc,
  nameDesc,
  dateAsc,
  dateDesc,
  originalDateAsc,
  originalDateDesc,
}

/// 音频列表设置状态
class AudioListSettingsState {
  /// 排序方式
  final AudioSortType sortType;

  const AudioListSettingsState({this.sortType = AudioSortType.dateDesc});

  AudioListSettingsState copyWith({AudioSortType? sortType}) {
    return AudioListSettingsState(sortType: sortType ?? this.sortType);
  }
}

@riverpod
class AudioListSettings extends _$AudioListSettings {
  @override
  AudioListSettingsState build() => const AudioListSettingsState();

  /// 设置排序方式
  void setSortType(AudioSortType type) {
    state = state.copyWith(sortType: type);
  }
}
