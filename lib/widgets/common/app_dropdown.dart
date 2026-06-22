/// 统一样式的下拉框。
///
/// 包一层 [DropdownButton]，统一全应用下拉框观感：去掉默认下划线、菜单圆角 12、
/// 背景用 surface、紧凑内距，让各设置/介绍面板内的下拉选择与其它浮层风格一致。
/// 仅做样式封装，选择行为（[value]/[items]/[onChanged]）原样透传。
library;

import 'package:flutter/material.dart';

/// 应用统一下拉框。
class AppDropdown<T> extends StatelessWidget {
  const AppDropdown({
    super.key,
    required this.value,
    required this.items,
    required this.onChanged,
    this.isDense = true,
    this.isExpanded = false,
    this.alignment = AlignmentDirectional.centerStart,
  });

  /// 当前选中值。
  final T? value;

  /// 选项列表。
  final List<DropdownMenuItem<T>> items;

  /// 选择回调（为 null 时禁用）。
  final ValueChanged<T?>? onChanged;

  /// 是否紧凑布局。
  final bool isDense;

  /// 是否撑满父级宽度（用于固定宽度容器内的下拉）。
  final bool isExpanded;

  /// 选中项对齐方式。
  final AlignmentGeometry alignment;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return DropdownButton<T>(
      value: value,
      items: items,
      onChanged: onChanged,
      isDense: isDense,
      isExpanded: isExpanded,
      alignment: alignment,
      // 去掉默认下划线，交由外层容器/主题控制边界
      underline: const SizedBox.shrink(),
      borderRadius: BorderRadius.circular(12),
      dropdownColor: theme.colorScheme.surface,
      elevation: 8,
      style: theme.textTheme.bodyMedium,
      icon: const Icon(Icons.arrow_drop_down),
    );
  }
}
