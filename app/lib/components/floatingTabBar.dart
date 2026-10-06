import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:khanak/global/themes.dart';

class FloatingTab {
  final IconData icon;
  final IconData selectedIcon;
  final String label;

  const FloatingTab({required this.icon, required this.selectedIcon, required this.label});
}

/// The bottom bar floating over the page on frosted glass: the tabs with
/// their names, and in the middle a brick-coloured "+" for a new entry.
///
/// Use as a Scaffold's `bottomNavigationBar` with `extendBody: true`.
class FloatingTabBar extends StatelessWidget {
  /// Two tabs go left of the "+", the rest to its right.
  final List<FloatingTab> tabs;
  final int selected;
  final ValueChanged<int> onSelected;
  final String centerLabel;
  final VoidCallback onCenter;

  const FloatingTabBar({
    super.key,
    required this.tabs,
    required this.selected,
    required this.onSelected,
    required this.centerLabel,
    required this.onCenter,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final radius = BorderRadius.circular(30);

    Widget tab(int index) {
      final item = tabs[index];
      final active = index == selected;
      final color = active ? colors.ink : colors.muted;
      return Expanded(
        child: Semantics(
          selected: active,
          button: true,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => onSelected(index),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 160),
                  child: Icon(active ? item.selectedIcon : item.icon, key: ValueKey(active), color: color, size: 25),
                ),
                const SizedBox(height: 3),
                Text(
                  item.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: context.text.labelSmall?.copyWith(
                    color: color,
                    fontWeight: active ? FontWeight.w700 : FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final center = Expanded(
      child: Semantics(
        button: true,
        label: centerLabel,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onCenter,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: colors.primary,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: colors.primary.withValues(alpha: 0.55),
                      blurRadius: 18,
                      spreadRadius: -6,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Icon(Icons.add_rounded, color: colors.onPrimary, size: 28),
              ),
              const SizedBox(height: 3),
              Text(
                centerLabel,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: context.text.labelSmall?.copyWith(color: colors.primary, fontWeight: FontWeight.w700),
              ),
            ],
          ),
        ),
      ),
    );

    return SafeArea(
      top: false,
      minimum: const EdgeInsets.only(bottom: AppTheme.spaceMd),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppTheme.spaceLg),
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: radius,
            boxShadow: [
              BoxShadow(
                color: colors.shadow.withValues(alpha: 0.28),
                blurRadius: 32,
                spreadRadius: -10,
                offset: const Offset(0, 12),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: radius,
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
              child: Container(
                height: 76,
                padding: const EdgeInsets.symmetric(horizontal: 6),
                decoration: BoxDecoration(
                  color: colors.surface.withValues(alpha: context.isDark ? 0.78 : 0.84),
                  borderRadius: radius,
                  border: Border.all(color: colors.border, width: 0.5),
                ),
                child: Row(
                  children: [
                    for (var i = 0; i < tabs.length; i++) ...[if (i == 2) center, tab(i)],
                    if (tabs.length <= 2) center,
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
