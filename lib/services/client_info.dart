/// 客户端平台/版本标识（AI 请求公共 header）。
///
/// 后端按 `x-app-platform` 决定是否对该平台执行 AI 免费额度限制
/// （env `AI_QUOTA_ENFORCED_PLATFORMS` 平台列表，见 docs/subscription-setup.md）。
/// 老版本客户端不带此 header，后端一律放行（fail-open），因此 header 缺失
/// 不会误伤——但新代码必须始终带上，否则该平台无法灰度启用限额。
library;

import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb;

/// 平台标识 header 名（与后端约定，小写）。
const String kAppPlatformHeader = 'x-app-platform';

/// App 版本 header 名（为未来按版本灰度预留）。
const String kAppVersionHeader = 'x-app-version';

/// 当前平台名：`ios` / `macos` / `android` / `windows`，未知平台返回空串。
///
/// 与后端 `normalizePlatform` 的合法值集合一致（非法值后端视为未知、不限额）。
String clientPlatformName() {
  if (kIsWeb) return '';
  if (Platform.isIOS) return 'ios';
  if (Platform.isMacOS) return 'macos';
  if (Platform.isAndroid) return 'android';
  if (Platform.isWindows) return 'windows';
  return '';
}

/// AI API 请求的公共客户端标识 headers。
///
/// [appVersion] 为空/null 时省略版本 header（如测试环境拿不到 PackageInfo）。
Map<String, String> clientInfoHeaders({String? appVersion}) {
  final platform = clientPlatformName();
  return {
    if (platform.isNotEmpty) kAppPlatformHeader: platform,
    if (appVersion != null && appVersion.isNotEmpty)
      kAppVersionHeader: appVersion,
  };
}
