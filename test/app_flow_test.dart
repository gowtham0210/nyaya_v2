import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:nyaya/app/app.dart';
import 'package:nyaya/app/router.dart';
import 'package:nyaya/core/api/token_store.dart';
import 'package:nyaya/core/storage/local_store.dart';
import 'package:nyaya/features/auth/data/auth_api.dart';
import 'package:nyaya/core/theme/app_theme.dart';
import 'package:nyaya/features/journey/application/journey_controller.dart';
import 'package:nyaya/features/legal_updates/data/legal_updates_repository.dart';
import 'package:nyaya/features/profile/application/profile_controller.dart';
import 'package:nyaya/features/leaderboard/data/league_api.dart';
import 'package:nyaya/features/progress/data/progress_api.dart';
import 'package:nyaya/features/review/data/review_api.dart';
import 'package:nyaya/features/quiz/application/quiz_controller.dart';
import 'package:nyaya/features/quiz/data/quiz_api.dart';
import 'package:nyaya/features/quiz/domain/question.dart';
import 'package:nyaya/features/quiz/domain/quiz_models.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/fake_backend.dart';

/// End-to-end user flows on the real widget tree (no network).
void main() {
  setUpAll(() => AppTheme.useGoogleFonts = false);

  late FakeQuizApi api;
  late FakeAuthApi authApi;

  Future<ProviderContainer> pumpApp(
    WidgetTester tester, {
    Map<String, Object> prefs = const {},
    bool signedIn = true,
    void Function(FakeQuizApi server)? server,
  }) async {
    tester.view.physicalSize = const Size(1170, 2532);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    SharedPreferences.setMockInitialValues(prefs);
    final sp = await SharedPreferences.getInstance();
    final tokens = signedIn ? signedInTokens() : MemoryTokenStore();
    api = FakeQuizApi();
    server?.call(api);
    final container = ProviderContainer(overrides: [
      sharedPreferencesProvider.overrideWithValue(sp),
      tokenStoreProvider.overrideWithValue(tokens),
      quizApiProvider.overrideWithValue(api),
      progressApiProvider.overrideWithValue(api),
      leagueApiProvider.overrideWithValue(api),
      reviewApiProvider.overrideWithValue(api),
      authApiProvider.overrideWithValue(authApi = FakeAuthApi(tokens)),
    ]);
    addTearDown(container.dispose);
    await tester.pumpWidget(UncontrolledProviderScope(container: container, child: const NyayaApp()));
    await tester.pump(const Duration(milliseconds: 500));
    return container;
  }

  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 12; i++) {
      await tester.pump(const Duration(milliseconds: 150));
    }
  }

  testWidgets('new user goes through onboarding to home', (tester) async {
    final c = await pumpApp(tester);
    expect(find.text('Choose your language'), findsOneWidget);

    await tester.tap(find.text('English').first);
    await settle(tester);
    // Intro slides: two "next" arrows, then Get Started.
    for (var i = 0; i < 2; i++) {
      await tester.tap(find.byTooltip('Continue'));
      await settle(tester);
    }
    await tester.tap(find.text('Get Started'));
    await settle(tester);
    await tester.tap(find.text('Law aspirant'));
    await settle(tester);
    await tester.tap(find.text('CONTINUE'));
    await settle(tester);
    await tester.tap(find.text('CONTINUE')); // keep default goal
    await settle(tester);
    await tester.enterText(find.byType(TextField), 'Asha');
    await settle(tester);
    await tester.tap(find.text('COMMIT TO MY GOAL'));
    await settle(tester);

    final p = c.read(profileProvider);
    expect(p.onboarded, isTrue);
    expect(p.name, 'Asha');
    expect(p.energy, 5);
    // Premium is hidden in the beta: no paywall after onboarding, straight to Home.
    await tester.pump(const Duration(milliseconds: 600));
    await settle(tester);
    expect(find.text('Maybe later'), findsNothing);
    expect(find.text('Explore Law'), findsOneWidget);
    expect(find.text('CONTINUE WHERE YOU LEFT OFF'), findsNothing);
  });

  testWidgets('playing a Case Path level end to end awards stars and XP', (tester) async {
    final onboarded = jsonEncode({'onboarded': true, 'name': 'Ravi', 'coins': 60, 'persona': 'citizen'});
    final c = await pumpApp(tester, prefs: {'profile_v1': onboarded});
    await settle(tester);

    await tester.tap(find.text('Explore').first); // Constitution "Start here" card
    await settle(tester);
    expect(c.read(profileProvider).energy, 4, reason: 'energy is charged at start');

    // Answer every question correctly; only the (fake) server knows which is right.
    for (var i = 0; i < 6; i++) {
      final bankQuestion = find.textContaining('Question ${i + 1} of');
      expect(bankQuestion, findsOneWidget);
      final correct = api.correctTextFor(_current(c).id);
      await tester.tap(find.text(correct).first);
      await settle(tester);
      expect(find.text('Correct!'), findsOneWidget);
      await tester.tap(find.text(i == 5 ? 'FINISH' : 'NEXT'));
      await settle(tester);
    }

    expect(find.text('Perfect case!'), findsOneWidget);
    expect(c.read(journeyProvider).stars['constitution_1'], 3);
    final p = c.read(profileProvider);
    expect(p.totalXp, greaterThan(0));
    expect(p.streak, 1);
    expect(p.energy, 5, reason: '3-star bonus refunds 1 energy');
    expect(find.text('NEXT LEVEL'), findsOneWidget);
  });

  testWidgets('Play again after a failed level starts a fresh attempt', (tester) async {
    final onboarded = jsonEncode({'onboarded': true, 'name': 'Ravi', 'persona': 'citizen'});
    final c = await pumpApp(tester, prefs: {'profile_v1': onboarded});
    await settle(tester);

    await tester.tap(find.text('Explore').first);
    await settle(tester);
    // Every answer wrong, so the level fails and offers Play again.
    for (var i = 0; i < 6; i++) {
      await tester.tap(find.text(api.wrongTextFor(_current(c).id)).first);
      await settle(tester);
      await tester.tap(find.text(i == 5 ? 'FINISH' : 'NEXT'));
      await settle(tester);
    }
    expect(find.text('PLAY AGAIN'), findsOneWidget);
    final started = api.sessionsStarted;

    await tester.tap(find.text('PLAY AGAIN'));
    await settle(tester);
    expect(api.sessionsStarted, started + 1, reason: 'a new server session');
    expect(find.textContaining('Question 1 of'), findsOneWidget);
    expect(find.text('PLAY AGAIN'), findsNothing);
  });

  testWidgets('a wrong answer shows the right one from the server, and a failed send can be retried', (tester) async {
    final onboarded = jsonEncode({'onboarded': true, 'name': 'Ravi', 'persona': 'citizen'});
    final c = await pumpApp(tester, prefs: {'profile_v1': onboarded});
    await settle(tester);
    await tester.tap(find.text('Explore').first);
    await settle(tester);

    final q = _current(c);
    api.failNextAnswer = true;
    await tester.tap(find.text(api.wrongTextFor(q.id)).first);
    await settle(tester);
    expect(find.text("Couldn't send your answer. Check your connection and tap again."), findsOneWidget);
    expect(find.text('Correct!'), findsNothing);

    await tester.tap(find.text(api.wrongTextFor(q.id)).first);
    await settle(tester);
    expect(find.text('Answer: ${api.correctTextFor(q.id)}'), findsOneWidget);
    expect(find.text('Because ${q.id}'), findsOneWidget, reason: 'explanation comes from the server');
    expect(find.text('Reference: Article ${q.difficulty}'), findsOneWidget);
    expect(find.text('Read the official text'), findsOneWidget, reason: 'the source has an official link');
  });

  testWidgets('a learner can delete their account with their password and starts over', (tester) async {
    final onboarded = jsonEncode({'onboarded': true, 'name': 'Ravi', 'persona': 'citizen'});
    final c = await pumpApp(tester, prefs: {'profile_v1': onboarded});
    await settle(tester);
    c.read(routerProvider).go(Routes.settings);
    await settle(tester);
    await tester.scrollUntilVisible(find.text('Delete account'), 300, scrollable: find.byType(Scrollable).first);
    await tester.tap(find.text('Delete account'));
    await settle(tester);

    final dialog = find.byType(AlertDialog);
    expect(find.descendant(of: dialog, matching: find.textContaining('cannot be undone')), findsOneWidget);

    // A wrong password keeps the account and says so.
    authApi.wrongPassword = true;
    await tester.enterText(find.descendant(of: dialog, matching: find.byType(TextField)), 'nope');
    await tester.tap(find.text('Delete my account'));
    await settle(tester);
    expect(find.text('That password is not right.'), findsOneWidget);
    expect(authApi.deleted, 0);

    authApi.wrongPassword = false;
    await tester.tap(find.text('Delete my account'));
    await settle(tester);
    expect(authApi.deleted, 1);
    expect(find.text('Choose your language'), findsOneWidget, reason: 'back to the start');
    expect(c.read(profileProvider).onboarded, isFalse);
  });

  testWidgets('a signed-out learner creates an account before the first quiz', (tester) async {
    final onboarded = jsonEncode({'onboarded': true, 'name': 'Asha', 'persona': 'citizen'});
    final c = await pumpApp(tester, prefs: {'profile_v1': onboarded}, signedIn: false);
    await settle(tester);

    await tester.tap(find.text('Explore').first);
    await settle(tester);
    expect(find.text('Create your free account'), findsOneWidget);
    expect(c.read(profileProvider).energy, 5, reason: 'no energy spent before signing in');

    await tester.enterText(find.widgetWithText(TextField, 'Email'), 'asha@test.local');
    await tester.enterText(find.widgetWithText(TextField, 'Password'), 'short');
    await tester.tap(find.text('CREATE ACCOUNT'));
    await settle(tester);
    expect(find.text('Enter a valid email and a password of at least 8 characters.'), findsOneWidget);

    await tester.enterText(find.widgetWithText(TextField, 'Password'), 'long enough');
    await tester.tap(find.text('CREATE ACCOUNT'));
    await settle(tester);
    expect(find.textContaining('Question 1 of'), findsOneWidget);
    expect(api.energy, 4, reason: 'the server charges the energy');
    expect(c.read(profileProvider).energy, 4);
    // The new account took the settings chosen during onboarding.
    expect(api.settings?.name, 'Asha');
    expect(api.settings?.persona, 'citizen');
    expect(api.settings?.onboarded, isTrue);
  });

  testWidgets('Journey tab shows the Case Path map and opens a level from its chapter card', (tester) async {
    final onboarded = jsonEncode({'onboarded': true, 'name': 'Ravi', 'persona': 'citizen'});
    await pumpApp(tester, prefs: {'profile_v1': onboarded});
    await settle(tester);

    await tester.tap(find.text('Journey'));
    await settle(tester);
    expect(find.text('Case Path'), findsOneWidget);
    expect(find.text('Your journey through Indian law'), findsOneWidget);
    expect(find.text('CHAPTER 1 · 0/3'), findsOneWidget);
    expect(find.text('You'), findsOneWidget);
    expect(tester.takeException(), isNull, reason: 'missing paintings fall back quietly');

    await tester.tap(find.text('CHAPTER 1 · 0/3'));
    await settle(tester);
    expect(find.text('Level 1'), findsOneWidget);
    expect(find.text('START'), findsOneWidget);
  });

  testWidgets('Home continue card resumes the next Case Path level', (tester) async {
    final onboarded = jsonEncode({'onboarded': true, 'name': 'Ravi', 'persona': 'citizen'});
    // Stars live on the server; the phone shows its copy.
    await pumpApp(
      tester,
      prefs: {'profile_v1': onboarded},
      server: (s) => s
        ..stars['constitution_1'] = 3
        ..quizzesCompleted = 1,
    );
    await settle(tester);

    expect(find.text('CONTINUE WHERE YOU LEFT OFF'), findsOneWidget);
    expect(find.text('Chapter 1 · Level 2'), findsOneWidget);
    expect(find.text('1/3'), findsOneWidget);

    await tester.tap(find.text('Continue'));
    await settle(tester);
    expect(find.textContaining('Question 1 of'), findsOneWidget);
  });

  testWidgets('Home shows latest updates and opens one', (tester) async {
    final onboarded = jsonEncode({'onboarded': true, 'name': 'Ravi', 'persona': 'citizen'});
    await pumpApp(tester, prefs: {'profile_v1': onboarded});
    await settle(tester);

    final updates = find.text('Latest legal updates');
    await tester.scrollUntilVisible(updates, 200, scrollable: find.byType(Scrollable).first);
    await settle(tester);
    expect(tester.takeException(), isNull, reason: 'missing thumbnails fall back quietly');

    final title = find.text('Supreme Court sets timelines for Governors on State Bills');
    expect(title, findsOneWidget);
    await tester.tap(title);
    await settle(tester);
    expect(find.text('Key points'), findsOneWidget);
  });

  testWidgets('Updates tab filters and saves updates', (tester) async {
    final onboarded = jsonEncode({'onboarded': true, 'name': 'Ravi', 'persona': 'citizen'});
    final c = await pumpApp(tester, prefs: {'profile_v1': onboarded});
    await settle(tester);

    await tester.tap(find.text('Updates').last);
    await settle(tester);
    expect(find.text('Legal Updates'), findsOneWidget);
    expect(find.text('Supreme Court sets timelines for Governors on State Bills'), findsOneWidget);
    expect(tester.takeException(), isNull, reason: 'missing thumbnails fall back quietly');

    await tester.tap(find.text('Supreme Court'));
    await settle(tester);
    expect(find.text('Waqf (Amendment) Act, 2025 receives Presidential assent'), findsNothing);
    expect(find.text('Supreme Court sets timelines for Governors on State Bills'), findsOneWidget);

    await tester.tap(find.bySemanticsLabel('Save update').first);
    await settle(tester);
    expect(c.read(savedUpdatesProvider), {'tn-governor-assent'});

    await tester.tap(find.text('All'));
    await settle(tester);
    expect(find.text('Waqf (Amendment) Act, 2025 receives Presidential assent'), findsOneWidget);
  });

  testWidgets('out of energy shows free alternatives instead of a dead end', (tester) async {
    final today = DateTime.now();
    final key = '${today.year.toString().padLeft(4, '0')}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';
    final profile = jsonEncode({'onboarded': true, 'name': 'Ravi', 'energy': 0, 'energyDay': key});
    // Energy lives on the server; the phone shows its copy.
    await pumpApp(tester, prefs: {'profile_v1': profile}, server: (s) => s.energy = 0);
    await settle(tester);

    await tester.tap(find.text('Explore').first); // Constitution "Start here" card
    await settle(tester);
    expect(find.text("You're out of energy"), findsOneWidget);
    expect(find.text("Play today's Daily Docket (free)"), findsOneWidget);
    expect(find.text('Ask the AI a legal question'), findsOneWidget);
    expect(find.text('Get unlimited energy'), findsNothing, reason: 'premium is hidden in the beta');
  });

  testWidgets('the league shows the server group, you, practice players and last week', (tester) async {
    final onboarded = jsonEncode({'onboarded': true, 'name': 'Ravi', 'persona': 'citizen'});
    final c = await pumpApp(
      tester,
      prefs: {'profile_v1': onboarded},
      server: (s) => s
        ..quizzesCompleted = 1
        ..totalXp = 250
        ..lastResult = const LeagueResult(weekId: '2026-W43', rank: 2, fromTier: 1, toTier: 2, bonusCoins: 50),
    );
    await settle(tester);
    // Last week's result arrives with the sync and is shown once.
    expect(find.text('Leaderboard'), findsOneWidget);
    await tester.tap(find.text('Leaderboard'));
    await settle(tester);
    expect(c.read(profileProvider).pendingLeagueOutcome, isNull);

    expect(find.textContaining('Ravi (You)'), findsOneWidget);
    expect(find.text('Practice player'), findsWidgets);
    expect(find.text('Finish a quiz this week to join a league.'), findsNothing);

    // Opening Home again doesn't show the same result twice.
    await tester.pageBack();
    await settle(tester);
    expect(find.text('Leaderboard'), findsNothing);
  });

  testWidgets('save and report a question, then find it on the Review page', (tester) async {
    final onboarded = jsonEncode({'onboarded': true, 'name': 'Ravi', 'persona': 'citizen'});
    final c = await pumpApp(tester, prefs: {'profile_v1': onboarded});
    await settle(tester);
    await tester.tap(find.text('Explore').first);
    await settle(tester);

    // Wrong on the first question: the explanation offers Save and Report.
    final first = _current(c);
    await tester.tap(find.text(api.wrongTextFor(first.id)).first);
    await settle(tester);
    // Below the explanation: scroll it up from under the answer bar.
    await tester.ensureVisible(find.text('Save'));
    await settle(tester);
    await tester.tap(find.text('Save'));
    await settle(tester);
    expect(api.savedQuestions, contains(first.questionId));
    expect(find.text('Saved'), findsOneWidget);

    await tester.ensureVisible(find.text('Report'));
    await settle(tester);
    await tester.tap(find.text('Report'));
    await settle(tester);
    await tester.tap(find.text('The law has changed'));
    await tester.enterText(find.byType(TextField), 'Now Section 173 BNSS');
    await tester.tap(find.text('Send report'));
    await settle(tester);
    expect(api.reports.single.versionId, first.id);
    expect(api.reports.single.reason, ReportReason.outdatedLaw);
    expect(api.reports.single.comment, 'Now Section 173 BNSS');
    expect(find.text('Thanks. Our legal team will check this question.'), findsOneWidget);
    // Let the message slide away from the answer bar.
    await tester.pump(const Duration(seconds: 5));
    await settle(tester);

    // Finish the level (the rest right), then open Review from Home.
    for (var i = 0; i < 6; i++) {
      if (i > 0) {
        await tester.tap(find.text(api.correctTextFor(_current(c).id)).first);
        await settle(tester);
      }
      await tester.tap(find.text(i == 5 ? 'FINISH' : 'NEXT'));
      await settle(tester);
    }
    await tester.tap(find.text('Back to map'));
    await settle(tester);
    await tester.tap(find.text('Home'));
    await settle(tester);
    final card = find.text('1 mistake · 1 saved');
    await tester.scrollUntilVisible(card, 200, scrollable: find.byType(Scrollable).first);
    await tester.tap(card);
    await settle(tester);
    expect(find.text('Question text ${first.id}'), findsOneWidget);
    expect(find.text('Wrong once'), findsOneWidget);
    expect(find.text('PRACTISE MISTAKES'), findsOneWidget);
  });
}


Question _current(ProviderContainer c) =>
    c.read(quizControllerProvider(const QuizRequest(QuizMode.casePath, levelId: 'constitution_1'))).current;
