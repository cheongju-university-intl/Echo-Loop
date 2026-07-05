import '../../analytics/models/event_names.dart';

/// App 内使用统计事件。
///
/// 这里的事件同时服务于本地计数和远端 analytics 上报。新增事件时必须明确
/// 对应的远端事件名和本地计数字段，避免业务入口散写字符串。
enum UsageEvent {
  audioUpload(Events.audioUpload),
  subtitleUploaded(Events.subtitleUploaded),
  aiTranscriptionStarted(Events.transcriptionStarted),
  aiTranscriptionCompleted(Events.transcriptionComplete),
  subStageCompleted(Events.stageAdvance),
  translationTapped(Events.translationRequested),
  analysisTapped(Events.analysisRequested),
  senseGroupTapped(Events.senseGroupRequested),
  translationSucceeded(Events.translationSucceeded),
  analysisSucceeded(Events.analysisSucceeded),
  senseGroupSucceeded(Events.senseGroupSucceeded),
  aiWordAnalysisSucceeded(Events.wordAnalysisSucceeded),
  bookmarkSentenceReviewCompleted(Events.bookmarkReviewComplete),
  flashcardReviewCompleted(Events.flashcardComplete),
  bookmarkSentenceSaved(Events.bookmarkToggle),
  wordSaved(Events.wordSave),
  recordingCompleted(Events.recordingComplete),
  studyTaskTapped(Events.studyTaskTapped),
  firstLearnCompleted(Events.firstLearnComplete),
  bookmarkReviewButtonTapped(Events.bookmarkReviewButtonTapped),
  flashcardButtonTapped(Events.flashcardButtonTapped);

  const UsageEvent(this.analyticsName);

  /// 远端 analytics 事件名。
  final String analyticsName;
}
