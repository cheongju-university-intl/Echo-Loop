// 音频时长提取工具
//
// 使用 just_audio 临时实例读取音频文件的时长，
// 用于在导入音频时预先获取时长信息。

import 'package:just_audio/just_audio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;

/// 读取音频文件时长（秒）
///
/// [relativePath] 相对于 Documents 目录的音频文件路径。
/// 失败时返回 0，不阻塞导入流程。
Future<int> getAudioDurationSeconds(String relativePath) async {
  final player = AudioPlayer();
  try {
    final docs = await getApplicationDocumentsDirectory();
    final fullPath = path.join(docs.path, relativePath);
    final duration = await player.setFilePath(fullPath);
    return duration?.inSeconds ?? 0;
  } catch (e) {
    // 提取时长失败不阻塞导入，返回 0
    return 0;
  } finally {
    await player.dispose();
  }
}
