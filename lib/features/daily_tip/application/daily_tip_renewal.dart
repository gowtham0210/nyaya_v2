import 'dart:async';

import 'package:flutter/widgets.dart';

import '../domain/india_day.dart';

/// How long past midnight the renewal waits, so a phone clock a moment ahead
/// of the server's does not ask while the server still has yesterday's tip.
const midnightGrace = Duration(seconds: 2);

/// Calls [renew] when the India day changes, so Home can fetch the new tip
/// without a pull to refresh:
///
/// - once, from a timer set for the next 00:00 India time (plus
///   [midnightGrace]); each time it fires it sets the next one, so there is
///   only ever one timer;
/// - when the app resumes into a different India day than the one it last
///   looked at, because timers do not run while the phone sleeps or the app is
///   away. Resuming on the same day asks for nothing.
///
/// Owned by a screen: [start] in `initState`, [dispose] in `dispose`, which
/// cancels the timer and stops listening.
class DailyTipRenewal with WidgetsBindingObserver {
  DailyTipRenewal({required this.clock, required this.renew});

  /// The phone's clock (injectable for tests).
  final DateTime Function() clock;
  final VoidCallback renew;

  Timer? _timer;
  String _day = '';
  bool _started = false;

  void start() {
    if (_started) return;
    _started = true;
    WidgetsBinding.instance.addObserver(this);
    _arm();
  }

  void dispose() {
    _started = false;
    _timer?.cancel();
    _timer = null;
    WidgetsBinding.instance.removeObserver(this);
  }

  void _arm() {
    final now = clock();
    _day = indiaDay(now);
    _timer?.cancel();
    _timer = Timer(untilIndiaMidnight(now) + midnightGrace, () {
      _arm();
      renew();
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed || !_started) return;
    if (indiaDay(clock()) == _day) return;
    // The timer slept through midnight: renew now and aim at the next one.
    _arm();
    renew();
  }
}
