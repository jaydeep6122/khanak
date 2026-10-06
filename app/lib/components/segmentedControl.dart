import 'package:flutter/material.dart';
import 'package:khanak/global/themes.dart';

/// An iOS-style segmented control: a grey track with a white thumb that
/// slides to the picked option.
class SegmentedControl<T> extends StatelessWidget {
  final List<T> options;
  final T selected;
  final String Function(T) label;
  final ValueChanged<T> onChanged;

  const SegmentedControl({
    super.key,
    required this.options,
    required this.selected,
    required this.label,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final index = options.indexOf(selected);
    return Container(
      height: 40,
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(color: colors.surfaceAlt, borderRadius: BorderRadius.circular(AppTheme.radiusSm)),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final width = constraints.maxWidth / options.length;
          return Stack(
            children: [
              if (index >= 0)
                AnimatedPositioned(
                  duration: const Duration(milliseconds: 220),
                  curve: Curves.easeOutCubic,
                  left: width * index,
                  top: 0,
                  bottom: 0,
                  width: width,
                  child: Container(
                    decoration: BoxDecoration(
                      color: context.isDark ? colors.muted.withValues(alpha: 0.35) : colors.surface,
                      borderRadius: BorderRadius.circular(11),
                      boxShadow: [
                        BoxShadow(
                          color: colors.shadow.withValues(alpha: 0.14),
                          blurRadius: 3,
                          offset: const Offset(0, 1),
                        ),
                      ],
                    ),
                  ),
                ),
              Row(
                children: [
                  for (final option in options)
                    Expanded(
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: () => onChanged(option),
                        child: Center(
                          child: Text(
                            label(option),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: context.text.labelLarge?.copyWith(
                              fontSize: 14,
                              fontWeight: option == selected ? FontWeight.w600 : FontWeight.w500,
                              color: option == selected ? colors.ink : colors.inkSecondary,
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }
}
