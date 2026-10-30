import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:sentry_flutter/sentry_flutter.dart';

import '../api/api_client.dart';

/// Crash and error reporting (Sentry).
///
/// Off unless the app is built with `--dart-define=SENTRY_DSN=...`, so tests
/// and local runs send nothing. Only errors are sent: no performance traces,
/// screenshots, taps or personal details (no name, email or answers).
abstract final class Monitoring {
  static const _dsn = String.fromEnvironment('SENTRY_DSN');
  static const _environment = String.fromEnvironment('SENTRY_ENV', defaultValue: kReleaseMode ? 'release' : 'debug');

  static bool get enabled => _dsn.isNotEmpty;

  /// Runs [app] with error reporting around it when a DSN was given.
  static Future<void> run(AppRunner app) async {
    if (!enabled) return app();
    await SentryFlutter.init((o) {
      o.dsn = _dsn;
      o.environment = _environment;
      o.sendDefaultPii = false;
      o.tracesSampleRate = null;
      o.enableAutoPerformanceTracing = false;
      o.attachScreenshot = false;
      o.attachViewHierarchy = false;
      o.enableUserInteractionBreadcrumbs = false;
      o.beforeSend = (event, hint) => worthReporting(event.throwable) ? event : null;
    }, appRunner: app);
  }

  /// Offline, timeouts and the API's own refusals (wrong password, no energy,
  /// signed out…) are normal life, not bugs. Server faults (5xx) and anything
  /// unexpected are reported.
  @visibleForTesting
  static bool worthReporting(Object? error) => switch (error) {
        ApiException(:final status) => status >= 500,
        SocketException() || TimeoutException() || http.ClientException() => false,
        _ => true,
      };

  /// Debug builds only: sends one harmless error so the setup can be checked in Sentry.
  static Future<void> sendTestError() async {
    await Sentry.captureException(StateError('Nyaya test error: Sentry is connected'));
  }
}
