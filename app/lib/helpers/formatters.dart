import 'package:intl/intl.dart';

class Formatters {
  Formatters._();

  static final NumberFormat _rupees = NumberFormat.currency(
    locale: 'en_IN',
    symbol: '₹',
    decimalDigits: 2,
  );

  static final NumberFormat _rupeesWhole = NumberFormat.currency(
    locale: 'en_IN',
    symbol: '₹',
    decimalDigits: 0,
  );

  // English month names in every app language: these dates also go into
  // PDFs, Excel files and WhatsApp messages, and the PDF fonts have no Hindi
  // or Gujarati letters.
  static final DateFormat _date = DateFormat('dd MMM yyyy', 'en_US');
  static final DateFormat _dateShort = DateFormat('dd MMM', 'en_US');
  static final DateFormat _dateTime = DateFormat('dd MMM yyyy, hh:mm a', 'en_US');
  static final DateFormat _apiDate = DateFormat('yyyy-MM-dd');

  static double _roundPaise(double amount) => (amount * 100).roundToDouble() / 100;

  /// ₹4,720 for whole rupees, ₹4,720.50 otherwise (Indian digit grouping).
  static String formatCurrency(double amount) {
    final rounded = _roundPaise(amount);
    return rounded == rounded.truncateToDouble()
        ? _rupeesWhole.format(rounded)
        : _rupees.format(rounded);
  }

  /// Always with paise: ₹4,720.00.
  static String formatCurrencyExact(double amount) => _rupees.format(_roundPaise(amount));

  /// Short form for tight spaces: ₹12.4L, ₹3.2Cr; smaller amounts in full.
  static String formatCompactCurrency(double amount) {
    final absolute = amount.abs();
    final sign = amount < 0 ? '-' : '';
    if (absolute >= 10000000) {
      return '$sign₹${formatNumber(absolute / 10000000, maxDecimals: 1)}Cr';
    }
    if (absolute >= 100000) {
      return '$sign₹${formatNumber(absolute / 100000, maxDecimals: 1)}L';
    }
    return formatCurrency(amount);
  }

  static final NumberFormat _count = NumberFormat('#,##,##0.###', 'en_IN');

  /// A count to read, grouped the Indian way: 245000 → "2,45,000". Not for
  /// filling a text field; use [formatNumber] there.
  static String formatCount(num value) => _count.format(value);

  /// Without trailing zeros: 250.5 → "250.5", 10.0 → "10".
  static String formatNumber(double value, {int maxDecimals = 3}) {
    var text = value.toStringAsFixed(maxDecimals);
    if (text.contains('.')) {
      text = text.replaceFirst(RegExp(r'0+$'), '');
      text = text.replaceFirst(RegExp(r'\.$'), '');
    }
    return text == '-0' ? '0' : text;
  }

  /// "25 BAG", "120.5 KGS".
  static String formatQuantity(double quantity, [String? unitCode]) {
    final number = formatNumber(quantity);
    return unitCode == null || unitCode.isEmpty ? number : '$number $unitCode';
  }

  static String formatPercent(double value) => '${formatNumber(value, maxDecimals: 2)}%';

  /// Two decimals at most, no trailing zeros.
  static String formatDouble(double value) => formatNumber(value, maxDecimals: 2);

  static String formatDate(DateTime date) => _date.format(date);

  static String formatDateShort(DateTime date) => _dateShort.format(date);

  static String formatDateTime(DateTime date) => _dateTime.format(date.toLocal());

  static String apiDateFormat(DateTime date) => _apiDate.format(date);

  /// "Today", "Yesterday", or the date.
  static String formatRelativeDate(DateTime date, {String today = 'Today', String yesterday = 'Yesterday'}) {
    final now = DateTime.now();
    final day = DateTime(date.year, date.month, date.day);
    final difference = DateTime(now.year, now.month, now.day).difference(day).inDays;
    if (difference == 0) return today;
    if (difference == 1) return yesterday;
    return formatDate(date);
  }

  /// Indian system: 12,34,567 → "Twelve Lakh Thirty Four Thousand Five Hundred Sixty Seven".
  static String numberToWords(int number) {
    if (number == 0) return 'Zero';
    const units = [
      '', 'One', 'Two', 'Three', 'Four', 'Five', 'Six', 'Seven', 'Eight',
      'Nine', 'Ten', 'Eleven', 'Twelve', 'Thirteen', 'Fourteen', 'Fifteen',
      'Sixteen', 'Seventeen', 'Eighteen', 'Nineteen',
    ];
    const tens = [
      '', '', 'Twenty', 'Thirty', 'Forty', 'Fifty', 'Sixty', 'Seventy',
      'Eighty', 'Ninety',
    ];

    String convert(int n) {
      if (n < 20) return units[n];
      if (n < 100) {
        return '${tens[n ~/ 10]}${n % 10 != 0 ? ' ${units[n % 10]}' : ''}';
      }
      if (n < 1000) {
        return '${units[n ~/ 100]} Hundred${n % 100 != 0 ? ' ${convert(n % 100)}' : ''}';
      }
      if (n < 100000) {
        return '${convert(n ~/ 1000)} Thousand${n % 1000 != 0 ? ' ${convert(n % 1000)}' : ''}';
      }
      if (n < 10000000) {
        return '${convert(n ~/ 100000)} Lakh${n % 100000 != 0 ? ' ${convert(n % 100000)}' : ''}';
      }
      return '${convert(n ~/ 10000000)} Crore${n % 10000000 != 0 ? ' ${convert(n % 10000000)}' : ''}';
    }

    return convert(number);
  }

  /// "Rupees Four Thousand Seven Hundred Twenty and Fifty Paise Only".
  static String amountInWords(double amount) {
    final rounded = _roundPaise(amount.abs());
    final rupees = rounded.truncate();
    final paise = ((rounded - rupees) * 100).round();
    final paiseText = paise > 0 ? ' and ${numberToWords(paise)} Paise' : '';
    return 'Rupees ${numberToWords(rupees)}$paiseText Only';
  }
}
