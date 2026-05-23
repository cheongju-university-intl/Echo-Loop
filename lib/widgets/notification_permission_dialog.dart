/// 通知权限 pre-prompt 对话框（仅 request 模式）。
///
/// 用户点 "开启" → 调 `NotificationPermissionService.onUserAcceptedPrompt`
/// → 真正调系统授权 API。
///
/// 注意：状态为 blocked（用户已走过系统流程但未授权）时，**不弹这个 dialog**，
/// 而是在 reminder_settings_screen 显示红色 banner，CTA 直接跳系统设置。
/// 这里只覆盖"首次请求"场景。
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../analytics/analytics_providers.dart';
import '../analytics/models/event_names.dart';
import '../l10n/app_localizations.dart';
import '../providers/notification_permission_provider.dart';

/// 显示 pre-prompt。返回 true 表示用户同意且系统授权成功。
///
/// `barrierDismissible: false` —— 用户必须明确点开启 / 暂不 / 右上角 ×，
/// 不能通过点背景把它当无声 dismiss（避免后续被人误解为「拒绝」）。
Future<bool> showNotificationPermissionDialog(
  BuildContext context,
  WidgetRef ref,
) async {
  ref
      .read(analyticsServiceProvider)
      .track(Events.notificationPromptShown, const {});
  final result = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (_) => _NotificationPermissionDialog(ref: ref),
  );
  return result ?? false;
}

class _NotificationPermissionDialog extends StatefulWidget {
  const _NotificationPermissionDialog({required this.ref});
  final WidgetRef ref;

  @override
  State<_NotificationPermissionDialog> createState() =>
      _NotificationPermissionDialogState();
}

class _NotificationPermissionDialogState
    extends State<_NotificationPermissionDialog> {
  /// 防连击：按下后锁住所有按钮，直到异步操作完成 + dialog pop。
  bool _processing = false;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return PopScope(
      // 拦截系统 back（Android）/ 手势返回。强制走 dismiss 流程
      // 而不是 null 返回，避免上层调用方误判。
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        if (!_processing) _onDismiss();
      },
      child: AlertDialog(
        titlePadding: EdgeInsets.zero,
        title: _DialogTitle(
          title: l10n.notificationPromptTitle,
          onClose: _processing ? null : _onDismiss,
        ),
        content: Text(l10n.notificationPromptBody),
        actions: [
          // 「暂不」用 TextButton，弱化为次要操作
          TextButton(
            onPressed: _processing ? null : _onDismiss,
            child: Text(l10n.notificationPromptCtaDismiss),
          ),
          // 「开启」用 FilledButton 突出为主要操作，引导用户点击
          FilledButton(
            onPressed: _processing ? null : _onGrant,
            child: Text(l10n.notificationPromptCtaGrant),
          ),
        ],
      ),
    );
  }

  Future<void> _onDismiss() async {
    if (_processing) return;
    setState(() => _processing = true);
    try {
      await widget.ref
          .read(notificationPermissionServiceProvider)
          .onUserDismissedPrompt();
    } finally {
      if (mounted) Navigator.pop(context, false);
    }
  }

  Future<void> _onGrant() async {
    if (_processing) return;
    setState(() => _processing = true);
    bool granted = false;
    try {
      granted = await widget.ref
          .read(notificationPermissionServiceProvider)
          .onUserAcceptedPrompt();
    } finally {
      if (mounted) Navigator.pop(context, granted);
    }
  }
}

/// 弹窗标题：标题 + 右上角关闭按钮（与 speech_permission_dialog 保持一致）。
class _DialogTitle extends StatelessWidget {
  final String title;
  final VoidCallback? onClose;

  const _DialogTitle({required this.title, required this.onClose});

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 24, 48, 0),
          child: Text(title, style: Theme.of(context).textTheme.headlineSmall),
        ),
        Positioned(
          top: 8,
          right: 8,
          child: IconButton(
            onPressed: onClose,
            icon: const Icon(Icons.close, size: 20),
            style: IconButton.styleFrom(
              padding: EdgeInsets.zero,
              minimumSize: const Size(32, 32),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            tooltip: MaterialLocalizations.of(context).closeButtonTooltip,
          ),
        ),
      ],
    );
  }
}
