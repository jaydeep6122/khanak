import 'package:flutter/material.dart';
import 'package:khanak/global/themes.dart';

/// White surface floating on a soft shadow, for list rows, sections and
/// summaries.
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

    final radius = BorderRadius.circular(AppTheme.radiusLg);

    return DecoratedBox(
      decoration: BoxDecoration(borderRadius: radius, boxShadow: context.cardShadow),
      child: Material(
        color: color ?? colors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: radius,
          side: borderColor == null ? BorderSide.none : BorderSide(color: borderColor!),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          onLongPress: onLongPress,
          child: Padding(padding: padding, child: child),
        ),
      ),
    );
  }
}
