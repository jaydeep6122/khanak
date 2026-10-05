import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:khanak/components/appButton.dart';
import 'package:khanak/global/themes.dart';
import 'package:khanak/helpers/navigation.dart';
import 'package:khanak/helpers/toastNotifications.dart';
import 'package:khanak/screens/update/maintenance.dart';
import 'package:khanak/services/appUpdateService.dart';

/// Replaces every open screen with [MaintenanceScreen] or [UpdateScreen]
/// when the app cannot be used. True when it did, so the caller stops what it
/// was about to open.
Future<bool> blockIfUnavailable() async {
  if (AppUpdateService.blocked) return true;
  final block = await AppUpdateService.check();
  if (block == null || AppUpdateService.blocked) {
    return AppUpdateService.blocked;
  }
  showBlock(block);
  return true;
}

/// Puts the screen for [block] in place of everything that is open.
void showBlock(AppBlock block) {
  AppUpdateService.blocked = true;
  navigatorKey.currentState?.pushAndRemoveUntil(
    getPageRoute(switch (block) {
      UnderMaintenance() => const MaintenanceScreen(),
      RequiredUpdate() => UpdateScreen(update: block),
    }),
    (route) => false,
  );
}

/// Shown instead of the app when this build is too old to use. There is no
/// way past it: back does nothing, and only updating from the store gets the
/// person back to their books.
class UpdateScreen extends StatelessWidget {
  final RequiredUpdate update;

  const UpdateScreen({super.key, required this.update});

  Future<void> _openStore() async {
    final url = update.storeUrl;
    if (url == null) return;
    if (!await launchUrl(
      Uri.parse(url),
      mode: LaunchMode.externalApplication,
    )) {
      showErrorToast('update_store_failed'.tr());
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return PopScope(
      canPop: false,
      child: Scaffold(
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(AppTheme.space2xl),
            child: Column(
              children: [
                const Spacer(),
                Container(
                  width: 88,
                  height: 88,
                  decoration: BoxDecoration(
                    color: colors.primarySoft,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.system_update_rounded,
                    size: 40,
                    color: colors.primary,
                  ),
                ),
                const SizedBox(height: AppTheme.spaceXl),
                Text(
                  'update_title'.tr(),
                  style: context.text.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: AppTheme.spaceSm),
                Text(
                  'update_message'.tr(),
                  style: context.text.bodyMedium,
                  textAlign: TextAlign.center,
                ),
                const Spacer(),
                if (update.storeUrl != null)
                  AppButton(
                    text: 'update_now'.tr(),
                    icon: Icons.download_rounded,
                    onPressed: _openStore,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
