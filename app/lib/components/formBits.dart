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

  const DateField({
    super.key,
    required this.label,
    required this.value,
    required this.onChanged,
    this.firstDate,
  });

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
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: const Icon(Icons.calendar_today_rounded, size: 20),
        ),
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
