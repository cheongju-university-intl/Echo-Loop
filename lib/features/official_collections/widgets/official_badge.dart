import 'package:flutter/material.dart';

import '../../../l10n/app_localizations.dart';

/// 官方合集标识芯片：`verified` 图标 + "官方"小标签，tonal 灰底。
///
/// 视觉轻量，不与其他彩色 badge（pin 红、学习进度紫）冲突。
class OfficialBadge extends StatelessWidget {
  const OfficialBadge({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: theme.colorScheme.secondaryContainer,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.verified_outlined,
            size: 12,
            color: theme.colorScheme.onSecondaryContainer,
          ),
          const SizedBox(width: 3),
          Text(
            l10n.officialBadge,
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.onSecondaryContainer,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

/// 已下架标识芯片（灰色），叠加在 [OfficialBadge] 旁边。
class OfficialDeprecatedBadge extends StatelessWidget {
  const OfficialDeprecatedBadge({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        l10n.officialDeprecatedBadge,
        style: theme.textTheme.labelSmall?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}
