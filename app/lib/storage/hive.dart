import 'package:khanak/storage/hive/cache.dart';
import 'package:khanak/storage/hive/user.dart';
import 'package:khanak/storage/hive/preferences.dart';

Future<void> openAllBoxes() async {
  await Future.wait([
    CacheBox.open(),
    UserBox.open(),
    PreferencesBox.open(),
  ]);
}

Future<void> clearBoxes() async {
  await Future.wait([
    CacheBox.clear(),
    UserBox.clear(),
  ]);
}
