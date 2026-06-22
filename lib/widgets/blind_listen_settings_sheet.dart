/// 盲听设置面板
///
/// 底部弹窗，即时生效，仅本次会话。
/// 设置项：每段重复次数 + 停顿模式（固定间隔/段长倍数）
/// UI 风格与复述设置面板保持一致。
library;

import 'package:flutter/material.dart';
import 'common/app_dropdown.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../l10n/app_localizations.dart';
import '../models/blind_listen_settings.dart';
import '../models/intensive_listen_settings.dart'
    show PauseMode, ShadowingControlMode;
import '../providers/learning_session/blind_listen_player_provider.dart';
import '../theme/app_theme.dart';

/// 显示盲听设置面板
Future<void> showBlindListenSettingsSheet(BuildContext context) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (context) => const _BlindListenSettingsSheet(),
  );
}

class _BlindListenSettingsSheet extends ConsumerWidget {
  const _BlindListenSettingsSheet();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final state = ref.watch(blindListenPlayerProvider);
    final settings = state.settings;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.l,
          AppSpacing.s,
          AppSpacing.l,
          AppSpacing.l,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 拖拽指示条
            Center(
              child: Container(
                width: 32,
                height: 4,
                margin: const EdgeInsets.only(bottom: AppSpacing.m),
                decoration: BoxDecoration(
                  color: theme.colorScheme.onSurfaceVariant.withValues(
                    alpha: 0.4,
                  ),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),

            // 标题
            Text(
              l10n.blindListenSettingsTitle,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: AppSpacing.xs),

            // 本次生效提示
            Text(
              l10n.settingsSessionOnly,
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant.withValues(
                  alpha: 0.6,
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.l),

            // 控制模式
            _buildControlModeSection(l10n, theme, settings, ref),
            const SizedBox(height: AppSpacing.l),

            // 重复次数和停顿设置仅在自动模式下显示
            if (!settings.isManualMode) ...[
              const SizedBox(height: AppSpacing.l),

              // 每段重复次数
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    l10n.retellRepeatCount,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  AppDropdown<int>(
                    value: settings.repeatCount,
                    items: List.generate(5, (i) {
                      final count = i + 1;
                      return DropdownMenuItem(
                        value: count,
                        child: Text('$count'),
                      );
                    }),
                    onChanged: (value) {
                      if (value != null) {
                        ref
                            .read(blindListenPlayerProvider.notifier)
                            .updateSettings(
                              settings.copyWith(repeatCount: value),
                            );
                      }
                    },
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.l),

              // 段间停顿标题
              Text(
                l10n.blindListenPauseBetween,
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: AppSpacing.s),

              // 停顿模式切换
              SizedBox(
                width: double.infinity,
                child: SegmentedButton<PauseMode>(
                  showSelectedIcon: false,
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
                    ref
                        .read(blindListenPlayerProvider.notifier)
                        .updateSettings(
                          settings.copyWith(pauseMode: selected.first),
                        );
                  },
                ),
              ),
              const SizedBox(height: AppSpacing.m),

              // 停顿模式详情
              _buildPauseModeDetail(l10n, theme, settings, ref),
            ],

            const SizedBox(height: AppSpacing.l),

            // 播放速度放在控制相关设置之后，作为本次盲听的全局播放参数。
            _buildPlaybackSpeedSection(l10n, theme, settings, ref),
          ],
        ),
      ),
    );
  }

  /// 播放速度滑块。
  ///
  /// 盲听速度仅对当前会话生效，步进为 0.05x，覆盖 0.5x-2.0x。
  Widget _buildPlaybackSpeedSection(
    AppLocalizations l10n,
    ThemeData theme,
    BlindListenSettings settings,
    WidgetRef ref,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              l10n.playbackSpeed,
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            Text(
              _formatSpeed(settings.playbackSpeed),
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        Slider(
          value: settings.playbackSpeed.clamp(0.5, 2.0),
          min: 0.5,
          max: 2.0,
          divisions: 30,
          label: _formatSpeed(settings.playbackSpeed),
          onChanged: (value) {
            final speed = (value * 20).round() / 20;
            ref
                .read(blindListenPlayerProvider.notifier)
                .updateSettings(settings.copyWith(playbackSpeed: speed));
          },
        ),
      ],
    );
  }

  /// 控制模式选择区域
  Widget _buildControlModeSection(
    AppLocalizations l10n,
    ThemeData theme,
    BlindListenSettings settings,
    WidgetRef ref,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n.listenAndRepeatControlModeLabel,
          style: theme.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: AppSpacing.s),
        SizedBox(
          width: double.infinity,
          child: SegmentedButton<ShadowingControlMode>(
            segments: [
              ButtonSegment(
                value: ShadowingControlMode.auto,
                label: Text(l10n.listenAndRepeatControlModeAuto),
                icon: const Icon(Icons.autorenew, size: 18),
              ),
              ButtonSegment(
                value: ShadowingControlMode.manual,
                label: Text(l10n.listenAndRepeatControlModeManual),
                icon: const Icon(Icons.touch_app, size: 18),
              ),
            ],
            selected: {settings.controlMode},
            onSelectionChanged: (selected) {
              ref
                  .read(blindListenPlayerProvider.notifier)
                  .updateSettings(
                    settings.copyWith(controlMode: selected.first),
                  );
            },
            showSelectedIcon: false,
          ),
        ),
        const SizedBox(height: AppSpacing.xs),
        Row(
          children: [
            Icon(
              Icons.info_outline,
              size: 14,
              color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.6),
            ),
            const SizedBox(width: AppSpacing.xs),
            Expanded(
              child: Text(
                settings.isManualMode
                    ? l10n.blindListenControlModeManualDesc
                    : l10n.blindListenControlModeAutoDesc,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant.withValues(
                    alpha: 0.6,
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  /// 停顿模式详情区域
  Widget _buildPauseModeDetail(
    AppLocalizations l10n,
    ThemeData theme,
    BlindListenSettings settings,
    WidgetRef ref,
  ) {
    return switch (settings.pauseMode) {
      PauseMode.smart => Row(
        children: [
          Icon(
            Icons.info_outline,
            size: 14,
            color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.6),
          ),
          const SizedBox(width: AppSpacing.xs),
          Expanded(
            child: Text(
              l10n.listenAndRepeatPauseSmartDesc,
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant.withValues(
                  alpha: 0.6,
                ),
              ),
            ),
          ),
        ],
      ),
      PauseMode.multiplier => _buildChipGrid(
        items: BlindListenSettings.multiplierOptions,
        labelBuilder: (v) => v == v.roundToDouble() ? '${v.toInt()}x' : '${v}x',
        selected: (v) => settings.pauseMultiplier == v,
        onSelected: (v) => ref
            .read(blindListenPlayerProvider.notifier)
            .updateSettings(settings.copyWith(pauseMultiplier: v)),
      ),
      PauseMode.fixed => () {
        final options = BlindListenSettings.fixedPauseOptions;
        var idx = options.indexOf(settings.fixedPauseSeconds);
        if (idx < 0) idx = 1; // 回退到 10s（默认值）
        return Row(
          children: [
            Expanded(
              child: Slider(
                value: idx.toDouble(),
                min: 0,
                max: (options.length - 1).toDouble(),
                divisions: options.length - 1,
                label: '${options[idx]}s',
                onChanged: (v) {
                  ref
                      .read(blindListenPlayerProvider.notifier)
                      .updateSettings(
                        settings.copyWith(
                          fixedPauseSeconds: options[v.round()],
                        ),
                      );
                },
              ),
            ),
            SizedBox(
              width: 36,
              child: Text(
                '${settings.fixedPauseSeconds}s',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        );
      }(),
    };
  }

  /// 等宽网格排列 ChoiceChip，每行 4 个
  Widget _buildChipGrid<T>({
    required List<T> items,
    required String Function(T) labelBuilder,
    required bool Function(T) selected,
    required void Function(T) onSelected,
  }) {
    const columns = 4;
    final rows = (items.length / columns).ceil();

    return Column(
      children: List.generate(rows, (row) {
        final start = row * columns;
        final end = (start + columns).clamp(0, items.length);
        final rowItems = items.sublist(start, end);

        return Padding(
          padding: EdgeInsets.only(top: row > 0 ? AppSpacing.xs : 0),
          child: Row(
            children: [
              for (var i = 0; i < columns; i++) ...[
                if (i > 0) const SizedBox(width: AppSpacing.xs),
                Expanded(
                  child: i < rowItems.length
                      ? ChoiceChip(
                          showCheckmark: false,
                          label: SizedBox(
                            width: double.infinity,
                            child: Text(
                              labelBuilder(rowItems[i]),
                              textAlign: TextAlign.center,
                            ),
                          ),
                          selected: selected(rowItems[i]),
                          onSelected: (s) {
                            if (s) onSelected(rowItems[i]);
                          },
                        )
                      : const SizedBox.shrink(),
                ),
              ],
            ],
          ),
        );
      }),
    );
  }

  /// 统一显示速度标签：整数速度显示为 1x，0.05 步进保留必要小数。
  String _formatSpeed(double speed) {
    if (speed == speed.roundToDouble()) return '${speed.toInt()}x';
    if ((speed * 10).roundToDouble() == speed * 10) {
      return '${speed.toStringAsFixed(1)}x';
    }
    return '${speed.toStringAsFixed(2)}x';
  }
}
