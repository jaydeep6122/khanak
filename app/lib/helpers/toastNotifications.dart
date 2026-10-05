import 'package:another_flushbar/flushbar.dart';
import 'package:flutter/material.dart';
import 'package:khanak/global/themes.dart';
import 'package:khanak/helpers/navigation.dart';

void _showToast({
  required String message,
  required Color color,
  required IconData icon,
  required int durationSeconds,
}) {
  final context = navigatorKey.currentContext;
  if (context == null || message.trim().isEmpty) return;

  WidgetsBinding.instance.addPostFrameCallback((_) {
    final activeContext = navigatorKey.currentContext;
    if (activeContext == null) return;
    
    Flushbar<void>(
      message: message,
      icon: Icon(icon, color: Colors.white, size: 22),
      shouldIconPulse: false,
      backgroundColor: color,
      duration: Duration(seconds: durationSeconds),
      flushbarPosition: FlushbarPosition.TOP,
      flushbarStyle: FlushbarStyle.FLOATING,
      messageColor: Colors.white,
      messageSize: 14,
      borderRadius: BorderRadius.circular(AppTheme.radiusMd),
      margin: const EdgeInsets.all(AppTheme.spaceMd),
      padding: const EdgeInsets.symmetric(
        horizontal: AppTheme.spaceLg,
        vertical: AppTheme.spaceMd + 2,
      ),
      animationDuration: const Duration(milliseconds: 300),
      forwardAnimationCurve: Curves.easeOutCubic,
      isDismissible: true,
      dismissDirection: FlushbarDismissDirection.VERTICAL,
    ).show(activeContext);
  });
}

void showSuccessToast(String message, {int durationSeconds = 3}) => _showToast(
  message: message,
  color: AppTheme.success,
  icon: Icons.check_circle_rounded,
  durationSeconds: durationSeconds,
);

/// Errors stay a little longer: they usually need reading.
void showErrorToast(String message, {int durationSeconds = 4}) => _showToast(
  message: message,
  color: AppTheme.error,
  icon: Icons.error_rounded,
  durationSeconds: durationSeconds,
);

void showInfoToast(String message, {int durationSeconds = 3}) => _showToast(
  message: message,
  color: AppTheme.info,
  icon: Icons.info_rounded,
  durationSeconds: durationSeconds,
);
