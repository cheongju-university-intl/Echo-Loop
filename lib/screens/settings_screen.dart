import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../l10n/app_localizations.dart';
import '../providers/settings_provider.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final settingsProvider = context.watch<SettingsProvider>();

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.settings),
      ),
      body: ListView(
        children: [
          _buildSection(
            context,
            title: l10n.appearance,
            children: [
              _buildThemeModeTile(context, l10n, settingsProvider),
              _buildLanguageTile(context, l10n, settingsProvider),
            ],
          ),
          const Divider(height: 32),
          _buildSection(
            context,
            title: l10n.about,
            children: [
              ListTile(
                leading: const Icon(Icons.info_outline),
                title: Text(l10n.version),
                subtitle: const Text('1.0.0'),
              ),
              ListTile(
                leading: const Icon(Icons.description_outlined),
                title: Text(l10n.appDescription),
              ),
            ],
          ),
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
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Text(
            title,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  color: Theme.of(context).colorScheme.primary,
                  fontWeight: FontWeight.bold,
                ),
          ),
        ),
        ...children,
      ],
    );
  }

  Widget _buildThemeModeTile(
    BuildContext context,
    AppLocalizations l10n,
    SettingsProvider provider,
  ) {
    return ListTile(
      leading: Icon(_getThemeIcon(provider.themeMode)),
      title: Text(l10n.themeMode),
      subtitle: Text(_getThemeModeName(l10n, provider.themeMode)),
      trailing: const Icon(Icons.chevron_right),
      onTap: () => _showThemeModeDialog(context, l10n, provider),
    );
  }

  Widget _buildLanguageTile(
    BuildContext context,
    AppLocalizations l10n,
    SettingsProvider provider,
  ) {
    return ListTile(
      leading: const Icon(Icons.language),
      title: Text(l10n.language),
      subtitle: Text(_getLanguageName(l10n, provider.locale)),
      trailing: const Icon(Icons.chevron_right),
      onTap: () => _showLanguageDialog(context, l10n, provider),
    );
  }

  IconData _getThemeIcon(ThemeMode mode) {
    return switch (mode) {
      ThemeMode.light => Icons.light_mode,
      ThemeMode.dark => Icons.dark_mode,
      ThemeMode.system => Icons.brightness_auto,
    };
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
    SettingsProvider provider,
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
              provider,
              ThemeMode.system,
              Icons.brightness_auto,
              l10n.themeModeSystem,
            ),
            _buildThemeOption(
              context,
              l10n,
              provider,
              ThemeMode.light,
              Icons.light_mode,
              l10n.themeModeLight,
            ),
            _buildThemeOption(
              context,
              l10n,
              provider,
              ThemeMode.dark,
              Icons.dark_mode,
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
    SettingsProvider provider,
    ThemeMode mode,
    IconData icon,
    String label,
  ) {
    final isSelected = provider.themeMode == mode;
    return ListTile(
      leading: Radio<ThemeMode>(
        value: mode,
        groupValue: provider.themeMode,
        onChanged: (value) {
          if (value != null) {
            provider.setThemeMode(value);
            Navigator.pop(context);
          }
        },
      ),
      title: Row(
        children: [
          Icon(icon, size: 20),
          const SizedBox(width: 12),
          Text(label),
        ],
      ),
      selected: isSelected,
      onTap: () {
        provider.setThemeMode(mode);
        Navigator.pop(context);
      },
    );
  }

  void _showLanguageDialog(
    BuildContext context,
    AppLocalizations l10n,
    SettingsProvider provider,
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
              provider,
              const Locale('en'),
              l10n.languageEnglish,
            ),
            _buildLanguageOption(
              context,
              l10n,
              provider,
              const Locale('zh'),
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
    SettingsProvider provider,
    Locale locale,
    String label,
  ) {
    final isSelected = provider.locale == locale;
    return ListTile(
      leading: Radio<Locale>(
        value: locale,
        groupValue: provider.locale,
        onChanged: (value) {
          if (value != null) {
            provider.setLocale(value);
            Navigator.pop(context);
          }
        },
      ),
      title: Text(label),
      selected: isSelected,
      onTap: () {
        provider.setLocale(locale);
        Navigator.pop(context);
      },
    );
  }
}
