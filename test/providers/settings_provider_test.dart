import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fluency/providers/settings_provider.dart';

void main() {
  group('AppSettingsState', () {
    group('默认值', () {
      test('初始状态正确', () {
        const state = AppSettingsState();

        expect(state.themeMode, ThemeMode.system);
        expect(state.locale, const Locale('en'));
      });
    });

    group('copyWith', () {
      test('setThemeMode 更新状态', () {
        const state = AppSettingsState();
        final copied = state.copyWith(themeMode: ThemeMode.dark);

        expect(copied.themeMode, ThemeMode.dark);
        expect(copied.locale, const Locale('en')); // 未修改
      });

      test('setLocale 更新状态', () {
        const state = AppSettingsState();
        final copied = state.copyWith(locale: const Locale('zh'));

        expect(copied.locale, const Locale('zh'));
        expect(copied.themeMode, ThemeMode.system); // 未修改
      });

      test('同时更新多个字段', () {
        const state = AppSettingsState();
        final copied = state.copyWith(
          themeMode: ThemeMode.light,
          locale: const Locale('ja'),
        );

        expect(copied.themeMode, ThemeMode.light);
        expect(copied.locale, const Locale('ja'));
      });

      test('不传参数时保持原值', () {
        const state = AppSettingsState(
          themeMode: ThemeMode.dark,
          locale: Locale('zh'),
        );
        final copied = state.copyWith();

        expect(copied.themeMode, ThemeMode.dark);
        expect(copied.locale, const Locale('zh'));
      });
    });
  });
}
