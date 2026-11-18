import 'dart:convert';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:material_ui/material_ui.dart';
import 'package:nyaya/app/app.dart';
import 'package:nyaya/app/router.dart';
import 'package:nyaya/core/api/api_client.dart';
import 'package:nyaya/core/api/token_store.dart';
import 'package:nyaya/core/services/sounds.dart';
import 'package:nyaya/core/storage/local_store.dart';
import 'package:nyaya/core/theme/app_theme.dart';
import 'package:nyaya/features/auth/data/auth_api.dart';
import 'package:nyaya/features/daily_tip/data/daily_tip_repository.dart';
import 'package:nyaya/features/leaderboard/data/league_api.dart';
import 'package:nyaya/features/legal_updates/data/legal_updates_repository.dart';
import 'package:nyaya/features/profile/domain/user_profile.dart';
import 'package:nyaya/features/progress/data/progress_api.dart';
import 'package:nyaya/features/quiz/data/quiz_api.dart';
import 'package:nyaya/features/reminders/data/reminder_notifications.dart';
import 'package:nyaya/features/review/data/review_api.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/fake_backend.dart';

Map<String, dynamic> tipJson({String id = 'tip-1'}) => {
      'id': id,
      'category': 'consumer_rights',
      'language': 'en',
      'title': 'You can ask for a bill',
      'summary': 'Every seller must give you a bill on request.',
      'explanation': 'Keep the bill as proof.',
      'legal_reference': 'Consumer Protection Act, 2019, Section 2(9)',
      'source_url': 'https://consumeraffairs.nic.in/acts-and-rules',
      'publish_date': '2026-11-17',
      'last_verified_on': '2026-11-10',
    };

void main() {
  setUpAll(() => AppTheme.useGoogleFonts = false);

  group('the API repository', () {
    HttpDailyTipRepository repoWith(Future<http.Response> Function(http.Request) handler) => HttpDailyTipRepository(
          ApiClient(baseUrl: 'https://api.test', client: MockClient(handler), tokens: signedInTokens()),
        );

    test("reads today's tip in the asked language, without a token", () async {
      final repo = repoWith((req) async {
        expect(req.url.path, '/v1/daily-tips/today');
        expect(req.url.queryParameters['language'], 'ta');
        expect(req.headers['authorization'], isNull);
        return http.Response(jsonEncode({'tip': tipJson()}), 200);
      });
      final tip = await repo.today('ta');
      expect(tip?.id, 'tip-1');
      expect(tip?.legalReference, 'Consumer Protection Act, 2019, Section 2(9)');
      expect(tip?.publishDate, DateTime(2026, 11, 17));
      expect(tip?.lastVerified, DateTime(2026, 11, 10));
    });

    test('no tip today is null, not an error', () async {
      final repo = repoWith((req) async => http.Response(jsonEncode({'tip': null}), 200));
      expect(await repo.today('en'), isNull);
    });

    test('a withdrawn tip is a 404', () async {
      final repo = repoWith((req) async {
        expect(req.url.path, '/v1/daily-tips/gone');
        return http.Response(jsonEncode({'code': 'not_found', 'message': 'Tip not found'}), 404);
      });
      await expectLater(repo.byId('gone'), throwsA(isA<ApiException>().having((e) => e.status, 'status', 404)));
    });

    test('a tip the app cannot read is an error, not a crash', () async {
      final repo = repoWith((req) async => http.Response(jsonEncode({...tipJson(), 'publish_date': 'soon'}), 200));
      await expectLater(repo.byId('tip-1'), throwsA(isA<ApiException>()));
    });
  });

  group('on Home', () {
    Future<void> settle(WidgetTester tester) async {
      for (var i = 0; i < 12; i++) {
        await tester.pump(const Duration(milliseconds: 150));
      }
    }

    /// Home is a lazy list: scrolls until [finder] is on screen.
    Future<void> showOnHome(WidgetTester tester, Finder finder) async {
      await tester.scrollUntilVisible(finder, 200, scrollable: find.byType(Scrollable).first);
      await tester.pump();
    }

    Future<ProviderContainer> pumpHome(
      WidgetTester tester,
      DailyTipRepository tips, {
      AppLanguage language = AppLanguage.en,
      DateTime Function()? clock,
    }) async {
      tester.view.physicalSize = const Size(1170, 2532);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);
      SharedPreferences.setMockInitialValues({
        'profile_v1': jsonEncode({'onboarded': true, 'name': 'Ravi', 'persona': 'citizen', 'language': language.code}),
      });
      final sp = await SharedPreferences.getInstance();
      final tokens = signedInTokens();
      final api = FakeQuizApi();
      final container = ProviderContainer(overrides: [
        sharedPreferencesProvider.overrideWithValue(sp),
        tokenStoreProvider.overrideWithValue(tokens),
        quizApiProvider.overrideWithValue(api),
        progressApiProvider.overrideWithValue(api),
        leagueApiProvider.overrideWithValue(api),
        reviewApiProvider.overrideWithValue(api),
        legalUpdatesRepositoryProvider.overrideWithValue(FakeLegalUpdates()),
        dailyTipRepositoryProvider.overrideWithValue(tips),
        if (clock != null) clockProvider.overrideWithValue(clock),
        reminderNotificationsProvider.overrideWithValue(FakeReminderNotifications()),
        soundPlayerProvider.overrideWithValue(FakeSounds()),
        authApiProvider.overrideWithValue(FakeAuthApi(tokens)),
      ]);
      addTearDown(container.dispose);
      await tester.pumpWidget(UncontrolledProviderScope(container: container, child: const NyayaApp()));
      await settle(tester);
      return container;
    }

    testWidgets("shows today's tip; Read more opens the whole tip with its source and verified date", (tester) async {
      await pumpHome(tester, FakeDailyTips(tip: sampleTip()));
      // The rest of Home is still there.
      expect(find.text('Explore Law'), findsOneWidget);
      // For a new learner the card sits just below the first screen.
      await showOnHome(tester, find.text('DAILY TIP'));
      expect(find.text('DAILY TIP'), findsOneWidget);
      expect(find.text('You can ask for a bill'), findsOneWidget);
      expect(find.text('Every seller must give you a bill on request.'), findsOneWidget);
      expect(find.text('Read more'), findsOneWidget);

      await tester.tap(find.text('Read more'));
      await settle(tester);
      expect(find.text('You can ask for a bill'), findsOneWidget);
      expect(find.textContaining('Keep it as proof'), findsOneWidget);
      expect(find.text('Legal reference'), findsOneWidget);
      expect(find.text('Consumer Protection Act, 2019, Section 2(9)'), findsOneWidget);
      expect(find.text('Read the official text'), findsOneWidget);
      expect(find.text('Last verified on November 10, 2026'), findsOneWidget);

      await tester.pageBack();
      await settle(tester);
      await showOnHome(tester, find.text('DAILY TIP'));
      expect(find.text('DAILY TIP'), findsOneWidget);
    });

    testWidgets('no tip published today leaves Home as it was, with no card or error', (tester) async {
      await pumpHome(tester, FakeDailyTips());
      expect(find.text('DAILY TIP'), findsNothing);
      expect(find.text("Couldn't load today's tip."), findsNothing);
      expect(find.text('Explore Law'), findsOneWidget);
    });

    testWidgets('a failed load says so and retrying brings the tip', (tester) async {
      final tips = FakeDailyTips(tip: sampleTip())..failing = true;
      await pumpHome(tester, tips);
      await showOnHome(tester, find.text("Couldn't load today's tip."));
      expect(find.text("Couldn't load today's tip."), findsOneWidget);
      expect(find.text('DAILY TIP'), findsNothing);

      tips.failing = false;
      await tester.tap(find.text('Try again'));
      await settle(tester);
      expect(find.text("Couldn't load today's tip."), findsNothing);
      await showOnHome(tester, find.text('DAILY TIP'));
      expect(find.text('DAILY TIP'), findsOneWidget);
    });

    testWidgets('the card changes at midnight India time without a pull to refresh', (tester) async {
      final clock = TestClock(istTime('2026-11-17', 23, 59));
      final tips = DatedTips(clock);
      await pumpHome(tester, tips, clock: clock.call);
      await showOnHome(tester, find.text('Tip for 2026-11-17'));
      expect(find.text('Tip for 2026-11-17'), findsOneWidget);
      expect(tips.calls, 1);

      clock.now = clock.now.add(const Duration(seconds: 62));
      await tester.pump(const Duration(seconds: 62));
      await settle(tester);
      expect(find.text('Tip for 2026-11-17'), findsNothing);
      expect(find.text('Tip for 2026-11-18'), findsOneWidget);
      expect(tips.calls, 2);
    });

    testWidgets('coming back to the app after midnight shows the new tip', (tester) async {
      final clock = TestClock(istTime('2026-11-17', 22));
      final tips = DatedTips(clock);
      await pumpHome(tester, tips, clock: clock.call);
      await showOnHome(tester, find.text('Tip for 2026-11-17'));

      // The real sequence: the app goes away and comes back through the in-between states.
      for (final state in [AppLifecycleState.inactive, AppLifecycleState.hidden, AppLifecycleState.paused]) {
        tester.binding.handleAppLifecycleStateChanged(state);
      }
      clock.now = istTime('2026-11-18', 8);
      for (final state in [AppLifecycleState.hidden, AppLifecycleState.inactive, AppLifecycleState.resumed]) {
        tester.binding.handleAppLifecycleStateChanged(state);
      }
      await settle(tester);
      expect(find.text('Tip for 2026-11-18'), findsOneWidget);
      expect(tips.calls, 2);
    });

    testWidgets("asks for the learner's language first", (tester) async {
      final tips = FakeDailyTips(tip: sampleTip());
      await pumpHome(tester, tips, language: AppLanguage.ta);
      expect(tips.languagesAsked, ['ta']);
      await showOnHome(tester, find.text('You can ask for a bill'));
      expect(find.text('DAILY TIP'), findsNothing); // The card's label is translated.
      expect(find.text('இன்றைய குறிப்பு'.toUpperCase()), findsOneWidget);
    });

    testWidgets("falls back to the English tip when there is none in the learner's language", (tester) async {
      final tips = _EnglishOnlyTips(sampleTip());
      await pumpHome(tester, tips, language: AppLanguage.ta);
      expect(tips.languagesAsked, ['ta', 'en']);
      await showOnHome(tester, find.text('You can ask for a bill'));
      expect(find.text('You can ask for a bill'), findsOneWidget);
    });
  });

  testWidgets('a tip opened from a link that is no longer published says so', (tester) async {
    tester.view.physicalSize = const Size(1170, 2532);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    SharedPreferences.setMockInitialValues({
      'profile_v1': jsonEncode({'onboarded': true, 'name': 'Ravi', 'persona': 'citizen'}),
    });
    final sp = await SharedPreferences.getInstance();
    final tokens = signedInTokens();
    final api = FakeQuizApi();
    final container = ProviderContainer(overrides: [
      sharedPreferencesProvider.overrideWithValue(sp),
      tokenStoreProvider.overrideWithValue(tokens),
      quizApiProvider.overrideWithValue(api),
      progressApiProvider.overrideWithValue(api),
      leagueApiProvider.overrideWithValue(api),
      reviewApiProvider.overrideWithValue(api),
      legalUpdatesRepositoryProvider.overrideWithValue(FakeLegalUpdates()),
      dailyTipRepositoryProvider.overrideWithValue(FakeDailyTips()),
      reminderNotificationsProvider.overrideWithValue(FakeReminderNotifications()),
      soundPlayerProvider.overrideWithValue(FakeSounds()),
      authApiProvider.overrideWithValue(FakeAuthApi(tokens)),
    ]);
    addTearDown(container.dispose);
    await tester.pumpWidget(UncontrolledProviderScope(container: container, child: const NyayaApp()));
    for (var i = 0; i < 6; i++) {
      await tester.pump(const Duration(milliseconds: 150));
    }
    container.read(routerProvider).push('/daily-tip/withdrawn');
    for (var i = 0; i < 12; i++) {
      await tester.pump(const Duration(milliseconds: 150));
    }
    expect(find.text("This tip isn't available any more."), findsOneWidget);
  });
}

/// Has a tip in English only.
class _EnglishOnlyTips extends FakeDailyTips {
  _EnglishOnlyTips(DailyTip tip) : super(tip: tip);

  @override
  Future<DailyTip?> today(String language) async {
    final tip = await super.today(language);
    return language == 'en' ? tip : null;
  }
}
