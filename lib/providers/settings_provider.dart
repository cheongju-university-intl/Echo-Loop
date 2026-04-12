import 'dart:ui' show PlatformDispatcher;

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'settings_provider.g.dart';

const _themeModeKey = 'theme_mode';
const _localeKey = 'locale';
const _nativeLanguageKey = 'native_language';
const _timeMachineDateTimeKey = 'developer_time_machine_at_ms';
const _legacyUnlockAllReviewsKey = 'unlock_all_reviews';
const _demoModeKey = 'demo_mode';

/// 支持的母语列表（BCP 47 代码 → 本地名称）
///
/// 后续扩展只需在此处添加条目。
const supportedNativeLanguages = <String, String>{
  'zh-CN': '简体中文',
  'zh-TW': '繁體中文',
};

/// 根据系统 locale 匹配母语。
///
/// 匹配规则：
/// 1. 精确匹配 languageCode + countryCode（如 zh-CN）
/// 2. languageCode 匹配第一个同语言条目（如系统 zh → zh-CN）
/// 3. 无匹配 → 列表第一个
String matchNativeLanguage(Locale systemLocale) {
  final codes = supportedNativeLanguages.keys.toList();

  // 精确匹配：languageCode + countryCode
  final systemTag =
      systemLocale.countryCode != null
          ? '${systemLocale.languageCode}-${systemLocale.countryCode}'
          : systemLocale.languageCode;
  if (supportedNativeLanguages.containsKey(systemTag)) return systemTag;

  // languageCode 模糊匹配
  for (final code in codes) {
    if (code.split('-').first == systemLocale.languageCode) return code;
  }

  // 回退到列表第一个
  return codes.first;
}

class AppSettingsState {
  final ThemeMode themeMode;

  /// 用户选择的界面语言（BCP 47）。
  ///
  /// 为 null 时表示跟随系统语言，不支持的系统语言回退到英语。
  final Locale? locale;

  /// 用户的母语（BCP 47 代码），用于 AI 翻译/解析的目标语言。
  ///
  /// 首次启动时根据系统语言自动匹配并持久化。
  final String nativeLanguage;

  /// 开发者选项：时光机时间。
  ///
  /// 为 null 时表示使用系统真实时间。
  final DateTime? timeMachineDateTime;

  /// 开发者选项：演示模式。
  ///
  /// 开启后使用独立的演示数据库，展示精心设计的假数据。
  final bool isDemoMode;

  /// 演示模式切换中的加载状态。
  final bool isDemoModeLoading;

  const AppSettingsState({
    this.themeMode = ThemeMode.system,
    this.locale,
    this.nativeLanguage = 'zh-CN',
    this.timeMachineDateTime,
    this.isDemoMode = false,
    this.isDemoModeLoading = false,
  });

  AppSettingsState copyWith({
    ThemeMode? themeMode,
    Locale? locale,
    bool clearLocale = false,
    String? nativeLanguage,
    DateTime? timeMachineDateTime,
    bool clearTimeMachineDateTime = false,
    bool? isDemoMode,
    bool? isDemoModeLoading,
  }) {
    return AppSettingsState(
      themeMode: themeMode ?? this.themeMode,
      locale: clearLocale ? null : locale ?? this.locale,
      nativeLanguage: nativeLanguage ?? this.nativeLanguage,
      timeMachineDateTime: clearTimeMachineDateTime
          ? null
          : timeMachineDateTime ?? this.timeMachineDateTime,
      isDemoMode: isDemoMode ?? this.isDemoMode,
      isDemoModeLoading: isDemoModeLoading ?? this.isDemoModeLoading,
    );
  }
}

@Riverpod(keepAlive: true)
class AppSettings extends _$AppSettings {
  @override
  AppSettingsState build() {
    _loadSettings();
    return const AppSettingsState();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();

    final themeModeString = prefs.getString(_themeModeKey) ?? 'system';
    final themeMode = switch (themeModeString) {
      'light' => ThemeMode.light,
      'dark' => ThemeMode.dark,
      _ => ThemeMode.system,
    };

    // 界面语言：兼容旧值 'zh' → 'zh-CN'
    final localeString = prefs.getString(_localeKey);
    final Locale? locale = switch (localeString) {
      'en' => const Locale('en'),
      'zh' || 'zh-CN' => const Locale('zh', 'CN'),
      _ => null, // 'system' 或无值时跟随系统
    };

    // 母语：首次启动时根据系统语言匹配并持久化
    final nativeLanguage = await _loadNativeLanguage(prefs);

    final timeMachineDateTime = await _loadTimeMachineDateTime(prefs);
    final isDemoMode = prefs.getBool(_demoModeKey) ?? false;

    state = state.copyWith(
      themeMode: themeMode,
      locale: locale,
      nativeLanguage: nativeLanguage,
      timeMachineDateTime: timeMachineDateTime,
      isDemoMode: isDemoMode,
    );
  }

  /// 加载母语设置，首次启动时自动匹配系统语言并持久化。
  Future<String> _loadNativeLanguage(SharedPreferences prefs) async {
    final stored = prefs.getString(_nativeLanguageKey);
    if (stored != null) return stored;

    // 首次启动：根据系统 locale 匹配
    final systemLocale = PlatformDispatcher.instance.locale;
    final matched = matchNativeLanguage(systemLocale);
    await prefs.setString(_nativeLanguageKey, matched);
    return matched;
  }

  /// 加载时光机时间，并兼容旧版“解锁所有复习”开关。
  Future<DateTime?> _loadTimeMachineDateTime(SharedPreferences prefs) async {
    final storedMillis = prefs.getInt(_timeMachineDateTimeKey);
    if (storedMillis != null) {
      return DateTime.fromMillisecondsSinceEpoch(storedMillis);
    }

    final legacyUnlockAllReviews =
        prefs.getBool(_legacyUnlockAllReviewsKey) ?? false;
    if (!legacyUnlockAllReviews) {
      return null;
    }

    final migratedDateTime = DateTime.now().add(const Duration(days: 365));
    await prefs.setInt(
      _timeMachineDateTimeKey,
      migratedDateTime.millisecondsSinceEpoch,
    );
    await prefs.remove(_legacyUnlockAllReviewsKey);
    return migratedDateTime;
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    state = state.copyWith(themeMode: mode);

    final prefs = await SharedPreferences.getInstance();
    final modeString = switch (mode) {
      ThemeMode.light => 'light',
      ThemeMode.dark => 'dark',
      ThemeMode.system => 'system',
    };
    await prefs.setString(_themeModeKey, modeString);
  }

  /// 设置界面语言（BCP 47）。
  ///
  /// 传入 null 时跟随系统语言。
  Future<void> setLocale(Locale? locale) async {
    state = locale == null
        ? state.copyWith(clearLocale: true)
        : state.copyWith(locale: locale);

    final prefs = await SharedPreferences.getInstance();
    final tag = locale == null
        ? 'system'
        : locale.countryCode != null
            ? '${locale.languageCode}-${locale.countryCode}'
            : locale.languageCode;
    await prefs.setString(_localeKey, tag);
  }

  /// 设置母语（BCP 47 代码）。
  Future<void> setNativeLanguage(String lang) async {
    state = state.copyWith(nativeLanguage: lang);

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_nativeLanguageKey, lang);
  }

  /// 设置开发者时光机时间。
  ///
  /// 传入 null 时恢复系统真实时间。
  Future<void> setTimeMachineDateTime(DateTime? value) async {
    state = state.copyWith(
      timeMachineDateTime: value,
      clearTimeMachineDateTime: value == null,
    );

    final prefs = await SharedPreferences.getInstance();
    if (value == null) {
      await prefs.remove(_timeMachineDateTimeKey);
    } else {
      await prefs.setInt(_timeMachineDateTimeKey, value.millisecondsSinceEpoch);
    }
    await prefs.remove(_legacyUnlockAllReviewsKey);
  }

  /// 设置演示模式加载状态（供 UI 显示 loading 指示器）。
  void setDemoModeLoading(bool loading) {
    state = state.copyWith(isDemoModeLoading: loading);
  }

  /// 持久化演示模式开关状态。
  ///
  /// 数据库切换由调用方（settings_screen）负责，
  /// 此方法只更新 UI 状态和 SharedPreferences。
  Future<void> setDemoMode(bool enabled) async {
    state = state.copyWith(isDemoMode: enabled, isDemoModeLoading: false);

    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_demoModeKey, enabled);
  }
}
