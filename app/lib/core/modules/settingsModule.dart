import 'package:flutter/material.dart';
import 'package:khanak/core/Core.dart';
import 'package:khanak/global/constants.dart';
import 'package:khanak/storage/hive/preferences.dart';

class SettingsModule {
  final Core core;
  SettingsModule(this.core);

  ThemeMode _themeMode = ThemeMode.system;
  ThemeMode get themeMode => _themeMode;

  /// Null until the language is picked on the first launch.
  AppLanguage? _language;
  AppLanguage? get language => _language;

  void load() {
    _themeMode = switch (PreferencesBox.getThemeMode()) {
      'dark' => ThemeMode.dark,
      'light' => ThemeMode.light,
      _ => ThemeMode.system,
    };
    _language = AppLanguage.byCode(PreferencesBox.getLanguage());
    core.notify();
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    _themeMode = mode;
    await PreferencesBox.setThemeMode(mode.name);
    core.notify();
  }

  /// Only remembers the choice; the screen switches the locale itself with
  /// `context.setLocale`, which needs a [BuildContext].
  Future<void> setLanguage(AppLanguage language) async {
    _language = language;
    await PreferencesBox.setLanguage(language.code);
    core.notify();
  }
}
