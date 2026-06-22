/// PopupMenuButton 菜单项的统一行样式。
///
/// 全应用的弹出菜单（音频 item 菜单、排序/筛选菜单等）共用同一套行布局：图标 + 标签
/// + 可选选中勾选，destructive 项统一红色。配合 app_theme 的 popupMenuTheme（圆角卡片
/// + 描边）让所有 PopupMenuButton 观感一致。
library;

import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';

const double _kAppPopupMenuMinWidth = 110;
const double _kAppPopupMenuIconBox = 20;

/// 构建统一样式的 [PopupMenuItem]，压缩默认高度并统一内边距。
PopupMenuItem<T> appPopupMenuItem<T>(
  BuildContext context, {
  required T value,
  Widget? icon,
  required String label,
  bool selected = false,
  bool destructive = false,
}) {
  return PopupMenuItem<T>(
    value: value,
    height: 44,
    padding: const EdgeInsets.symmetric(horizontal: AppSpacing.m),
    child: appPopupMenuRow(
      context,
      icon: icon,
      label: label,
      selected: selected,
      destructive: destructive,
    ),
  );
}

/// 构建 [PopupMenuItem] 的统一行内容。
///
/// - [icon]：行首图标组件（调用方可自定大小/颜色，未传则不显示图标）。
/// - [label]：菜单文案，过长省略。
/// - [selected]：选中态，在行尾显示主色勾选，文案加粗高亮。
/// - [destructive]：危险操作（删除/重置），文案与默认图标用 error 色。
///
/// [selected] 与 [destructive] 互斥使用；同传时以 destructive 的配色为准。
Widget appPopupMenuRow(
  BuildContext context, {
  Widget? icon,
  required String label,
  bool selected = false,
  bool destructive = false,
}) {
  final theme = Theme.of(context);
  final colorScheme = theme.colorScheme;
  final color = destructive
      ? colorScheme.error
      : selected
      ? colorScheme.primary
      : colorScheme.onSurface.withValues(alpha: 0.84);
  final iconColor = destructive
      ? colorScheme.error
      : selected
      ? colorScheme.primary
      : colorScheme.onSurfaceVariant.withValues(alpha: 0.9);

  return ConstrainedBox(
    constraints: const BoxConstraints(minWidth: _kAppPopupMenuMinWidth),
    child: Row(
      children: [
        SizedBox(
          width: _kAppPopupMenuIconBox,
          child: icon == null
              ? null
              : Center(
                  child: IconTheme.merge(
                    data: IconThemeData(size: 18, color: iconColor),
                    child: icon,
                  ),
                ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            label,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: color,
              fontSize: 15,
              fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
              letterSpacing: 0.1,
            ),
          ),
        ),
        if (selected)
          Padding(
            padding: const EdgeInsets.only(left: AppSpacing.s),
            child: Icon(Icons.check, size: 16, color: colorScheme.primary),
          ),
      ],
    ),
  );
}
