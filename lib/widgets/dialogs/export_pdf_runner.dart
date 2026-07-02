/// 学习材料导出 PDF 的 UI 编排
///
/// 从音频列表菜单触发：组装 loader 依赖 → 进度弹窗 → 聚合数据 →
/// 生成 PDF → 平台分发（移动端系统分享 / 桌面端另存为）。
/// 逻辑集中在此文件，`audio_list_tile` 只保留菜单项和一行调用。
library;

import 'dart:async';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:share_plus/share_plus.dart';
import 'package:universal_io/io.dart';

import '../../database/providers.dart';
import '../../l10n/app_localizations.dart';
import '../../models/audio_item.dart';
import '../../providers/settings_provider.dart';
import '../../services/dictionary_service.dart';
import '../../services/pdf_export/study_pdf_export_service.dart';
import '../../services/pdf_export/study_pdf_loader.dart';

/// 导出指定音频的学习材料 PDF 并分享/保存
///
/// 全程只读已有数据（字幕/收藏/AI 缓存），不发起网络请求。
/// 失败时弹 SnackBar 提示，不抛出。
Future<void> runStudyPdfExport(
  BuildContext context,
  WidgetRef ref,
  AudioItem audioItem,
) async {
  final l10n = AppLocalizations.of(context)!;

  final loader = StudyPdfLoader(
    audioItemDao: ref.read(audioItemDaoProvider),
    bookmarkDao: ref.read(bookmarkDaoProvider),
    savedWordDao: ref.read(savedWordDaoProvider),
    savedSenseGroupDao: ref.read(savedSenseGroupDaoProvider),
    aiCacheDao: ref.read(sentenceAiCacheDaoProvider),
    localDictLookup: DictionaryService.instance.lookup,
  );
  final targetLanguage = ref.read(
    appSettingsProvider.select((s) => s.nativeLanguage),
  );

  // 进度弹窗（不可点击外部关闭；生成完成后由代码关闭）
  var dialogOpen = true;
  unawaited(
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => PopScope(
        canPop: false,
        child: AlertDialog(
          content: Row(
            children: [
              const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(strokeWidth: 2.5),
              ),
              const SizedBox(width: 16),
              Expanded(child: Text(l10n.pdfExporting)),
            ],
          ),
        ),
      ),
    ).then((_) => dialogOpen = false),
  );

  void closeDialog() {
    if (dialogOpen && context.mounted) {
      Navigator.of(context, rootNavigator: true).pop();
      dialogOpen = false;
    }
  }

  try {
    final document = await loader.load(
      audioItem.id,
      targetLanguage: targetLanguage,
    );
    final pdfPath = await StudyPdfExportService().export(document);

    closeDialog();
    if (!context.mounted) return;

    if (Platform.isIOS || Platform.isAndroid) {
      final box = context.findRenderObject() as RenderBox?;
      await Share.shareXFiles(
        [XFile(pdfPath, mimeType: 'application/pdf')],
        sharePositionOrigin: box != null
            ? box.localToGlobal(Offset.zero) & box.size
            : Rect.zero,
      );
      // 分享完成后清理临时文件
      try {
        await File(pdfPath).delete();
      } catch (_) {}
    } else {
      final fileName = p.basename(pdfPath);
      final home = Platform.environment['HOME'];
      final downloadsDir = home != null ? '$home/Downloads' : null;

      final savePath = await FilePicker.platform.saveFile(
        dialogTitle: l10n.exportPdf,
        fileName: fileName,
        initialDirectory: downloadsDir,
        type: FileType.custom,
        allowedExtensions: ['pdf'],
      );
      if (savePath != null) {
        await File(pdfPath).copy(savePath);
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('${l10n.exportSuccess}: ${p.basename(savePath)}'),
            ),
          );
        }
      }
      try {
        await File(pdfPath).delete();
      } catch (_) {}
    }
  } catch (e) {
    closeDialog();
    if (!context.mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(l10n.pdfExportFailed('$e'))));
  }
}
