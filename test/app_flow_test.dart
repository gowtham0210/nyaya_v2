import 'dart:convert';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:nyaya/app/app.dart';
import 'package:nyaya/app/router.dart';
import 'package:nyaya/core/api/token_store.dart';
import 'package:nyaya/core/config/features.dart';
import 'package:nyaya/core/services/sounds.dart';
import 'package:nyaya/core/storage/local_store.dart';
import 'package:nyaya/features/auth/application/auth_controller.dart';
import 'package:nyaya/features/auth/data/auth_api.dart';
import 'package:nyaya/core/theme/app_theme.dart';
import 'package:nyaya/features/journey/application/journey_controller.dart';
import 'package:nyaya/features/journey/presentation/journey_screen.dart';
import 'package:nyaya/features/legal_updates/data/legal_updates_repository.dart';
import 'package:nyaya/features/legal_updates/presentation/updates_screen.dart';
import 'package:nyaya/features/reminders/data/reminder_notifications.dart';
import 'package:nyaya/features/profile/application/profile_controller.dart';
import 'package:nyaya/features/profile/domain/user_profile.dart';
import 'package:nyaya/features/leaderboard/data/league_api.dart';
import 'package:nyaya/features/progress/application/progress_sync.dart';
import 'package:nyaya/features/progress/data/progress_api.dart';
import 'package:nyaya/features/progress/domain/server_progress.dart';
import 'package:nyaya/features/settings/presentation/settings_screen.dart';
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
  late FakeSounds sounds;

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
      legalUpdatesRepositoryProvider.overrideWithValue(FakeLegalUpdates()),
      reminderNotificationsProvider.overrideWithValue(FakeReminderNotifications()),
      soundPlayerProvider.overrideWithValue(sounds = FakeSounds()),
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
    await tester.tap(find.text('GET STARTED'));
    await settle(tester);

    final p = c.read(profileProvider);
    expect(p.onboarded, isTrue);
    expect(p.persona, Persona.aspirant);
    // No name or goal questions: the name stays empty, the goal keeps its default.
    expect(p.name, isEmpty);
    expect(p.dailyGoal, 3);
    expect(p.energy, 5);
    // No paywall after onboarding (premium is offered after the first quiz): straight to Home.
    await tester.pump(const Duration(milliseconds: 600));
    await settle(tester);
    expect(find.text('Maybe later'), findsNothing);
    expect(find.text('Explore Law'), findsOneWidget);
    expect(find.text('CONTINUE WHERE YOU LEFT OFF'), findsNothing);
  });

  testWidgets('a new learner picks a language, then creates an account, then sees the intro', (tester) async {
    final c = await pumpApp(tester, signedIn: false);
    expect(find.text('Choose your language'), findsOneWidget);
    await tester.tap(find.text('English').first);
    await settle(tester);

    expect(find.text('Create your free account'), findsOneWidget);
    expect(find.byTooltip('Close'), findsNothing);
    await tester.enterText(find.widgetWithText(TextField, 'Your name'), 'Meena');
    await tester.enterText(find.widgetWithText(TextField, 'Email'), 'meena@test.local');
    await tester.enterText(find.widgetWithText(TextField, 'Password'), 'long enough');
    await tester.tap(find.text('CREATE ACCOUNT'));
    await settle(tester);

    expect(c.read(authProvider)?.email, 'meena@test.local');
    expect(find.text('Create your free account'), findsNothing);
    // The intro slides follow, then the persona.
    for (var i = 0; i < 2; i++) {
      await tester.tap(find.byTooltip('Continue'));
      await settle(tester);
    }
    await tester.tap(find.text('Get Started'));
    await settle(tester);
    await tester.tap(find.text('Law aspirant'));
    await settle(tester);
    await tester.tap(find.text('GET STARTED'));
    await settle(tester);
    expect(c.read(profileProvider).onboarded, isTrue);
    expect(api.settings?.name, 'Meena');
  });

  testWidgets('playing a Case Path level end to end awards stars and XP', (tester) async {
    final onboarded = jsonEncode({'onboarded': true, 'name': 'Ravi', 'coins': 60, 'persona': 'citizen'});
    final c = await pumpApp(tester, prefs: {'profile_v1': onboarded});
    await settle(tester);

    await tester.tap(find.text('Start learning').first); // "Start your learning journey" card
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

    // Clearing a level for the first time opens the next one: "Level up!" first.
    expect(find.text('Level up!'), findsOneWidget);
    expect(find.text('Level 1 cleared · Constitution Basics'), findsOneWidget);
    expect(find.text('Level 2 is now open'), findsOneWidget);
    await tester.tap(find.text('CONTINUE'));
    await settle(tester);
    expect(find.text('Level up!'), findsNothing);
    expect(find.text('Perfect case!'), findsOneWidget);
    expect(sounds.played, [...List.filled(6, Sfx.correct), Sfx.levelComplete]);
    expect(c.read(journeyProvider).stars['constitution_1'], 3);
    final p = c.read(profileProvider);
    expect(p.totalXp, greaterThan(0));
    expect(p.streak, 1);
    expect(p.energy, 5, reason: '3-star bonus refunds 1 energy');
    expect(find.text('NEXT LEVEL'), findsOneWidget);

    // A cleared level is free to replay, and the sheet says so.
    await tester.tap(find.text('Back to map'));
    await settle(tester);
    await tester.tap(find.bySemanticsLabel(RegExp(r'^Level 1, Completed')).first);
    await settle(tester);
    expect(find.text('Free replay'), findsOneWidget);
    await tester.tap(find.text('REPLAY · FREE'));
    await settle(tester);
    expect(find.textContaining('Question 1 of'), findsOneWidget);
    expect(c.read(profileProvider).energy, 5);
    expect(api.energy, 5);
  });

  // Premium is hidden in the beta; run with --dart-define=NYAYA_PREMIUM=true.
  Future<void> finishFirstLevel(WidgetTester tester, ProviderContainer c) async {
    await settle(tester);
    await tester.tap(find.text('Start learning').first);
    await settle(tester);
    for (var i = 0; i < 6; i++) {
      await tester.tap(find.text(api.correctTextFor(_current(c).id)).first);
      await settle(tester);
      await tester.tap(find.text(i == 5 ? 'FINISH' : 'NEXT'));
      await settle(tester);
    }
  }

  testWidgets('premium is offered once, on the first quiz result', (tester) async {
    final onboarded = jsonEncode({'onboarded': true, 'name': 'Ravi', 'persona': 'citizen'});
    final c = await pumpApp(tester, prefs: {'profile_v1': onboarded});
    await finishFirstLevel(tester, c);

    expect(find.text('Unlock unlimited energy'), findsOneWidget);
    expect(c.read(localStoreProvider).readJson('premium_offer_v1'), isNotNull);
  }, skip: !Features.premium);

  testWidgets('premium is not offered again after it was shown', (tester) async {
    final onboarded = jsonEncode({'onboarded': true, 'name': 'Ravi', 'persona': 'citizen'});
    final c = await pumpApp(tester, prefs: {
      'profile_v1': onboarded,
      'premium_offer_v1': jsonEncode({'shown': true}),
    });
    await finishFirstLevel(tester, c);

    expect(find.text('Perfect case!'), findsOneWidget);
    expect(find.text('Unlock unlimited energy'), findsNothing);
  }, skip: !Features.premium);

  testWidgets('Play again after a failed level starts a fresh attempt', (tester) async {
    final onboarded = jsonEncode({'onboarded': true, 'name': 'Ravi', 'persona': 'citizen'});
    final c = await pumpApp(tester, prefs: {'profile_v1': onboarded});
    await settle(tester);

    await tester.tap(find.text('Start learning').first);
    await settle(tester);
    // Every answer wrong, so the level fails and offers Play again.
    for (var i = 0; i < 6; i++) {
      await tester.tap(find.text(api.wrongTextFor(_current(c).id)).first);
      await settle(tester);
      await tester.tap(find.text(i == 5 ? 'FINISH' : 'NEXT'));
      await settle(tester);
    }
    expect(find.text('PLAY AGAIN'), findsOneWidget);
    expect(sounds.played, List.filled(6, Sfx.wrong), reason: 'a failed level ends quietly');
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
    await tester.tap(find.text('Start learning').first);
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

  testWidgets('the app tells the server it was opened, once a day', (tester) async {
    final onboarded = jsonEncode({'onboarded': true, 'name': 'Ravi', 'persona': 'citizen'});
    final c = await pumpApp(tester, prefs: {'profile_v1': onboarded});
    await settle(tester);
    expect(api.appOpens, 1, reason: 'on start, signed in');

    // Coming back to the app the same day sends nothing more.
    final notifier = c.read(progressSyncProvider.notifier);
    await notifier.noteOpen();
    await notifier.noteOpen();
    expect(api.appOpens, 1);
  });

  testWidgets('a signed-out learner sends no app-open', (tester) async {
    final onboarded = jsonEncode({'onboarded': true, 'name': 'Asha', 'persona': 'citizen'});
    final c = await pumpApp(tester, prefs: {'profile_v1': onboarded}, signedIn: false);
    await settle(tester);
    await c.read(progressSyncProvider.notifier).noteOpen();
    expect(api.appOpens, 0);
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

  testWidgets('a signed-out learner must create an account before anything else', (tester) async {
    final onboarded = jsonEncode({'onboarded': true, 'name': 'Asha', 'persona': 'citizen'});
    final c = await pumpApp(tester, prefs: {'profile_v1': onboarded}, signedIn: false);
    await settle(tester);

    expect(find.text('Create your free account'), findsOneWidget, reason: 'sign-in is the first screen');
    expect(find.byTooltip('Close'), findsNothing, reason: 'it cannot be skipped');
    expect(c.read(profileProvider).energy, 5);

    await tester.enterText(find.widgetWithText(TextField, 'Email'), 'asha@test.local');
    await tester.enterText(find.widgetWithText(TextField, 'Password'), 'short');
    await tester.tap(find.text('CREATE ACCOUNT'));
    await settle(tester);
    expect(find.text('Enter a valid email and a password of at least 8 characters.'), findsOneWidget);

    await tester.enterText(find.widgetWithText(TextField, 'Password'), 'long enough');
    await tester.tap(find.text('CREATE ACCOUNT'));
    await settle(tester);
    expect(c.read(routerProvider).state.matchedLocation, Routes.home);

    await tester.tap(find.text('Start learning').first);
    await settle(tester);
    expect(find.textContaining('Question 1 of'), findsOneWidget);
    expect(api.energy, 4, reason: 'the server charges the energy');
    expect(c.read(profileProvider).energy, 4);
    // The new account took the settings chosen during onboarding.
    expect(api.settings?.name, 'Asha');
    expect(api.settings?.persona, 'citizen');
    expect(api.settings?.onboarded, isTrue);
  });

  testWidgets('the name typed at sign-up becomes the learner name, and sign-out clears it', (tester) async {
    // Onboarding no longer asks for a name, so the phone has none.
    final onboarded = jsonEncode({'onboarded': true, 'name': '', 'persona': 'citizen'});
    final c = await pumpApp(tester, prefs: {'profile_v1': onboarded}, signedIn: false);
    await settle(tester);

    await tester.enterText(find.widgetWithText(TextField, 'Your name'), 'Nisha');
    await tester.enterText(find.widgetWithText(TextField, 'Email'), 'nisha@test.local');
    await tester.enterText(find.widgetWithText(TextField, 'Password'), 'long enough');
    await tester.tap(find.text('CREATE ACCOUNT'));
    await settle(tester);
    expect(api.settings?.name, 'Nisha', reason: 'not the "Learner" placeholder');
    expect(c.read(profileProvider).name, 'Nisha');

    await c.read(authProvider.notifier).signOut();
    await settle(tester);
    expect(c.read(profileProvider).name, isEmpty);
    expect(find.text('Create your free account'), findsOneWidget, reason: 'signing out leads to sign-in');
  });

  testWidgets('an account saved with the placeholder name gets its sign-up name back', (tester) async {
    final c = await pumpApp(tester, server: (s) {
      s.settings = const ServerSettings(
        name: 'Learner',
        persona: 'citizen',
        language: 'en',
        dailyGoal: 3,
        onboarded: true,
      );
    });
    await settle(tester);
    expect(api.settings?.name, 'Ravi');
    expect(c.read(profileProvider).name, 'Ravi');
  });

  testWidgets('a learner who forgot their password resets it with the emailed code and plays', (tester) async {
    final onboarded = jsonEncode({'onboarded': true, 'name': 'Asha', 'persona': 'citizen'});
    final c = await pumpApp(tester, prefs: {'profile_v1': onboarded}, signedIn: false);
    await settle(tester);

    await tester.tap(find.text('I already have an account'));
    await settle(tester);
    await tester.enterText(find.widgetWithText(TextField, 'Email'), 'asha@test.local');
    await tester.tap(find.text('Forgot password?'));
    await settle(tester);

    expect(find.text('Reset your password'), findsOneWidget);
    await tester.tap(find.text('SEND CODE'));
    await settle(tester);
    expect(authApi.resetRequested, ['asha@test.local'], reason: 'the email typed on sign-in carries over');
    expect(find.textContaining("we've sent it a 6-digit code"), findsOneWidget);

    await tester.enterText(find.widgetWithText(TextField, '6-digit code'), '000000');
    await tester.enterText(find.widgetWithText(TextField, 'New password'), 'a new password');
    await tester.tap(find.text('SET NEW PASSWORD'));
    await settle(tester);
    expect(find.text('This code is wrong or has expired. Ask for a new one.'), findsOneWidget);

    await tester.enterText(find.widgetWithText(TextField, '6-digit code'), FakeAuthApi.resetCode);
    await tester.tap(find.text('SET NEW PASSWORD'));
    await settle(tester);
    expect(c.read(authProvider)?.email, 'asha@test.local');
    expect(c.read(routerProvider).state.matchedLocation, Routes.home, reason: 'signed in, on to Home');
  });

  testWidgets('Journey tab shows the Case Path map and opens a level from its chapter card', (tester) async {
    final onboarded = jsonEncode({'onboarded': true, 'name': 'Ravi', 'persona': 'citizen'});
    await pumpApp(tester, prefs: {'profile_v1': onboarded});
    await settle(tester);

    await tester.tap(find.text('Journey'));
    await settle(tester);
    expect(find.text('Learning Path'), findsOneWidget);
    expect(find.text('Your journey through Indian law'), findsOneWidget);
    expect(find.text('CHAPTER 1 · 0/3 COMPLETED'), findsOneWidget);
    expect(find.text('You'), findsOneWidget);
    expect(tester.takeException(), isNull, reason: 'missing paintings fall back quietly');

    await tester.tap(find.text('CHAPTER 1 · 0/3 COMPLETED'));
    await settle(tester);
    expect(find.text('Level 1'), findsOneWidget);
    // What a try costs and what each star needs, before starting.
    expect(find.text('6 questions'), findsOneWidget);
    expect(find.text('1 energy'), findsOneWidget);
    expect(find.text('No time limit'), findsOneWidget);
    expect(find.text('50% · pass'), findsOneWidget);
    expect(find.text('80%'), findsOneWidget);
    expect(find.text('100%'), findsOneWidget);
    expect(find.text('START · 1 ENERGY'), findsOneWidget);

    await tester.tap(find.text('How scoring works'));
    await settle(tester);
    expect(find.text('Your best score is kept. A lower score never takes away stars.'), findsOneWidget);
    expect(find.text("Wrong answers don't take away marks."), findsOneWidget);
  });

  testWidgets('a locked level says what to do next and the list shows every state', (tester) async {
    final onboarded = jsonEncode({'onboarded': true, 'name': 'Ravi', 'persona': 'citizen'});
    final c = await pumpApp(tester, prefs: {'profile_v1': onboarded}, server: (s) => s..stars['constitution_1'] = 2);
    await settle(tester);
    await tester.tap(find.text('Journey'));
    await settle(tester);

    await tester.tap(find.byTooltip('Show levels as a list'));
    await settle(tester);
    expect(find.text('All levels'), findsOneWidget);
    expect(find.text('Completed'), findsOneWidget);
    expect(find.text('Next step'), findsOneWidget);
    expect(find.text('1 of 3 levels done'), findsOneWidget);

    // Level 3 of the first chapter is locked.
    await tester.tap(find.text('Level 3').first);
    await settle(tester);
    expect(find.text('Level 3 · Locked'), findsOneWidget);
    expect(
      find.text('Levels open in order. Your next step is Level 2 · Constitution Basics.'),
      findsOneWidget,
    );
    expect(find.textContaining('ENERGY'), findsNothing, reason: 'a locked level has no start button');
    await tester.tap(find.text('Show my next step'));
    await settle(tester);
    expect(find.text('Level 3 · Locked'), findsNothing);
    expect(c.read(journeyProvider).current?.id, 'constitution_2');
  });

  testWidgets('a chapter chest goes from locked to ready to collected, once', (tester) async {
    final onboarded = jsonEncode({'onboarded': true, 'name': 'Ravi', 'persona': 'citizen', 'coins': 60});
    final c = await pumpApp(
      tester,
      prefs: {'profile_v1': onboarded},
      server: (s) => s
        ..stars.addAll({'constitution_1': 3, 'constitution_2': 2, 'constitution_3': 1})
        ..chestOffline = true,
    );
    await settle(tester);
    await tester.tap(find.text('Journey'));
    await settle(tester);

    // The second chapter's chest is still locked.
    await tester.tap(find.byTooltip('Show levels as a list'));
    await settle(tester);
    final locked = find.text('Chapter chest').at(1);
    await tester.ensureVisible(locked);
    await tester.pump();
    await tester.tap(locked);
    await settle(tester);
    expect(find.text('Complete all levels in this chapter to unlock your reward.'), findsOneWidget);
    expect(find.text('0 of 3 levels done'), findsOneWidget);
    expect(find.text('CONTINUE LEARNING'), findsOneWidget);
    expect(find.text('OPEN CHEST'), findsNothing);
    await tester.tap(find.text('CONTINUE LEARNING'));
    await settle(tester);

    await tester.tap(find.byTooltip('Show levels as a list'));
    await settle(tester);
    await tester.tap(find.text('Your chapter reward is ready'));
    await settle(tester);
    expect(find.text('Reward: 30 coins'), findsOneWidget);

    // Offline: no reward is shown and the chest can still be opened.
    await tester.tap(find.text('OPEN CHEST'));
    await settle(tester);
    expect(find.textContaining("Couldn't open the chest"), findsOneWidget);
    expect(find.text('OPEN CHEST'), findsOneWidget);
    expect(c.read(journeyProvider).openedChests, isEmpty);

    api.chestOffline = false;
    await tester.tap(find.text('OPEN CHEST'));
    await tester.tap(find.text('OPEN CHEST'), warnIfMissed: false); // a second tap while claiming
    await settle(tester);
    expect(find.text('Chapter reward collected'), findsOneWidget);
    expect(find.text('You received 30 coins.'), findsOneWidget);
    expect(find.text('OPEN CHEST'), findsNothing);
    expect(api.openedChests, {'constitution_chest'});
    expect(c.read(profileProvider).coins, 90, reason: 'paid once');
    expect(c.read(journeyProvider).openedChests, {'constitution_chest'});
  });

  testWidgets('resource chips explain stars, energy and coins', (tester) async {
    final semantics = tester.ensureSemantics();
    final onboarded = jsonEncode({'onboarded': true, 'name': 'Ravi', 'persona': 'citizen'});
    await pumpApp(tester, prefs: {'profile_v1': onboarded});
    await settle(tester);
    await tester.tap(find.text('Journey'));
    await settle(tester);

    for (final (label, text) in [
      ('0 Stars', 'Earn up to 3 stars on each level'),
      ('5 energy left', 'Each Learning Path level costs 1 energy. You get 5 free energy every day.'),
      ('60 Coins', 'Spend them in the Store on energy refills and streak freezes.'),
    ]) {
      await tester.tap(find.bySemanticsLabel(label));
      await settle(tester);
      expect(find.textContaining(text), findsOneWidget, reason: label);
      await tester.tapAt(const Offset(20, 20)); // outside the sheet
      await settle(tester);
    }

    // The coins sheet leads straight to the store, not the top of Settings.
    await tester.tap(find.bySemanticsLabel('60 Coins'));
    await settle(tester);
    await tester.tap(find.text('Open the Store'));
    await settle(tester);
    final store = tester.getRect(find.textContaining('STORE'));
    expect(store.top, lessThan(400), reason: 'store section scrolled to the top');
    expect(find.text('Streak freeze'), findsOneWidget);
    semantics.dispose();
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
    expect(find.text('1 of 3 levels done'), findsOneWidget);

    await tester.tap(find.text('Continue'));
    await settle(tester);
    expect(find.textContaining('Question 1 of'), findsOneWidget);
  });

  double top(WidgetTester tester, String text) => tester.getTopLeft(find.text(text).first).dy;

  /// A screen tall enough to build every Home section at once.
  Future<void> tallScreen(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1170, 12000);
    await settle(tester);
  }

  testWidgets('a new learner sees where to start before the quiz modes, and featured laws last', (tester) async {
    final onboarded = jsonEncode({'onboarded': true, 'name': 'Ravi', 'persona': 'citizen'});
    await pumpApp(tester, prefs: {'profile_v1': onboarded});
    await tallScreen(tester);

    expect(find.text('Start your learning journey'), findsOneWidget);
    expect(find.text('RECOMMENDED START'), findsOneWidget);
    expect(find.text('CONTINUE WHERE YOU LEFT OFF'), findsNothing);
    expect(top(tester, 'Start your learning journey'), lessThan(top(tester, 'Quiz modes')));
    expect(top(tester, 'Core Laws'), lessThan(top(tester, 'FEATURED')), reason: 'featured laws come last');
    // Energy in words: Case Path and Duel cost 1, Exam 2, the Daily Docket is free.
    expect(find.text('1 energy'), findsNWidgets(2));
    expect(find.text('2 energy'), findsOneWidget);
    expect(find.text('Free'), findsOneWidget);
  });

  testWidgets('a returning learner sees Continue first, before the quiz modes', (tester) async {
    final onboarded = jsonEncode({'onboarded': true, 'name': 'Ravi', 'persona': 'citizen'});
    await pumpApp(tester, prefs: {'profile_v1': onboarded}, server: (s) => s..stars['constitution_1'] = 3);
    await tallScreen(tester);

    expect(find.text('Start your learning journey'), findsNothing);
    expect(top(tester, 'CONTINUE WHERE YOU LEFT OFF'), lessThan(top(tester, 'Quiz modes')));
    expect(top(tester, 'Quiz modes'), lessThan(top(tester, 'FEATURED')), reason: 'no promotion above the learning');
  });

  testWidgets('Home has a top bar with the app name, and search finds laws, topics and updates', (tester) async {
    final onboarded = jsonEncode({'onboarded': true, 'name': 'Ravi', 'persona': 'citizen'});
    final c = await pumpApp(tester, prefs: {'profile_v1': onboarded});
    await settle(tester);
    expect(find.text('Nyaya Kural'), findsOneWidget);

    await tester.tap(find.byTooltip('Search'));
    await settle(tester);
    await tester.enterText(find.byType(TextField), 'bns');
    await settle(tester);
    expect(find.text('Bharatiya Nyaya Sanhita (BNS)'), findsOneWidget);
    expect(find.text('Criminal Law (BNS)'), findsOneWidget, reason: 'the topic matches too');
    expect(find.text('Ask AI: “bns”'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'waqf');
    await settle(tester);
    expect(find.text('Waqf (Amendment) Act, 2025 receives Presidential assent'), findsOneWidget);

    // A law opens its Journey chapter, not the chat.
    await tester.enterText(find.byType(TextField), 'bns');
    await settle(tester);
    await tester.tap(find.text('Bharatiya Nyaya Sanhita (BNS)'));
    await settle(tester);
    expect(c.read(routerProvider).state.matchedLocation, Routes.journey);
    // The criminal law chapter is still locked, so its sheet says what to do first.
    expect(find.text('Level 1 · Locked'), findsOneWidget);
    expect(c.read(journeyFocusProvider), isNull, reason: 'the request is used once');
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

    // The filter row scrolls sideways; the Saved pill pushed this one off a small screen.
    await tester.drag(find.text('All'), const Offset(-150, 0));
    await settle(tester);
    await tester.tap(find.text('Supreme Court'));
    await settle(tester);
    expect(find.text('Waqf (Amendment) Act, 2025 receives Presidential assent'), findsNothing);
    expect(find.text('Supreme Court sets timelines for Governors on State Bills'), findsOneWidget);

    await tester.tap(find.bySemanticsLabel('Save update').first);
    await settle(tester);
    expect(c.read(savedUpdatesProvider), {'news-1'});

    await tester.drag(find.text('Supreme Court'), const Offset(300, 0));
    await settle(tester);
    await tester.tap(find.text('All'));
    await settle(tester);
    expect(find.text('Waqf (Amendment) Act, 2025 receives Presidential assent'), findsOneWidget);

    // Saved shows only what was bookmarked.
    await tester.tap(find.text('Saved'));
    await settle(tester);
    expect(find.text('Supreme Court sets timelines for Governors on State Bills'), findsOneWidget);
    expect(find.text('Waqf (Amendment) Act, 2025 receives Presidential assent'), findsNothing);
  });

  testWidgets('out of energy shows free alternatives instead of a dead end', (tester) async {
    final today = DateTime.now();
    final key = '${today.year.toString().padLeft(4, '0')}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';
    final profile = jsonEncode({'onboarded': true, 'name': 'Ravi', 'energy': 0, 'energyDay': key});
    // Energy lives on the server; the phone shows its copy.
    await pumpApp(tester, prefs: {'profile_v1': profile}, server: (s) => s.energy = 0);
    await settle(tester);

    await tester.tap(find.text('Start learning').first); // "Start your learning journey" card
    await settle(tester);
    expect(find.text("You're out of energy"), findsOneWidget);
    expect(find.text("Play Today's Questions (free)"), findsOneWidget);
    expect(find.text('Ask the AI a legal question'), findsOneWidget);
    expect(find.text('Get unlimited energy'), findsNothing, reason: 'premium is hidden in the beta');
  });

  testWidgets('Reset this phone brings back onboarding, keeps the name, and does not repeat the league result', (tester) async {
    final onboarded = jsonEncode({'onboarded': true, 'name': 'Ravi', 'persona': 'citizen', 'leagueResultSeen': '2026-W43'});
    final c = await pumpApp(
      tester,
      prefs: {'profile_v1': onboarded},
      server: (s) => s
        ..settings = const ServerSettings(name: 'Ravi', persona: 'citizen', language: 'en', dailyGoal: 3, onboarded: true)
        ..quizzesCompleted = 1
        ..lastResult = const LeagueResult(weekId: '2026-W43', rank: 1, fromTier: 1, toTier: 2, bonusCoins: 50),
    );
    await settle(tester);
    expect(find.text('Leaderboard'), findsNothing, reason: 'last week was already seen');

    c.read(routerProvider).push(Routes.settings);
    await settle(tester);
    // Settings is on top of the tabs: scroll its list, not Home's.
    final reset = find.text('Reset this phone');
    await tester.scrollUntilVisible(
      reset,
      300,
      scrollable: find.descendant(of: find.byType(SettingsScreen), matching: find.byType(Scrollable)).first,
    );
    await tester.pump();
    await tester.tap(reset);
    await settle(tester);
    expect(find.textContaining('Your XP, stars, coins and streak are saved to your account'), findsOneWidget);
    await tester.tap(find.text('Reset'));
    await settle(tester);

    expect(find.text('Choose your language'), findsOneWidget);
    expect(api.settings!.onboarded, isFalse, reason: 'the account starts over too');
    expect(c.read(profileProvider).name, 'Ravi');
    expect(find.text('Leaderboard'), findsNothing, reason: 'no league result again');
  });

  testWidgets('leaving Home while the league result is open still marks it seen', (tester) async {
    final onboarded = jsonEncode({'onboarded': true, 'name': 'Ravi', 'persona': 'citizen'});
    final c = await pumpApp(
      tester,
      prefs: {'profile_v1': onboarded},
      server: (s) => s
        ..quizzesCompleted = 1
        ..lastResult = const LeagueResult(weekId: '2026-W43', rank: 2, fromTier: 1, toTier: 2, bonusCoins: 50),
    );
    await settle(tester);
    expect(find.text('Leaderboard'), findsOneWidget, reason: 'the result dialog is open');
    // A screen outside the tabs replaces Home (as a sign-out does) and closes the dialog.
    c.read(routerProvider).go(Routes.signIn);
    await settle(tester);
    expect(tester.takeException(), isNull);
    expect(c.read(profileProvider).pendingLeagueOutcome, isNull, reason: 'still marked as seen');
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

  testWidgets('the all-time tab shows the server board, and you further down', (tester) async {
    final onboarded = jsonEncode({'onboarded': true, 'name': 'Ravi', 'persona': 'citizen'});
    final c = await pumpApp(
      tester,
      prefs: {'profile_v1': onboarded},
      server: (s) => s
        ..quizzesCompleted = 1
        ..totalXp = 5
        ..allTimeOthers = [for (var i = 0; i < 55; i++) (name: 'Learner $i', xp: 1000 - i)],
    );
    await settle(tester);
    c.read(routerProvider).push(Routes.leaderboard);
    await settle(tester);
    await tester.tap(find.text('All time'));
    await settle(tester);
    expect(find.text('56 learners on the board'), findsOneWidget);
    // The podium shows the top three.
    expect(find.text('Learner 0'), findsOneWidget);
    expect(find.text('Learner 2'), findsOneWidget);
    // Past the top 50, your own place still shows at the end.
    final me = find.textContaining('Ravi (You)');
    await tester.scrollUntilVisible(me, 400, scrollable: find.byType(Scrollable).last);
    expect(me, findsOneWidget);
    expect(find.text('56'), findsOneWidget);
    expect(find.text('Learner 54'), findsNothing);
  });

  testWidgets('without XP the all-time tab asks for a first quiz', (tester) async {
    final onboarded = jsonEncode({'onboarded': true, 'name': 'Ravi', 'persona': 'citizen'});
    final c = await pumpApp(
      tester,
      prefs: {'profile_v1': onboarded},
      server: (s) => s..allTimeOthers = [(name: 'Asha K.', xp: 40)],
    );
    await settle(tester);
    c.read(routerProvider).push(Routes.leaderboard);
    await settle(tester);
    await tester.tap(find.text('All time'));
    await settle(tester);
    expect(find.text('Finish a quiz to get on the all-time board.'), findsOneWidget);
    expect(find.text('Asha K.'), findsOneWidget);
  });

  testWidgets('a duel from Home races the opponent the server picked, and the server settles it', (tester) async {
    final onboarded = jsonEncode({'onboarded': true, 'name': 'Ravi', 'persona': 'citizen'});
    final c = await pumpApp(tester, prefs: {'profile_v1': onboarded});
    await settle(tester);
    const duel = QuizRequest(QuizMode.duel);
    // Home's quiz modes section opens it.
    final tile = find.text('Quick Quiz');
    await tester.scrollUntilVisible(tile, 200, scrollable: find.byType(Scrollable).first);
    await tester.ensureVisible(tile);
    await settle(tester);
    await tester.tap(tile);
    await settle(tester);

    // The opponent comes from the server, not a made-up list.
    expect(find.text('Asha K.'), findsWidgets);
    expect(find.text('Practice player'), findsNothing);
    final count = c.read(quizControllerProvider(duel)).questions.length;
    for (var i = 0; i < count; i++) {
      final q = c.read(quizControllerProvider(duel)).current;
      await tester.tap(find.text(api.correctTextFor(q.id)).first);
      await settle(tester);
      await tester.tap(find.text(i == count - 1 ? 'FINISH' : 'NEXT'));
      await settle(tester);
    }
    expect(find.text('You won the duel!'), findsOneWidget);
    expect(sounds.played.last, Sfx.duelWon);
    // The answer times reached the server, and the record is the server's.
    expect(api.duelsWon, 1);
    final p = c.read(profileProvider);
    expect((p.duelRating, p.duelsPlayed, p.duelsWon), (1016, 1, 1));
  });

  testWidgets('with sound effects off nothing plays, and sounds load only when on', (tester) async {
    final onboarded = jsonEncode({'onboarded': true, 'name': 'Ravi', 'persona': 'citizen', 'soundOn': false});
    final c = await pumpApp(tester, prefs: {'profile_v1': onboarded});
    await settle(tester);
    expect(sounds.warmedUp, isFalse);
    await tester.tap(find.text('Start learning').first);
    await settle(tester);
    await tester.tap(find.text(api.correctTextFor(_current(c).id)).first);
    await settle(tester);
    expect(find.text('Correct!'), findsOneWidget);
    expect(sounds.played, isEmpty);
  });

  testWidgets('a timed question ticks for its last five seconds', (tester) async {
    final onboarded = jsonEncode({'onboarded': true, 'name': 'Ravi', 'persona': 'citizen'});
    final c = await pumpApp(tester, prefs: {'profile_v1': onboarded});
    await settle(tester);
    expect(sounds.warmedUp, isTrue);
    const duel = QuizRequest(QuizMode.duel);
    c.read(routerProvider).push(Routes.quiz, extra: duel);
    await settle(tester);
    int left() => c.read(quizControllerProvider(duel)).secondsLeft!;
    // 15 seconds a question: quiet until 5 are left, then one tick a second.
    while (left() > 6) {
      await tester.pump(const Duration(seconds: 1));
    }
    expect(sounds.played, isEmpty);
    while (left() > 1) {
      await tester.pump(const Duration(seconds: 1));
    }
    expect(sounds.played, List.filled(5, Sfx.tick));

    // Time runs out: the server is told, and the right answer shows at once.
    await tester.pump(const Duration(seconds: 1));
    await settle(tester);
    expect(find.text("Time's up"), findsOneWidget);
    expect(find.textContaining('Answer: '), findsOneWidget);
    expect(api.verdictsSent.last?.reveal.correctIndex, isNotNull);
    c.read(routerProvider).go(Routes.home);
    await settle(tester);
  });

  testWidgets('a practice opponent is labelled as one', (tester) async {
    final onboarded = jsonEncode({'onboarded': true, 'name': 'Ravi', 'persona': 'citizen'});
    final c = await pumpApp(tester, prefs: {'profile_v1': onboarded}, server: (s) => s.practiceOpponent = true);
    await settle(tester);
    c.read(routerProvider).push(Routes.quiz, extra: const QuizRequest(QuizMode.duel));
    await settle(tester);
    expect(find.text('Meera K.'), findsWidgets);
    expect(find.text('Practice player'), findsOneWidget);
    // Leave the quiz, so its countdown stops.
    c.read(routerProvider).go(Routes.home);
    await settle(tester);
  });

  testWidgets('save and report a question, then find it on the Review page', (tester) async {
    final onboarded = jsonEncode({'onboarded': true, 'name': 'Ravi', 'persona': 'citizen'});
    final c = await pumpApp(tester, prefs: {'profile_v1': onboarded});
    await settle(tester);
    await tester.tap(find.text('Start learning').first);
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
    await tester.tap(find.text('CONTINUE')); // past "Level up!"
    await settle(tester);
    await tester.tap(find.text('Back to map'));
    await settle(tester);
    await tester.tap(find.text('Home'));
    await settle(tester);
    final card = find.text('1 mistake · 1 saved');
    await tester.scrollUntilVisible(card, 200, scrollable: find.byType(Scrollable).first);
    // Mid-screen, clear of the pinned top bar.
    await Scrollable.ensureVisible(tester.element(card), alignment: 0.5);
    await settle(tester);
    expect(find.text('Review your mistakes'), findsOneWidget);
    expect(find.text('Review now'), findsOneWidget);
    await tester.tap(card);
    await settle(tester);
    expect(find.text('Question text ${first.id}'), findsOneWidget);
    expect(find.text('Wrong once'), findsOneWidget);
    expect(find.text('PRACTISE MISTAKES'), findsOneWidget);
  });

  testWidgets('before an answer there is no dead Next button, and answers say their state', (tester) async {
    final semantics = tester.ensureSemantics();
    final onboarded = jsonEncode({'onboarded': true, 'name': 'Ravi', 'persona': 'citizen'});
    final c = await pumpApp(tester, prefs: {'profile_v1': onboarded});
    await settle(tester);
    await tester.tap(find.text('Start learning').first);
    await settle(tester);

    expect(find.text('Tap an answer to check it.'), findsOneWidget);
    expect(find.text('NEXT'), findsNothing);
    expect(find.text('Select an answer'), findsNothing);
    expect(find.text('1/6'), findsNothing, reason: '"Question 1 of 6" is enough');

    final q = _current(c);
    final wrong = api.wrongTextFor(q.id);
    await tester.tap(find.text(wrong).first);
    await settle(tester);
    expect(find.text('Not quite'), findsOneWidget);
    expect(find.bySemanticsLabel(RegExp(', your answer, wrong\$')), findsOneWidget);
    expect(find.bySemanticsLabel(RegExp(', correct answer\$')), findsOneWidget);
    expect(find.text('NEXT'), findsOneWidget);

    // A second tap on another option sends nothing.
    await tester.tap(find.text(api.correctTextFor(q.id)).first, warnIfMissed: false);
    await settle(tester);
    expect(c.read(quizControllerProvider(const QuizRequest(QuizMode.casePath, levelId: 'constitution_1'))).answers, hasLength(1));
    semantics.dispose();
  });

  testWidgets('leaving says exactly what happens to the energy', (tester) async {
    final onboarded = jsonEncode({'onboarded': true, 'name': 'Ravi', 'persona': 'citizen'});
    final c = await pumpApp(tester, prefs: {'profile_v1': onboarded});
    await settle(tester);
    await tester.tap(find.text('Start learning').first);
    await settle(tester);

    await tester.tap(find.byTooltip('Close'));
    await settle(tester);
    expect(find.text("You haven't answered yet, so you'll get your 1 energy back."), findsOneWidget);
    await tester.tap(find.text('Keep playing'));
    await settle(tester);

    await tester.tap(find.text(api.correctTextFor(_current(c).id)).first);
    await settle(tester);
    await tester.tap(find.byTooltip('Close'));
    await settle(tester);
    expect(
      find.text(
        "This attempt will end and can't be continued later. Your answers so far won't count, "
        "and the 1 energy isn't given back.",
      ),
      findsOneWidget,
    );
    await tester.tap(find.text('Leave'));
    await settle(tester);
    expect(c.read(profileProvider).energy, 4, reason: 'an answered attempt keeps its charge');
  });

  testWidgets('leaving offline before answering says the energy was not given back', (tester) async {
    final onboarded = jsonEncode({'onboarded': true, 'name': 'Ravi', 'persona': 'citizen'});
    await pumpApp(tester, prefs: {'profile_v1': onboarded}, server: (s) => s.abandonOffline = true);
    await settle(tester);
    await tester.tap(find.text('Start learning').first);
    await settle(tester);
    await tester.tap(find.byTooltip('Close'));
    await settle(tester);
    await tester.tap(find.text('Leave'));
    await settle(tester);
    expect(find.text("Couldn't reach Nyaya Kural, so your energy wasn't given back."), findsOneWidget);
  });

  testWidgets('the free Daily Docket promises no refund when you leave', (tester) async {
    final onboarded = jsonEncode({'onboarded': true, 'name': 'Ravi', 'persona': 'citizen'});
    final c = await pumpApp(tester, prefs: {'profile_v1': onboarded});
    await settle(tester);
    c.read(routerProvider).push(Routes.quiz, extra: const QuizRequest(QuizMode.dailyDocket));
    await settle(tester);
    expect(find.text('Answer within 30 seconds. No answer in time counts as wrong.'), findsOneWidget);
    await tester.tap(find.byTooltip('Close'));
    await settle(tester);
    expect(find.text("You haven't answered yet, so nothing is lost. You can start again later."), findsOneWidget);
    await tester.tap(find.text('Leave'));
    await settle(tester);
  });

  testWidgets('time away from the app comes off a running timer', (tester) async {
    final onboarded = jsonEncode({'onboarded': true, 'name': 'Ravi', 'persona': 'citizen'});
    final c = await pumpApp(tester, prefs: {'profile_v1': onboarded});
    await settle(tester);
    const duel = QuizRequest(QuizMode.duel);
    c.read(routerProvider).push(Routes.quiz, extra: duel);
    await settle(tester);
    expect(find.textContaining('A right answer scores up to 1,000 points'), findsOneWidget);
    final ctl = c.read(quizControllerProvider(duel).notifier);
    final before = c.read(quizControllerProvider(duel)).secondsLeft!;
    ctl.catchUp(const Duration(seconds: 3));
    expect(c.read(quizControllerProvider(duel)).secondsLeft, before - 3);
    ctl.catchUp(const Duration(minutes: 5));
    await settle(tester);
    expect(c.read(quizControllerProvider(duel)).answers.single.isSkipped, isTrue);
    expect(find.text("Time's up"), findsOneWidget);
    c.read(routerProvider).go(Routes.home);
    await settle(tester);
  });

  testWidgets('the exam counts answered questions, not skipped ones', (tester) async {
    final onboarded = jsonEncode({'onboarded': true, 'name': 'Ravi', 'persona': 'citizen'});
    final c = await pumpApp(tester, prefs: {'profile_v1': onboarded});
    await settle(tester);
    const exam = QuizRequest(QuizMode.exam);
    c.read(routerProvider).push(Routes.quiz, extra: exam);
    await settle(tester);
    final total = c.read(quizControllerProvider(exam)).questions.length;
    expect(find.text('0 of $total answered'), findsOneWidget);
    expect(find.text("Pick an answer, then move on. You can't go back to a question."), findsOneWidget);

    await tester.tap(find.text('SKIP'));
    await settle(tester);
    expect(find.text('0 of $total answered'), findsOneWidget, reason: 'a skip is not an answer');
    final q = c.read(quizControllerProvider(exam)).current;
    await tester.tap(find.text(api.correctTextFor(q.id)).first);
    await settle(tester);
    expect(find.text('1 of $total answered'), findsOneWidget);
    c.read(routerProvider).go(Routes.home);
    await settle(tester);
  });

  testWidgets('a failed report says so in the sheet and keeps the text', (tester) async {
    final onboarded = jsonEncode({'onboarded': true, 'name': 'Ravi', 'persona': 'citizen'});
    final c = await pumpApp(tester, prefs: {'profile_v1': onboarded}, server: (s) => s.reportOffline = true);
    await settle(tester);
    await tester.tap(find.text('Start learning').first);
    await settle(tester);
    await tester.tap(find.text(api.wrongTextFor(_current(c).id)).first);
    await settle(tester);
    await tester.ensureVisible(find.text('Report'));
    await settle(tester);
    await tester.tap(find.text('Report'));
    await settle(tester);
    await tester.tap(find.text('Typo or wording'));
    await tester.enterText(find.byType(TextField), 'Article number looks off');
    await tester.tap(find.text('Send report'));
    await settle(tester);
    expect(find.text("Couldn't send your report. Your text is kept, so you can try again."), findsOneWidget);
    expect(find.text('Article number looks off'), findsOneWidget);
    expect(api.reports, isEmpty);

    api.reportOffline = false;
    await tester.tap(find.text('Try again'));
    await settle(tester);
    expect(api.reports.single.comment, 'Article number looks off');
    expect(find.text('Thanks. Our legal team will check this question.'), findsOneWidget);
  });

  testWidgets('answer review shows your answer and the right one', (tester) async {
    final onboarded = jsonEncode({'onboarded': true, 'name': 'Ravi', 'persona': 'citizen'});
    final c = await pumpApp(tester, prefs: {'profile_v1': onboarded});
    await settle(tester);
    await tester.tap(find.text('Start learning').first);
    await settle(tester);
    final first = _current(c);
    final wrong = api.wrongTextFor(first.id);
    for (var i = 0; i < 6; i++) {
      await tester.tap(find.text(i == 0 ? wrong : api.correctTextFor(_current(c).id)).first);
      await settle(tester);
      await tester.tap(find.text(i == 5 ? 'FINISH' : 'NEXT'));
      await settle(tester);
    }
    expect(find.text('5/6 correct'), findsOneWidget);
    await tester.tap(find.text('CONTINUE')); // past "Level up!"
    await settle(tester);
    await tester.tap(find.text('Review answers'));
    await settle(tester);
    expect(find.text('Hide answers'), findsOneWidget);
    expect(find.text('Your answer: $wrong'), findsOneWidget);
    expect(find.text('Correct answer: ${api.correctTextFor(first.id)}'), findsOneWidget);
  });

  testWidgets('an update card shows its uploaded picture, or the category painting without one', (tester) async {
    LegalUpdate update({String? imageUrl}) => LegalUpdate(
      id: 'u',
      category: UpdateCategory.supremeCourt,
      title: 'T',
      summary: 'S',
      keyPoints: const ['K'],
      whyItMatters: 'W',
      source: 'Src',
      date: DateTime(2026, 1, 1),
      readMinutes: 2,
      imageUrl: imageUrl,
    );
    Future<void> show(LegalUpdate u) => tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: SizedBox(width: 248, height: 124, child: UpdatePicture(update: u)),
      ),
    );

    await show(update());
    expect(find.byType(UpdateFallbackArt), findsOneWidget);
    expect(find.byType(CachedNetworkImage), findsNothing);

    await show(update(imageUrl: 'https://api.test/v1/news/u/image?v=1'));
    expect(find.byType(CachedNetworkImage), findsOneWidget);
  });
}


Question _current(ProviderContainer c) =>
    c.read(quizControllerProvider(const QuizRequest(QuizMode.casePath, levelId: 'constitution_1'))).current;
