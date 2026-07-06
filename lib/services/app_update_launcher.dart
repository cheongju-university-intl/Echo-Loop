/// App 更新启动器。
///
/// 所有渠道都通过外部 URL 更新：Google Play 渠道打开应用商店，
/// APK 渠道打开 APK 直链。保持更新流程简单可控。
library;

import 'package:url_launcher/url_launcher.dart';

import '../models/app_update_info.dart';

class AppUpdateLauncher {
  const AppUpdateLauncher();

  Future<void> launch({
    required AppUpdateInfo info,
    required String? primaryUrl,
  }) async {
    if (primaryUrl == null || primaryUrl.isEmpty) return;
    final opened = await _tryLaunch(primaryUrl);
    if (!opened && info.channel == AppUpdateChannel.androidGooglePlay) {
      // 商店链接（market://）打不开时回退到 https 商店页：优先渠道配置，
      // 缺失则用顶层 fallback（_googlePlayDownloadUrl 写入的默认 Play 网页链接）。
      final fallback =
          info.platforms.android.googlePlay.fallbackUrl ??
          info.downloadUrl['fallback'];
      await _tryLaunch(fallback);
    }
  }

  Future<bool> _tryLaunch(String? url) async {
    if (url == null || url.isEmpty) return false;
    try {
      return launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    } catch (_) {
      return false;
    }
  }
}
