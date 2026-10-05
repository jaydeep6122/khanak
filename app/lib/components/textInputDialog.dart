import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

/// Asks for one line of text. Returns it trimmed, or null when cancelled or
/// left empty.
Future<String?> showTextInputDialog(
  BuildContext context, {
  required String title,
  required String label,
  String? initialValue,
  String? confirmText,
  int maxLength = 100,
  TextCapitalization textCapitalization = TextCapitalization.sentences,
}) async {
  final result = await showDialog<String>(
    context: context,
    builder: (_) => _TextInputDialog(
      title: title,
      label: label,
      initialValue: initialValue,
      confirmText: confirmText ?? 'save'.tr(),
      maxLength: maxLength,
      textCapitalization: textCapitalization,
    ),
  );
  final text = result?.trim();
  return text == null || text.isEmpty ? null : text;
}

class _TextInputDialog extends StatefulWidget {
  final String title;
  final String label;
  final String? initialValue;
  final String confirmText;
  final int maxLength;
  final TextCapitalization textCapitalization;

  const _TextInputDialog({
    required this.title,
    required this.label,
    required this.initialValue,
    required this.confirmText,
    required this.maxLength,
    required this.textCapitalization,
  });

  @override
  State<_TextInputDialog> createState() => _TextInputDialogState();
}

class _TextInputDialogState extends State<_TextInputDialog> {
  late final _controller = TextEditingController(text: widget.initialValue);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() => Navigator.of(context).pop(_controller.text);

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: TextField(
        controller: _controller,
        autofocus: true,
        maxLength: widget.maxLength,
        textCapitalization: widget.textCapitalization,
        textInputAction: TextInputAction.done,
        onSubmitted: (_) => _submit(),
        decoration: InputDecoration(labelText: widget.label, counterText: ''),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text('cancel'.tr()),
        ),
        FilledButton(onPressed: _submit, child: Text(widget.confirmText)),
      ],
    );
  }
}
