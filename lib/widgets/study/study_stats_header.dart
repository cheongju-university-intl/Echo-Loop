import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../l10n/app_localizations.dart';
import '../../providers/study_stats_provider.dart';
import '../../theme/app_theme.dart';
import 'learned_word_forms_sheet.dart';

/// 学习统计头部组件
///
/// 分三层信息层次：
/// 1. 今日卡片：学习时长 + 听/说明细（同一时间维度）
/// 2. 本周柱状图：标题行含本周累计，柱体双色堆叠
/// 3. 词汇量 badge：累计量 + 今日增量，可点击展开
class StudyStatsHeader extends ConsumerWidget {
  const StudyStatsHeader({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statsAsync = ref.watch(studyStatsNotifierProvider);

    return statsAsync.when(
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
      data: (stats) => Column(
        children: [
          _TodayCard(stats: stats),
          if (stats.dailySeconds.any((s) => s > 0)) ...[
            const SizedBox(height: AppSpacing.s),
            _WeeklyBarChart(
              weekTotalSeconds: stats.weekTotalSeconds,
              dailyInputSeconds: stats.dailyInputSeconds,
              dailyOutputSeconds: stats.dailyOutputSeconds,
              dailyTotalSeconds: stats.dailySeconds,
            ),
          ],
        ],
      ),
    );
  }
}

/// 今日学习卡片
///
/// 顶部大字显示今日总时长，下方两列显示听/说明细。
/// 所有数据均为"今日"维度，视觉上清晰统一。
class _TodayCard extends StatelessWidget {
  final StudyStats stats;

  const _TodayCard({required this.stats});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);

    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.m,
          vertical: 12,
        ),
        child: Column(
          children: [
            // 第一行：今日时长
            Row(
              children: [
                Icon(
                  Icons.timer_outlined,
                  size: 16,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(width: 6),
                Text(
                  l10n.todayStudyTimeShort,
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  _formatTime(l10n, stats.todaySeconds),
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: theme.colorScheme.onSurface,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            // 第二行：听 / 说 / 词汇 三列（clamp 防御脏数据）
            Builder(builder: (context) {
              final clampedInput = math.min(
                stats.todayInputSeconds,
                stats.todaySeconds,
              );
              final clampedOutput = math.min(
                stats.todayOutputSeconds,
                math.max(0, stats.todaySeconds - clampedInput),
              );
              if (clampedInput != stats.todayInputSeconds ||
                  clampedOutput != stats.todayOutputSeconds) {
                debugPrint(
                  '⚠️ 今日卡片 clamp: input ${stats.todayInputSeconds}→$clampedInput, '
                  'output ${stats.todayOutputSeconds}→$clampedOutput, '
                  'total ${stats.todaySeconds}',
                );
              }
              return Row(
              children: [
                Expanded(
                  flex: 3,
                  child: _ListenSpeakItem(
                    icon: Icons.headphones_outlined,
                    iconColor: Colors.teal,
                    timeText: _formatTimeShort(clampedInput),
                    wordText:
                        '${_formatWordCount(stats.todayInputWords)}${l10n.localeName == 'zh' ? '词' : 'w'}',
                  ),
                ),
                Container(
                  width: 1,
                  height: 24,
                  color: theme.colorScheme.outlineVariant.withValues(alpha: 0.4),
                ),
                Expanded(
                  flex: 3,
                  child: _ListenSpeakItem(
                    icon: Icons.mic_outlined,
                    iconColor: Colors.deepPurple,
                    timeText: _formatTimeShort(clampedOutput),
                    wordText:
                        '${_formatWordCount(stats.todayOutputWords)}${l10n.localeName == 'zh' ? '词' : 'w'}',
                  ),
                ),
                Container(
                  width: 1,
                  height: 24,
                  color: theme.colorScheme.outlineVariant.withValues(alpha: 0.4),
                ),
                Expanded(
                  flex: 2,
                  child: _VocabItem(
                    todayNew: stats.todayNewWordForms,
                    onTap: () => showLearnedWordFormsSheet(context: context),
                  ),
                ),
              ],
            );
            }),
          ],
        ),
      ),
    );
  }
}

/// 听/说单项指标
///
/// 图标 + 时间 · 词数，水平居中排列。
class _ListenSpeakItem extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String timeText;
  final String wordText;

  const _ListenSpeakItem({
    required this.icon,
    required this.iconColor,
    required this.timeText,
    required this.wordText,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return FittedBox(
      fit: BoxFit.scaleDown,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 14, color: iconColor),
          const SizedBox(width: 4),
          Text(
            timeText,
            style: theme.textTheme.labelMedium?.copyWith(
              fontWeight: FontWeight.w600,
              color: theme.colorScheme.onSurface,
            ),
          ),
          Text(
            ' · ',
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          Text(
            wordText,
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

/// 词汇今日新增项（嵌入今日卡片第二行）
///
/// 只显示今日新增词数，点击可打开词汇列表弹窗查看全局数据。
class _VocabItem extends StatelessWidget {
  final int todayNew;
  final VoidCallback onTap;

  const _VocabItem({required this.todayNew, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;
    return GestureDetector(
      onTap: onTap,
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.spellcheck_rounded, size: 14, color: Colors.indigo),
            const SizedBox(width: 4),
            Text(
              '+${_formatWordCount(todayNew)}',
              style: theme.textTheme.labelMedium?.copyWith(
                fontWeight: FontWeight.w600,
                color: theme.colorScheme.onSurface,
              ),
            ),
            Text(
              l10n.localeName == 'zh' ? '词' : 'w',
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 7 天学习时长柱状图（双色堆叠）
///
/// 标题行显示"本周"累计时长，柱体底部 teal = 输入，顶部 deepPurple = 输出。
/// 向前兼容：旧数据无 input/output 时，用 totalSeconds 当输入（teal 单色）。
class _WeeklyBarChart extends StatelessWidget {
  final int weekTotalSeconds;
  final List<int> dailyInputSeconds;
  final List<int> dailyOutputSeconds;
  final List<int> dailyTotalSeconds;

  const _WeeklyBarChart({
    required this.weekTotalSeconds,
    required this.dailyInputSeconds,
    required this.dailyOutputSeconds,
    required this.dailyTotalSeconds,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;

    // 柱高基于 totalSeconds（而非 input+output），避免重叠计时导致柱高虚高
    final maxSeconds = dailyTotalSeconds.reduce((a, b) => a > b ? a : b);
    const maxBarHeight = 56.0;

    // 计算最近 7 天的星期标签
    final now = DateTime.now();
    final weekdayLabels = List.generate(7, (i) {
      final date = now.subtract(Duration(days: 6 - i));
      return _weekdayShort(date.weekday);
    });

    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.m,
          12,
          AppSpacing.m,
          12,
        ),
        child: Column(
          children: [
            // 标题行：本周累计
            Row(
              children: [
                Icon(
                  Icons.date_range_outlined,
                  size: 15,
                  color: theme.colorScheme.tertiary,
                ),
                const SizedBox(width: 5),
                Text(
                  '${l10n.weekStudyTimeShort}: ${_formatTime(l10n, weekTotalSeconds)}',
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            // 柱状图
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: List.generate(7, (i) {
                final isToday = i == 6;
                final totalSec = dailyTotalSeconds[i];
                final ratio = maxSeconds > 0 ? totalSec / maxSeconds : 0.0;
                final barHeight =
                    (ratio * maxBarHeight).clamp(3.0, maxBarHeight);

                // Clamp input/output 防御历史脏数据
                final hasBreakdown =
                    dailyInputSeconds[i] > 0 || dailyOutputSeconds[i] > 0;
                final rawInput =
                    hasBreakdown ? dailyInputSeconds[i] : dailyTotalSeconds[i];
                final rawOutput = hasBreakdown ? dailyOutputSeconds[i] : 0;
                final inputSec = math.min(rawInput, totalSec);
                final outputSec = math.min(rawOutput, math.max(0, totalSec - inputSec));
                if (rawInput != inputSec || rawOutput != outputSec) {
                  debugPrint(
                    '⚠️ 柱状图 clamp day$i: input $rawInput→$inputSec, '
                    'output $rawOutput→$outputSec, total $totalSec',
                  );
                }
                final inputRatio =
                    totalSec > 0 ? inputSec / totalSec : 1.0;

                return Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // 柱顶数值
                      if (totalSec > 0)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 3),
                          child: Text(
                            _formatMinutes(totalSec),
                            style: theme.textTheme.labelSmall?.copyWith(
                              fontSize: 9,
                              fontWeight: isToday
                                  ? FontWeight.w600
                                  : FontWeight.normal,
                              color: isToday
                                  ? theme.colorScheme.primary
                                  : theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ),
                      // 柱体（双色堆叠或纯输入单色）
                      if (outputSec > 0)
                        _buildStackedBar(
                          barHeight: barHeight,
                          inputRatio: inputRatio,
                          isToday: isToday,
                        )
                      else
                        Container(
                          height: barHeight,
                          margin: const EdgeInsets.symmetric(horizontal: 5),
                          decoration: BoxDecoration(
                            color: isToday
                                ? Colors.teal
                                : Colors.teal.withValues(alpha: 0.2),
                            borderRadius: const BorderRadius.vertical(
                              top: Radius.circular(4),
                              bottom: Radius.circular(2),
                            ),
                          ),
                        ),
                      const SizedBox(height: 5),
                      // 星期标签
                      Text(
                        weekdayLabels[i],
                        style: theme.textTheme.labelSmall?.copyWith(
                          fontSize: 10,
                          fontWeight:
                              isToday ? FontWeight.bold : FontWeight.normal,
                          color: isToday
                              ? theme.colorScheme.primary
                              : theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                );
              }),
            ),
          ],
        ),
      ),
    );
  }

  /// 构建双色堆叠柱体
  Widget _buildStackedBar({
    required double barHeight,
    required double inputRatio,
    required bool isToday,
  }) {
    final inputHeight = (barHeight * inputRatio).clamp(1.0, barHeight - 1);
    final outputHeight = barHeight - inputHeight;
    final alpha = isToday ? 1.0 : 0.3;

    return Container(
      height: barHeight,
      margin: const EdgeInsets.symmetric(horizontal: 5),
      child: Column(
        children: [
          // 顶部：输出（deepPurple）
          Container(
            height: outputHeight,
            decoration: BoxDecoration(
              color: Colors.deepPurple.withValues(alpha: alpha),
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(4),
              ),
            ),
          ),
          // 底部：输入（teal）
          Container(
            height: inputHeight,
            decoration: BoxDecoration(
              color: Colors.teal.withValues(alpha: alpha),
              borderRadius: const BorderRadius.vertical(
                bottom: Radius.circular(2),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 格式化秒数为分钟显示（柱状图上方的数字）
  String _formatMinutes(int seconds) {
    final minutes = (seconds / 60).ceil();
    if (minutes < 60) return '${minutes}m';
    return '${minutes ~/ 60}h';
  }

  /// 星期几缩写
  String _weekdayShort(int weekday) {
    return switch (weekday) {
      1 => 'Mon',
      2 => 'Tue',
      3 => 'Wed',
      4 => 'Thu',
      5 => 'Fri',
      6 => 'Sat',
      7 => 'Sun',
      _ => '',
    };
  }
}

/// 格式化秒数为简短时间显示（用于听/说明细）
///
/// 0 → "0分", < 3600 → "N分", >= 3600 → "Nh Mm"
String _formatTimeShort(int seconds) {
  if (seconds <= 0) return '0分';
  final totalMinutes = (seconds / 60).ceil();
  if (totalMinutes < 60) return '$totalMinutes分';
  final hours = totalMinutes ~/ 60;
  final minutes = totalMinutes % 60;
  if (minutes == 0) return '${hours}h';
  return '${hours}h${minutes}m';
}

/// 格式化词数显示
///
/// < 1000 → "856", >= 1000 → "1,234", >= 10000 → "12.3k"
String _formatWordCount(int count) {
  if (count >= 10000) {
    final k = count / 1000;
    return '${k.toStringAsFixed(1)}k';
  }
  if (count >= 1000) {
    final str = count.toString();
    return '${str.substring(0, str.length - 3)},${str.substring(str.length - 3)}';
  }
  return count.toString();
}

/// 格式化学习时长显示
String _formatTime(AppLocalizations l10n, int seconds) {
  final totalMinutes = (seconds / 60).ceil();
  if (totalMinutes <= 0) return l10n.studyTimeMinutes(0);
  if (totalMinutes < 60) return l10n.studyTimeMinutes(totalMinutes);
  final hours = totalMinutes ~/ 60;
  final minutes = totalMinutes % 60;
  return l10n.studyTimeHoursMinutes(hours, minutes);
}
