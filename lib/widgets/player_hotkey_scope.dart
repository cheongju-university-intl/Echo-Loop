import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// 通用学习快捷键作用域
///
/// 为学习界面提供键盘快捷键支持：
/// - Space：播放/暂停
/// - Left Arrow：上一句/上一段
/// - Right Arrow：下一句/下一段
///
/// 各页面通过回调传入自己的逻辑，不绑定任何具体 Provider。
class LearningHotkeyScope extends StatelessWidget {
  /// 播放/暂停回调
  final VoidCallback? onPlayPause;

  /// 上一句/上一段回调
  final VoidCallback? onPrevious;

  /// 下一句/下一段回调
  final VoidCallback? onNext;

  final Widget child;

  const LearningHotkeyScope({
    super.key,
    this.onPlayPause,
    this.onPrevious,
    this.onNext,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Focus(
      autofocus: true,
      onKeyEvent: (node, event) {
        if (event is! KeyDownEvent) return KeyEventResult.ignored;

        final key = event.logicalKey;

        if (key == LogicalKeyboardKey.space) {
          onPlayPause?.call();
          return KeyEventResult.handled;
        }

        if (key == LogicalKeyboardKey.arrowLeft) {
          onPrevious?.call();
          return KeyEventResult.handled;
        }

        if (key == LogicalKeyboardKey.arrowRight) {
          onNext?.call();
          return KeyEventResult.handled;
        }

        return KeyEventResult.ignored;
      },
      child: child,
    );
  }
}
