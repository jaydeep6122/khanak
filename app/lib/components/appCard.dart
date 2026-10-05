import 'package:flutter/material.dart';
import 'package:khanak/global/themes.dart';

/// Bordered surface used for list rows, sections and summaries.
class AppCard extends StatelessWidget {
  final Widget child;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final EdgeInsetsGeometry padding;
  final Color? color;
  final Color? borderColor;

  const AppCard({
    super.key,
    required this.child,
    this.onTap,
    this.onLongPress,
    this.padding = const EdgeInsets.all(AppTheme.spaceLg),
    this.color,
    this.borderColor,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Material(
      color: color ?? colors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
        side: BorderSide(color: borderColor ?? colors.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        onLongPress: onLongPress,
        child: Padding(padding: padding, child: child),
      ),
    );
  }
}
