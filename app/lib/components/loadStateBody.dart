import 'package:flutter/material.dart';
import 'package:khanak/components/errorWidget.dart';
import 'package:khanak/components/loadingIndicator.dart';
import 'package:khanak/core/components/moduleBase.dart';

/// Shows the loaded value, or a spinner / error with retry while there is
/// nothing to show yet.
class LoadStateBody<T> extends StatelessWidget {
  final LoadState<T> state;
  final Future<void> Function() onRetry;
  final Widget Function(BuildContext context, T value) builder;

  const LoadStateBody({
    super.key,
    required this.state,
    required this.onRetry,
    required this.builder,
  });

  @override
  Widget build(BuildContext context) {
    final value = state.value;
    if (value != null) return builder(context, value);
    if (state.error != null) {
      return AppErrorWidget(errorMessage: state.error!, onRetry: onRetry);
    }
    return const LoadingIndicator();
  }
}

/// Like [LoadStateBody], for a section inside a scrolling page: the spinner
/// and error take a fixed height instead of the whole screen.
class LoadStateSection<T> extends StatelessWidget {
  final LoadState<T> state;
  final Future<void> Function() onRetry;
  final Widget Function(BuildContext context, T value) builder;
  final double placeholderHeight;

  const LoadStateSection({
    super.key,
    required this.state,
    required this.onRetry,
    required this.builder,
    this.placeholderHeight = 280,
  });

  @override
  Widget build(BuildContext context) {
    final value = state.value;
    if (value != null) return builder(context, value);
    return SizedBox(
      height: placeholderHeight,
      child: state.error != null
          ? AppErrorWidget(errorMessage: state.error!, onRetry: onRetry)
          : const LoadingIndicator(),
    );
  }
}

/// Runs [reload] after this frame when [when] is true. Call from `build` with
/// a state's `needsReload`, so data changed elsewhere refreshes on screen.
void scheduleReload(bool when, VoidCallback reload) {
  if (!when) return;
  WidgetsBinding.instance.addPostFrameCallback((_) => reload());
}
