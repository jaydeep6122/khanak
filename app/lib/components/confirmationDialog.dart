import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:khanak/components/appButton.dart';
import 'package:khanak/global/themes.dart';

class ConfirmationDialog extends StatelessWidget {
  final String title;
  final String message;
  final String confirmText;
  final String? cancelText;
  final bool isDestructive;
  final IconData? icon;

  const ConfirmationDialog({
    super.key,
    required this.title,
    required this.message,
    required this.confirmText,
    this.cancelText,
    this.isDestructive = false,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return AlertDialog(
      icon: icon == null
          ? null
          : Icon(icon, size: 28, color: isDestructive ? colors.danger : colors.primary),
      title: Text(title, textAlign: TextAlign.center),
      content: Text(message, textAlign: TextAlign.center),
      actionsPadding: const EdgeInsets.fromLTRB(
        AppTheme.spaceLg,
        0,
        AppTheme.spaceLg,
        AppTheme.spaceLg,
      ),
      actions: [
        Row(
          children: [
            Expanded(
              child: AppButton(
                text: cancelText ?? 'cancel'.tr(),
                variant: AppButtonVariant.outline,
                compact: true,
                onPressed: () => Navigator.of(context).pop(false),
              ),
            ),
            const SizedBox(width: AppTheme.spaceSm),
            Expanded(
              child: AppButton(
                text: confirmText,
                variant: isDestructive ? AppButtonVariant.danger : AppButtonVariant.primary,
                compact: true,
                onPressed: () => Navigator.of(context).pop(true),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

/// True only when the user confirms.
Future<bool> showConfirmDialog(
  BuildContext context, {
  required String title,
  required String message,
  required String confirmText,
  String? cancelText,
  bool isDestructive = false,
  IconData? icon,
}) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (_) => ConfirmationDialog(
      title: title,
      message: message,
      confirmText: confirmText,
      cancelText: cancelText,
      isDestructive: isDestructive,
      icon: icon,
    ),
  );
  return result ?? false;
}

/// Confirms a cancellation with an optional reason. Null when dismissed,
/// otherwise the reason ('' when left empty).
Future<String?> showReasonDialog(
  BuildContext context, {
  required String title,
  required String message,
  required String confirmText,
  String? hint,
}) {
  return showDialog<String>(
    context: context,
    builder: (_) => _ReasonDialog(
      title: title,
      message: message,
      confirmText: confirmText,
      hint: hint,
    ),
  );
}

class _ReasonDialog extends StatefulWidget {
  final String title;
  final String message;
  final String confirmText;
  final String? hint;

  const _ReasonDialog({
    required this.title,
    required this.message,
    required this.confirmText,
    this.hint,
  });

  @override
  State<_ReasonDialog> createState() => _ReasonDialogState();
}

class _ReasonDialogState extends State<_ReasonDialog> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(widget.message),
          const SizedBox(height: AppTheme.spaceLg),
          TextField(
            controller: _controller,
            maxLength: 500,
            maxLines: 2,
            textCapitalization: TextCapitalization.sentences,
            decoration: InputDecoration(
              labelText: 'reason_optional'.tr(),
              hintText: widget.hint,
              counterText: '',
            ),
          ),
        ],
      ),
      actionsPadding: const EdgeInsets.fromLTRB(
        AppTheme.spaceLg,
        0,
        AppTheme.spaceLg,
        AppTheme.spaceLg,
      ),
      actions: [
        Row(
          children: [
            Expanded(
              child: AppButton(
                text: 'keep'.tr(),
                variant: AppButtonVariant.outline,
                compact: true,
                onPressed: () => Navigator.of(context).pop(),
              ),
            ),
            const SizedBox(width: AppTheme.spaceSm),
            Expanded(
              child: AppButton(
                text: widget.confirmText,
                variant: AppButtonVariant.danger,
                compact: true,
                onPressed: () => Navigator.of(context).pop(_controller.text.trim()),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
