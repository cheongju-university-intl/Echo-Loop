enum PlaybackMode {
  singleSentence,
  fullArticle,
  bookmarkedOnly,
}

class PlaybackSettings {
  final bool loopEnabled;
  final int loopCount; // number of loops per item, 1-20
  final Duration pauseInterval; // pause duration between loops
  final double playbackSpeed;
  final PlaybackMode mode;
  final bool showTranscript;

  PlaybackSettings({
    this.loopEnabled = false,
    this.loopCount = 3,
    this.pauseInterval = const Duration(seconds: 1),
    this.playbackSpeed = 1.0,
    this.mode = PlaybackMode.fullArticle,
    this.showTranscript = true,
  });

  Map<String, dynamic> toJson() => {
        'loopEnabled': loopEnabled,
        'loopCount': loopCount,
        'pauseInterval': pauseInterval.inMilliseconds,
        'playbackSpeed': playbackSpeed,
        'mode': mode.index,
        'showTranscript': showTranscript,
      };

  factory PlaybackSettings.fromJson(Map<String, dynamic> json) =>
      PlaybackSettings(
        loopEnabled: json['loopEnabled'] ?? false,
        // sanitize legacy values: 0 (infinite) -> default 3; clamp to 1-20
        loopCount: (() {
          final raw = json['loopCount'];
          final v = raw is int ? raw : 3;
          if (v < 1) return 3;
          if (v > 20) return 20;
          return v;
        })(),
        // pauseInterval in ms; clamp to 0-30s
        pauseInterval: (() {
          final ms = json['pauseInterval'];
          final rawMs = ms is int ? ms : 1000;
          int secs = (rawMs / 1000).round();
          if (secs < 0) secs = 0;
          if (secs > 30) secs = 30;
          return Duration(seconds: secs);
        })(),
        playbackSpeed: json['playbackSpeed'] ?? 1.0,
        mode: PlaybackMode.values[json['mode'] ?? 1],
        showTranscript: json['showTranscript'] ?? true,
      );

  PlaybackSettings copyWith({
    bool? loopEnabled,
    int? loopCount,
    Duration? pauseInterval,
    double? playbackSpeed,
    PlaybackMode? mode,
    bool? showTranscript,
  }) {
    return PlaybackSettings(
      loopEnabled: loopEnabled ?? this.loopEnabled,
      loopCount: loopCount ?? this.loopCount,
      pauseInterval: pauseInterval ?? this.pauseInterval,
      playbackSpeed: playbackSpeed ?? this.playbackSpeed,
      mode: mode ?? this.mode,
      showTranscript: showTranscript ?? this.showTranscript,
    );
  }
}
