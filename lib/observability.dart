import 'dart:async';
import 'dart:developer' as dev;
import 'package:flutter/foundation.dart';

/// Central crash / error capture (qa-audit OBS-1).
///
/// Previously an uncaught exception in release just vanished — invisible to
/// anyone. Now every Flutter framework error, platform-dispatcher error and
/// async-zone error funnels through [_capture], which logs it. This is also the
/// single place to forward to a remote crash reporter (e.g. Sentry) once a DSN
/// is configured: implement [_report] and call it from [_capture]. Keeping the
/// capture here means wiring a reporter later is a one-line change and needs no
/// new dependency today.
class Observability {
  Observability._();

  /// Run [body] (which should call `runApp`) inside a guarded zone so that
  /// asynchronous errors can't escape uncaptured. Framework + platform error
  /// handlers are installed first.
  static Future<void> runGuarded(FutureOr<void> Function() body) async {
    FlutterError.onError = (details) {
      FlutterError.presentError(details); // keep the red-screen in debug
      _capture(details.exception, details.stack, context: 'flutter');
    };
    PlatformDispatcher.instance.onError = (error, stack) {
      _capture(error, stack, context: 'platform');
      return true; // handled — don't crash the isolate on a stray platform error
    };
    await runZonedGuarded(() async {
      await body();
    }, (error, stack) => _capture(error, stack, context: 'zone'));
  }

  static void _capture(Object error, StackTrace? stack, {String? context}) {
    dev.log(
      'Uncaught error${context != null ? ' [$context]' : ''}',
      name: 'kukcal.crash',
      error: error,
      stackTrace: stack,
    );
    // _report(error, stack, context);  // ← wire a remote reporter (Sentry) here
  }
}
