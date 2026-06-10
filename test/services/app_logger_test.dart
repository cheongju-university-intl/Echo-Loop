/// AppLogger 落盘日志测试。
///
/// 验证：开启落盘后每条日志同步写入文件、可读回；超限时只保留尾部。
/// 落盘是排查 native 崩溃（崩溃前内存缓冲丢失）的关键，需保证可靠。
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:echo_loop/services/app_logger.dart';

void main() {
  late Directory tempDir;
  late String logPath;

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('app_logger_test');
    logPath = '${tempDir.path}/app.log';
  });

  tearDown(() {
    if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
  });

  test('开启落盘后日志写入文件并可读回', () async {
    await AppLogger.initFileSink(logPath);
    AppLogger.log('Test', 'hello world');

    final persisted = await AppLogger.readPersistedLog();
    expect(persisted, isNotNull);
    expect(persisted, contains('[Test] hello world'));
    // 文件内容应与读回一致。
    expect(File(logPath).readAsStringSync(), contains('hello world'));
  });

  test('formatLine 输出 HH:MM:SS.mmm [tag] message 格式', () {
    final line = AppLogger.formatLine(
      DateTime(2026, 6, 10, 9, 8, 7, 123),
      'ASREngine',
      'decode done',
    );
    expect(line, '09:08:07.123 [ASREngine] decode done');
  });

  test('超过上限时启动只保留尾部', () async {
    // 预置一个超大日志文件（> 512KB）。
    final big = StringBuffer();
    for (var i = 0; i < 60000; i++) {
      big.writeln('11:11:11.111 [Old] line $i');
    }
    File(logPath).writeAsStringSync(big.toString());
    expect(File(logPath).lengthSync(), greaterThan(512 * 1024));

    await AppLogger.initFileSink(logPath);

    final after = File(logPath).readAsStringSync();
    expect(after.length, lessThan(512 * 1024));
    expect(after, startsWith('--- 日志已截断，保留尾部 ---'));
    // 截断后应保留最近的行，丢弃最早的行。
    expect(after, contains('line 59999'));
    expect(after, isNot(contains('line 0\n')));
  });
}
