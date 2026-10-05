import 'package:hive_flutter/hive_flutter.dart';

/// Choices made on this phone. Kept when signing out.
class PreferencesBox {
  static const String boxName = 'preferencesBox';

  static const String themeModeKey = 'themeMode';
  static const String languageKey = 'language';

  static Box get _box => Hive.box(boxName);

  static Future<void> open() async {
    await Hive.openBox(boxName);
  }

  /// 'light', 'dark' or 'system'.
  static Future<void> setThemeMode(String themeMode) async {
    await _box.put(themeModeKey, themeMode);
  }

  static String getThemeMode() => _box.get(themeModeKey) ?? 'system';

  /// A language code such as 'gu', or null until one is picked.
  static Future<void> setLanguage(String code) async {
    await _box.put(languageKey, code);
  }

  static String? getLanguage() => _box.get(languageKey) as String?;
}
