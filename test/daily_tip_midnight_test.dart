import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nyaya/core/storage/local_store.dart';
import 'package:nyaya/features/daily_tip/application/daily_tip_renewal.dart';
import 'package:nyaya/features/daily_tip/data/daily_tip_repository.dart';
import 'package:nyaya/features/daily_tip/domain/india_day.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/fake_backend.dart';

void main() {
  group('India day', () {
    test('is the India date at that instant, whatever zone the phone is in', () {
      // 18:29:59 UTC is 23:59:59 in India; one second later it is the next day.
      expect(indiaDay(DateTime.utc(2026, 11, 17, 18, 29, 59)), '2026-11-17');
      expect(indiaDay(DateTime.utc(2026, 11, 17, 18, 30)), '2026-11-18');
      // The same instants written in another zone's offset give the same day.
      expect(indiaDay(DateTime.parse('2026-11-17T10:29:59-08:00')), '2026-11-17');
      expect(indiaDay(DateTime.parse('2026-11-17T10:30:00-08:00')), '2026-11-18');
      expect(indiaDay(DateTime.utc(2026, 12, 31, 18, 30)), '2027-01-01');
    });

    test('counts down to the next 00:00 India time', () {
      expect(untilIndiaMidnight(istTime('2026-11-18', 0, 0, 0).subtract(const Duration(seconds: 1))), const Duration(seconds: 1));
      expect(untilIndiaMidnight(istTime('2026-11-17', 12)), const Duration(hours: 12));
      // Exactly at midnight the next one is a whole day away, never zero.
      expect(untilIndiaMidnight(istTime('2026-11-18')), const Duration(days: 1));
    });
  });

  group('the tip renews itself', () {
    late TestClock clock;
    late DatedTips server;
    late SharedPreferences prefs;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      prefs = await SharedPreferences.getInstance();
      clock = TestClock(istTime('2026-11-17', 23, 59));
      server = DatedTips(clock);
    });

    /// Home's setup: the provider, watched by the card, and the renewal its screen owns.
    ({ProviderContainer c, DailyTipRenewal renewal, void Function() close}) openHome() {
      final c = ProviderContainer(overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        clockProvider.overrideWithValue(clock.call),
        dailyTipRepositoryProvider.overrideWithValue(server),
      ]);
      final sub = c.listen(dailyTipProvider, (_, _) {});
      final renewal = DailyTipRenewal(clock: clock.call, renew: () => c.invalidate(dailyTipProvider))..start();
      return (
        c: c,
        renewal: renewal,
        close: () {
          renewal.dispose();
          sub.close();
          c.dispose();
        },
      );
    }

    /// Moves the clock and fake time on together, as real time does.
    Future<void> elapse(WidgetTester tester, Duration d) async {
      clock.now = clock.now.add(d);
      await tester.pump(d);
    }

    /// Lets Riverpod rebuild what was just invalidated.
    Future<void> tick(WidgetTester tester) => elapse(tester, const Duration(milliseconds: 10));

    String? shown(ProviderContainer c) => c.read(dailyTipProvider).value?.title;

    testWidgets('changes at midnight India time by itself, with one more request and no more', (tester) async {
      final h = openHome();
      await tester.pump();
      expect(shown(h.c), 'Tip for 2026-11-17');
      expect(server.calls, 1);

      // Up to a second past midnight (inside the grace) nothing has been asked.
      await elapse(tester, const Duration(seconds: 61));
      expect(server.calls, 1);
      expect(shown(h.c), 'Tip for 2026-11-17');

      // The grace ends: the new day's tip is fetched, once.
      await elapse(tester, const Duration(seconds: 1));
      await tester.pump();
      expect(server.calls, 2);
      expect(shown(h.c), 'Tip for 2026-11-18');

      // The rest of the day brings no further requests.
      await elapse(tester, const Duration(hours: 23));
      expect(server.calls, 2);

      // The next midnight does the same again: the timer was set anew.
      await elapse(tester, const Duration(hours: 1));
      await tester.pump();
      expect(server.calls, 3);
      expect(shown(h.c), 'Tip for 2026-11-19');
      h.close();
    });

    testWidgets('keeps showing the old tip until the new one arrives', (tester) async {
      final h = openHome();
      await tester.pump();
      server.gate = Completer<void>();
      await elapse(tester, const Duration(seconds: 62));
      // Renewing: the request is out, and the old tip is still there for the card to show.
      expect(server.calls, 2);
      expect(h.c.read(dailyTipProvider).isLoading, isTrue);
      expect(shown(h.c), 'Tip for 2026-11-17');
      server.gate!.complete();
      await tester.pump();
      expect(shown(h.c), 'Tip for 2026-11-18');
      h.close();
    });

    testWidgets('resuming on the same day asks for nothing', (tester) async {
      final h = openHome();
      await tester.pump();
      await elapse(tester, const Duration(seconds: 20));
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tick(tester);
      expect(server.calls, 1);
      h.close();
    });

    testWidgets('resuming after midnight fetches the new day (the timer slept through it)', (tester) async {
      final h = openHome();
      await tester.pump();
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      // The phone slept: the clock moved on but no fake time passed, so the timer has not fired.
      clock.now = istTime('2026-11-18', 7, 30);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tick(tester);
      expect(server.calls, 2);
      expect(shown(h.c), 'Tip for 2026-11-18');

      // Resuming again the same morning adds nothing, and the old timer does not fire on top.
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tick(tester);
      await elapse(tester, const Duration(minutes: 5));
      expect(server.calls, 2);
      h.close();
    });

    testWidgets('opening the app after midnight fetches the current day at once', (tester) async {
      clock.now = istTime('2026-11-18', 0, 5);
      final h = openHome();
      await tester.pump();
      expect(server.calls, 1);
      expect(shown(h.c), 'Tip for 2026-11-18');
      h.close();
    });

    testWidgets('leaving Home cancels the timer and the resume check', (tester) async {
      final h = openHome();
      await tester.pump();
      h.renewal.dispose();

      await elapse(tester, const Duration(days: 2));
      clock.now = istTime('2026-11-20', 9);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tick(tester);
      expect(server.calls, 1);
      h.close();
    });

    testWidgets('starting twice, or pulling to refresh, never adds a second timer', (tester) async {
      final h = openHome();
      await tester.pump();
      h.renewal.start();
      h.c.invalidate(dailyTipProvider); // a pull to refresh
      await tick(tester);
      expect(server.calls, 2);

      await elapse(tester, const Duration(seconds: 62));
      await tester.pump();
      // One midnight, one request.
      expect(server.calls, 3);
      h.close();
    });
  });
}
