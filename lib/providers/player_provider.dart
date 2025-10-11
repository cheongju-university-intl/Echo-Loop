import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';
import '../models/audio_item.dart';
import '../models/sentence.dart';
import '../models/playback_settings.dart';
import '../services/subtitle_parser.dart';
import '../services/storage_service.dart';

class PlayerProvider extends ChangeNotifier {
  final AudioPlayer _audioPlayer = AudioPlayer();
  
  AudioItem? _currentAudioItem;
  List<Sentence> _sentences = [];
  int? _currentSentenceIndex;
  PlaybackSettings _settings = PlaybackSettings();
  Set<int> _bookmarkedIndices = {};
  
  bool _isLoading = false;
  int _currentLoopCount = 0;
  Timer? _pauseTimer;
  Timer? _sentenceEndTimer;
  StreamSubscription? _positionSubscription;
  StreamSubscription? _playerStateSubscription;
  bool _isDisposed = false;

  // Getters
  AudioPlayer get audioPlayer => _audioPlayer;
  AudioItem? get currentAudioItem => _currentAudioItem;
  List<Sentence> get sentences => _sentences;
  List<Sentence> get bookmarkedSentences => 
      _sentences.where((s) => _bookmarkedIndices.contains(s.index)).toList();
  int? get currentSentenceIndex => _currentSentenceIndex;
  Sentence? get currentSentence => 
      _currentSentenceIndex != null && _currentSentenceIndex! < _sentences.length
          ? _sentences[_currentSentenceIndex!]
          : null;
  PlaybackSettings get settings => _settings;
  Set<int> get bookmarkedIndices => _bookmarkedIndices;
  bool get isLoading => _isLoading;
  bool get isPlaying => _audioPlayer.playing;
  Duration get currentPosition => _audioPlayer.position;
  Duration? get totalDuration => _audioPlayer.duration;
  bool get hasAudio => _currentAudioItem != null;
  bool get hasSentences => _sentences.isNotEmpty;

  PlayerProvider() {
    _loadSettings();
    _setupListeners();
  }

  Future<void> _loadSettings() async {
    _settings = await StorageService.loadSettings();
    notifyListeners();
  }

  void _setupListeners() {
    _positionSubscription = _audioPlayer.positionStream.listen(_onPositionChanged);
    _playerStateSubscription = _audioPlayer.playerStateStream.listen(_onPlayerStateChanged);
  }

  void _onPositionChanged(Duration position) {
    _updateCurrentSentence(position);
  }

  void _onPlayerStateChanged(PlayerState state) {
    if (state.processingState == ProcessingState.completed) {
      _handlePlaybackCompleted();
    }
    notifyListeners();
  }

  void _updateCurrentSentence(Duration position) {
    if (_sentences.isEmpty) return;

    final index = _sentences.indexWhere(
      (s) => position >= s.startTime && position < s.endTime,
    );

    if (index != -1 && index != _currentSentenceIndex) {
      _currentSentenceIndex = index;
      notifyListeners();
    }
  }

  Future<void> loadAudio(AudioItem audioItem) async {
    if (_currentAudioItem?.id == audioItem.id) return;

    _isLoading = true;
    notifyListeners();

    try {
      // Stop current playback
      await stop();

      _currentAudioItem = audioItem;
      _sentences = [];
      _currentSentenceIndex = null;
      _currentLoopCount = 0;

      // Load audio
      try {
        await _audioPlayer.setFilePath(audioItem.audioPath);
        await _audioPlayer.setSpeed(_settings.playbackSpeed);
      } catch (e) {
        print('Error loading audio file: $e');
        _currentAudioItem = null;
        rethrow;
      }

      // Load transcript if available
      if (audioItem.hasTranscript) {
        try {
          _sentences = await SubtitleParser.parseSubtitle(audioItem.transcriptPath!);
        } catch (e) {
          print('Error loading transcript: $e');
          // Continue without transcript
        }
      }

      // Load bookmarks
      try {
        _bookmarkedIndices = await StorageService.loadBookmarks(audioItem.id);
        
        // Update sentence bookmark status
        for (var sentence in _sentences) {
          sentence.isBookmarked = _bookmarkedIndices.contains(sentence.index);
        }
      } catch (e) {
        print('Error loading bookmarks: $e');
        _bookmarkedIndices = {};
      }

      // Set initial sentence to first sentence if available
      if (_sentences.isNotEmpty) {
        _currentSentenceIndex = 0;
        await _audioPlayer.seek(_sentences[0].startTime);
      }

    } catch (e) {
      print('Error loading audio: $e');
      _currentAudioItem = null;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> play() async {
    if (_currentAudioItem == null) return;

    if (_settings.mode == PlaybackMode.singleSentence) {
      // If no sentence is selected, select the first one
      if (_currentSentenceIndex == null) {
        final targetSentences = _getTargetSentences();
        if (targetSentences.isNotEmpty) {
          await playSentence(targetSentences.first.index);
        }
      } else {
        await playSentence(_currentSentenceIndex!);
      }
    } else if (_settings.mode == PlaybackMode.bookmarkedOnly) {
      // Play bookmarked sentences with per-sentence control so loop/pause work
      final bookmarked = bookmarkedSentences;
      if (bookmarked.isEmpty) return;
      
      int targetIndex;
      if (_currentSentenceIndex == null ||
          !_bookmarkedIndices.contains(_currentSentenceIndex)) {
        targetIndex = bookmarked.first.index;
      } else {
        targetIndex = _currentSentenceIndex!;
      }
      await playSentence(targetIndex);
    } else {
      await _audioPlayer.play();
    }
  }

  Future<void> pause() async {
    await _audioPlayer.pause();
    _pauseTimer?.cancel();
    _sentenceEndTimer?.cancel();
  }

  Future<void> stop() async {
    await _audioPlayer.stop();
    _pauseTimer?.cancel();
    _sentenceEndTimer?.cancel();
    _currentLoopCount = 0;
  }

  Future<void> seek(Duration position) async {
    await _audioPlayer.seek(position);
  }

  Future<void> playSentence(int index) async {
    if (index < 0 || index >= _sentences.length) return;

    _currentSentenceIndex = index;
    _currentLoopCount = 0;
    
    await _playSentenceInternal(index);
  }

  Future<void> _playSentenceInternal(int index) async {
    if (_isDisposed) return;
    
    final sentence = _sentences[index];
    await _audioPlayer.seek(sentence.startTime);
    await _audioPlayer.play();

    // Cancel any existing sentence end timer
    _sentenceEndTimer?.cancel();
    
    // Schedule pause at sentence end
    // Adjust for current playback speed so the timer fires when audio reaches the end
    final speed = _audioPlayer.speed == 0 ? 1.0 : _audioPlayer.speed;
    final scaledMs = (sentence.duration.inMilliseconds / speed).round();
    final duration = Duration(milliseconds: scaledMs);
    _sentenceEndTimer = Timer(duration, () async {
      if (!_isDisposed && _audioPlayer.playing && _currentSentenceIndex == index) {
        await _audioPlayer.pause();
        await _handleSentenceCompleted();
      }
    });
  }

  Future<void> _handleSentenceCompleted() async {
    if (_isDisposed) return;

    // Check if we should loop this sentence
    if (_settings.loopEnabled) {
      _currentLoopCount++;
      
      // loopCount is clamped to 1-20; no infinite loop support
      final shouldLoop = _currentLoopCount < _settings.loopCount;
      
      if (shouldLoop && _currentSentenceIndex != null) {
        _pauseTimer?.cancel();
        _pauseTimer = Timer(_settings.pauseInterval, () async {
          if (!_isDisposed) {
            await _playSentenceInternal(_currentSentenceIndex!);
          }
        });
        return;
      }
    }
    
    // Loop not enabled or loop completed
    // In single sentence/bookmarked mode, move to next sentence and auto-play
    if (_settings.mode == PlaybackMode.singleSentence ||
        _settings.mode == PlaybackMode.bookmarkedOnly) {
      _currentLoopCount = 0;
      await nextSentence();
      if (_currentSentenceIndex != null) {
        await _playSentenceInternal(_currentSentenceIndex!);
      }
    }
  }

  void _handlePlaybackCompleted() {
    if (_isDisposed) return;
    
    if (_settings.mode == PlaybackMode.fullArticle && _settings.loopEnabled) {
      _currentLoopCount++;
      
      // loopCount is clamped to 1-20; no infinite loop support
      final shouldLoop = _currentLoopCount < _settings.loopCount;
      
      if (shouldLoop) {
        _pauseTimer?.cancel();
        _pauseTimer = Timer(_settings.pauseInterval, () async {
          if (!_isDisposed) {
            await _audioPlayer.seek(Duration.zero);
            await _audioPlayer.play();
          }
        });
      }
    }
  }

  Future<void> nextSentence() async {
    if (_sentences.isEmpty) return;
    
    final targetSentences = _getTargetSentences();
    if (targetSentences.isEmpty) return;

    int nextIndex;
    if (_currentSentenceIndex == null) {
      nextIndex = targetSentences.first.index;
    } else {
      final currentPosInTarget = targetSentences.indexWhere(
        (s) => s.index == _currentSentenceIndex
      );
      if (currentPosInTarget == -1 || currentPosInTarget >= targetSentences.length - 1) {
        nextIndex = targetSentences.first.index;
      } else {
        nextIndex = targetSentences[currentPosInTarget + 1].index;
      }
    }

    // Just seek, don't auto-play
    _currentSentenceIndex = nextIndex;
    await seek(_sentences[nextIndex].startTime);
    notifyListeners();
  }

  Future<void> previousSentence() async {
    if (_sentences.isEmpty) return;
    
    final targetSentences = _getTargetSentences();
    if (targetSentences.isEmpty) return;

    int prevIndex;
    if (_currentSentenceIndex == null) {
      prevIndex = targetSentences.last.index;
    } else {
      final currentPosInTarget = targetSentences.indexWhere(
        (s) => s.index == _currentSentenceIndex
      );
      if (currentPosInTarget <= 0) {
        prevIndex = targetSentences.last.index;
      } else {
        prevIndex = targetSentences[currentPosInTarget - 1].index;
      }
    }

    // Just seek, don't auto-play
    _currentSentenceIndex = prevIndex;
    await seek(_sentences[prevIndex].startTime);
    notifyListeners();
  }

  List<Sentence> _getTargetSentences() {
    if (_settings.mode == PlaybackMode.bookmarkedOnly) {
      return bookmarkedSentences;
    }
    return _sentences;
  }

  Future<void> toggleBookmark(int index) async {
    if (_bookmarkedIndices.contains(index)) {
      _bookmarkedIndices.remove(index);
      _sentences[index].isBookmarked = false;
    } else {
      _bookmarkedIndices.add(index);
      _sentences[index].isBookmarked = true;
    }

    if (_currentAudioItem != null) {
      await StorageService.saveBookmarks(_currentAudioItem!.id, _bookmarkedIndices);
    }
    
    notifyListeners();
  }

  Future<void> updateSettings(PlaybackSettings newSettings) async {
    _settings = newSettings;
    await _audioPlayer.setSpeed(newSettings.playbackSpeed);
    await StorageService.saveSettings(newSettings);
    notifyListeners();
  }

  @override
  void dispose() {
    _isDisposed = true;
    _pauseTimer?.cancel();
    _sentenceEndTimer?.cancel();
    _positionSubscription?.cancel();
    _playerStateSubscription?.cancel();
    _audioPlayer.dispose();
    super.dispose();
  }
}
