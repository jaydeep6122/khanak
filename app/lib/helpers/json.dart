/// Tolerant readers for API JSON.
///
/// The backend sends money and quantities as decimal strings ("4720.00"),
/// counts as numbers, and business dates as 'YYYY-MM-DD'.
library;

double asDouble(Object? value, [double fallback = 0]) =>
    asDoubleOrNull(value) ?? fallback;

double? asDoubleOrNull(Object? value) {
  if (value == null) return null;
  if (value is num) return value.toDouble();
  return double.tryParse(value.toString());
}

int asInt(Object? value, [int fallback = 0]) => asIntOrNull(value) ?? fallback;

int? asIntOrNull(Object? value) {
  if (value == null) return null;
  if (value is num) return value.toInt();
  return int.tryParse(value.toString());
}

bool asBool(Object? value, [bool fallback = false]) =>
    value is bool ? value : fallback;

String asString(Object? value, [String fallback = '']) =>
    value?.toString() ?? fallback;

/// A 'YYYY-MM-DD' business date becomes local midnight; a full timestamp is
/// converted to local time.
DateTime? asDate(Object? value) {
  if (value == null) return null;
  final text = value.toString();
  final parsed = DateTime.tryParse(text);
  if (parsed == null) return null;
  return text.length == 10
      ? DateTime(parsed.year, parsed.month, parsed.day)
      : parsed.toLocal();
}

Map<String, dynamic> asMap(Object? value) =>
    value is Map ? Map<String, dynamic>.from(value) : <String, dynamic>{};

Map<String, dynamic>? asMapOrNull(Object? value) =>
    value is Map ? Map<String, dynamic>.from(value) : null;

List<Map<String, dynamic>> asMapList(Object? value) => value is List
    ? value.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList()
    : <Map<String, dynamic>>[];

String _two(int n) => n.toString().padLeft(2, '0');

/// 'YYYY-MM-DD' for sending a business date to the API.
String apiDate(DateTime date) =>
    '${date.year.toString().padLeft(4, '0')}-${_two(date.month)}-${_two(date.day)}';
