/// 意群快捷操作工具条
///
/// 浮动在 badge 上方，简洁的图标按钮样式。
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// 意群快捷操作工具条
///
/// 圆形深色背景，只显示一个书签图标。
/// 点击切换收藏/取消收藏。
class SenseGroupActionBar extends StatelessWidget {
  /// 是否已收藏
  final bool isSaved;

  /// 收藏/取消收藏回调
  final VoidCallback onToggleSave;

  const SenseGroupActionBar({
    super.key,
    required this.isSaved,
    required this.onToggleSave,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bgColor = theme.colorScheme.inverseSurface;
    final fgColor = theme.colorScheme.onInverseSurface;

    return Container(
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(
            color: Colors.black26,
            blurRadius: 4,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () {
            HapticFeedback.lightImpact();
            onToggleSave();
          },
          child: Padding(
            padding: const EdgeInsets.all(6),
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              child: Icon(
                isSaved ? Icons.bookmark_rounded : Icons.bookmark_outline_rounded,
                key: ValueKey(isSaved),
                size: 18,
                color: isSaved ? Colors.amber : fgColor,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
