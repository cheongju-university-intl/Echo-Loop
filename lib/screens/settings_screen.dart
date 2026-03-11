import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../l10n/app_localizations.dart';
import '../providers/developer_options_provider.dart';
import '../providers/package_info_provider.dart';
import '../providers/settings_provider.dart';
import '../theme/app_theme.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final settings = ref.watch(appSettingsProvider);
    final showDeveloperOptions = ref.watch(showDeveloperOptionsProvider);
    final settingsController = ref.read(appSettingsProvider.notifier);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.settings)),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.m),
        children: [
          _buildSection(
            context,
            title: l10n.appearance,
            children: [
              _buildThemeModeTile(context, l10n, settings, settingsController),
              _buildLanguageTile(context, l10n, settings, settingsController),
            ],
          ),
          const SizedBox(height: AppSpacing.m),
          _buildAboutSection(context, ref, l10n),
          if (showDeveloperOptions) ...[
            const SizedBox(height: AppSpacing.m),
            _buildDeveloperSection(context, l10n, settings, settingsController),
          ],
        ],
      ),
    );
  }

  Widget _buildSection(
    BuildContext context, {
    required String title,
    required List<Widget> children,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.m,
            AppSpacing.s,
            AppSpacing.m,
            AppSpacing.s,
          ),
          child: Text(
            title,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
              color: Theme.of(context).colorScheme.primary,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        Card(child: Column(children: _intersperseDividers(children))),
      ],
    );
  }

  /// 构建关于信息区域
  Widget _buildAboutSection(
    BuildContext context,
    WidgetRef ref,
    AppLocalizations l10n,
  ) {
    final colorScheme = Theme.of(context).colorScheme;
    return _buildSection(
      context,
      title: l10n.about,
      children: [
        ListTile(
          leading: _emojiIcon('ℹ️'),
          title: Text(l10n.version),
          trailing: Text(
            ref.watch(packageInfoProvider).version,
            style: TextStyle(color: colorScheme.onSurfaceVariant),
          ),
        ),
        ListTile(leading: _emojiIcon('📖'), title: Text(l10n.appDescription)),
      ],
    );
  }

  /// 构建开发者选项区域
  Widget _buildDeveloperSection(
    BuildContext context,
    AppLocalizations l10n,
    AppSettingsState settings,
    AppSettings controller,
  ) {
    final formattedTimeMachine = _formatTimeMachineDateTime(
      context,
      settings.timeMachineDateTime,
    );
    return _buildSection(
      context,
      title: l10n.developer,
      children: [
        ListTile(
          leading: _emojiIcon('🔧'),
          title: Text(l10n.timeMachine),
          subtitle: Text(
            formattedTimeMachine == null
                ? l10n.timeMachineUseSystemTime
                : '${l10n.timeMachineCurrentTime}: $formattedTimeMachine',
          ),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => _showTimeMachineDialog(
            context,
            l10n,
            controller,
            settings.timeMachineDateTime,
          ),
        ),
      ],
    );
  }

  /// 显示时光机设置对话框。
  ///
  /// 对话框内允许分别选择日期与时间，并支持恢复系统时间。
  Future<void> _showTimeMachineDialog(
    BuildContext context,
    AppLocalizations l10n,
    AppSettings controller,
    DateTime? initialDateTime,
  ) async {
    DateTime? selectedDateTime = initialDateTime;

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setState) {
            final formattedDateTime = _formatTimeMachineDateTime(
              context,
              selectedDateTime,
            );
            return AlertDialog(
              title: Text(l10n.timeMachine),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    formattedDateTime == null
                        ? l10n.timeMachineUseSystemTime
                        : '${l10n.timeMachineCurrentTime}: $formattedDateTime',
                  ),
                  const SizedBox(height: AppSpacing.m),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () async {
                            final nextDateTime = await _pickDate(
                              dialogContext,
                              selectedDateTime,
                            );
                            if (nextDateTime == null) return;
                            setState(() {
                              selectedDateTime = nextDateTime;
                            });
                          },
                          child: Text(l10n.timeMachineSelectDate),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.s),
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () async {
                            final nextDateTime = await _pickTime(
                              dialogContext,
                              selectedDateTime,
                            );
                            if (nextDateTime == null) return;
                            setState(() {
                              selectedDateTime = nextDateTime;
                            });
                          },
                          child: Text(l10n.timeMachineSelectTime),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.s),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton(
                      onPressed: () {
                        setState(() {
                          selectedDateTime = null;
                        });
                      },
                      child: Text(l10n.timeMachineReset),
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  child: Text(l10n.cancel),
                ),
                FilledButton(
                  onPressed: () async {
                    await controller.setTimeMachineDateTime(selectedDateTime);
                    if (!dialogContext.mounted) return;
                    Navigator.of(dialogContext).pop();
                  },
                  child: Text(l10n.save),
                ),
              ],
            );
          },
        );
      },
    );
  }

  /// 选择时光机日期，并保留已有时间部分。
  Future<DateTime?> _pickDate(
    BuildContext context,
    DateTime? currentDateTime,
  ) async {
    final baseDateTime = _normalizedPickerBaseDateTime(currentDateTime);
    final pickedDate = await showDatePicker(
      context: context,
      initialDate: baseDateTime,
      firstDate: DateTime(2020, 1, 1),
      lastDate: DateTime(2100, 12, 31),
    );
    if (pickedDate == null) return null;

    return DateTime(
      pickedDate.year,
      pickedDate.month,
      pickedDate.day,
      baseDateTime.hour,
      baseDateTime.minute,
    );
  }

  /// 选择时光机时间，并保留已有日期部分。
  Future<DateTime?> _pickTime(
    BuildContext context,
    DateTime? currentDateTime,
  ) async {
    final baseDateTime = _normalizedPickerBaseDateTime(currentDateTime);
    final pickedTime = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(
        hour: baseDateTime.hour,
        minute: baseDateTime.minute,
      ),
    );
    if (pickedTime == null) return null;

    return DateTime(
      baseDateTime.year,
      baseDateTime.month,
      baseDateTime.day,
      pickedTime.hour,
      pickedTime.minute,
    );
  }

  /// 为 picker 提供分钟精度的默认时间。
  DateTime _normalizedPickerBaseDateTime(DateTime? currentDateTime) {
    final baseDateTime = currentDateTime ?? DateTime.now();
    return DateTime(
      baseDateTime.year,
      baseDateTime.month,
      baseDateTime.day,
      baseDateTime.hour,
      baseDateTime.minute,
    );
  }

  String? _formatTimeMachineDateTime(BuildContext context, DateTime? dateTime) {
    if (dateTime == null) return null;
    final locale = Localizations.localeOf(context).toLanguageTag();
    return DateFormat('yyyy-MM-dd HH:mm', locale).format(dateTime);
  }

  /// 构建 emoji 图标（Learna AI 风格）
  Widget _emojiIcon(String emoji) {
    return SizedBox(
      width: 32,
      height: 32,
      child: Center(child: Text(emoji, style: const TextStyle(fontSize: 22))),
    );
  }

  /// 在 children 之间插入浅灰分割线
  List<Widget> _intersperseDividers(List<Widget> children) {
    if (children.length <= 1) return children;
    final result = <Widget>[];
    for (var i = 0; i < children.length; i++) {
      result.add(children[i]);
      if (i < children.length - 1) {
        result.add(const Divider(height: 1, indent: 56));
      }
    }
    return result;
  }

  Widget _buildThemeModeTile(
    BuildContext context,
    AppLocalizations l10n,
    AppSettingsState settings,
    AppSettings controller,
  ) {
    final colorScheme = Theme.of(context).colorScheme;
    return ListTile(
      leading: _emojiIcon('🎨'),
      title: Text(l10n.themeMode),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            _getThemeModeName(l10n, settings.themeMode),
            style: TextStyle(color: colorScheme.onSurfaceVariant),
          ),
          const SizedBox(width: AppSpacing.xs),
          const Icon(Icons.chevron_right),
        ],
      ),
      onTap: () => _showThemeModeDialog(context, l10n, settings, controller),
    );
  }

  Widget _buildLanguageTile(
    BuildContext context,
    AppLocalizations l10n,
    AppSettingsState settings,
    AppSettings controller,
  ) {
    final colorScheme = Theme.of(context).colorScheme;
    return ListTile(
      leading: _emojiIcon('🌐'),
      title: Text(l10n.language),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            _getLanguageName(l10n, settings.locale),
            style: TextStyle(color: colorScheme.onSurfaceVariant),
          ),
          const SizedBox(width: AppSpacing.xs),
          const Icon(Icons.chevron_right),
        ],
      ),
      onTap: () => _showLanguageDialog(context, l10n, settings, controller),
    );
  }

  String _getThemeModeName(AppLocalizations l10n, ThemeMode mode) {
    return switch (mode) {
      ThemeMode.light => l10n.themeModeLight,
      ThemeMode.dark => l10n.themeModeDark,
      ThemeMode.system => l10n.themeModeSystem,
    };
  }

  String _getLanguageName(AppLocalizations l10n, Locale locale) {
    return switch (locale.languageCode) {
      'zh' => l10n.languageChinese,
      _ => l10n.languageEnglish,
    };
  }

  void _showThemeModeDialog(
    BuildContext context,
    AppLocalizations l10n,
    AppSettingsState settings,
    AppSettings controller,
  ) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.themeMode),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildThemeOption(
              context,
              l10n,
              settings,
              controller,
              ThemeMode.system,
              '⚙️',
              l10n.themeModeSystem,
            ),
            _buildThemeOption(
              context,
              l10n,
              settings,
              controller,
              ThemeMode.light,
              '☀️',
              l10n.themeModeLight,
            ),
            _buildThemeOption(
              context,
              l10n,
              settings,
              controller,
              ThemeMode.dark,
              '🌛',
              l10n.themeModeDark,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildThemeOption(
    BuildContext context,
    AppLocalizations l10n,
    AppSettingsState settings,
    AppSettings controller,
    ThemeMode mode,
    String emoji,
    String label,
  ) {
    final isSelected = settings.themeMode == mode;
    return ListTile(
      leading: Icon(
        isSelected ? Icons.check_circle : Icons.circle_outlined,
        color: isSelected
            ? Theme.of(context).colorScheme.primary
            : Theme.of(context).colorScheme.outline,
      ),
      title: Row(
        children: [
          Text(emoji, style: const TextStyle(fontSize: 20)),
          const SizedBox(width: 12),
          Text(label),
        ],
      ),
      selected: isSelected,
      onTap: () {
        controller.setThemeMode(mode);
        Navigator.pop(context);
      },
    );
  }

  void _showLanguageDialog(
    BuildContext context,
    AppLocalizations l10n,
    AppSettingsState settings,
    AppSettings controller,
  ) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.language),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildLanguageOption(
              context,
              l10n,
              settings,
              controller,
              const Locale('en'),
              '🇺🇸',
              l10n.languageEnglish,
            ),
            _buildLanguageOption(
              context,
              l10n,
              settings,
              controller,
              const Locale('zh'),
              '🇨🇳',
              l10n.languageChinese,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLanguageOption(
    BuildContext context,
    AppLocalizations l10n,
    AppSettingsState settings,
    AppSettings controller,
    Locale locale,
    String emoji,
    String label,
  ) {
    final isSelected = settings.locale == locale;
    return ListTile(
      leading: Icon(
        isSelected ? Icons.check_circle : Icons.circle_outlined,
        color: isSelected
            ? Theme.of(context).colorScheme.primary
            : Theme.of(context).colorScheme.outline,
      ),
      title: Row(
        children: [
          Text(emoji, style: const TextStyle(fontSize: 20)),
          const SizedBox(width: 12),
          Text(label),
        ],
      ),
      selected: isSelected,
      onTap: () {
        controller.setLocale(locale);
        Navigator.pop(context);
      },
    );
  }
}
