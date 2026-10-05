import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:khanak/api/api.dart';
import 'package:khanak/helpers/json.dart';

/// Why the app cannot be used right now.
sealed class AppBlock {
  const AppBlock();
}

/// The server is switched off for maintenance (MAINTENANCE_MODE).
class UnderMaintenance extends AppBlock {
  const UnderMaintenance();
}

/// A build too old to use: the store page to update from, when there is one.
class RequiredUpdate extends AppBlock {
  final String? storeUrl;

  const RequiredUpdate({this.storeUrl});
}

/// Asks the server whether this build may be used: not during maintenance,
/// and not below the oldest build it still supports.
class AppUpdateService {
  AppUpdateService._();

  /// Set while the update or maintenance screen is up. The update screen
  /// stays until the app is updated, which restarts it; the maintenance
  /// screen clears this when it hands back to the app.
  static bool blocked = false;

  static String? get _platform => switch (defaultTargetPlatform) {
    TargetPlatform.android => 'android',
    TargetPlatform.iOS => 'ios',
    _ => null,
  };

  /// Null when this build may be used. When the server cannot be reached the
  /// answer is [whenUnreachable], null by default: being offline must not
  /// lock anyone out of their books.
  static Future<AppBlock?> check({AppBlock? whenUnreachable}) async {
    final platform = _platform;
    if (kIsWeb || platform == null) return null;
    try {
      final (info, json) = await (
        PackageInfo.fromPlatform(),
        Api.instance.app.version(platform),
      ).wait.timeout(const Duration(seconds: 8));
      if (json['maintenance'] == true) return const UnderMaintenance();
      final build = int.tryParse(info.buildNumber) ?? 0;
      final minBuild = asInt(json['min_build']);
      if (build >= minBuild) return null;
      return RequiredUpdate(storeUrl: json['store_url'] as String?);
    } catch (_) {
      return whenUnreachable;
    }
  }
}
