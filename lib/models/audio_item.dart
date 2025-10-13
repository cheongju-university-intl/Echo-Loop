import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;

class AudioItem {
  final String id;
  final String name;
  final String audioPath; // 相对路径，如 "audios/file.mp3"
  final String? transcriptPath; // 相对路径，如 "transcripts/file.srt"
  final DateTime addedDate;
  final int totalDuration; // in seconds

  AudioItem({
    required this.id,
    required this.name,
    required this.audioPath,
    this.transcriptPath,
    required this.addedDate,
    this.totalDuration = 0,
  });

  bool get hasTranscript => transcriptPath != null && transcriptPath!.isNotEmpty;

  /// 获取音频文件的完整路径
  Future<String> getFullAudioPath() async {
    final docs = await getApplicationDocumentsDirectory();
    return path.join(docs.path, audioPath);
  }

  /// 获取字幕文件的完整路径
  Future<String?> getFullTranscriptPath() async {
    if (!hasTranscript) return null;
    final docs = await getApplicationDocumentsDirectory();
    return path.join(docs.path, transcriptPath!);
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'audioPath': audioPath,
        'transcriptPath': transcriptPath,
        'addedDate': addedDate.toIso8601String(),
        'totalDuration': totalDuration,
      };

  factory AudioItem.fromJson(Map<String, dynamic> json) => AudioItem(
        id: json['id'],
        name: json['name'],
        audioPath: json['audioPath'],
        transcriptPath: json['transcriptPath'],
        addedDate: DateTime.parse(json['addedDate']),
        totalDuration: json['totalDuration'] ?? 0,
      );

  AudioItem copyWith({
    String? id,
    String? name,
    String? audioPath,
    String? transcriptPath,
    DateTime? addedDate,
    int? totalDuration,
  }) {
    return AudioItem(
      id: id ?? this.id,
      name: name ?? this.name,
      audioPath: audioPath ?? this.audioPath,
      transcriptPath: transcriptPath ?? this.transcriptPath,
      addedDate: addedDate ?? this.addedDate,
      totalDuration: totalDuration ?? this.totalDuration,
    );
  }
}
