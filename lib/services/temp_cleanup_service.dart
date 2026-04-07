/// 临时目录清理服务。
///
/// 录音 .caf 文件、导出/导入临时目录等在 app 非正常退出时可能残留，
/// 提供统一的清理入口供启动时和手动清缓存时调用。
///
/// iOS/macOS 原生录音用 `NSTemporaryDirectory()`（沙盒根/tmp/），
/// 而 Flutter `getTemporaryDirectory()` 返回 `Library/Caches`（不同目录）。
/// Android 不支持录音功能，无 .caf 文件，tmp/ 不存在时自动跳过。
library;

import 'dart:io';

import 'package:path_provider/path_provider.dart';

import '../utils/file_size.dart';
import 'app_logger.dart';

/// 清理结果。
class CleanupResult {
  const CleanupResult({required this.freedBytes});

  /// 释放的字节数。
  final int freedBytes;
}

/// 启动时清理：只清沙盒根/tmp/ 中超过 [minAge] 的文件。
///
/// 不清 Library/Caches（避免误删其他插件缓存）。
/// [minAge] 默认 60 秒，防止极端情况下删掉刚创建的录音文件。
Future<CleanupResult> cleanupRecordingTempFiles({
  Duration minAge = const Duration(seconds: 60),
}) async {
  final nsTmpDir = await _getNsTmpDir();
  if (nsTmpDir == null) return const CleanupResult(freedBytes: 0);
  return _cleanupDirectory(nsTmpDir, minAge: minAge);
}

/// 设置页「清除缓存」：全量清理 tmp/ + Library/Caches。
Future<CleanupResult> cleanupAllTempFiles() async {
  var totalBytes = 0;
  final dirs = <Directory>[];

  final nsTmpDir = await _getNsTmpDir();
  if (nsTmpDir != null) dirs.add(nsTmpDir);

  try {
    dirs.add(await getTemporaryDirectory());
  } catch (_) {}

  for (final dir in dirs) {
    final result = await _cleanupDirectory(dir);
    totalBytes += result.freedBytes;
  }
  return CleanupResult(freedBytes: totalBytes);
}

/// 获取沙盒根/tmp/ 目录（iOS/macOS），不存在时返回 null。
Future<Directory?> _getNsTmpDir() async {
  try {
    final docsDir = await getApplicationDocumentsDirectory();
    final dir = Directory('${docsDir.parent.path}/tmp');
    if (await dir.exists()) return dir;
  } catch (_) {}
  return null;
}

/// 清理指定目录中的文件，可选按文件年龄过滤。
Future<CleanupResult> _cleanupDirectory(
  Directory dir, {
  Duration? minAge,
}) async {
  var totalBytes = 0;
  var deletedCount = 0;
  var failedCount = 0;
  final now = DateTime.now();

  try {
    AppLogger.log('TempCleanup', 'Scanning ${dir.path}');
    await for (final entity in dir.list()) {
      try {
        // 按年龄过滤：跳过修改时间不足 minAge 的文件
        if (minAge != null) {
          final stat = await entity.stat();
          if (now.difference(stat.modified) < minAge) continue;
        }

        if (entity is File) {
          totalBytes += await entity.length();
        } else if (entity is Directory) {
          totalBytes += await calculateDirectorySize(entity);
        }
        await entity.delete(recursive: true);
        deletedCount++;
      } catch (e) {
        failedCount++;
        AppLogger.log('TempCleanup', 'Failed: ${entity.path}: $e');
      }
    }
    AppLogger.log(
      'TempCleanup',
      'Done: deleted=$deletedCount, failed=$failedCount, '
          'freed=${formatBytes(totalBytes)}',
    );
  } catch (e) {
    AppLogger.log('TempCleanup', 'Error: $e');
  }
  return CleanupResult(freedBytes: totalBytes);
}
