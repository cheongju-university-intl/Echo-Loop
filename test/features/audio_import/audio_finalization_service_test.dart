import 'dart:io';

import 'package:echo_loop/features/audio_import/audio_finalization_service.dart';
import 'package:echo_loop/features/audio_import/audio_transcode_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

/// 转码桩：成功时把扩展名换成 `.m4a`、复制内容并删除源文件；失败时原样返回。
class _FakeTranscodeService extends AudioTranscodeService {
  _FakeTranscodeService({required this.shouldTranscode});

  final bool shouldTranscode;

  @override
  Future<AudioTranscodeResult> transcodeToM4a({
    required Directory dataDir,
    required String relativePath,
  }) async {
    if (!shouldTranscode) {
      return AudioTranscodeResult(
        relativePath: relativePath,
        transcoded: false,
      );
    }
    final source = File(p.join(dataDir.path, relativePath));
    final targetRelativePath = relativePath.replaceAll(
      RegExp(r'\.[^.]+$'),
      '.m4a',
    );
    final target = File(p.join(dataDir.path, targetRelativePath));
    await target.create(recursive: true);
    await target.writeAsBytes(await source.readAsBytes());
    await source.delete();
    return AudioTranscodeResult(
      relativePath: targetRelativePath,
      transcoded: true,
    );
  }
}

void main() {
  group('AudioFinalizationService', () {
    late Directory tmpDir;

    setUp(() async {
      tmpDir = await Directory.systemTemp.createTemp('audio_finalize_test_');
      final importDir = Directory(p.join(tmpDir.path, 'tmp', 'audio_import'));
      await importDir.create(recursive: true);
    });

    tearDown(() async {
      if (await tmpDir.exists()) await tmpDir.delete(recursive: true);
    });

    Future<String> writeTemp(String name, List<int> bytes) async {
      final file = File(p.join(tmpDir.path, 'tmp', 'audio_import', name));
      await file.writeAsBytes(bytes);
      return p.join('tmp', 'audio_import', name);
    }

    test('转码成功：按转码后指纹落盘，原始/转码指纹分别返回，临时清理', () async {
      final service = AudioFinalizationService(
        transcodeService: _FakeTranscodeService(shouldTranscode: true),
        computeSha256: (path) async =>
            path.endsWith('.m4a') ? 'sha-final' : 'sha-original',
      );
      final temp = await writeTemp('a.mp3', [1, 2, 3]);

      final result = await service.finalize(
        dataDir: tmpDir,
        tempRelativePath: temp,
        targetSubdir: p.join('audios', 'imported'),
      );

      expect(
        result.relativePath,
        p.join('audios', 'imported', 'sha-final.m4a'),
      );
      expect(result.sha256, 'sha-final');
      expect(result.originalSha256, 'sha-original');
      expect(result.created, isTrue);
      expect(
        await File(p.join(tmpDir.path, result.relativePath)).exists(),
        isTrue,
      );
      expect(
        await Directory(
          p.join(tmpDir.path, 'tmp', 'audio_import'),
        ).list().toList(),
        isEmpty,
      );
    });

    test('转码失败：回退原始音频并按原始指纹落盘', () async {
      final service = AudioFinalizationService(
        transcodeService: _FakeTranscodeService(shouldTranscode: false),
        computeSha256: (_) async => 'sha-original',
      );
      final temp = await writeTemp('a.mp3', [4, 5, 6]);

      final result = await service.finalize(
        dataDir: tmpDir,
        tempRelativePath: temp,
        targetSubdir: 'audios',
      );

      expect(result.relativePath, p.join('audios', 'sha-original.mp3'));
      expect(result.sha256, 'sha-original');
      expect(result.originalSha256, 'sha-original');
      expect(result.created, isTrue);
    });

    test('同指纹文件已存在：复用现有文件，不覆盖内容且标记 created=false', () async {
      final existing = File(
        p.join(tmpDir.path, 'audios', 'imported', 'sha-final.m4a'),
      );
      await existing.create(recursive: true);
      await existing.writeAsBytes([9, 9, 9]);

      final service = AudioFinalizationService(
        transcodeService: _FakeTranscodeService(shouldTranscode: true),
        computeSha256: (_) async => 'sha-final',
      );
      final temp = await writeTemp('b.mp3', [1, 2, 3]);

      final result = await service.finalize(
        dataDir: tmpDir,
        tempRelativePath: temp,
        targetSubdir: p.join('audios', 'imported'),
      );

      expect(result.created, isFalse);
      expect(await existing.readAsBytes(), [9, 9, 9]);
      expect(
        await Directory(
          p.join(tmpDir.path, 'tmp', 'audio_import'),
        ).list().toList(),
        isEmpty,
      );
    });
  });
}
