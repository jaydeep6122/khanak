import 'package:flutter/material.dart';
import 'package:khanak/global/themes.dart';

/// The kinds of entry, each with its own icon and colour so a row is
/// recognised before it is read.
enum Tint {
  bricks,
  fire,
  money,
  truck,
  expense,
  work,
  neutral;

  IconData get icon => switch (this) {
    Tint.bricks => Icons.grid_view_rounded,
    Tint.fire => Icons.local_fire_department_rounded,
    Tint.money => Icons.payments_rounded,
    Tint.truck => Icons.local_shipping_rounded,
    Tint.expense => Icons.receipt_long_rounded,
    Tint.work => Icons.handyman_rounded,
    Tint.neutral => Icons.circle_outlined,
  };

  Color color(BuildContext context) {
    final c = context.colors;
    return switch (this) {
      Tint.bricks => c.primary,
      Tint.fire => c.warning,
      Tint.money => c.success,
      Tint.truck => c.info,
      Tint.expense => c.violet,
      Tint.work || Tint.neutral => c.inkSecondary,
    };
  }

  Color soft(BuildContext context) {
    final c = context.colors;
    return switch (this) {
      Tint.bricks => c.primarySoft,
      Tint.fire => c.warningSoft,
      Tint.money => c.successSoft,
      Tint.truck => c.infoSoft,
      Tint.expense => c.violetSoft,
      Tint.work || Tint.neutral => c.surfaceAlt,
    };
  }
}

/// A rounded square holding an icon in a soft tint.
class TintIcon extends StatelessWidget {
  final Tint tint;
  final IconData? icon;
  final double size;

  const TintIcon({super.key, required this.tint, this.icon, this.size = 36});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(color: tint.soft(context), borderRadius: BorderRadius.circular(size * 0.33)),
      alignment: Alignment.center,
      child: Icon(icon ?? tint.icon, size: size * 0.52, color: tint.color(context)),
    );
  }
}
