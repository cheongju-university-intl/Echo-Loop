/// 文本右键/长按上下文菜单
///
/// 提供复制等文本操作，支持 iOS 长按和桌面端右键。
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../l10n/app_localizations.dart';

/// 文本右键/长按上下文菜单
class TextContextMenu {
  /// 显示上下文菜单
  ///
  /// [context] 当前 BuildContext
  /// [position] 菜单弹出位置（全局坐标）
  /// [text] 要复制的文本内容
  static Future<void> show(
    BuildContext context,
    Offset position,
    String text,
  ) async {
    final l10n = AppLocalizations.of(context)!;
    final overlay =
        Overlay.of(context).context.findRenderObject() as RenderBox?;

    final theme = Theme.of(context);

    // 提前捕获根 ScaffoldMessenger，避免在 BottomSheet 等独立 Navigator 中找不到
    final messenger = ScaffoldMessenger.maybeOf(context);

    final result = await showMenu<String>(
      context: context,
      position: RelativeRect.fromRect(
        position & const Size(40, 40),
        Offset.zero & (overlay?.size ?? const Size(0, 0)),
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
        ),
      ),
      elevation: 3,
      shadowColor: Colors.black.withValues(alpha: 0.15),
      surfaceTintColor: Colors.transparent,
      color: theme.colorScheme.surface,
      constraints: const BoxConstraints(minWidth: 120),
      items: [
        PopupMenuItem<String>(
          value: 'copy',
          height: 40,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.copy_rounded,
                size: 18,
                color: theme.colorScheme.onSurfaceVariant,
              ),
              const SizedBox(width: 10),
              Text(
                l10n.copy,
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ],
    );

    if (result == 'copy') {
      await Clipboard.setData(ClipboardData(text: text));
      messenger?.showSnackBar(
        SnackBar(
          content: Text(l10n.copied),
          duration: const Duration(seconds: 1),
        ),
      );
    }
  }
}
