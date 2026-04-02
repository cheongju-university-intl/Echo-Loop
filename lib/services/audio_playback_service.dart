/// 通用音频播放服务。
///
/// 封装 just_audio 的 [AudioPlayer]，提供简洁的 play/stop API。
/// 播放完成自动回到 idle 状态。
library;

import 'dart:async';

import 'package:just_audio/just_audio.dart';

/// 通用音频播放服务。
///
/// 用于播放本地音频文件（如用户录音 .m4a）。
/// 懒初始化 [AudioPlayer]，首次 play 时创建。
class AudioPlaybackService {
  AudioPlayer? _player;
  StreamSubscription<PlayerState>? _playerStateSub;
  String? _currentFilePath;
  Completer<void>? _playCompleter;

  /// 当前是否正在播放。
  bool get isPlaying => _player?.playing ?? false;

  /// 当前播放的文件路径。
  String? get currentFilePath => _currentFilePath;

  /// 播放音频文件，返回 Future 在播放完成或被停止时 complete。
  Future<void> play(String filePath) async {
    // 停止当前播放
    if (_player != null) {
      await _player!.stop();
    }
    _playCompleter?.complete();
    _playCompleter = Completer<void>();

    final player = await _ensurePlayer();
    _currentFilePath = filePath;
    await player.setFilePath(filePath);
    await player.play();

    // 返回 Future，播放完成或 stop 时 complete
    return _playCompleter!.future;
  }

  /// 停止播放。
  Future<void> stop() async {
    if (_player == null) {
      _currentFilePath = null;
      _playCompleter?.complete();
      _playCompleter = null;
      return;
    }
    await _player!.stop();
    _currentFilePath = null;
    _playCompleter?.complete();
    _playCompleter = null;
  }

  /// 释放资源。
  Future<void> dispose() async {
    await _playerStateSub?.cancel();
    _playerStateSub = null;
    if (_player != null) {
      await _player!.dispose();
      _player = null;
    }
    _currentFilePath = null;
    _playCompleter?.complete();
    _playCompleter = null;
  }

  /// 懒初始化播放器。
  Future<AudioPlayer> _ensurePlayer() async {
    if (_player != null) return _player!;

    final player = AudioPlayer();
    _player = player;
    _playerStateSub = player.playerStateStream.listen((playerState) {
      if (playerState.processingState == ProcessingState.completed) {
        _currentFilePath = null;
        _playCompleter?.complete();
        _playCompleter = null;
      }
    });
    return player;
  }
}
