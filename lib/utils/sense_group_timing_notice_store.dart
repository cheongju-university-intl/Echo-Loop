import 'package:shared_preferences/shared_preferences.dart';

/// 意群推测时间提示的本地持久化状态。
///
/// 用户上传字幕生成的词级时间戳是根据字幕片段和词长推测的；播放这类意群前
/// 只提醒一次，避免把 SharedPreferences key 散落在 UI 交互代码中。
class SenseGroupTimingNoticeStore {
  SenseGroupTimingNoticeStore(this._prefs);

  static const String syntheticTimingNoticeSeenKey =
      'sense_group_synthetic_timing_notice_seen';

  final SharedPreferences _prefs;

  /// 是否已经向用户提示过上传字幕的意群播放时间可能不准。
  bool get hasSeenSyntheticTimingNotice =>
      _prefs.getBool(syntheticTimingNoticeSeenKey) ?? false;

  /// 标记上传字幕的意群播放时间提示已展示。
  Future<void> markSyntheticTimingNoticeSeen() {
    return _prefs.setBool(syntheticTimingNoticeSeenKey, true);
  }
}
