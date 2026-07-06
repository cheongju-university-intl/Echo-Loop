/// 客户端平台/版本标识（AI 请求公共 header）测试。
///
/// 覆盖：平台名合法性、headers 组装（版本缺省时省略）、API client 构造时
/// 已把标识写入 Dio 公共 headers；Linux 等未知测试宿主按 fail-open 省略平台标识。
library;

import 'dart:io' show Platform;

import 'package:echo_loop/services/client_info.dart';
import 'package:echo_loop/services/sentence_ai_api_client.dart';
import 'package:echo_loop/services/transcription_api_client.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  // 真实构造函数会挂 GeoInterceptor（内部取 SharedPreferences），需 mock 初始化。
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('clientPlatformName', () {
    test('返回后端约定的合法平台名（与 normalizePlatform 集合一致）', () {
      final name = clientPlatformName();
      expect(['ios', 'macos', 'android', 'windows', ''], contains(name));
      // 测试宿主即本机平台，校验映射正确；Linux CI 为未知平台，返回空串。
      if (Platform.isMacOS) expect(name, 'macos');
      if (Platform.isLinux) expect(name, isEmpty);
    });
  });

  group('clientInfoHeaders', () {
    test('支持的平台携带平台标识；给定版本时携带版本', () {
      final headers = clientInfoHeaders(appVersion: '1.2.3');
      final platform = clientPlatformName();
      if (platform.isEmpty) {
        expect(headers.containsKey(kAppPlatformHeader), isFalse);
      } else {
        expect(headers[kAppPlatformHeader], platform);
      }
      expect(headers[kAppVersionHeader], '1.2.3');
    });

    test('版本为 null/空串时省略版本 header（降级不阻断）', () {
      expect(clientInfoHeaders().containsKey(kAppVersionHeader), isFalse);
      expect(
        clientInfoHeaders(appVersion: '').containsKey(kAppVersionHeader),
        isFalse,
      );
    });
  });

  group('API client 公共 headers', () {
    test('SentenceAiApiClient 携带平台与版本标识', () {
      final client = SentenceAiApiClient(
        baseUrl: 'https://example.com',
        appVersion: '9.9.9',
      );
      final platform = clientPlatformName();
      if (platform.isEmpty) {
        expect(client.defaultHeaders.containsKey(kAppPlatformHeader), isFalse);
      } else {
        expect(client.defaultHeaders[kAppPlatformHeader], platform);
      }
      expect(client.defaultHeaders[kAppVersionHeader], '9.9.9');
      client.dispose();
    });

    test('TranscriptionApiClient 携带平台与版本标识', () {
      final client = TranscriptionApiClient(
        baseUrl: 'https://example.com',
        appVersion: '9.9.9',
      );
      final platform = clientPlatformName();
      if (platform.isEmpty) {
        expect(client.defaultHeaders.containsKey(kAppPlatformHeader), isFalse);
      } else {
        expect(client.defaultHeaders[kAppPlatformHeader], platform);
      }
      expect(client.defaultHeaders[kAppVersionHeader], '9.9.9');
      client.dispose();
    });

    test('未传版本时不带版本 header，平台标识仍在', () {
      final client = SentenceAiApiClient(baseUrl: 'https://example.com');
      final platform = clientPlatformName();
      if (platform.isEmpty) {
        expect(client.defaultHeaders.containsKey(kAppPlatformHeader), isFalse);
      } else {
        expect(client.defaultHeaders[kAppPlatformHeader], platform);
      }
      expect(client.defaultHeaders.containsKey(kAppVersionHeader), isFalse);
      client.dispose();
    });
  });
}
