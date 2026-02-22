// 音频列表排序设置 Provider
//
// 管理音频视图的排序方式，独立于 audioLibraryProvider。
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'audio_list_settings_provider.g.dart';

/// 音频排序方式
enum AudioSortType { nameAsc, nameDesc, dateAsc, dateDesc }

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
