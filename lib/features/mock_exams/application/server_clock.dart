import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Makes a fresh monotonic stopwatch: a function that says how long it has run.
/// A provider so tests can drive time by hand.
typedef ElapsedSource = Duration Function();

final elapsedSourceFactoryProvider = Provider<ElapsedSource Function()>((ref) {
  return () {
    final sw = Stopwatch()..start();
    return () => sw.elapsed;
  };
});

/// The server's time, kept ticking by a monotonic stopwatch.
///
/// The server's `server_now` fixes the starting point; after that only the
/// stopwatch moves it, so changing the phone's clock, its time zone or
/// backgrounding the app cannot move a deadline. Each successful contact with
/// the server resets the base to its time.
class ServerClock {
  ServerClock(DateTime serverNow, ElapsedSource Function() factory)
      : _factory = factory,
        _base = serverNow.toUtc() {
    _elapsed = _factory();
  }

  final ElapsedSource Function() _factory;
  DateTime _base;
  late ElapsedSource _elapsed;

  DateTime now() => _base.add(_elapsed());

  /// Takes the server's latest time as the new base.
  void resync(DateTime serverNow) {
    _base = serverNow.toUtc();
    _elapsed = _factory();
  }

  /// Time left until [deadline], never below zero.
  Duration remaining(DateTime deadline) {
    final left = deadline.toUtc().difference(now());
    return left.isNegative ? Duration.zero : left;
  }
}
