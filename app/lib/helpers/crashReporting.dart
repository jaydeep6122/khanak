import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:khanak/helpers/logger.dart';

/// Signature for a crash-reporting sink (Sentry, Crashlytics, …).
typedef CrashReporter =
    Future<void> Function(
      Object error,
      StackTrace? stack, {
      String? context,
      bool fatal,
    });

/// Central error reporting.
///
/// Nothing was capturing errors before this: there was no `runZonedGuarded`,
/// no `FlutterError.onError` and no reporter, so every production failure was
/// invisible. This wires up the capture points and routes them through a
/// single pluggable sink.
///
/// **The sink is currently a debug-only logger.** To start receiving real
/// reports, pick a provider and assign [reporter] in `main()` before
/// [runGuarded] — for example:
///
/// ```dart
/// CrashReporting.reporter = (error, stack, {context, fatal}) =>
///     Sentry.captureException(error, stackTrace: stack);
/// ```
class CrashReporting {
  CrashReporting._();

  /// Assign to forward errors to a real backend. Defaults to debug logging.
  static CrashReporter? reporter;

  /// Report a handled error. Safe to call from anywhere; never throws.
  static Future<void> report(
    Object error,
    StackTrace? stack, {
    String? context,
    bool fatal = false,
  }) async {
    final label = context == null ? '' : ' [$context]';
    logger('ERROR$label: $error');
    if (stack != null && kDebugMode) {
      logger(stack.toString());
    }

    final sink = reporter;
    if (sink == null) return;
    try {
      await sink(error, stack, context: context, fatal: fatal);
    } catch (e) {
      // A failing reporter must never take the app down with it.
      logger('Crash reporter failed: $e');
    }
  }

  /// Installs the framework-level error handlers, then runs [body] inside a
  /// guarded zone so async errors outside the framework are caught too.
  static void runGuarded(void Function() body) {
    FlutterError.onError = (details) {
      FlutterError.presentError(details);
      report(
        details.exception,
        details.stack,
        context: details.context?.toDescription(),
        fatal: true,
      );
    };

    PlatformDispatcher.instance.onError = (error, stack) {
      report(error, stack, context: 'PlatformDispatcher', fatal: true);
      return true;
    };

    runZonedGuarded(body, (error, stack) {
      report(error, stack, context: 'uncaught', fatal: true);
    });
  }
}
