import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../database/providers.dart';
import '../services/learned_vocabulary_tracker.dart';

/// 已学习词形追踪器 Provider
///
/// 统一管理异步批量写库和统计刷新。
final learnedVocabularyTrackerProvider = Provider<LearnedVocabularyTracker>((
  ref,
) {
  final dao = ref.watch(learnedWordFormDaoProvider);
  final tracker = LearnedVocabularyTracker(
    persistWordForms: dao.insertIfAbsentAll,
    // 不在 flush 时刷新统计：学习期间 flush 频繁（~400ms），会触发不可见的
    // StudyScreen 重建（柱状图等）。统计在 session 结束时由
    // LearningSessionNotifier.endSession / BookmarkReviewNotifier 统一刷新。
    onStatsUpdated: () {},
    onError: (error, stackTrace) {
      debugPrint('LearnedVocabularyTracker flush failed: $error\n$stackTrace');
    },
  );

  ref.onDispose(() {
    unawaited(tracker.dispose());
  });

  return tracker;
});
