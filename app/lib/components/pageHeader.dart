import 'package:flutter/material.dart';
import 'package:khanak/global/themes.dart';

/// The big bold title at the top of a tab ("આજે", "મજૂર"), with an optional
/// line above it and buttons on the right.
class LargeTitle extends StatelessWidget {
  final String title;

  /// Small text above the title, such as the factory's name.
  final Widget? overline;

  /// Shown at the end of the title line, such as a season pill.
  final Widget? badge;
  final List<Widget> actions;

  const LargeTitle({super.key, required this.title, this.overline, this.badge, this.actions = const []});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(AppTheme.spaceXl, AppTheme.spaceMd, AppTheme.spaceXl, AppTheme.spaceLg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (overline != null || actions.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: AppTheme.spaceMd),
              child: Row(
                children: [
                  Expanded(child: overline ?? const SizedBox()),
                  for (final action in actions)
                    Padding(
                      padding: const EdgeInsets.only(left: AppTheme.spaceSm),
                      child: action,
                    ),
                ],
              ),
            ),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(child: Text(title, style: context.text.headlineLarge)),
              ?badge,
            ],
          ),
        ],
      ),
    );
  }
}

/// A round white button with an icon, for the top of a screen.
class CircleButton extends StatelessWidget {
  final IconData? icon;
  final Widget? child;
  final VoidCallback? onTap;
  final String? tooltip;

  /// Filled with ink instead of white, for the main action ("+").
  final bool filled;

  const CircleButton({super.key, this.icon, this.child, this.onTap, this.tooltip, this.filled = false});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final button = DecoratedBox(
      decoration: BoxDecoration(shape: BoxShape.circle, boxShadow: filled ? null : context.cardShadow),
      child: Material(
        color: filled ? colors.ink : colors.surface,
        shape: const CircleBorder(),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: SizedBox(
            width: 38,
            height: 38,
            child: Center(child: child ?? Icon(icon, size: 20, color: filled ? colors.onInk : colors.ink)),
          ),
        ),
      ),
    );
    return tooltip == null ? button : Tooltip(message: tooltip!, child: button);
  }
}

/// A small rounded label with a soft background.
class Pill extends StatelessWidget {
  final String text;
  final Color color;
  final Color background;

  const Pill({super.key, required this.text, required this.color, required this.background});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(color: background, borderRadius: BorderRadius.circular(AppTheme.radiusFull)),
      child: Text(text, style: context.text.labelMedium?.copyWith(color: color)),
    );
  }
}
