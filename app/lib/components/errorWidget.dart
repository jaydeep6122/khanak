import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:khanak/components/appButton.dart';
import 'package:khanak/global/themes.dart';

class AppErrorWidget extends StatelessWidget {
  final String errorMessage;
  final VoidCallback? onRetry;

  const AppErrorWidget({super.key, required this.errorMessage, this.onRetry});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.space3xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(color: colors.dangerSoft, shape: BoxShape.circle),
              child: Icon(Icons.cloud_off_rounded, size: 32, color: colors.danger),
            ),
            const SizedBox(height: AppTheme.spaceLg),
            Text(
              'error_title'.tr(),
              style: context.text.titleMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppTheme.spaceXs + 2),
            Text(errorMessage, style: context.text.bodyMedium, textAlign: TextAlign.center),
            if (onRetry != null) ...[
              const SizedBox(height: AppTheme.spaceXl),
              AppButton(
                text: 'retry'.tr(),
                icon: Icons.refresh_rounded,
                variant: AppButtonVariant.outline,
                onPressed: onRetry,
                expand: false,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
