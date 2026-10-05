import 'package:flutter/material.dart';
import 'package:khanak/global/themes.dart';

enum AppButtonVariant {
  /// The main action on a screen.
  primary,

  /// A softer action next to a primary one.
  secondary,
  outline,

  /// Cancel, delete, sign out.
  danger,
  text,
}

class AppButton extends StatelessWidget {
  final String text;
  final VoidCallback? onPressed;
  final bool isLoading;
  final IconData? icon;
  final AppButtonVariant variant;

  /// Fill the available width.
  final bool expand;

  /// 40 pt tall instead of 52, for buttons inside cards and rows.
  final bool compact;

  const AppButton({
    super.key,
    required this.text,
    this.onPressed,
    this.isLoading = false,
    this.icon,
    this.variant = AppButtonVariant.primary,
    this.expand = true,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final (Color background, Color foreground, BorderSide side) = switch (variant) {
      AppButtonVariant.primary => (colors.primary, colors.onPrimary, BorderSide.none),
      AppButtonVariant.secondary => (colors.primarySoft, colors.primary, BorderSide.none),
      AppButtonVariant.outline => (Colors.transparent, colors.ink, BorderSide(color: colors.border)),
      AppButtonVariant.danger => (colors.danger, Colors.white, BorderSide.none),
      AppButtonVariant.text => (Colors.transparent, colors.primary, BorderSide.none),
    };

    final content = isLoading
        ? SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(strokeWidth: 2.2, color: foreground),
          )
        : Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                Icon(icon, size: compact ? 18 : 20),
                const SizedBox(width: AppTheme.spaceSm),
              ],
              Flexible(child: Text(text, overflow: TextOverflow.ellipsis)),
            ],
          );

    final button = TextButton(
      onPressed: isLoading ? null : onPressed,
      style: TextButton.styleFrom(
        backgroundColor: background,
        foregroundColor: foreground,
        disabledBackgroundColor: isLoading || background == Colors.transparent
            ? background
            : background.withValues(alpha: 0.45),
        disabledForegroundColor: isLoading ? foreground : foreground.withValues(alpha: 0.6),
        minimumSize: Size(0, compact ? 40 : 52),
        padding: EdgeInsets.symmetric(horizontal: compact ? 14 : 20),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTheme.radiusSm),
          side: side,
        ),
        textStyle: context.text.labelLarge?.copyWith(fontSize: compact ? 14 : 15),
      ),
      child: content,
    );

    return expand ? SizedBox(width: double.infinity, child: button) : button;
  }
}
