import 'dart:async';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:khanak/components/appButton.dart';
import 'package:khanak/global/themes.dart';
import 'package:khanak/helpers/navigation.dart';
import 'package:khanak/helpers/toastNotifications.dart';
import 'package:khanak/screens/splash/splash.dart';
import 'package:khanak/screens/update/update.dart';
import 'package:khanak/services/appUpdateService.dart';

/// Shown instead of the app while the server is under maintenance. Back does
/// nothing; it asks the server again every [_recheckEvery], on "Try again"
/// and when the app comes back to the front, and hands back to the splash
/// screen as soon as maintenance is over, so nobody has to restart the app.
class MaintenanceScreen extends StatefulWidget {
  const MaintenanceScreen({super.key});

  @override
  State<MaintenanceScreen> createState() => _MaintenanceScreenState();
}

class _MaintenanceScreenState extends State<MaintenanceScreen>
    with WidgetsBindingObserver {
  static const _recheckEvery = Duration(seconds: 30);

  Timer? _timer;
  bool _checking = false;
  bool _tapped = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _timer = Timer.periodic(_recheckEvery, (_) => _check());
  }

  @override
  void dispose() {
    _timer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _check();
  }

  Future<void> _check({bool tapped = false}) async {
    if (_checking) return;
    setState(() {
      _checking = true;
      _tapped = tapped;
    });
    // Leave only when the server says maintenance is over, not merely
    // because it could not be reached.
    final block = await AppUpdateService.check(
      whenUnreachable: const UnderMaintenance(),
    );
    if (!mounted) return;
    setState(() => _checking = false);

    switch (block) {
      case UnderMaintenance():
        if (tapped) showInfoToast('maintenance_still_on'.tr());
      case RequiredUpdate():
        showBlock(block);
      case null:
        AppUpdateService.blocked = false;
        Navigator.of(context).pushAndRemoveUntil(
          getPageRoute(const SplashScreen()),
          (route) => false,
        );
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
                    Icons.construction_rounded,
                    size: 40,
                    color: colors.primary,
                  ),
                ),
                const SizedBox(height: AppTheme.spaceXl),
                Text(
                  'maintenance_title'.tr(),
                  style: context.text.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: AppTheme.spaceSm),
                Text(
                  'maintenance_message'.tr(),
                  style: context.text.bodyMedium,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: AppTheme.spaceLg),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppTheme.spaceMd,
                    vertical: AppTheme.spaceXs + 2,
                  ),
                  decoration: BoxDecoration(
                    color: colors.successSoft,
                    borderRadius: BorderRadius.circular(AppTheme.radiusFull),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.verified_user_outlined,
                        size: 16,
                        color: colors.success,
                      ),
                      const SizedBox(width: AppTheme.spaceXs + 2),
                      Flexible(
                        child: Text(
                          'maintenance_data_safe'.tr(),
                          style: context.text.labelMedium?.copyWith(
                            color: colors.success,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const Spacer(),
                AppButton(
                  text: 'retry'.tr(),
                  icon: Icons.refresh_rounded,
                  isLoading: _checking && _tapped,
                  onPressed: () => _check(tapped: true),
                ),
                const SizedBox(height: AppTheme.spaceSm),
                Text(
                  'maintenance_auto_check'.tr(),
                  style: context.text.bodySmall?.copyWith(color: colors.muted),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
