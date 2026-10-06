import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:khanak/global/themes.dart';
import 'package:khanak/helpers/datePicker.dart';
import 'package:khanak/helpers/formatters.dart';

/// A tappable field that shows a date and opens the picker. Entries cannot
/// be dated in the future, so the picker stops at today.
class DateField extends StatelessWidget {
  final String label;
  final DateTime value;
  final ValueChanged<DateTime> onChanged;
  final DateTime? firstDate;

  const DateField({super.key, required this.label, required this.value, required this.onChanged, this.firstDate});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(AppTheme.radiusSm),
      onTap: () async {
        final picked = await pickAppDate(
          context: context,
          initialDate: value,
          firstDate: firstDate,
          lastDate: DateTime.now(),
        );
        if (picked != null) onChanged(picked);
      },
      child: InputDecorator(
        decoration: InputDecoration(labelText: label, prefixIcon: const Icon(Icons.calendar_today_rounded, size: 20)),
        child: Text(
          Formatters.formatRelativeDate(value, today: 'today'.tr(), yesterday: 'yesterday'.tr()),
          style: context.text.bodyLarge,
        ),
      ),
    );
  }
}

/// A row of large choice chips, one of which is picked.
class ChoiceRow<T> extends StatelessWidget {
  final List<T> options;
  final T? selected;
  final String Function(T) label;
  final IconData Function(T)? icon;
  final ValueChanged<T> onSelected;

  const ChoiceRow({
    super.key,
    required this.options,
    required this.selected,
    required this.label,
    required this.onSelected,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Wrap(
      spacing: AppTheme.spaceSm,
      runSpacing: AppTheme.spaceSm,
      children: [
        for (final option in options)
          ChoiceChip(
            label: Text(label(option)),
            avatar: icon == null
                ? null
                : Icon(icon!(option), size: 18, color: option == selected ? colors.primary : colors.muted),
            selected: option == selected,
            showCheckmark: false,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            onSelected: (_) => onSelected(option),
          ),
      ],
    );
  }
}

/// A label above a group of fields.
class FieldLabel extends StatelessWidget {
  final String text;

  const FieldLabel(this.text, {super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: AppTheme.spaceXs, bottom: AppTheme.spaceSm),
      child: Text(text, style: context.text.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
    );
  }
}

/// A line of what will be saved: "Ramesh · 22,000 × ₹550 / 1000" and its amount.
class PayLine extends StatelessWidget {
  final String label;
  final String? detail;
  final double amount;
  final bool strong;

  const PayLine({super.key, required this.label, this.detail, required this.amount, this.strong = false});

  @override
  Widget build(BuildContext context) {
    final style = strong ? context.text.titleMedium : context.text.bodyLarge;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppTheme.spaceXs),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: style),
                if (detail != null) Text(detail!, style: context.text.bodySmall),
              ],
            ),
          ),
          Text(Formatters.formatCurrency(amount), style: style?.copyWith(fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
}

/// The entry's date as a small pill at the top right of a form ("આજે"),
/// opening the picker. Entries cannot be dated in the future.
class DatePill extends StatelessWidget {
  final DateTime value;
  final ValueChanged<DateTime> onChanged;
  final DateTime? firstDate;

  const DatePill({super.key, required this.value, required this.onChanged, this.firstDate});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Padding(
      padding: const EdgeInsets.only(right: AppTheme.spaceMd),
      child: Center(
        child: Material(
          color: colors.surface,
          shape: const StadiumBorder(),
          child: InkWell(
            customBorder: const StadiumBorder(),
            onTap: () async {
              final picked = await pickAppDate(
                context: context,
                initialDate: value,
                firstDate: firstDate,
                lastDate: DateTime.now(),
              );
              if (picked != null) onChanged(picked);
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.calendar_today_rounded, size: 14, color: colors.muted),
                  const SizedBox(width: 6),
                  Text(
                    Formatters.formatRelativeDate(value, today: 'today'.tr(), yesterday: 'yesterday'.tr()),
                    style: context.text.labelMedium?.copyWith(color: colors.ink, fontSize: 14),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// A note typed straight into a white card, without a box around it.
class NoteCard extends StatelessWidget {
  final TextEditingController controller;
  final String hint;

  const NoteCard({super.key, required this.controller, required this.hint});

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: context.colors.surface,
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
        boxShadow: context.cardShadow,
      ),
      child: TextField(
        controller: controller,
        minLines: 1,
        maxLines: 4,
        textCapitalization: TextCapitalization.sentences,
        style: context.text.bodyLarge,
        decoration: InputDecoration(
          hintText: hint,
          filled: false,
          border: InputBorder.none,
          enabledBorder: InputBorder.none,
          focusedBorder: InputBorder.none,
          prefixIcon: const Icon(Icons.notes_rounded, size: 20),
          contentPadding: const EdgeInsets.symmetric(horizontal: AppTheme.spaceLg, vertical: 16),
        ),
      ),
    );
  }
}

/// Choices as small tiles with an icon, three to a row; the picked one is
/// filled with ink.
class ChoiceGrid<T> extends StatelessWidget {
  final List<T> options;
  final T? selected;
  final String Function(T) label;
  final IconData Function(T) icon;
  final Color Function(BuildContext context, T option) iconColor;
  final ValueChanged<T> onSelected;

  const ChoiceGrid({
    super.key,
    required this.options,
    required this.selected,
    required this.label,
    required this.icon,
    required this.iconColor,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final radius = BorderRadius.circular(AppTheme.radiusMd);
    return GridView.count(
      crossAxisCount: 3,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: AppTheme.spaceSm,
      crossAxisSpacing: AppTheme.spaceSm,
      childAspectRatio: 1.15,
      children: [
        for (final option in options)
          AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            decoration: BoxDecoration(borderRadius: radius, boxShadow: option == selected ? null : context.cardShadow),
            child: Material(
              color: option == selected ? colors.ink : colors.surface,
              borderRadius: radius,
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                onTap: () => onSelected(option),
                child: Padding(
                  padding: const EdgeInsets.all(AppTheme.spaceSm),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        icon(option),
                        size: 24,
                        color: option == selected ? colors.onInk : iconColor(context, option),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        label(option),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                        style: context.text.labelMedium?.copyWith(
                          color: option == selected ? colors.onInk : colors.ink,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
