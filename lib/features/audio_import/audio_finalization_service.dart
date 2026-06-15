import 'package:path/path.dart' as p;
import 'package:universal_io/io.dart';

import '../../utils/audio_fingerprint.dart';
import 'audio_import_models.dart';
import 'audio_transcode_service.dart';

/// 音频落盘结果。
///
/// [relativePath] 正式音频相对数据目录的路径；[sha256] 为转码/回退后内容指纹，
/// 用作稳定文件名；[originalSha256] 为转码前原始音频指纹（供 AI 转录缓存复用）；
/// [created] 表示是否新写入文件（false 表示命中同指纹已有文件、直接复用）。
class FinalizedAudio {
  const FinalizedAudio({
    required this.relativePath,
    required this.sha256,
    required this.originalSha256,
    required this.created,
  });

  final String relativePath;
  final String sha256;
  final String originalSha256;
  final bool created;
}

/// 临时音频统一转码 + 按内容指纹落盘的共享流程。
///
/// 链接下载（[AudioImportService]）和本地导入（添加音频对话框）都走这里，
/// 保证转码策略、指纹复用、临时文件清理三处一致，避免重复实现产生分叉。
class AudioFinalizationService {
  AudioFinalizationService({
    AudioTranscodeService? transcodeService,
    Future<String> Function(String absolutePath)? computeSha256,
  }) : _transcodeService = transcodeService ?? AudioTranscodeService(),
       _computeSha256 = computeSha256 ?? computeAudioSha256;

  final AudioTranscodeService _transcodeService;
  final Future<String> Function(String absolutePath) _computeSha256;

  /// 转码 [tempRelativePath] 指向的临时音频，按转码后指纹落盘到 [targetSubdir]。
  ///
  /// [dataDir] 应用数据根目录；[tempRelativePath] / [targetSubdir] 均相对它，
  /// 例如 `tmp/audio_import/xxx.mp3` 与 `audios/imported`。同指纹文件已存在时复用
  /// 现有文件、删除本次临时产物；无论成功失败都会清理原始临时文件。
  Future<FinalizedAudio> finalize({
    required Directory dataDir,
    required String tempRelativePath,
    required String targetSubdir,
  }) async {
    final targetDir = Directory(p.join(dataDir.path, targetSubdir));
    await targetDir.create(recursive: true);

    final originalFile = File(p.join(dataDir.path, tempRelativePath));
    final originalSha256 = await _fingerprint(originalFile);

    final transcodeResult = await _transcodeService.transcodeToM4a(
      dataDir: dataDir,
      relativePath: tempRelativePath,
    );
    final sourceFile = File(p.join(dataDir.path, transcodeResult.relativePath));
    final sha256 = await _fingerprint(sourceFile);
    final finalName = '$sha256${p.extension(sourceFile.path)}';
    final finalFile = File(p.join(targetDir.path, finalName));

    final created = !await finalFile.exists();
    if (created) {
      await _moveToFinal(sourceFile: sourceFile, finalFile: finalFile);
    } else {
      await _deleteIfExists(sourceFile);
    }
    // 转码成功时原始临时文件通常已被删除/移动，这里兜底清理回退或同名替换残留。
    await _deleteIfExists(originalFile);

    return FinalizedAudio(
      relativePath: p.join(targetSubdir, finalName),
      sha256: sha256,
      originalSha256: originalSha256,
      created: created,
    );
  }

  /// 计算指纹，失败统一抛存储类异常，便于上层归一处理。
  Future<String> _fingerprint(File file) async {
    try {
      return await _computeSha256(file.path);
    } catch (e) {
      throw AudioImportException(
        AudioImportFailureCode.storage,
        'Failed to fingerprint audio',
        e,
      );
    }
  }

  /// 移动到正式目录；跨卷 rename 失败时回退 copy，并清理半成品。
  Future<void> _moveToFinal({
    required File sourceFile,
    required File finalFile,
  }) async {
    try {
      await sourceFile.rename(finalFile.path);
      return;
    } on FileSystemException {
      try {
        await sourceFile.copy(finalFile.path);
        await _deleteIfExists(sourceFile);
        return;
      } on FileSystemException catch (e) {
        await _deleteIfExists(finalFile);
        throw AudioImportException(
          AudioImportFailureCode.storage,
          'Failed to save audio',
          e,
        );
      }
    }
  }

  Future<void> _deleteIfExists(File file) async {
    if (!await file.exists()) return;
    try {
      await file.delete();
    } catch (_) {}
  }
}
