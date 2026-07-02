/// 学习材料 PDF 导出门面
///
/// 负责「读字体 → isolate 生成 PDF → 写临时文件」的编排：
/// - 字体经 rootBundle 读取（只能在主 isolate），static 缓存避免二次导出重读 ~12MB；
/// - PDF 生成（字体解析 + 子集化，数百 ms 级 CPU）放 `compute` isolate；
/// - 产物写入 `pdf_export_<ts>` 临时目录（前缀已登记 temp_cleanup_service 白名单），
///   调用方分享完成后负责删除。
library;

import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../models/pdf_export/study_pdf_data.dart';
import '../audio_export_service.dart';
import 'study_pdf_builder.dart';

/// 学习材料 PDF 导出服务
class StudyPdfExportService {
  /// 字体字节缓存（同会话多次导出免重读 assets）
  static Uint8List? _latinRegular;
  static Uint8List? _latinBold;
  static Uint8List? _latinItalic;
  static Uint8List? _cjkRegular;
  static Uint8List? _appIconPng;

  /// 生成 PDF 并写入临时目录，返回文件完整路径
  ///
  /// 调用方（分享/保存完成后）负责清理临时文件。
  Future<String> export(StudyPdfDocument document) async {
    _latinRegular ??= await _loadAsset('assets/fonts/pdf/NotoSans-Regular.ttf');
    _latinBold ??= await _loadAsset('assets/fonts/pdf/NotoSans-Bold.ttf');
    _latinItalic ??= await _loadAsset('assets/fonts/pdf/NotoSans-Italic.ttf');
    _cjkRegular ??= await _loadAsset('assets/fonts/pdf/NotoSansSC-Regular.ttf');
    // 品牌图标仅为装饰：加载失败（如旧构建未含该 asset）降级为纯文字角标，
    // 不让整个导出失败
    try {
      _appIconPng ??= await _loadAsset('assets/icon/app-icon-96.png');
    } catch (_) {
      _appIconPng = null;
    }

    final now = DateTime.now();
    final request = StudyPdfBuildRequest(
      document: document,
      latinRegular: _latinRegular!,
      latinBold: _latinBold!,
      latinItalic: _latinItalic!,
      cjkRegular: _cjkRegular!,
      appIconPng: _appIconPng,
      exportDate:
          '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}',
    );

    final bytes = await compute(buildStudyPdfBytes, request);

    final safeName = AudioExportService().sanitizeFileName(document.title);
    final tempDir = await _createTempDir();
    final pdfPath = p.join(tempDir.path, '$safeName.pdf');
    await File(pdfPath).writeAsBytes(bytes);
    return pdfPath;
  }

  /// 从 assets 读原始字节（字体 / 品牌图标）
  Future<Uint8List> _loadAsset(String assetPath) async {
    final data = await rootBundle.load(assetPath);
    return Uint8List.sublistView(data);
  }

  /// 创建临时目录（前缀 `pdf_export_`，见 temp_cleanup_service 白名单）
  Future<Directory> _createTempDir() async {
    final systemTemp = await getTemporaryDirectory();
    final dir = Directory(
      p.join(
        systemTemp.path,
        'pdf_export_${DateTime.now().millisecondsSinceEpoch}',
      ),
    );
    await dir.create(recursive: true);
    return dir;
  }
}
