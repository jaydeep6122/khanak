import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:khanak/global/themes.dart';
import 'package:khanak/helpers/inputFormatters.dart';

/// Asks for a rupee amount. Returns what was typed, trimmed; an empty string
/// when [resetText] was tapped (back to the rate, or an equal share); null
/// when dismissed.
///
/// The dialog owns its text field's controller, so it is let go only once the
/// dialog has finished closing; one disposed by the caller as soon as the
/// dialog returns is still used by the closing animation.
Future<String?> showAmountDialog(
  BuildContext context, {
  required String title,
  String? initialValue,
  String? help,
  String? helperText,
  String? suffixText,
  String? resetText,
}) {
  return showDialog<String>(
    context: context,
    builder: (_) => _AmountDialog(
      title: title,
      initialValue: initialValue,
      help: help,
      helperText: helperText,
      suffixText: suffixText,
      resetText: resetText,
    ),
  );
}

class _AmountDialog extends StatefulWidget {
  final String title;
  final String? initialValue;
  final String? help;
  final String? helperText;
  final String? suffixText;
  final String? resetText;

  const _AmountDialog({
    required this.title,
    required this.initialValue,
    required this.help,
    required this.helperText,
    required this.suffixText,
    required this.resetText,
  });

  @override
  State<_AmountDialog> createState() => _AmountDialogState();
}

class _AmountDialogState extends State<_AmountDialog> {
  late final _controller = TextEditingController(text: widget.initialValue);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() => Navigator.of(context).pop(_controller.text.trim());

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (widget.help != null) ...[
            Text(widget.help!, style: context.text.bodyMedium),
            const SizedBox(height: AppTheme.spaceMd),
          ],
          TextField(
            controller: _controller,
            autofocus: true,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [DecimalInputFormatter(decimals: 2)],
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => _submit(),
            style: context.text.headlineSmall,
            decoration: InputDecoration(
              prefixText: '₹ ',
              suffixText: widget.suffixText,
              helperText: widget.helperText,
              helperMaxLines: 3,
            ),
          ),
        ],
      ),
      actions: [
        if (widget.resetText != null)
          TextButton(onPressed: () => Navigator.of(context).pop(''), child: Text(widget.resetText!)),
        TextButton(onPressed: () => Navigator.of(context).pop(), child: Text('cancel'.tr())),
        FilledButton(onPressed: _submit, child: Text('save'.tr())),
      ],
    );
  }
}
