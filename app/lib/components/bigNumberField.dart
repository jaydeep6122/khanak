import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:khanak/global/themes.dart';
import 'package:khanak/helpers/formatters.dart';
import 'package:khanak/helpers/inputFormatters.dart';

/// The main number of a form, typed large in the middle of the screen, with
/// buttons that add round amounts ("+1,000").
class BigNumberField extends StatelessWidget {
  final TextEditingController controller;
  final String label;

  /// Shown before the number, such as "₹".
  final String? prefix;
  final List<int> quickAdds;
  final FormFieldValidator<String>? validator;
  final bool decimal;
  final bool autofocus;

  const BigNumberField({
    super.key,
    required this.controller,
    required this.label,
    this.prefix,
    this.quickAdds = const [],
    this.validator,
    this.decimal = false,
    this.autofocus = false,
  });

  void _add(int amount) {
    final current = double.tryParse(controller.text.replaceAll(',', '')) ?? 0;
    final next = current + amount;
    controller.text = next == next.roundToDouble() ? '${next.round()}' : Formatters.formatDouble(next);
    controller.selection = TextSelection.collapsed(offset: controller.text.length);
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final style = context.text.displaySmall?.copyWith(fontSize: 54, letterSpacing: -2, height: 1.05);
    return Column(
      children: [
        Text(label, style: context.text.labelMedium),
        const SizedBox(height: AppTheme.spaceSm),
        TextFormField(
          controller: controller,
          autofocus: autofocus,
          textAlign: TextAlign.center,
          keyboardType: TextInputType.numberWithOptions(decimal: decimal),
          inputFormatters: [decimal ? DecimalInputFormatter(decimals: 2) : FilteringTextInputFormatter.digitsOnly],
          style: style,
          cursorColor: colors.primary,
          validator: validator,
          decoration: InputDecoration(
            filled: false,
            isDense: true,
            contentPadding: EdgeInsets.zero,
            border: InputBorder.none,
            enabledBorder: InputBorder.none,
            focusedBorder: InputBorder.none,
            errorBorder: InputBorder.none,
            focusedErrorBorder: InputBorder.none,
            hintText: '0',
            hintStyle: style?.copyWith(color: colors.muted.withValues(alpha: 0.4)),
            prefixText: prefix,
            prefixStyle: style?.copyWith(color: colors.muted),
            errorStyle: context.text.bodySmall?.copyWith(color: colors.danger),
          ),
        ),
        if (quickAdds.isNotEmpty) ...[
          const SizedBox(height: AppTheme.spaceMd),
          Wrap(
            spacing: AppTheme.spaceSm,
            runSpacing: AppTheme.spaceSm,
            alignment: WrapAlignment.center,
            children: [
              for (final amount in quickAdds)
                QuickChip(text: '+${Formatters.formatCount(amount)}', onTap: () => _add(amount)),
            ],
          ),
        ],
      ],
    );
  }
}

/// A small white pill button.
class QuickChip extends StatelessWidget {
  final String text;
  final VoidCallback onTap;
  final bool selected;

  const QuickChip({super.key, required this.text, required this.onTap, this.selected = false});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppTheme.radiusFull),
        boxShadow: selected ? null : context.cardShadow,
      ),
      child: Material(
        color: selected ? colors.ink : colors.surface,
        shape: const StadiumBorder(),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            child: Text(
              text,
              style: context.text.labelMedium?.copyWith(
                color: selected ? colors.onInk : colors.inkSecondary,
                fontSize: 14,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
