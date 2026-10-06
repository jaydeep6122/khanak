import 'package:flutter/material.dart';
import 'package:khanak/components/groupedSection.dart';
import 'package:khanak/components/tint.dart';
import 'package:khanak/global/themes.dart';

/// A sheet listing a few choices (a kiln, a truck), the current one ticked.
/// Each shows [tint]'s icon, or its own [leading]. Null when dismissed.
Future<T?> pickOption<T>(
  BuildContext context, {
  required String title,
  required List<T> options,
  required String Function(T) label,
  bool Function(T)? isSelected,
  Tint tint = Tint.neutral,
  Widget Function(T)? leading,
  String? empty,
}) {
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (context) {
      final colors = context.colors;
      return SafeArea(
        top: false,
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.8),
          child: ListView(
            shrinkWrap: true,
            padding: const EdgeInsets.fromLTRB(AppTheme.spaceLg, 0, AppTheme.spaceLg, AppTheme.spaceXl),
            children: [
              Padding(
                padding: const EdgeInsets.only(left: AppTheme.spaceXs, bottom: AppTheme.spaceLg),
                child: Text(title, style: context.text.headlineSmall),
              ),
              if (options.isEmpty && empty != null)
                Padding(
                  padding: const EdgeInsets.all(AppTheme.spaceLg),
                  child: Text(empty, textAlign: TextAlign.center, style: context.text.bodyMedium),
                )
              else
                GroupedSection(
                  children: [
                    for (final option in options)
                      GroupedRow(
                        leading: leading?.call(option) ?? TintIcon(tint: tint),
                        title: label(option),
                        chevron: false,
                        trailing: isSelected?.call(option) == true
                            ? Icon(Icons.check_rounded, color: colors.primary)
                            : null,
                        onTap: () => Navigator.of(context).pop(option),
                      ),
                  ],
                ),
            ],
          ),
        ),
      );
    },
  );
}

/// A whole number changed with − and + buttons, for small counts like trips.
class CountStepper extends StatelessWidget {
  final int value;
  final int min;
  final ValueChanged<int> onChanged;

  const CountStepper({super.key, required this.value, this.min = 1, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    Widget button(IconData icon, VoidCallback? onTap) => Material(
      color: colors.surfaceAlt,
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(6),
          child: Icon(icon, size: 18, color: onTap == null ? colors.muted : colors.ink),
        ),
      ),
    );
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        button(Icons.remove_rounded, value > min ? () => onChanged(value - 1) : null),
        SizedBox(
          width: 40,
          child: Text('$value', textAlign: TextAlign.center, style: context.text.titleMedium),
        ),
        button(Icons.add_rounded, () => onChanged(value + 1)),
      ],
    );
  }
}
