import 'package:flutter/material.dart';
import 'package:khanak/components/appButton.dart';
import 'package:khanak/global/themes.dart';

class EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? description;
  final String? buttonText;
  final IconData? buttonIcon;
  final VoidCallback? onButtonPressed;

  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    this.description,
    this.buttonText,
    this.buttonIcon,
    this.onButtonPressed,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppTheme.space3xl,
          vertical: AppTheme.space2xl,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(color: colors.primarySoft, shape: BoxShape.circle),
              child: Icon(icon, size: 32, color: colors.primary),
            ),
            const SizedBox(height: AppTheme.spaceLg),
            Text(title, style: context.text.titleMedium, textAlign: TextAlign.center),
            if (description != null) ...[
              const SizedBox(height: AppTheme.spaceXs + 2),
              Text(description!, style: context.text.bodyMedium, textAlign: TextAlign.center),
            ],
            if (buttonText != null && onButtonPressed != null) ...[
              const SizedBox(height: AppTheme.spaceXl),
              AppButton(
                text: buttonText!,
                icon: buttonIcon,
                onPressed: onButtonPressed,
                expand: false,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
