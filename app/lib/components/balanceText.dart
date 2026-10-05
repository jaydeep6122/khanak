import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:khanak/global/themes.dart';
import 'package:khanak/helpers/formatters.dart';

/// A worker's balance in words: "To pay ₹3,175" when the factory owes them,
/// "To get ₹4,000" when they took more than they earned.
class BalanceText extends StatelessWidget {
  final double balance;
  final bool large;

  const BalanceText({super.key, required this.balance, this.large = false});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final (label, color) = balance > 0.004
        ? ('to_pay'.tr(), colors.danger)
        : balance < -0.004
        ? ('to_get'.tr(), colors.success)
        : ('settled_up'.tr(), colors.muted);
    final amount = balance.abs() < 0.005 ? '' : Formatters.formatCurrency(balance.abs());

    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (amount.isNotEmpty)
          Text(
            amount,
            style: (large ? context.text.headlineMedium : context.text.titleMedium)?.copyWith(
              color: color,
              fontWeight: FontWeight.w700,
            ),
          ),
        Text(label, style: (large ? context.text.bodyLarge : context.text.bodySmall)?.copyWith(color: color)),
      ],
    );
  }
}
