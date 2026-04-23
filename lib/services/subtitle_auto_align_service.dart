/// AI 字幕自动校准服务。
///
/// 根据本地音频的静音区间微调句子边界。
/// 当原生解码不可用或任意阶段失败时，只记录日志并回退到原始字幕。
library;

import 'dart:math' as math;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/word_timestamp.dart';
import '../utils/srt_generator.dart';
import 'app_logger.dart';
import 'native_audio_decoder.dart';

/// 静音区间。
class SilenceInterval {
  final double startTime;
  final double endTime;

  const SilenceInterval({required this.startTime, required this.endTime});
}

/// 静音检测配置。
class SilenceDetectionConfig {
  final double thresholdDb;
  final int analysisWindowMs;
  final int minSilenceMs;
  final int noiseBurstMs;

  const SilenceDetectionConfig({
    required this.thresholdDb,
    required this.analysisWindowMs,
    required this.minSilenceMs,
    required this.noiseBurstMs,
  });
}

/// 自动校准配置。
class AutoAlignConfig extends SilenceDetectionConfig {
  final int paddingMs;
  final int shortSilenceSplitMs;

  const AutoAlignConfig({
    required super.thresholdDb,
    required super.analysisWindowMs,
    required super.minSilenceMs,
    required super.noiseBurstMs,
    required this.paddingMs,
    required this.shortSilenceSplitMs,
  });
}

/// 句子边界更新。
class SentenceBoundaryUpdate {
  final int sentenceIndex;
  final double startTime;
  final double endTime;

  const SentenceBoundaryUpdate({
    required this.sentenceIndex,
    required this.startTime,
    required this.endTime,
  });
}

/// 静音检测策略。
abstract class SilenceDetectionStrategy {
  SilenceInterval? detectLongestSilence(
    DecodedAudioData audioData,
    double candidateStart,
    double candidateEnd,
    SilenceDetectionConfig config,
  );

  List<SilenceInterval> detectSilenceIntervals(
    DecodedAudioData audioData,
    double candidateStart,
    double candidateEnd,
    SilenceDetectionConfig config,
  );
}

/// 自动校准默认配置。
const defaultAutoAlignConfig = AutoAlignConfig(
  thresholdDb: -40,
  analysisWindowMs: 10,
  minSilenceMs: 25,
  noiseBurstMs: 25,
  paddingMs: 150,
  shortSilenceSplitMs: 300,
);

const _epsilon = 1e-6;
const _logTag = 'SubtitleAutoAlign';

class _FrameRange {
  final int startFrame;
  final int endFrame;
  final bool isSilent;

  const _FrameRange({
    required this.startFrame,
    required this.endFrame,
    required this.isSilent,
  });
}

String _fmtSec(double seconds) => seconds.toStringAsFixed(3);

String _describeSilence(SilenceInterval? silence) {
  if (silence == null) return 'none';
  return '[${_fmtSec(silence.startTime)}s, ${_fmtSec(silence.endTime)}s]';
}

String _describeSentence(int index, TranscriptSentence sentence) {
  final start = _fmtSec(sentence.startTime.inMilliseconds / 1000);
  final end = _fmtSec(sentence.endTime.inMilliseconds / 1000);
  return '#$index [$start-$end] "${sentence.text}"'
      ' words=${sentence.startWordIndex}-${sentence.endWordIndex}';
}

String _describeBoundaryUpdate(SentenceBoundaryUpdate update) {
  return '#${update.sentenceIndex}'
      ' [${_fmtSec(update.startTime)}-${_fmtSec(update.endTime)}]';
}

double _clampDouble(double value, double min, double max) {
  return math.min(math.max(value, min), max);
}

int _clampInt(int value, int min, int max) {
  return math.min(math.max(value, min), max);
}

double _midpoint(double start, double end) => start + (end - start) / 2;

double _frameDurationSec(SilenceDetectionConfig config) =>
    config.analysisWindowMs / 1000;

double _rangeDurationSec(_FrameRange range, double frameSec) =>
    (range.endFrame - range.startFrame) * frameSec;

double _toDbfs(double rms) {
  if (rms <= 0) {
    return double.negativeInfinity;
  }
  return 20 * math.log(rms) / math.ln10;
}

List<_FrameRange> _buildRanges(List<bool> flags) {
  if (flags.isEmpty) {
    return const [];
  }

  final ranges = <_FrameRange>[];
  var startFrame = 0;
  var current = flags[0];

  for (var i = 1; i < flags.length; i++) {
    if (flags[i] == current) {
      continue;
    }
    ranges.add(
      _FrameRange(startFrame: startFrame, endFrame: i, isSilent: current),
    );
    startFrame = i;
    current = flags[i];
  }

  ranges.add(
    _FrameRange(
      startFrame: startFrame,
      endFrame: flags.length,
      isSilent: current,
    ),
  );
  return ranges;
}

List<bool> _normalizeFlags(List<bool> flags, SilenceDetectionConfig config) {
  if (flags.isEmpty) {
    return flags;
  }

  final normalized = List<bool>.from(flags);
  final frameSec = _frameDurationSec(config);
  final minSilenceSec = config.minSilenceMs / 1000;
  final noiseBurstSec = config.noiseBurstMs / 1000;

  for (final range in _buildRanges(normalized)) {
    if (range.isSilent &&
        _rangeDurationSec(range, frameSec) + _epsilon < minSilenceSec) {
      normalized.fillRange(range.startFrame, range.endFrame, false);
    }
  }

  for (final range in _buildRanges(normalized)) {
    if (!range.isSilent &&
        _rangeDurationSec(range, frameSec) + _epsilon < noiseBurstSec) {
      final prev = range.startFrame > 0
          ? normalized[range.startFrame - 1]
          : null;
      final next = range.endFrame < normalized.length
          ? normalized[range.endFrame]
          : null;
      if (prev == true && next == true) {
        normalized.fillRange(range.startFrame, range.endFrame, true);
      }
    }
  }

  for (final range in _buildRanges(normalized)) {
    if (range.isSilent &&
        _rangeDurationSec(range, frameSec) + _epsilon < minSilenceSec) {
      normalized.fillRange(range.startFrame, range.endFrame, false);
    }
  }

  return normalized;
}

SilenceInterval? _pickLongestCenteredSilence(
  List<SilenceInterval> ranges,
  double candidateStart,
  double candidateEnd,
) {
  final center = _midpoint(candidateStart, candidateEnd);
  SilenceInterval? best;
  var bestDuration = -1.0;
  var bestCenterDistance = double.infinity;

  for (final range in ranges) {
    final startTime = math.max(candidateStart, range.startTime);
    final endTime = math.min(candidateEnd, range.endTime);
    final duration = endTime - startTime;
    if (duration <= 0) {
      continue;
    }

    final distance = (_midpoint(startTime, endTime) - center).abs();
    if (duration > bestDuration + _epsilon ||
        ((duration - bestDuration).abs() <= _epsilon &&
            distance < bestCenterDistance - _epsilon)) {
      best = SilenceInterval(startTime: startTime, endTime: endTime);
      bestDuration = duration;
      bestCenterDistance = distance;
    }
  }

  return best;
}

List<SilenceInterval> _toSilenceIntervals(
  List<_FrameRange> ranges,
  double candidateStart,
  double candidateEnd,
  double frameSec,
) {
  return ranges
      .where((range) => range.isSilent)
      .map((range) {
        return SilenceInterval(
          startTime: candidateStart + range.startFrame * frameSec,
          endTime: math.min(
            candidateEnd,
            candidateStart + range.endFrame * frameSec,
          ),
        );
      })
      .where((range) => range.endTime - range.startTime > _epsilon)
      .toList();
}

SilenceInterval? _findContainingSilence(
  List<SilenceInterval> ranges,
  double time,
) {
  for (final range in ranges) {
    if (range.startTime - _epsilon <= time &&
        time <= range.endTime + _epsilon) {
      return range;
    }
  }
  return null;
}

SilenceInterval _expandCandidateInterval(
  List<SilenceInterval> ranges,
  double candidateStart,
  double candidateEnd,
) {
  final startRange = _findContainingSilence(ranges, candidateStart);
  final endRange = _findContainingSilence(ranges, candidateEnd);

  return SilenceInterval(
    startTime: startRange == null
        ? candidateStart
        : math.min(startRange.startTime, candidateStart),
    endTime: endRange == null
        ? candidateEnd
        : math.max(endRange.endTime, candidateEnd),
  );
}

/// 固定阈值静音检测。
///
/// 直接在解码后的单声道 PCM 上做逐窗 RMS 计算。
class FixedThresholdSilenceStrategy implements SilenceDetectionStrategy {
  const FixedThresholdSilenceStrategy();

  @override
  List<SilenceInterval> detectSilenceIntervals(
    DecodedAudioData audioData,
    double candidateStart,
    double candidateEnd,
    SilenceDetectionConfig config,
  ) {
    if (candidateEnd - candidateStart <= _epsilon) {
      return const [];
    }

    final frameSec = _frameDurationSec(config);
    final totalFrames = math.max(
      1,
      ((candidateEnd - candidateStart) / frameSec).ceil(),
    );
    final sampleRate = audioData.sampleRate;
    final samples = audioData.samples;
    final silentFrames = List<bool>.filled(totalFrames, false);

    for (var frame = 0; frame < totalFrames; frame++) {
      final frameStartTime = candidateStart + frame * frameSec;
      final frameEndTime = math.min(candidateEnd, frameStartTime + frameSec);
      final startSample = _clampInt(
        (frameStartTime * sampleRate).floor(),
        0,
        samples.length,
      );
      final endSample = _clampInt(
        (frameEndTime * sampleRate).ceil(),
        startSample + 1,
        samples.length,
      );

      var sumSquares = 0.0;
      for (var sample = startSample; sample < endSample; sample++) {
        final mixed = samples[sample];
        sumSquares += mixed * mixed;
      }

      final count = math.max(1, endSample - startSample);
      final rms = math.sqrt(sumSquares / count);
      silentFrames[frame] = _toDbfs(rms) <= config.thresholdDb;
    }

    final normalized = _normalizeFlags(silentFrames, config);
    return _toSilenceIntervals(
      _buildRanges(normalized),
      candidateStart,
      candidateEnd,
      frameSec,
    );
  }

  @override
  SilenceInterval? detectLongestSilence(
    DecodedAudioData audioData,
    double candidateStart,
    double candidateEnd,
    SilenceDetectionConfig config,
  ) {
    return _pickLongestCenteredSilence(
      detectSilenceIntervals(audioData, candidateStart, candidateEnd, config),
      candidateStart,
      candidateEnd,
    );
  }
}

double _resolveBoundary(
  double originalValue,
  SilenceInterval candidate,
  SilenceInterval? silence,
  bool isStartEdge,
  AutoAlignConfig config,
  bool splitShortCandidate,
) {
  final candidateDurationMs = (candidate.endTime - candidate.startTime) * 1000;
  if (splitShortCandidate &&
      candidateDurationMs + _epsilon < config.shortSilenceSplitMs) {
    return _midpoint(candidate.startTime, candidate.endTime);
  }

  if (silence == null) {
    return originalValue;
  }

  final silenceDurationMs = (silence.endTime - silence.startTime) * 1000;
  if (silenceDurationMs + _epsilon < config.shortSilenceSplitMs) {
    return _midpoint(silence.startTime, silence.endTime);
  }

  final paddingSec = config.paddingMs / 1000;
  return isStartEdge
      ? silence.endTime - paddingSec
      : silence.startTime + paddingSec;
}

List<SentenceBoundaryUpdate> _computeAutoAlignedSentenceBoundaries({
  required List<TranscriptSentence> sentences,
  required List<WordTimestamp> words,
  required DecodedAudioData audioData,
  SilenceDetectionStrategy strategy = const FixedThresholdSilenceStrategy(),
  AutoAlignConfig config = defaultAutoAlignConfig,
}) {
  if (sentences.isEmpty) {
    return const [];
  }

  final duration = audioData.samples.length / audioData.sampleRate;
  final allSilenceRanges = strategy.detectSilenceIntervals(
    audioData,
    0,
    duration,
    config,
  );
  AppLogger.log(
    _logTag,
    'detect silence done: duration=${_fmtSec(duration)}s, intervals=${allSilenceRanges.length}',
  );
  final nextBoundaries = <SentenceBoundaryUpdate>[
    for (var i = 0; i < sentences.length; i++)
      SentenceBoundaryUpdate(
        sentenceIndex: i,
        startTime: sentences[i].startTime.inMilliseconds / 1000,
        endTime: sentences[i].endTime.inMilliseconds / 1000,
      ),
  ];
  final originals = <SentenceBoundaryUpdate>[
    for (var i = 0; i < sentences.length; i++)
      SentenceBoundaryUpdate(
        sentenceIndex: i,
        startTime: sentences[i].startTime.inMilliseconds / 1000,
        endTime: sentences[i].endTime.inMilliseconds / 1000,
      ),
  ];

  final first = sentences.first;
  final firstCandidate = _expandCandidateInterval(
    allSilenceRanges,
    0,
    _clampDouble(first.startTime.inMilliseconds / 1000, 0, duration),
  );
  final startSilence = strategy.detectLongestSilence(
    audioData,
    firstCandidate.startTime,
    firstCandidate.endTime,
    config,
  );
  AppLogger.log(
    _logTag,
    'sentence start candidate: sentence=0 range=${_describeSilence(firstCandidate)} chosen=${_describeSilence(startSilence)}',
  );
  nextBoundaries[0] = SentenceBoundaryUpdate(
    sentenceIndex: 0,
    startTime: _resolveBoundary(
      first.startTime.inMilliseconds / 1000,
      firstCandidate,
      startSilence,
      true,
      config,
      false,
    ),
    endTime: nextBoundaries[0].endTime,
  );

  for (var i = 0; i < sentences.length - 1; i++) {
    final current = sentences[i];
    final next = sentences[i + 1];
    final candidate = _expandCandidateInterval(
      allSilenceRanges,
      _clampDouble(current.endTime.inMilliseconds / 1000, 0, duration),
      _clampDouble(next.startTime.inMilliseconds / 1000, 0, duration),
    );
    final silence = strategy.detectLongestSilence(
      audioData,
      candidate.startTime,
      candidate.endTime,
      config,
    );
    AppLogger.log(
      _logTag,
      'sentence boundary candidate: left=$i right=${i + 1} range=${_describeSilence(candidate)} chosen=${_describeSilence(silence)}',
    );
    nextBoundaries[i] = SentenceBoundaryUpdate(
      sentenceIndex: i,
      startTime: nextBoundaries[i].startTime,
      endTime: _resolveBoundary(
        current.endTime.inMilliseconds / 1000,
        candidate,
        silence,
        false,
        config,
        true,
      ),
    );
    nextBoundaries[i + 1] = SentenceBoundaryUpdate(
      sentenceIndex: i + 1,
      startTime: _resolveBoundary(
        next.startTime.inMilliseconds / 1000,
        candidate,
        silence,
        true,
        config,
        true,
      ),
      endTime: nextBoundaries[i + 1].endTime,
    );
  }

  final lastIndex = sentences.length - 1;
  final last = sentences[lastIndex];
  final lastCandidate = _expandCandidateInterval(
    allSilenceRanges,
    _clampDouble(last.endTime.inMilliseconds / 1000, 0, duration),
    duration,
  );
  final endSilence = strategy.detectLongestSilence(
    audioData,
    lastCandidate.startTime,
    lastCandidate.endTime,
    config,
  );
  AppLogger.log(
    _logTag,
    'sentence end candidate: sentence=$lastIndex range=${_describeSilence(lastCandidate)} chosen=${_describeSilence(endSilence)}',
  );
  nextBoundaries[lastIndex] = SentenceBoundaryUpdate(
    sentenceIndex: lastIndex,
    startTime: nextBoundaries[lastIndex].startTime,
    endTime: _resolveBoundary(
      last.endTime.inMilliseconds / 1000,
      lastCandidate,
      endSilence,
      false,
      config,
      false,
    ),
  );

  for (var i = 0; i < nextBoundaries.length; i++) {
    final boundary = nextBoundaries[i];
    final original = originals[i];
    var startTime = _clampDouble(boundary.startTime, 0, duration);
    var endTime = _clampDouble(boundary.endTime, 0, duration);
    if (startTime > endTime + _epsilon) {
      startTime = original.startTime;
      endTime = original.endTime;
    }
    nextBoundaries[i] = SentenceBoundaryUpdate(
      sentenceIndex: boundary.sentenceIndex,
      startTime: startTime,
      endTime: endTime,
    );
  }

  for (var i = 0; i < nextBoundaries.length - 1; i++) {
    final current = nextBoundaries[i];
    final next = nextBoundaries[i + 1];
    if (current.endTime <= next.startTime + _epsilon) {
      continue;
    }
    nextBoundaries[i] = SentenceBoundaryUpdate(
      sentenceIndex: current.sentenceIndex,
      startTime: current.startTime,
      endTime: originals[i].endTime,
    );
    nextBoundaries[i + 1] = SentenceBoundaryUpdate(
      sentenceIndex: next.sentenceIndex,
      startTime: originals[i + 1].startTime,
      endTime: next.endTime,
    );
  }

  for (var i = 0; i < nextBoundaries.length; i++) {
    final boundary = nextBoundaries[i];
    final original = originals[i];
    if (boundary.startTime > boundary.endTime + _epsilon) {
      nextBoundaries[i] = original;
    }
  }

  // 保守保证边界词仍然存在非负时长，避免把句边界推到词内部之外。
  for (var i = 0; i < nextBoundaries.length; i++) {
    final boundary = nextBoundaries[i];
    final sentence = sentences[boundary.sentenceIndex];
    final startWordIndex = sentence.startWordIndex;
    final endWordIndex = sentence.endWordIndex;
    if (startWordIndex == null ||
        endWordIndex == null ||
        startWordIndex < 0 ||
        endWordIndex >= words.length) {
      continue;
    }
    final firstWord = words[startWordIndex];
    final lastWord = words[endWordIndex];
    var startTime = boundary.startTime;
    var endTime = boundary.endTime;
    final original = originals[i];
    if (startTime > firstWord.endTime.inMilliseconds / 1000 + _epsilon) {
      startTime = original.startTime;
    }
    if (endTime + _epsilon < lastWord.startTime.inMilliseconds / 1000) {
      endTime = original.endTime;
    }
    if (startTime > endTime + _epsilon) {
      startTime = original.startTime;
      endTime = original.endTime;
    }
    nextBoundaries[i] = SentenceBoundaryUpdate(
      sentenceIndex: boundary.sentenceIndex,
      startTime: startTime,
      endTime: endTime,
    );
  }

  return nextBoundaries;
}

/// 自动校准服务。
class SubtitleAutoAlignService {
  final NativeAudioDecoder _decoder;
  final Duration Function(Duration estimatedAudioDuration) _timeoutForDuration;

  SubtitleAutoAlignService({
    required NativeAudioDecoder decoder,
    Duration Function(Duration estimatedAudioDuration)? timeoutForDuration,
  }) : _decoder = decoder,
       _timeoutForDuration =
           timeoutForDuration ??
           SubtitleAutoAlignService.defaultTimeoutForAudio;

  static Duration defaultTimeoutForAudio(Duration estimatedAudioDuration) {
    final seconds = estimatedAudioDuration.inMilliseconds / 1000;
    final timeoutSeconds = math.min(20.0, math.max(3.0, 3.0 + seconds * 0.08));
    return Duration(milliseconds: (timeoutSeconds * 1000).round());
  }

  /// 尝试使用本地音频静音区间校准句子边界。
  ///
  /// 任意阶段失败都只记录日志并返回原始 [sentences]。
  Future<List<TranscriptSentence>> alignIfPossible({
    required String audioPath,
    required List<TranscriptSentence> sentences,
    required List<WordTimestamp> words,
  }) async {
    AppLogger.log(
      _logTag,
      'start auto-align: audioPath=$audioPath sentences=${sentences.length} words=${words.length}',
    );
    if (sentences.isEmpty || words.isEmpty) {
      AppLogger.log(
        _logTag,
        'skip auto-align: empty transcript sentences=${sentences.length} words=${words.length}',
      );
      return sentences;
    }
    if (!_decoder.isSupported) {
      AppLogger.log(
        _logTag,
        'skip auto-align: native decode unsupported on current platform',
      );
      return sentences;
    }
    if (!_hasUsableWordBoundaries(sentences, words.length)) {
      AppLogger.log(
        _logTag,
        'skip auto-align: transcript is missing usable word boundaries',
      );
      return sentences;
    }

    final estimatedAudioDuration = _estimateAudioDuration(sentences, words);
    final timeout = _timeoutForDuration(estimatedAudioDuration);
    AppLogger.log(
      _logTag,
      'auto-align timeout budget: estimatedAudio=${estimatedAudioDuration.inMilliseconds}ms timeout=${timeout.inMilliseconds}ms',
    );

    for (var i = 0; i < sentences.length; i++) {
      AppLogger.log(
        _logTag,
        'input sentence ${_describeSentence(i, sentences[i])}',
      );
    }

    try {
      return await _runAutoAlign(
        audioPath: audioPath,
        sentences: sentences,
        words: words,
      ).timeout(
        timeout,
        onTimeout: () {
          AppLogger.log(
            _logTag,
            'skip auto-align: timed out after ${timeout.inMilliseconds}ms',
          );
          return sentences;
        },
      );
    } catch (error) {
      AppLogger.log(
        _logTag,
        'skip auto-align: native decode or alignment failed ($error)',
      );
      return sentences;
    }
  }

  Future<List<TranscriptSentence>> _runAutoAlign({
    required String audioPath,
    required List<TranscriptSentence> sentences,
    required List<WordTimestamp> words,
  }) async {
    AppLogger.log(_logTag, 'decode start: $audioPath');
    final decoded = await _decoder.decode(audioPath);
    if (decoded == null || decoded.samples.isEmpty || decoded.sampleRate <= 0) {
      AppLogger.log(
        _logTag,
        'skip auto-align: native decoder returned no samples',
      );
      return sentences;
    }
    final durationSec = decoded.samples.length / decoded.sampleRate;
    AppLogger.log(
      _logTag,
      'decode success: sampleRate=${decoded.sampleRate} samples=${decoded.samples.length} duration=${_fmtSec(durationSec)}s',
    );

    final updates = _computeAutoAlignedSentenceBoundaries(
      sentences: sentences,
      words: words,
      audioData: decoded,
    );
    if (updates.isEmpty) {
      AppLogger.log(_logTag, 'no boundary updates generated');
      return sentences;
    }
    for (final update in updates) {
      AppLogger.log(
        _logTag,
        'computed boundary ${_describeBoundaryUpdate(update)}',
      );
    }
    final aligned = _applyUpdates(sentences, updates);
    for (var i = 0; i < aligned.length; i++) {
      final before = sentences[i];
      final after = aligned[i];
      AppLogger.log(
        _logTag,
        'apply sentence #$i: ${_fmtSec(before.startTime.inMilliseconds / 1000)}-${_fmtSec(before.endTime.inMilliseconds / 1000)}'
        ' -> ${_fmtSec(after.startTime.inMilliseconds / 1000)}-${_fmtSec(after.endTime.inMilliseconds / 1000)}',
      );
    }
    AppLogger.log(_logTag, 'auto-align done: updated=${updates.length}');
    return aligned;
  }

  Duration _estimateAudioDuration(
    List<TranscriptSentence> sentences,
    List<WordTimestamp> words,
  ) {
    var maxMs = 0;
    for (final sentence in sentences) {
      if (sentence.endTime.inMilliseconds > maxMs) {
        maxMs = sentence.endTime.inMilliseconds;
      }
    }
    for (final word in words) {
      if (word.endTime.inMilliseconds > maxMs) {
        maxMs = word.endTime.inMilliseconds;
      }
    }
    return Duration(milliseconds: math.max(1000, maxMs));
  }

  bool _hasUsableWordBoundaries(
    List<TranscriptSentence> sentences,
    int wordsLength,
  ) {
    for (final sentence in sentences) {
      final startWordIndex = sentence.startWordIndex;
      final endWordIndex = sentence.endWordIndex;
      if (startWordIndex == null ||
          endWordIndex == null ||
          startWordIndex < 0 ||
          endWordIndex < startWordIndex ||
          endWordIndex >= wordsLength) {
        return false;
      }
    }
    return true;
  }

  List<TranscriptSentence> _applyUpdates(
    List<TranscriptSentence> sentences,
    List<SentenceBoundaryUpdate> updates,
  ) {
    final updateByIndex = {
      for (final update in updates) update.sentenceIndex: update,
    };
    return [
      for (var i = 0; i < sentences.length; i++)
        if (updateByIndex.containsKey(i))
          TranscriptSentence(
            text: sentences[i].text,
            startTime: Duration(
              milliseconds: (updateByIndex[i]!.startTime * 1000).round(),
            ),
            endTime: Duration(
              milliseconds: (updateByIndex[i]!.endTime * 1000).round(),
            ),
            startWordIndex: sentences[i].startWordIndex,
            endWordIndex: sentences[i].endWordIndex,
          )
        else
          sentences[i],
    ];
  }
}

/// 自动校准服务 Provider。
final subtitleAutoAlignServiceProvider = Provider<SubtitleAutoAlignService>(
  (ref) =>
      SubtitleAutoAlignService(decoder: ref.read(nativeAudioDecoderProvider)),
);
