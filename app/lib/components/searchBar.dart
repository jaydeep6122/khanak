import 'dart:async';

import 'package:flutter/material.dart';
import 'package:khanak/global/themes.dart';

/// Search field that reports changes after the user pauses typing.
class AppSearchBar extends StatefulWidget {
  final String hintText;
  final void Function(String) onChanged;
  final String initialValue;
  final Duration debounceDuration;

  const AppSearchBar({
    super.key,
    required this.hintText,
    required this.onChanged,
    this.initialValue = '',
    this.debounceDuration = const Duration(milliseconds: 350),
  });

  @override
  State<AppSearchBar> createState() => _AppSearchBarState();
}

class _AppSearchBarState extends State<AppSearchBar> {
  late final _controller = TextEditingController(text: widget.initialValue);
  Timer? _debounce;

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _onChanged(String value) {
    setState(() {});
    _debounce?.cancel();
    _debounce = Timer(widget.debounceDuration, () => widget.onChanged(value.trim()));
  }

  void _clear() {
    _debounce?.cancel();
    _controller.clear();
    setState(() {});
    widget.onChanged('');
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final border = OutlineInputBorder(
      borderRadius: BorderRadius.circular(AppTheme.radiusMd),
      borderSide: BorderSide(color: colors.border),
    );

    return TextField(
      controller: _controller,
      onChanged: _onChanged,
      textInputAction: TextInputAction.search,
      style: context.text.bodyLarge,
      decoration: InputDecoration(
        hintText: widget.hintText,
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        prefixIcon: const Icon(Icons.search_rounded, size: 22),
        suffixIcon: _controller.text.isEmpty
            ? null
            : IconButton(
                tooltip: MaterialLocalizations.of(context).deleteButtonTooltip,
                icon: const Icon(Icons.close_rounded, size: 20),
                onPressed: _clear,
              ),
        border: border,
        enabledBorder: border,
        focusedBorder: border.copyWith(
          borderSide: BorderSide(color: colors.primary, width: 1.6),
        ),
      ),
    );
  }
}
