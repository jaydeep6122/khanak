import 'package:easy_localization/easy_localization.dart';

/// Unique constraints the server reports on a 409, mapped to what went wrong.
const Map<String, String> _constraintMessages = {
  'work_types_name_unique': 'error_work_type_name_exists',
  'trucks_factory_id_number_key': 'error_truck_number_exists',
};

/// Turns a server message into text for the user.
///
/// The server already writes most messages for people ("A supervisor can
/// only give advances"), so those pass through. Validation errors arrive as
/// "groups.0.workers: A group needs at least one worker"; the field path is
/// rewritten to "Row 1 · Workers: ...".
String userFriendlyError(String message, {String? constraint}) {
  final known = constraint == null ? null : _constraintMessages[constraint];
  if (known != null) return known.tr();

  // Several validation issues are joined with ", "; split only where a new
  // "field.path: " starts, since messages themselves may contain commas.
  final issues = message.split(RegExp(r', (?=[a-z_][a-z0-9_.]*: )'));
  final described = issues.map(_describeIssue).toList();
  return described.join('\n');
}

String _describeIssue(String issue) {
  final match = RegExp(r'^([a-z_][a-z0-9_.]*): (.+)$').firstMatch(issue);
  if (match == null) return issue;

  final path = match.group(1)!.split('.');
  final text = match.group(2)!;
  final field = path.lastWhere((part) => int.tryParse(part) == null);

  // A list index names which row is wrong ("lines.2.quantity").
  final indexPart = path.lastWhere(
    (part) => int.tryParse(part) != null,
    orElse: () => '',
  );
  final row = indexPart.isEmpty
      ? ''
      : '${'error_row_prefix'.tr(namedArgs: {'number': '${int.parse(indexPart) + 1}'})} · ';

  return '$row${_fieldLabel(field)}: ${_lowerFirst(text)}';
}

String _fieldLabel(String field) {
  final key = 'field_$field';
  final translated = key.tr();
  if (translated != key) return translated;
  final words = field.replaceAll('_', ' ');
  return words[0].toUpperCase() + words.substring(1);
}

String _lowerFirst(String text) =>
    text.isEmpty ? text : text[0].toLowerCase() + text.substring(1);
