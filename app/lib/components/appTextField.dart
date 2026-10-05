import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class AppTextField extends StatefulWidget {
  final TextEditingController? controller;
  final String labelText;
  final String? hintText;
  final String? helperText;
  final String? initialValue;
  final String? Function(String?)? validator;
  final TextInputType keyboardType;
  final TextInputAction? textInputAction;
  final TextCapitalization textCapitalization;
  final bool isPassword;
  final IconData? prefixIcon;
  final Widget? suffixIcon;
  final String? prefixText;
  final String? suffixText;
  final int? maxLines;
  final int? minLines;
  final int? maxLength;
  final void Function(String)? onChanged;
  final void Function(String)? onFieldSubmitted;
  final void Function(String?)? onSaved;
  final bool readOnly;
  final bool enabled;
  final bool autofocus;
  final VoidCallback? onTap;
  final FocusNode? focusNode;
  final List<TextInputFormatter>? inputFormatters;
  final Iterable<String>? autofillHints;

  const AppTextField({
    super.key,
    this.controller,
    required this.labelText,
    this.hintText,
    this.helperText,
    this.initialValue,
    this.validator,
    this.keyboardType = TextInputType.text,
    this.textInputAction,
    this.textCapitalization = TextCapitalization.none,
    this.isPassword = false,
    this.prefixIcon,
    this.suffixIcon,
    this.prefixText,
    this.suffixText,
    this.maxLines = 1,
    this.minLines,
    this.maxLength,
    this.onChanged,
    this.onFieldSubmitted,
    this.onSaved,
    this.readOnly = false,
    this.enabled = true,
    this.autofocus = false,
    this.onTap,
    this.focusNode,
    this.inputFormatters,
    this.autofillHints,
  });

  @override
  State<AppTextField> createState() => _AppTextFieldState();
}

class _AppTextFieldState extends State<AppTextField> {
  late bool _obscureText = widget.isPassword;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: widget.controller,
      initialValue: widget.controller == null ? widget.initialValue : null,
      focusNode: widget.focusNode,
      obscureText: widget.isPassword && _obscureText,
      keyboardType: widget.keyboardType,
      textInputAction: widget.textInputAction,
      textCapitalization: widget.textCapitalization,
      maxLines: widget.isPassword ? 1 : widget.maxLines,
      minLines: widget.minLines,
      maxLength: widget.maxLength,
      onChanged: widget.onChanged,
      onFieldSubmitted: widget.onFieldSubmitted,
      onSaved: widget.onSaved,
      readOnly: widget.readOnly,
      enabled: widget.enabled,
      autofocus: widget.autofocus,
      onTap: widget.onTap,
      inputFormatters: widget.inputFormatters,
      autofillHints: widget.autofillHints,
      validator: widget.validator,
      buildCounter: (context, {required currentLength, required isFocused, maxLength}) => null,
      style: Theme.of(context).textTheme.bodyLarge,
      decoration: InputDecoration(
        labelText: widget.labelText.isEmpty ? null : widget.labelText,
        hintText: widget.hintText,
        helperText: widget.helperText,
        prefixText: widget.prefixText,
        suffixText: widget.suffixText,
        prefixIcon: widget.prefixIcon == null ? null : Icon(widget.prefixIcon, size: 20),
        suffixIcon: widget.isPassword
            ? IconButton(
                tooltip: _obscureText ? 'Show password' : 'Hide password',
                icon: Icon(
                  _obscureText ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                  size: 20,
                ),
                onPressed: () => setState(() => _obscureText = !_obscureText),
              )
            : widget.suffixIcon,
      ),
    );
  }
}
