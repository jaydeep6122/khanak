import 'package:flutter/material.dart';
import 'package:khanak/components/tint.dart';
import 'package:khanak/global/themes.dart';

/// The round badge with a worker's first letter, shown instead of a photo.
/// The letter picks one of a few soft colours, so neighbours in a list
/// look different.
class InitialBadge extends StatelessWidget {
  final String letter;
  final double size;
  final bool muted;

  /// A white ring, for badges that overlap.
  final bool ring;

  const InitialBadge({super.key, required this.letter, this.size = 42, this.muted = false, this.ring = false});

  static const _tints = [Tint.bricks, Tint.truck, Tint.money, Tint.expense, Tint.fire];

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final tint = muted ? Tint.neutral : _tints[letter.runes.fold(0, (a, b) => a + b) % _tints.length];
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: tint.soft(context),
        shape: BoxShape.circle,
        border: ring ? Border.all(color: colors.surface, width: 2) : null,
      ),
      child: Text(
        letter,
        style: context.text.titleMedium?.copyWith(
          color: muted ? colors.muted : tint.color(context),
          fontSize: size * 0.4,
          fontWeight: FontWeight.w600,
          height: 1,
        ),
      ),
    );
  }
}
