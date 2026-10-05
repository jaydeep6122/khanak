import 'package:hive_flutter/hive_flutter.dart';

class UserBox {
  static const String boxName = 'userBox';

  static const String deviceAuthEnabledKey = 'deviceAuthEnabled';
  static const String lastLoginEmailKey = 'lastLoginEmail';

  static Future<void> open() async {
    await Hive.openBox(boxName);
  }

  static Future<void> close() async {
    final box = Hive.box(boxName);
    await box.close();
  }

  static Future<void> clear() async {
    final box = Hive.box(boxName);
    await box.clear();
  }

  // Data methods
  static Future<void> setDeviceAuthEnabled(bool value) async {
    final box = Hive.box(boxName);
    await box.put(deviceAuthEnabledKey, value);
  }

  static bool getDeviceAuthEnabled() {
    final box = Hive.box(boxName);
    return box.get(deviceAuthEnabledKey) ?? false;
  }

  static Future<void> setLastLoginEmail(String email) async {
    final box = Hive.box(boxName);
    await box.put(lastLoginEmailKey, email);
  }

  static String getLastLoginEmail() {
    final box = Hive.box(boxName);
    return box.get(lastLoginEmailKey) ?? '';
  }
}
