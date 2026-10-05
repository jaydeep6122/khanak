import 'package:flutter/material.dart';
import 'package:khanak/global/themes.dart';

/// Khanak's mark: three bricks laid in a bond, drawn in the theme's brick
/// colour. Stands in for a logo image until there is one.
class BrickMark extends StatelessWidget {
  final double size;

  const BrickMark({super.key, this.size = 56});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final brick = size * 0.42;
    final gap = size * 0.06;

    Widget block(double width) => Container(
      width: width,
      height: size * 0.22,
      decoration: BoxDecoration(
        color: colors.primary,
        borderRadius: BorderRadius.circular(size * 0.04),
      ),
    );

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: colors.primarySoft,
        borderRadius: BorderRadius.circular(size * 0.24),
      ),
      alignment: Alignment.center,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          block(brick),
          SizedBox(height: gap),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [block(brick), SizedBox(width: gap), block(brick)],
          ),
        ],
      ),
    );
  }
}

/// The round badge with a worker's first letter, shown instead of a photo.
class InitialBadge extends StatelessWidget {
  final String letter;
  final double size;
  final bool muted;

  const InitialBadge({super.key, required this.letter, this.size = 42, this.muted = false});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: muted ? colors.surfaceAlt : colors.primarySoft,
        shape: BoxShape.circle,
      ),
      child: Text(
        letter,
        style: context.text.titleMedium?.copyWith(
          color: muted ? colors.muted : colors.primary,
          fontSize: size * 0.42,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
