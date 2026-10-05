import 'package:flutter/material.dart';

// Shared date pickers. Colours come from the app theme (including dark mode).

/// Far enough back to enter earlier financial years.
DateTime appDateFirst() => DateTime(DateTime.now().year - 5);

/// Allows forward-dated documents (due dates) without unbounded scrolling.
DateTime appDateLast() => DateTime(DateTime.now().year + 2, 12, 31);

Future<DateTime?> pickAppDate({
  required BuildContext context,
  DateTime? initialDate,
  DateTime? firstDate,
  DateTime? lastDate,
}) {
  final first = firstDate ?? appDateFirst();
  final last = lastDate ?? appDateLast();

  // Clamp rather than let showDatePicker assert when an old record's date
  // sits outside the range.
  var initial = initialDate ?? DateTime.now();
  if (initial.isBefore(first)) initial = first;
  if (initial.isAfter(last)) initial = last;

  return showDatePicker(
    context: context,
    initialDate: initial,
    firstDate: first,
    lastDate: last,
  );
}

Future<DateTimeRange?> pickAppDateRange({
  required BuildContext context,
  DateTimeRange? initialRange,
  DateTime? firstDate,
  DateTime? lastDate,
}) {
  final first = firstDate ?? appDateFirst();
  final last = lastDate ?? appDateLast();

  var initial = initialRange;
  if (initial != null && (initial.start.isBefore(first) || initial.end.isAfter(last))) {
    initial = null;
  }

  return showDateRangePicker(
    context: context,
    firstDate: first,
    lastDate: last,
    initialDateRange: initial,
  );
}
