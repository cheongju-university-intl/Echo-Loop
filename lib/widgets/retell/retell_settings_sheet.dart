/// 复述设置面板
///
/// 底部弹窗，即时生效，仅本次会话。
/// 设置项：重复次数 + 可见词生成方式 + 可见词比例 + 停顿模式
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../l10n/app_localizations.dart';
import '../../models/intensive_listen_settings.dart';
import '../../models/retell_settings.dart';
import '../../providers/learning_session/retell_player_provider.dart';
import '../../theme/app_theme.dart';

/// 显示复述设置面板
Future<void> showRetellSettingsSheet(BuildContext context) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (context) => const _RetellSettingsSheet(),
  );
}

class _RetellSettingsSheet extends ConsumerWidget {
  const _RetellSettingsSheet();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final state = ref.watch(retellPlayerProvider);
    final settings = state.settings;

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.l, AppSpacing.l, AppSpacing.l, AppSpacing.xl,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 拖拽指示条
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: theme.colorScheme.outlineVariant,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.l),

          // 标题
          Text(
            l10n.retellSettingsTitle,
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: AppSpacing.l),

          // 重复次数
          Text(
            l10n.retellRepeatCount,
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: AppSpacing.s),
          Wrap(
            spacing: AppSpacing.s,
            children: List.generate(5, (i) {
              final count = i + 1;
              return ChoiceChip(
                label: Text('$count'),
                selected: settings.repeatCount == count,
                onSelected: (selected) {
                  if (selected) {
                    ref.read(retellPlayerProvider.notifier).updateSettings(
                          settings.copyWith(repeatCount: count),
                        );
                  }
                },
              );
            }),
          ),
          const SizedBox(height: AppSpacing.l),

          // 可见词生成方式
          Text(
            l10n.retellKeywordMethod,
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: AppSpacing.s),
          SegmentedButton<KeywordMethod>(
            segments: [
              ButtonSegment(
                value: KeywordMethod.off,
                label: Text(l10n.retellKeywordMethodOff),
              ),
              ButtonSegment(
                value: KeywordMethod.random,
                label: Text(l10n.retellKeywordMethodRandom),
              ),
              ButtonSegment(
                value: KeywordMethod.ai,
                label: Tooltip(
                  message: l10n.retellKeywordMethodAiComingSoon,
                  child: Text(l10n.retellKeywordMethodAi),
                ),
                enabled: false,
              ),
            ],
            selected: {settings.keywordMethod},
            onSelectionChanged: (selected) {
              ref.read(retellPlayerProvider.notifier).updateSettings(
                    settings.copyWith(keywordMethod: selected.first),
                  );
            },
          ),

          // 可见词比例（关闭时隐藏）
          if (settings.keywordMethod != KeywordMethod.off) ...[
            const SizedBox(height: AppSpacing.l),
            Text(
              l10n.retellKeywordRatio,
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: AppSpacing.s),
            Wrap(
              spacing: AppSpacing.s,
              children: [
                for (final ratio in KeywordRatio.values)
                  ChoiceChip(
                    label: Text('${ratio.numerator}/${ratio.denominator}'),
                    selected: settings.keywordRatio == ratio,
                    onSelected: (selected) {
                      if (selected) {
                        ref
                            .read(retellPlayerProvider.notifier)
                            .updateSettings(
                              settings.copyWith(keywordRatio: ratio),
                            );
                      }
                    },
                  ),
              ],
            ),
          ],
          const SizedBox(height: AppSpacing.l),

          // 停顿模式
          Text(
            l10n.retellPauseMode,
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: AppSpacing.s),
          SegmentedButton<PauseMode>(
            segments: [
              ButtonSegment(
                value: PauseMode.smart,
                label: Text(l10n.pauseModeSmart),
              ),
              ButtonSegment(
                value: PauseMode.fixed,
                label: Text(l10n.pauseModeFixed),
              ),
              ButtonSegment(
                value: PauseMode.multiplier,
                label: Text(l10n.pauseModeMultiplier),
              ),
            ],
            selected: {settings.pauseMode},
            onSelectionChanged: (selected) {
              ref.read(retellPlayerProvider.notifier).updateSettings(
                    settings.copyWith(pauseMode: selected.first),
                  );
            },
          ),
          const SizedBox(height: AppSpacing.m),

          // 固定间隔选项（仅 fixed 模式）
          if (settings.pauseMode == PauseMode.fixed) ...[
            Text(
              '${l10n.fixedPauseSeconds}: ${settings.fixedPauseSeconds}s',
              style: theme.textTheme.bodyMedium,
            ),
            Slider(
              value: settings.fixedPauseSeconds.toDouble(),
              min: 5,
              max: 60,
              divisions: 11,
              label: '${settings.fixedPauseSeconds}s',
              onChanged: (value) {
                ref.read(retellPlayerProvider.notifier).updateSettings(
                      settings.copyWith(fixedPauseSeconds: value.round()),
                    );
              },
            ),
          ],

          // 倍数选项（仅 multiplier 模式）
          if (settings.pauseMode == PauseMode.multiplier) ...[
            Text(
              '${l10n.pauseMultiplier}: ${settings.pauseMultiplier}x',
              style: theme.textTheme.bodyMedium,
            ),
            Slider(
              value: settings.pauseMultiplier,
              min: 1.0,
              max: 3.0,
              divisions: 4,
              label: '${settings.pauseMultiplier}x',
              onChanged: (value) {
                ref.read(retellPlayerProvider.notifier).updateSettings(
                      settings.copyWith(
                        pauseMultiplier: (value * 2).round() / 2,
                      ),
                    );
              },
            ),
          ],

          // 临时提示
          const SizedBox(height: AppSpacing.s),
          Text(
            l10n.settingsSessionOnly,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}
