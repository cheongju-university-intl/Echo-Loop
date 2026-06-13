// 音频内容有效性检测工具
//
// 两级判定，便宜的先行：
//   1. 解码时长探测：just_audio 解不出时长（<=0）→ 文件损坏/空。
//   2. 振幅分析：能解码出时长才跑，用 just_waveform 取全局峰值，
//      峰值低于满量程的保守比例 → 全程静音、无人声。
// 两种情况都判为 [AudioContentStatus.suspectEmpty]，统一一个标记。

import 'package:just_waveform/just_waveform.dart';
import 'package:path/path.dart' as path;
import 'package:universal_io/io.dart';
import 'package:uuid/uuid.dart';

import '../models/audio_item.dart';
import 'app_data_dir.dart';
import 'audio_duration.dart';

/// 「响亮样本」振幅门限：绝对振幅 > 满量程 × 该比例 视为有声内容。
///
/// 约 1% 满量程 ≈ -40 dBFS；低于此的样本视为静音背景噪声。
const double _loudAmplitudeRatio = 0.01;

/// 静音判定：响亮样本占比 < 该比例 即视为整体静音。
///
/// 用占比而非全局峰值，对少量离群样本健壮——`just_waveform` 16-bit 解析存在
/// 已知偏移缺陷（数据视图比真实数据早 10 字节，导致 [Waveform.data] 头部混入
/// 几个头部字段值，如 samplesPerPixel）。全局峰值会被这几个垃圾值污染而漏判，
/// 占比法可忽略这种极少数离群点。
const double _minLoudFraction = 0.005;

/// 纯函数：判断波形样本是否整体静音。
///
/// [samples] 为 just_waveform 的 min/max 交错样本（[Waveform.data]）。
/// [bits] 为采样位宽（16 或 8），决定满量程 `1 << (bits-1)`。
/// 统计「响亮样本占比」：占比低于 [minLoudFraction] 判为静音。
/// 空样本无法判定，返回 false（不过度标记）。
bool isWaveformSilent(
  List<int> samples, {
  required int bits,
  double loudRatio = _loudAmplitudeRatio,
  double minLoudFraction = _minLoudFraction,
}) {
  if (samples.isEmpty) return false;
  final loudThreshold = (1 << (bits - 1)) * loudRatio;
  var loudCount = 0;
  for (final sample in samples) {
    if (sample.abs() > loudThreshold) loudCount++;
  }
  return loudCount / samples.length < minLoudFraction;
}

/// 评估音频文件内容状态。
///
/// [relativePath] 相对应用数据目录的音频路径。
/// [decodedDurationSeconds] 若调用方已算出解码时长（如 podcast 下载流程），
/// 传入可避免重复解码；未传则现算。
///
/// 解码失败 → [AudioContentStatus.suspectEmpty]；
/// 能解码但全程静音 → [AudioContentStatus.suspectEmpty]；
/// 其余 → [AudioContentStatus.ok]。波形阶段异常时返回 ok（时长已证明可解码）。
Future<AudioContentStatus> evaluateAudioContent(
  String relativePath, {
  int? decodedDurationSeconds,
}) async {
  final duration =
      decodedDurationSeconds ?? await getAudioDurationSeconds(relativePath);
  if (duration <= 0) {
    // 解不出时长 → 文件损坏/空。
    return AudioContentStatus.suspectEmpty;
  }

  final silent = await _isFileSilent(relativePath);
  return silent ? AudioContentStatus.suspectEmpty : AudioContentStatus.ok;
}

/// 用 just_waveform 解码波形并判断是否静音。
///
/// 写临时波形文件、读取后删除。任何异常视为「无法判定」返回 false
/// （时长已证明文件可解码，不因波形失败而误标）。
Future<bool> _isFileSilent(String relativePath) async {
  File? waveFile;
  try {
    final dataDir = await getAppDataDirectory();
    final fullPath = path.join(dataDir.path, relativePath);
    final tmpDir = Directory(path.join(dataDir.path, 'tmp', 'content_check'));
    await tmpDir.create(recursive: true);
    waveFile = File(path.join(tmpDir.path, '${const Uuid().v4()}.wave'));

    Waveform? waveform;
    // 粗 zoom 足够取峰值，加快解码。
    await for (final progress in JustWaveform.extract(
      audioInFile: File(fullPath),
      waveOutFile: waveFile,
      zoom: const WaveformZoom.pixelsPerSecond(20),
    )) {
      waveform = progress.waveform;
    }
    if (waveform == null) return false;

    // flags==0 → 16bit（Int16List），否则 8bit。
    final bits = waveform.flags == 0 ? 16 : 8;
    return isWaveformSilent(waveform.data, bits: bits);
  } catch (_) {
    return false;
  } finally {
    if (waveFile != null && await waveFile.exists()) {
      try {
        await waveFile.delete();
      } catch (_) {}
    }
  }
}
