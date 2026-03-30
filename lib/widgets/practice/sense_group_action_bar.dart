/// 意群快捷操作工具条
///
/// 浮动在 badge 上方的深色工具条，目前支持收藏操作。
/// 使用 [OverlayEntry] + [CompositedTransformFollower] 实现定位。
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../l10n/app_localizations.dart';

/// 意群快捷操作工具条
///
/// 深色背景，圆角 8dp，带向下三角箭头指向 badge。
/// 支持收藏/取消收藏操作。
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
    final l10n = AppLocalizations.of(context)!;
    final bgColor = theme.colorScheme.inverseSurface;
    final fgColor = theme.colorScheme.onInverseSurface;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // 工具条主体
        Container(
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(8),
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
              borderRadius: BorderRadius.circular(8),
              onTap: () {
                HapticFeedback.lightImpact();
                onToggleSave();
              },
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 200),
                      child: Icon(
                        isSaved ? Icons.star_rounded : Icons.star_outline_rounded,
                        key: ValueKey(isSaved),
                        size: 16,
                        color: isSaved ? Colors.amber : fgColor,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      isSaved
                          ? l10n.senseGroupSaved
                          : l10n.senseGroupSave,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: fgColor,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        // 向下三角箭头
        CustomPaint(
          size: const Size(12, 6),
          painter: _TrianglePainter(color: bgColor),
        ),
      ],
    );
  }
}

/// 向下三角箭头画笔
class _TrianglePainter extends CustomPainter {
  final Color color;

  _TrianglePainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()
      ..moveTo(0, 0)
      ..lineTo(size.width / 2, size.height)
      ..lineTo(size.width, 0)
      ..close();
    canvas.drawPath(path, Paint()..color = color);
  }

  @override
  bool shouldRepaint(_TrianglePainter oldDelegate) =>
      color != oldDelegate.color;
}
