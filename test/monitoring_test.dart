import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:nyaya/core/api/api_client.dart';
import 'package:nyaya/core/monitoring/monitoring.dart';

void main() {
  test('reporting is off unless the app is built with a Sentry key', () {
    expect(Monitoring.enabled, isFalse);
  });

  test('only real faults are worth reporting', () {
    // Normal life: offline, slow networks, and the API refusing a request.
    expect(Monitoring.worthReporting(const ApiException(0, 'network', 'Could not reach the server')), isFalse);
    expect(Monitoring.worthReporting(const ApiException(401, 'unauthenticated', 'Sign in')), isFalse);
    expect(Monitoring.worthReporting(const ApiException(403, 'wrong_password', 'No')), isFalse);
    expect(Monitoring.worthReporting(const ApiException(409, 'not_enough_energy', 'No')), isFalse);
    expect(Monitoring.worthReporting(const SocketException('offline')), isFalse);
    expect(Monitoring.worthReporting(TimeoutException('slow')), isFalse);
    expect(Monitoring.worthReporting(http.ClientException('reset')), isFalse);
    // Faults: a server error, and anything the app did not expect.
    expect(Monitoring.worthReporting(const ApiException(503, 'error', 'Down')), isTrue);
    expect(Monitoring.worthReporting(StateError('bug')), isTrue);
    expect(Monitoring.worthReporting(null), isTrue);
  });
}
