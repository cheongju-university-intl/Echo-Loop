/// 跟读专用播放器 Provider
///
/// 难句跟读播放器，与 IntensiveListenPlayer 同层级，直接操作 AudioEngine。
/// 核心功能：
/// - 逐句播放（遍数根据难度调整：veryEasy/easy=2, medium=3, hard=4, veryHard=5）
/// - 遍间停顿时间：max(句长×2, 2000ms)，给用户跟读时间
/// - 取消难句收藏（从播放列表移除该句）
/// - 手动上一句/下一句
///
/// 使用 sealed class [PlaybackPhase] 状态机管理播放阶段，
/// 替代布尔标志组合，使无效状态在类型层面不可表达。
///
/// 使用 SentencePlaybackEngine 的 sessionId 守护防止异步竞态。
library;

import 'dart:async';
import 'dart:math' as math;
import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../../analytics/analytics_providers.dart';
import '../../analytics/models/event_names.dart';
import '../../database/providers.dart';
import '../../models/intensive_listen_settings.dart';
import '../../models/study_stage.dart';
import '../../services/app_logger.dart';
import '../../models/sentence.dart';
import '../../services/learned_vocabulary_tracker.dart';
import '../../services/study_event_recorder.dart';
import '../../utils/word_counter.dart';
import '../audio_engine/audio_engine_provider.dart';
import '../learned_vocabulary_tracker_provider.dart';
import '../learning_progress_provider.dart';
import '../listen_and_repeat_turn_controller_provider.dart';
import 'learning_session_provider.dart';
import 'playback_phase.dart';
import 'sentence_playback_engine.dart';

part 'listen_and_repeat_player_provider.g.dart';

/// 跟读播放器状态
class ListenAndRepeatPlayerState {
  /// 当前句子索引（0-based，在过滤后的难句列表中的索引）
  final int currentSentenceIndex;

  /// 难句总数
  final int totalSentences;

  /// 当前遍数（1-based，"第N遍"）
  final int currentPlayCount;

  /// 目标播放遍数（根据难度动态计算，已弃用，由 settings.repeatCount 代替）
  final int targetPlayCount;

  /// 跟读设置（循环次数 + 停顿模式）
  final IntensiveListenSettings settings;

  /// 播放阶段状态机
  ///
  /// 替代原来的 isPlaying / isPauseBetweenPlays / isPauseBetweenSentences /
  /// isCountdownPaused / isCountdownFastForward / isPostEvalCountdown /
  /// pauseRemaining / pauseDuration 等 8 个字段。
  final PlaybackPhase phase;

  /// 收藏标记版本号（每次 toggle 递增，用于触发 select 监听的 rebuild）
  final int bookmarkVersion;

  const ListenAndRepeatPlayerState({
    this.currentSentenceIndex = 0,
    this.totalSentences = 0,
    this.currentPlayCount = 1,
    this.targetPlayCount = 3,
    this.settings = const IntensiveListenSettings(),
    this.phase = const IdlePhase(),
    this.bookmarkVersion = 0,
  });

  ListenAndRepeatPlayerState copyWith({
    int? currentSentenceIndex,
    int? totalSentences,
    int? currentPlayCount,
    int? targetPlayCount,
    IntensiveListenSettings? settings,
    PlaybackPhase? phase,
    int? bookmarkVersion,
  }) {
    return ListenAndRepeatPlayerState(
      currentSentenceIndex: currentSentenceIndex ?? this.currentSentenceIndex,
      totalSentences: totalSentences ?? this.totalSentences,
      currentPlayCount: currentPlayCount ?? this.currentPlayCount,
      targetPlayCount: targetPlayCount ?? this.targetPlayCount,
      settings: settings ?? this.settings,
      phase: phase ?? this.phase,
      bookmarkVersion: bookmarkVersion ?? this.bookmarkVersion,
    );
  }

  // ========== 便捷 getter（向后兼容 + Screen 层简化访问） ==========

  /// 是否正在播放音频
  bool get isPlaying => phase is PlayingPhase;

  /// 是否处于任意停顿中（遍间 / 句间 / 评估后）
  bool get isPauseBetweenPlays =>
      phase is RepeatPausePhase ||
      phase is AdvancePausePhase ||
      phase is PostEvalPausePhase;

  /// 是否处于句间停顿中
  bool get isPauseBetweenSentences =>
      phase is AdvancePausePhase ||
      (phase is PostEvalPausePhase &&
          (phase as PostEvalPausePhase).isSentencePause);

  /// 是否处于评估后倒计时中
  bool get isPostEvalCountdown => phase is PostEvalPausePhase;

  /// 当前步骤是否自然完成
  bool get stepFinished =>
      phase is IdlePhase && (phase as IdlePhase).stepFinished;

  /// 停顿剩余时间
  Duration get pauseRemaining => _activeCountdown?.remaining ?? Duration.zero;

  /// 停顿总时长
  Duration get pauseDuration => _activeCountdown?.total ?? Duration.zero;

  /// 倒计时是否暂停中
  bool get isCountdownPaused => _activeCountdown?.isPaused ?? false;

  /// 倒计时是否快进中
  bool get isCountdownFastForward => _activeCountdown?.isFastForward ?? false;

  /// 倒计时是否因用户交互临时挂起
  bool get isCountdownSuspended => _activeCountdown?.isSuspended ?? false;

  /// 获取当前活跃的倒计时状态（如有）
  CountdownState? get _activeCountdown => switch (phase) {
    RepeatPausePhase(:final countdown) => countdown,
    AdvancePausePhase(:final countdown) => countdown,
    PostEvalPausePhase(:final countdown) => countdown,
    _ => null,
  };
}

/// 跟读专用播放器 Provider
///
/// 组合 SentencePlaybackEngine 实现逐句跟读播放循环。
/// 句子列表来自精听阶段标记的难句。
@Riverpod(keepAlive: true)
class ListenAndRepeatPlayer extends _$ListenAndRepeatPlayer {
  /// 难句列表（可变，取消收藏时会移除）
  List<Sentence> _sentences = [];

  /// 学习事件记录器
  late StudyEventRecorder _recorder;

  /// 播放引擎（统一管理所有倒计时：遍间/句间/评估后）
  late SentencePlaybackEngine _engine;

  @override
  ListenAndRepeatPlayerState build() {
    LearnedVocabularyTracker? vocabTracker;
    try {
      vocabTracker = ref.read(learnedVocabularyTrackerProvider);
    } catch (e) {
      AppLogger.log('Player', '⚠ vocabTracker 不可用（测试环境？）: $e');
    }
    _recorder = StudyEventRecorder(
      studyTimeService: ref.read(studyTimeServiceProvider),
      vocabTracker: vocabTracker,
      stage: StudyStage.listenAndRepeat,
    );

    _engine = SentencePlaybackEngine(
      getEngine: () => ref.read(audioEngineProvider.notifier),
      recorder: _recorder,
    );
    ref.onDispose(() {
      _engine.cleanup();
    });
    return const ListenAndRepeatPlayerState();
  }

  /// 初始化跟读播放器
  ///
  /// [sentences] 难句列表（会深拷贝）
  /// [startIndex] 起始句子索引（断点续学）
  /// [targetPlayCount] 目标播放遍数（根据难度计算）
  Future<void> initialize(
    List<Sentence> sentences, {
    int startIndex = 0,
    int targetPlayCount = 3,
  }) async {
    _engine.cleanup();
    _sentences = sentences.map((s) => s.copyWith()).toList();

    final safeIndex = _sentences.isEmpty
        ? 0
        : startIndex.clamp(0, _sentences.length - 1);

    state = ListenAndRepeatPlayerState(
      currentSentenceIndex: safeIndex,
      totalSentences: _sentences.length,
      targetPlayCount: targetPlayCount,
      settings: IntensiveListenSettings(repeatCount: targetPlayCount),
    );
    ref.read(analyticsServiceProvider).track(Events.listenRepeatStart, {
      EventParams.audioId: ref.read(learningSessionProvider).audioItemId ?? '',
      EventParams.totalSentences: _sentences.length,
    });

    // 注入 recorder 到录音控制器
    ref
        .read(shadowingRecordingControllerProvider.notifier)
        .setRecorder(_recorder);
  }

  /// 获取当前句子
  Sentence? get currentSentence =>
      _sentences.isNotEmpty && state.currentSentenceIndex < _sentences.length
      ? _sentences[state.currentSentenceIndex]
      : null;

  /// 获取句子列表（只读）
  List<Sentence> get sentences => List.unmodifiable(_sentences);

  /// 获取当前句子索引（供外部保存断点用）
  int get currentIndex => state.currentSentenceIndex;

  /// 异步保存跟读断点，不阻塞当前句开始播放。
  void _persistCurrentSentenceIndexAsync() {
    final session = ref.read(learningSessionProvider);
    final audioItemId = session.audioItemId;
    if (audioItemId == null) return;

    unawaited(
      ref
          .read(learningProgressNotifierProvider.notifier)
          .saveShadowingSentenceIndex(
            audioItemId,
            state.currentSentenceIndex,
            isFreePlay: session.isFreePlay,
          ),
    );
  }

  /// 开始播放当前句子
  Future<void> startPlaying() async {
    if (_sentences.isEmpty) return;
    await _startSentence();
  }

  /// 外部中断播放通知（如意群播放）
  ///
  /// 只更新播放状态，不影响停顿等其他状态，
  /// 避免录音面板等 UI 意外消失。
  void notifyExternalStop() {
    if (state.isPlaying) {
      state = state.copyWith(phase: const IdlePhase());
    }
  }

  /// 挂起倒计时（用户交互时调用：播放录音、查词典、打开设置等）
  ///
  /// 取消引擎倒计时并标记 isSuspended，UI 隐藏倒计时。
  /// 如果倒计时已被用户主动暂停（isPaused），则不干预。
  void suspendCountdown() {
    final countdown = state._activeCountdown;
    if (countdown == null || countdown.isSuspended) return;
    _engine.invalidateSession();
    // 保留 isPaused 状态，restart 时恢复
    _updateCountdown(countdown.copyWith(isSuspended: true));
  }

  /// 恢复倒计时（用户交互结束时调用：录音播放结束、弹窗关闭等）
  ///
  /// 如果挂起前倒计时是暂停的，恢复为暂停状态（不自动开始）。
  /// 否则用保存的 total 时长重新开始倒计时。
  void restartCountdown() {
    final countdown = state._activeCountdown;
    if (countdown == null || !countdown.isSuspended) return;

    final wasPaused = countdown.isPaused;
    final total = countdown.total;

    _updateCountdown(
      countdown.copyWith(
        isSuspended: false,
        remaining: total,
        isPaused: wasPaused,
        isFastForward: false,
      ),
    );

    // 始终启动 engine countdown（即使 isPaused，也需要 engine 有活跃的 timer）
    _engine.autoAdvance(
      pauseDuration: total,
      onPauseStarted: (_) {},
      onTick: (remaining) {
        final cd = state._activeCountdown;
        if (cd != null && !cd.isSuspended) {
          _updateCountdown(cd.copyWith(remaining: remaining));
        }
      },
      onAdvance: () async {
        completePausedTurn();
      },
    );

    // 挂起前是暂停的 → 立即暂停新启动的 engine countdown
    if (wasPaused) {
      _engine.pauseCountdown();
    }
  }

  /// 暂停播放
  Future<void> pause() async {
    _engine.invalidateSession();
    state = state.copyWith(phase: const IdlePhase());
  }

  /// 恢复播放（从当前句子重新开始播放循环）
  Future<void> resume() async {
    await _startSentence(startPlayCount: state.currentPlayCount);
  }

  /// 跳转到下一句
  Future<void> goToNext() async {
    if (state.currentSentenceIndex >= state.totalSentences - 1) return;

    _engine.invalidateSession();

    state = state.copyWith(
      currentSentenceIndex: state.currentSentenceIndex + 1,
      currentPlayCount: 1,
      phase: const IdlePhase(),
    );

    await _startSentence();
  }

  /// 跳转到上一句
  Future<void> goToPrevious() async {
    if (state.currentSentenceIndex <= 0) return;

    _engine.invalidateSession();

    state = state.copyWith(
      currentSentenceIndex: state.currentSentenceIndex - 1,
      currentPlayCount: 1,
      phase: const IdlePhase(),
    );

    await _startSentence();
  }

  /// 取消当前句子的难句收藏
  ///
  /// 从播放列表移除当前句子，返回被移除的句子（供外部删除书签）。
  /// 若列表为空→标记完成；否则自动调整索引。
  Sentence? removeDifficultMark() {
    if (_sentences.isEmpty) return null;

    _engine.invalidateSession();

    final removedIndex = state.currentSentenceIndex;
    final removed = _sentences[removedIndex];
    _sentences.removeAt(removedIndex);

    if (_sentences.isEmpty) {
      state = state.copyWith(totalSentences: 0, phase: const IdlePhase());
      return removed;
    }

    // 调整索引：如果移除的是最后一句，回退一格
    final newIndex = removedIndex >= _sentences.length
        ? _sentences.length - 1
        : removedIndex;

    state = state.copyWith(
      currentSentenceIndex: newIndex,
      totalSentences: _sentences.length,
      currentPlayCount: 1,
      phase: const IdlePhase(),
    );

    return removed;
  }

  /// 切换当前句子的收藏标记（不从列表移除）
  ///
  /// 仅更新内存中的 isBookmarked 状态并触发 UI 重建，
  /// DB 操作由 Screen 层负责。
  void toggleCurrentBookmark() {
    if (_sentences.isEmpty) return;
    final idx = state.currentSentenceIndex;
    final s = _sentences[idx];
    _sentences[idx] = s.copyWith(isBookmarked: !s.isBookmarked);
    state = state.copyWith(bookmarkVersion: state.bookmarkVersion + 1);
  }

  /// 更新跟读设置（即时生效，仅本次会话）
  ///
  /// 当 repeatCount 调小时，clamp currentPlayCount 避免越界显示（如"第3/1遍"），
  /// 并中断当前播放循环、以新设置重新开始当前句子。
  void updateSettings(IntensiveListenSettings newSettings) {
    var clampedPlayCount = state.currentPlayCount;
    if (clampedPlayCount > newSettings.repeatCount) {
      clampedPlayCount = newSettings.repeatCount;
    }

    final modeChanged = newSettings.isManualMode != state.settings.isManualMode;
    final needRestart = newSettings.repeatCount != state.settings.repeatCount;

    state = state.copyWith(
      settings: newSettings,
      currentPlayCount: clampedPlayCount,
    );

    // 自动↔手动切换时，停在当前句子，取消一切异步操作
    if (modeChanged) {
      _engine.invalidateSession();
      state = state.copyWith(phase: const IdlePhase());
      return;
    }

    // repeatCount 变化时中断当前循环，以新设置重新开始
    if (needRestart && state.isPlaying) {
      _engine.invalidateSession();
      _startSentence();
    }
  }

  /// 暂停倒计时（统一走 Engine）
  void pauseCountdown() {
    final countdown = state._activeCountdown;
    if (countdown == null || countdown.isPaused) return;
    _engine.pauseCountdown();
    _updateCountdown(countdown.copyWith(isPaused: true));
  }

  /// 恢复倒计时（统一走 Engine）
  void resumeCountdown() {
    final countdown = state._activeCountdown;
    if (countdown == null || !countdown.isPaused) return;
    _engine.resumeCountdown();
    _updateCountdown(countdown.copyWith(isPaused: false));
  }

  /// 切换倒计时快进（10 倍速/正常速）
  ///
  /// 如果当前暂停中，快进会同时恢复倒计时。
  void toggleCountdownFastForward() {
    final countdown = state._activeCountdown;
    if (countdown == null) return;
    final isFF = !countdown.isFastForward;
    _engine.setCountdownSpeed(isFF ? 10.0 : 1.0);
    if (countdown.isPaused) _engine.resumeCountdown();
    _updateCountdown(countdown.copyWith(isFastForward: isFF, isPaused: false));
  }

  /// 更新当前 phase 内的 CountdownState
  void _updateCountdown(CountdownState countdown) {
    final phase = state.phase;
    final newPhase = switch (phase) {
      RepeatPausePhase() => phase.copyWith(countdown: countdown),
      AdvancePausePhase() => phase.copyWith(countdown: countdown),
      PostEvalPausePhase() => phase.copyWith(countdown: countdown),
      _ => phase,
    };
    state = state.copyWith(phase: newPhase);
  }

  /// 倒计时期间重播当前句子
  Future<void> replayDuringCountdown() async {
    _engine.invalidateSession();
    state = state.copyWith(phase: const IdlePhase());
    await _startSentence(startPlayCount: state.currentPlayCount);
  }

  /// 立即完成当前停顿回合，继续后续播放流程。
  Future<void> completePausedTurn() async {
    final phase = state.phase;

    // 判断停顿类型
    final bool isAdvancing;
    switch (phase) {
      case RepeatPausePhase():
        isAdvancing = false;
      case AdvancePausePhase():
        isAdvancing = true;
      case PostEvalPausePhase(:final isSentencePause):
        isAdvancing = isSentencePause;
      default:
        AppLogger.log('Player', 'completePausedTurn 跳过：不在停顿中');
        return;
    }

    AppLogger.log(
      'Player',
      'completePausedTurn: '
          'phase=${phase.runtimeType}, '
          'isAdvancing=$isAdvancing, '
          'play=${state.currentPlayCount}/${state.settings.repeatCount}, '
          'sentence=${state.currentSentenceIndex + 1}/${state.totalSentences}',
    );

    _engine.invalidateSession();
    state = state.copyWith(phase: const IdlePhase());

    if (isAdvancing) {
      final isLastSentence =
          state.currentSentenceIndex >= state.totalSentences - 1;
      if (isLastSentence) {
        AppLogger.log('Player', '→ 完成（最后一句）');
        state = state.copyWith(phase: const IdlePhase(stepFinished: true));
        _trackShadowingComplete();
        return;
      }

      AppLogger.log('Player', '→ 下一句 #${state.currentSentenceIndex + 2}');
      state = state.copyWith(
        currentSentenceIndex: state.currentSentenceIndex + 1,
        currentPlayCount: 1,
      );
      await _startSentence();
      return;
    }

    final nextPlayCount = state.currentPlayCount + 1;
    if (nextPlayCount > state.settings.repeatCount) {
      AppLogger.log(
        'Player',
        '→ autoAdvance（${state.settings.repeatCount}遍已满）',
      );
      await _autoAdvance();
      return;
    }

    AppLogger.log('Player', '→ 第$nextPlayCount/${state.settings.repeatCount}遍');
    await _startSentence(startPlayCount: nextPlayCount);
  }

  /// 录音评估完成后启动 review 倒计时（5s）。
  ///
  /// 通过 Engine 的 autoAdvance 统一管理倒计时，
  /// 先 invalidate 旧 session（使遍间停顿的 await 安全退出），
  /// 再启动新的 5 秒倒计时。
  /// [extraDuration] 额外时长（如用户手动停止录音时加 2 秒）。
  /// 手动模式下直接 return，由用户手动推进。
  void startPostEvaluationPause({Duration extraDuration = Duration.zero}) {
    if (!state.isPauseBetweenPlays) return;
    if (state.settings.isManualMode) return;

    final reviewDuration = const Duration(seconds: 5) + extraDuration;
    final isSentencePause = state.isPauseBetweenSentences;

    // 杀掉旧 session（遍间停顿的 engine 循环安全退出）
    _engine.invalidateSession();

    state = state.copyWith(
      phase: PostEvalPausePhase(
        isSentencePause: isSentencePause,
        countdown: CountdownState(
          remaining: reviewDuration,
          total: reviewDuration,
        ),
      ),
    );

    // 通过 engine 的 autoAdvance 启动新的 5 秒倒计时
    _engine.autoAdvance(
      pauseDuration: reviewDuration,
      onPauseStarted: (_) {
        // phase 已在上面设置，此处无需操作
      },
      onTick: (remaining) {
        final phase = state.phase;
        if (phase is PostEvalPausePhase) {
          state = state.copyWith(
            phase: phase.copyWith(
              countdown: phase.countdown.copyWith(remaining: remaining),
            ),
          );
        }
      },
      onAdvance: () async {
        if (state.phase is PostEvalPausePhase) {
          completePausedTurn();
        }
      },
    );
  }

  /// 取消评估后倒计时（不推进到下一句）
  void cancelPostEvalCountdown() {
    if (state.phase is! PostEvalPausePhase) return;
    _engine.invalidateSession();
    // 回到遍间停顿状态（保留 completedPlayCount）
    state = state.copyWith(
      phase: RepeatPausePhase(
        completedPlayCount: state.currentPlayCount,
        countdown: const CountdownState(),
      ),
    );
  }

  /// 停止播放（用户在最后一句主动点击完成按钮时调用）
  ///
  /// 仅停止播放，弹窗由 screen 层直接调用。
  void stopPlayback() {
    _engine.invalidateSession();
    state = state.copyWith(phase: const IdlePhase());
  }

  /// 释放资源
  void disposePlayer() {
    ref.read(shadowingRecordingControllerProvider.notifier).setRecorder(null);
    _engine.cleanup();
    _sentences = [];
    state = const ListenAndRepeatPlayerState();
  }

  /// 上报跟读完成事件
  void _trackShadowingComplete() {
    ref.read(analyticsServiceProvider).track(Events.listenRepeatComplete, {
      EventParams.audioId: ref.read(learningSessionProvider).audioItemId ?? '',
      EventParams.totalSentences: state.totalSentences,
    });
  }

  // ========== 内部方法 ==========

  /// 开始播放当前句子的循环
  Future<void> _startSentence({int startPlayCount = 1}) async {
    final sentence = currentSentence;
    if (sentence == null) return;

    // 跳过零时长句子
    if (sentence.duration <= Duration.zero) {
      await _autoAdvance();
      return;
    }

    state = state.copyWith(
      currentPlayCount: startPlayCount,
      phase: PlayingPhase(playCount: startPlayCount),
    );
    _persistCurrentSentenceIndexAsync();

    final wordCount = countWords(sentence.text);
    final session = ref.read(learningSessionProvider.notifier);

    // 手动模式：只播一遍，不循环
    final effectiveRepeatCount = state.settings.isManualMode
        ? 1
        : state.settings.repeatCount;

    await _engine.playSentenceLoop(
      sentence: sentence,
      repeatCount: effectiveRepeatCount,
      startPlayCount: startPlayCount,
      pauseCalculator: _buildPauseCalculator(),
      onPlayCountChanged: (playCount) {
        state = state.copyWith(
          currentPlayCount: playCount,
          phase: PlayingPhase(playCount: playCount),
        );
      },
      onPauseStarted: (pauseDur) {
        // 停顿开始 = 用户跟读 = 输出
        session.addOutputWords(wordCount);
        state = state.copyWith(
          phase: RepeatPausePhase(
            completedPlayCount: state.currentPlayCount,
            countdown: CountdownState(remaining: pauseDur, total: pauseDur),
          ),
        );
      },
      onPauseEnded: () {
        // engine 循环会紧接着调用 onPlayCountChanged 设置 PlayingPhase，
        // 此处无需额外操作。
      },
      onTick: (remaining) {
        final phase = state.phase;
        if (phase is RepeatPausePhase) {
          state = state.copyWith(
            phase: phase.copyWith(
              countdown: phase.countdown.copyWith(remaining: remaining),
            ),
          );
        }
      },
      onAllPlaysCompleted: () async {
        await _autoAdvance();
      },
    );
  }

  /// 自动推进到下一句（最后一句也走停顿流程）
  Future<void> _autoAdvance() async {
    final isLastSentence =
        state.currentSentenceIndex >= state.totalSentences - 1;

    // 所有句子（包括最后一句）都走停顿，给用户跟读时间
    final sentence = currentSentence;
    final calculator = _buildPauseCalculator();
    final pauseDur = sentence != null
        ? calculator(sentence.duration)
        : const Duration(seconds: 2);

    await _engine.autoAdvance(
      pauseDuration: pauseDur,
      onPauseStarted: (dur) {
        state = state.copyWith(
          phase: AdvancePausePhase(
            countdown: CountdownState(remaining: dur, total: dur),
          ),
        );
      },
      onTick: (remaining) {
        final phase = state.phase;
        if (phase is AdvancePausePhase) {
          state = state.copyWith(
            phase: phase.copyWith(
              countdown: phase.countdown.copyWith(remaining: remaining),
            ),
          );
        }
      },
      onAdvance: () async {
        if (isLastSentence) {
          // 最后一句停顿结束 → 发出完成信号
          state = state.copyWith(phase: const IdlePhase(stepFinished: true));
          _trackShadowingComplete();
        } else {
          // 非最后一句 → 推进到下一句
          state = state.copyWith(
            currentSentenceIndex: state.currentSentenceIndex + 1,
            currentPlayCount: 1,
            phase: const IdlePhase(),
          );
          await _startSentence();
        }
      },
    );
  }

  /// 重置到第一句并重新开始播放（供"再来一遍"使用）
  Future<void> resetToStart() async {
    _engine.invalidateSession();
    state = state.copyWith(
      currentSentenceIndex: 0,
      currentPlayCount: 1,
      phase: const IdlePhase(),
    );
    await startPlaying();
  }

  /// 根据当前设置构建停顿计算器
  ///
  /// 返回的 lambda 在每次调用时读取最新 `state.settings`，
  /// 确保用户在播放中途修改停顿设置后能即时生效。
  /// - smart: max(句长×2, 2000ms)（跟读专用，给用户足够跟读时间）
  /// - fixed / multiplier: 复用精听的 calculatePauseDuration 逻辑
  PauseCalculator _buildPauseCalculator() {
    return (Duration sentenceDuration) {
      final settings = state.settings;
      return switch (settings.pauseMode) {
        PauseMode.smart => listenAndRepeatPauseCalculator(sentenceDuration),
        PauseMode.fixed => Duration(seconds: settings.fixedPauseSeconds),
        PauseMode.multiplier => Duration(
          milliseconds: math.max(
            (sentenceDuration.inMilliseconds * settings.pauseMultiplier)
                .round(),
            1000,
          ),
        ),
      };
    };
  }
}
