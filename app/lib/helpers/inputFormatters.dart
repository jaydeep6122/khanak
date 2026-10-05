import 'package:flutter/services.dart';

/// Allows only a number with at most [decimals] decimal places while typing
/// (amounts: 2, quantities: 3, rates: 4).
class DecimalInputFormatter extends TextInputFormatter {
  final int decimals;
  final bool allowNegative;

  DecimalInputFormatter({this.decimals = 2, this.allowNegative = false});

  late final RegExp _pattern = RegExp(
    decimals == 0
        ? '^${allowNegative ? '-?' : ''}\\d*\$'
        : '^${allowNegative ? '-?' : ''}\\d*(\\.\\d{0,$decimals})?\$',
  );

  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    return _pattern.hasMatch(newValue.text) ? newValue : oldValue;
  }
}

/// Upper-cases as the user types (GSTIN, PAN, IFSC, vehicle numbers).
class UpperCaseTextFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    return newValue.copyWith(text: newValue.text.toUpperCase());
  }
}

/// Amount text ready to send to the API: trimmed, without grouping commas,
/// or null when empty.
String? apiAmount(String? input) {
  final text = input?.trim().replaceAll(',', '');
  return text == null || text.isEmpty ? null : text;
}
