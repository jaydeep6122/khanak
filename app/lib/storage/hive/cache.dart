import 'package:hive_flutter/hive_flutter.dart';

/// What the app keeps between launches so it opens straight to the last
/// factory: the signed-in user, their factories and which one was open.
/// Cleared on sign out.
class CacheBox {
  static const String boxName = 'cacheBox';

  static const String userKey = 'user';
  static const String factoriesKey = 'factories';
  static const String selectedFactoryIdKey = 'selectedFactoryId';

  static Box get _box => Hive.box(boxName);

  static Future<void> open() async {
    await Hive.openBox(boxName);
  }

  static Future<void> clear() async {
    await _box.clear();
  }

  static Future<void> setUser(Map<String, dynamic> user) async {
    await _box.put(userKey, user);
  }

  static Map<String, dynamic>? getUser() {
    final value = _box.get(userKey);
    return value is Map ? Map<String, dynamic>.from(value) : null;
  }

  static Future<void> setFactories(List<Map<String, dynamic>> factories) async {
    await _box.put(factoriesKey, factories);
  }

  static List<Map<String, dynamic>> getFactories() {
    final value = _box.get(factoriesKey);
    if (value is! List) return [];
    return value.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
  }

  static Future<void> setSelectedFactoryId(String? id) async {
    await _box.put(selectedFactoryIdKey, id);
  }

  static String? getSelectedFactoryId() => _box.get(selectedFactoryIdKey) as String?;
}
