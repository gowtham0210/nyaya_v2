import 'dart:convert';

import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:nyaya/app/app.dart';
import 'package:nyaya/app/router.dart';
import 'package:nyaya/core/api/api_client.dart';
import 'package:nyaya/core/api/token_store.dart';
import 'package:nyaya/core/services/sounds.dart';
import 'package:nyaya/core/storage/local_store.dart';
import 'package:nyaya/core/theme/app_theme.dart';
import 'package:nyaya/features/auth/application/auth_controller.dart';
import 'package:nyaya/features/auth/data/auth_api.dart';
import 'package:nyaya/features/constitution/data/constitution_repository.dart';
import 'package:nyaya/features/daily_tip/data/daily_tip_repository.dart';
import 'package:nyaya/features/leaderboard/data/league_api.dart';
import 'package:nyaya/features/legal_updates/data/legal_updates_repository.dart';
import 'package:nyaya/features/mock_exams/application/attempt_controller.dart';
import 'package:nyaya/features/mock_exams/data/mock_exam_api.dart';
import 'package:nyaya/features/mock_exams/application/mock_exam_providers.dart';
import 'package:nyaya/features/mock_exams/application/server_clock.dart';
import 'package:nyaya/features/mock_exams/data/mock_exam_cache.dart';
import 'package:nyaya/features/mock_exams/presentation/mock_exams_card.dart';
import 'package:nyaya/features/mock_exams/presentation/mock_result_screen.dart' show mockScore;
import 'package:nyaya/features/mock_exams/domain/mock_exam_models.dart';
import 'package:nyaya/features/progress/data/progress_api.dart';
import 'package:nyaya/features/quiz/data/quiz_api.dart';
import 'package:nyaya/features/reminders/data/reminder_notifications.dart';
import 'package:nyaya/features/review/data/review_api.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/fake_backend.dart';
import 'support/fake_mock_exam_api.dart';

/// The Mock Exams screens, in the real app against a fake server.
void main() {
  setUpAll(() => AppTheme.useGoogleFonts = false);

  late FakeMockExamApi exam;
  late SharedPreferences prefs;

  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 12; i++) {
      await tester.pump(const Duration(milliseconds: 150));
    }
  }

  Future<ProviderContainer> pumpApp(
    WidgetTester tester, {
    String theme = 'light',
    double textScale = 1,
    double viewHeight = 2532,
    ManualMonotonic? mono,
  }) async {
    tester.view.physicalSize = Size(1170, viewHeight);
    tester.view.devicePixelRatio = 3;
    tester.platformDispatcher.textScaleFactorTestValue = textScale;
    addTearDown(tester.view.reset);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    SharedPreferences.setMockInitialValues({
      'profile_v1': jsonEncode({
        'onboarded': true,
        'name': 'Ravi',
        'coins': 60,
        'persona': 'citizen',
        'themeMode': theme,
        'language': 'en',
      }),
    });
    prefs = await SharedPreferences.getInstance();
    final tokens = signedInTokens();
    final quiz = FakeQuizApi();
    final container = ProviderContainer(overrides: [
      sharedPreferencesProvider.overrideWithValue(prefs),
      tokenStoreProvider.overrideWithValue(tokens),
      quizApiProvider.overrideWithValue(quiz),
      progressApiProvider.overrideWithValue(quiz),
      leagueApiProvider.overrideWithValue(quiz),
      reviewApiProvider.overrideWithValue(quiz),
      legalUpdatesRepositoryProvider.overrideWithValue(FakeLegalUpdates()),
      dailyTipRepositoryProvider.overrideWithValue(FakeDailyTips()),
      constitutionRepositoryProvider.overrideWithValue(FakeConstitution()),
      reminderNotificationsProvider.overrideWithValue(FakeReminderNotifications()),
      soundPlayerProvider.overrideWithValue(FakeSounds()),
      authApiProvider.overrideWithValue(FakeAuthApi(tokens)),
      mockExamApiProvider.overrideWithValue(exam),
      if (mono != null) elapsedSourceFactoryProvider.overrideWithValue(mono.factory),
      autosaveTuningProvider.overrideWithValue(const AutosaveTuning(debounce: Duration(milliseconds: 10))),
    ]);
    addTearDown(container.dispose);
    await tester.pumpWidget(UncontrolledProviderScope(container: container, child: const NyayaApp()));
    await settle(tester);
    return container;
  }

  Future<void> go(WidgetTester tester, ProviderContainer c, String route) async {
    c.read(routerProvider).go(route);
    await settle(tester);
  }

  setUp(() => exam = FakeMockExamApi());

  group('finding Mock Exams', () {
    testWidgets('Home shows no entry while every exam is switched off', (tester) async {
      exam.available.clear();
      await pumpApp(tester);
      expect(find.text('Mock Exams'), findsNothing);
      expect(exam.availabilityCalls, 3, reason: 'each known exam is asked once');
      expect(exam.startCalls, 0);
    });

    testWidgets('Home shows the entry once an exam is open, and it leads to that exam only', (tester) async {
      final c = await pumpApp(tester);
      expect(find.text('Mock Exams'), findsOneWidget);
      await tester.tap(find.text('Mock Exams'));
      await settle(tester);
      expect(find.text('AIBE'), findsOneWidget);
      expect(find.text('CLAT'), findsNothing);
      expect(find.text('AILET'), findsNothing);
      expect(c.read(routerProvider).state.matchedLocation, Routes.mockExams);
    });

    testWidgets('lists exactly the exams the API shows, and never starts an attempt to check', (tester) async {
      exam.available.addAll([MockExamSlugs.clat, MockExamSlugs.ailet]);
      final c = await pumpApp(tester);
      await go(tester, c, Routes.mockExams);
      expect(find.text('AIBE'), findsOneWidget);
      expect(find.text('CLAT'), findsOneWidget);
      expect(find.text('AILET'), findsOneWidget);
      expect(exam.startCalls, 0);
    });

    testWidgets('says nothing is open when no exam is available', (tester) async {
      exam.available.clear();
      final c = await pumpApp(tester);
      await go(tester, c, Routes.mockExams);
      expect(find.text('No mock exams are open yet.'), findsOneWidget);
    });

    testWidgets('offers a retry when the exams cannot be reached', (tester) async {
      exam.offline = true;
      final c = await pumpApp(tester);
      await go(tester, c, Routes.mockExams);
      expect(find.textContaining('Couldn’t load Mock Exams'), findsOneWidget);
      exam.offline = false;
      await tester.tap(find.text('Try again'));
      await settle(tester);
      expect(find.text('AIBE'), findsOneWidget);
    });
  });

  group('the Home entry', () {
    /// Each animated section's total animation time, in order. A section's
    /// fade-in delay is 40 ms times its position, so the totals show the delays.
    List<Duration> fadeDelays(WidgetTester tester) {
      final totals = [for (final a in tester.widgetList<Animate>(find.byType(Animate))) a.duration];
      return [for (final t in totals) t - totals.first];
    }

    testWidgets('takes no space when no exam is open, and Home animates exactly as before', (tester) async {
      exam.available.clear();
      // A tall screen, so every section is built and its animation can be seen.
      await pumpApp(tester, viewHeight: 12000);
      expect(tester.getSize(find.byType(MockExamsCard, skipOffstage: false)).height, 0);
      // Continue learning, Review, the tip slot and the Quiz modes grid fade in,
      // each after its own position's delay: 0, 40, 80 and 160 ms.
      expect(fadeDelays(tester), [Duration.zero, const Duration(milliseconds: 40), const Duration(milliseconds: 80), const Duration(milliseconds: 160)]);
    });

    testWidgets('showing the card changes no section’s animation or delay', (tester) async {
      exam.available.clear();
      final c = await pumpApp(tester, viewHeight: 12000);
      final hidden = fadeDelays(tester);
      exam.available.add(MockExamSlugs.aibe);
      c.invalidate(availableMockExamsProvider);
      await settle(tester);
      expect(tester.getSize(find.byType(MockExamsCard)).height, greaterThan(0));
      expect(fadeDelays(tester), hidden);
    });

    testWidgets('is the first thing on Home, above Continue learning', (tester) async {
      final c = await pumpApp(tester);
      expect(c.read(availableMockExamsProvider).asData?.value, [MockExamSlugs.aibe]);
      final card = tester.getTopLeft(find.text('Mock Exams')).dy;
      final next = tester.getTopLeft(find.text('Start learning').first).dy;
      expect(card, lessThan(next));
      // And it is on the first screen, without scrolling.
      expect(find.text('Mock Exams'), findsOneWidget);
    });

    testWidgets('does not shift Home when it is hidden: the first section starts where it did', (tester) async {
      exam.available.clear();
      await pumpApp(tester);
      final withoutCard = tester.getTopLeft(find.text('Start learning').first).dy;
      exam.available.add(MockExamSlugs.aibe);
      final c = ProviderScope.containerOf(tester.element(find.byType(NyayaApp)));
      c.invalidate(availableMockExamsProvider);
      await settle(tester);
      final withCard = tester.getTopLeft(find.text('Start learning').first).dy;
      expect(withCard, greaterThan(withoutCard), reason: 'a visible card pushes the rest down, nothing else changes');
    });
  });

  group('an exam’s papers and the start choice', () {
    testWidgets('shows no Unverified pill and no random mock option', (tester) async {
      exam.paperList = [samplePaper()];
      final c = await pumpApp(tester);
      await go(tester, c, Routes.mockExam('aibe'));
      expect(find.text('Fixture paper'), findsOneWidget);
      expect(find.text('Unverified'), findsNothing);
      expect(find.text('Random mock'), findsNothing);
      expect(exam.startCalls, 0, reason: 'looking at the list does not start anything');
    });

    testWidgets('an unverified paper with no clock shows only Start Practice and no notes', (tester) async {
      exam.paperList = [samplePaper(durationSeconds: 3600)];
      final c = await pumpApp(tester);
      await go(tester, c, Routes.mockExam('aibe'));
      await tester.tap(find.text('Fixture paper'));
      await settle(tester);
      expect(find.text('Unverified'), findsNothing);
      expect(find.text('The marking rules for this paper aren’t officially confirmed yet.'), findsNothing);
      expect(find.text('Start Practice'), findsOneWidget);
      expect(find.textContaining('Timed Practice'), findsNothing);
    });

    testWidgets('a confirmed paper with a duration allows timed mode', (tester) async {
      exam.paperList = [samplePaper(durationSeconds: 3600, configStatus: 'official_confirmed')];
      final c = await pumpApp(tester);
      await go(tester, c, Routes.mockExam('aibe'));
      expect(find.text('Unverified'), findsNothing);
      await tester.tap(find.text('Fixture paper'));
      await settle(tester);
      expect(tester.widget<FilledButton>(find.widgetWithText(FilledButton, 'Start Timed Practice (60 minutes)')).onPressed, isNotNull);
    });

    testWidgets('the details screen is one clean page: details, the practice note and two same-style buttons', (tester) async {
      exam.paperList = [samplePaper(durationSeconds: 3600, configStatus: 'official_confirmed')];
      final c = await pumpApp(tester);
      await go(tester, c, Routes.mockExam('aibe'));
      await tester.tap(find.text('Fixture paper'));
      await settle(tester);
      expect(find.text('Exam details'), findsOneWidget);
      expect(find.text('Fixture paper'), findsOneWidget);
      expect(find.textContaining('4 questions'), findsOneWidget);
      expect(find.text('No time limit. Your answers are saved as you go.'), findsOneWidget);
      expect(find.text('Before you start'), findsOneWidget);
      expect(find.textContaining('reminder on this device only'), findsOneWidget);
      final practice = tester.widget<FilledButton>(find.widgetWithText(FilledButton, 'Start Practice'));
      final timed = tester.widget<FilledButton>(find.widgetWithText(FilledButton, 'Start Timed Practice (60 minutes)'));
      expect(practice.style?.minimumSize?.resolve({}), timed.style?.minimumSize?.resolve({}));
      expect(find.byType(OutlinedButton), findsNothing);
      expect(exam.startCalls, 0, reason: 'reading the details starts nothing');
    });

    testWidgets('an unverified paper with a practice timer offers it, labelled, and keeps official timed mode off', (tester) async {
      exam.paperList = [samplePaper(durationSeconds: null, practiceTimerSeconds: 10800)];
      final c = await pumpApp(tester);
      await go(tester, c, Routes.mockExam('aibe'));
      await tester.tap(find.text('Fixture paper'));
      await settle(tester);
      expect(find.text('Start Practice'), findsOneWidget);
      expect(find.text('Start Timed Practice (180 minutes)'), findsOneWidget);
      expect(find.text('Practice timing — not officially confirmed by BCI'), findsNothing);
      expect(exam.startCalls, 0);
    });

    testWidgets('starting timed practice opens an attempt with a countdown and the practice label', (tester) async {
      exam.hasAttempt = false;
      exam.paperList = [samplePaper(practiceTimerSeconds: 10800)];
      final c = await pumpApp(tester);
      await go(tester, c, Routes.mockExam('aibe'));
      await tester.tap(find.text('Fixture paper'));
      await settle(tester);
      // The start choice scrolls inside its pinned area on a short screen.
      await tester.ensureVisible(find.text('Start Timed Practice (180 minutes)'));
      await settle(tester);
      await tester.tap(find.text('Start Timed Practice (180 minutes)'));
      await settle(tester);
      expect(exam.startCalls, 1);
      expect(exam.mode, AttemptMode.practice, reason: 'it is still a practice attempt, never the official timed mode');
      expect(exam.deadline, isNotNull);
      expect(find.text('Question 1 of 4'), findsOneWidget);
      expect(find.textContaining('left'), findsWidgets, reason: 'a countdown is shown');
      expect(find.text('Practice timing — not officially confirmed by BCI'), findsOneWidget);
    });

    testWidgets('a paper without a practice timer does not offer one', (tester) async {
      exam.paperList = [samplePaper()];
      final c = await pumpApp(tester);
      await go(tester, c, Routes.mockExam('aibe'));
      await tester.tap(find.text('Fixture paper'));
      await settle(tester);
      expect(find.textContaining('Timed Practice'), findsNothing);
    });

    testWidgets('starting practice opens the attempt', (tester) async {
      exam.hasAttempt = false;
      exam.paperList = [samplePaper()];
      final c = await pumpApp(tester);
      await go(tester, c, Routes.mockExam('aibe'));
      await tester.tap(find.text('Fixture paper'));
      await settle(tester);
      await tester.tap(find.text('Start Practice'));
      await settle(tester);
      expect(exam.startCalls, 1);
      expect(find.text('Question 1 of 4'), findsOneWidget);
    });

    testWidgets('explains an unfinished attempt instead of starting another', (tester) async {
      exam.begin();
      exam.paperList = [samplePaper()];
      final c = await pumpApp(tester);
      await go(tester, c, Routes.mockExam('aibe'));
      // The unfinished attempt is offered first.
      expect(find.text('Continue your attempt'), findsOneWidget);
      await tester.tap(find.text('Fixture paper').last); // the first is the resume card
      await settle(tester);
      await tester.tap(find.text('Start Practice'));
      await settle(tester);
      expect(find.text('You already have an unfinished attempt. Resume it first.'), findsOneWidget);
    });
  });

  group('taking an attempt', () {
    testWidgets('shows questions with no key, saves a chosen answer, and shows a withdrawn placeholder', (tester) async {
      exam.begin();
      final c = await pumpApp(tester);
      await go(tester, c, Routes.mockAttempt('aibe', 'attempt-1'));
      expect(find.text('Question 1 of 4'), findsOneWidget);
      expect(find.text('Question text 1'), findsOneWidget);
      expect(find.text('Practice · no time limit'), findsOneWidget);
      expect(find.textContaining(FakeMockExamApi.secret), findsNothing);

      await tester.tap(find.text('Option b of 1'));
      await settle(tester);
      expect(exam.answers[1]!.selected, ['b']);
      expect(find.text('Saved'), findsOneWidget);
      expect(find.text('1 of 3 answered'), findsOneWidget);

      // Go to the withdrawn question through the palette.
      await tester.tap(find.byTooltip('Questions'));
      await settle(tester);
      await tester.tap(find.bySemanticsLabel(RegExp('Question 4, Withdrawn')));
      await settle(tester);
      expect(find.text('This question was withdrawn'), findsOneWidget);
      expect(find.byType(RadioListTile<String>), findsNothing);
      expect(find.textContaining('Option a of 4'), findsNothing);
    });

    testWidgets('resuming reopens the question the learner left on', (tester) async {
      exam.begin();
      final c = await pumpApp(tester);
      await go(tester, c, Routes.mockAttempt('aibe', 'attempt-1'));
      expect(find.text('Question 1 of 4'), findsOneWidget);
      await tester.tap(find.byTooltip('Questions'));
      await settle(tester);
      await tester.tap(find.bySemanticsLabel(RegExp('Question 3')));
      await settle(tester);
      expect(find.text('Question 3 of 4'), findsOneWidget);

      await go(tester, c, Routes.mockExam('aibe'));
      await go(tester, c, Routes.mockAttempt('aibe', 'attempt-1'));
      expect(find.text('Question 3 of 4'), findsOneWidget);
    });

    testWidgets('says "server issue" for a server error, and "offline" only for a lost connection', (tester) async {
      exam.begin();
      final c = await pumpApp(tester);
      await go(tester, c, Routes.mockAttempt('aibe', 'attempt-1'));

      exam.failNextSave = const ApiException(503, 'unavailable', 'x');
      await tester.tap(find.text('Option b of 1'));
      await settle(tester);
      expect(find.text('Server issue. Your answers are saved and will retry automatically.'), findsOneWidget);
      expect(find.textContaining('Offline.'), findsNothing);
      expect(exam.answers, isEmpty, reason: 'not delivered yet, and still queued');

      // The usual retry (2 s) delivers it.
      for (var i = 0; i < 20; i++) {
        await tester.pump(const Duration(milliseconds: 150));
      }
      expect(exam.answers[1]!.selected, ['b']);
      expect(find.text('Saved'), findsOneWidget);

      exam.offline = true;
      await tester.tap(find.text('Option c of 1'));
      await settle(tester);
      expect(find.text('Offline. Answers will be saved when you’re back online.'), findsOneWidget);
      expect(find.textContaining('Server issue'), findsNothing);
      // Back online: the retry delivers it, and nothing is left waiting.
      exam.offline = false;
      for (var i = 0; i < 20; i++) {
        await tester.pump(const Duration(milliseconds: 150));
      }
      expect(exam.answers[1]!.selected, ['c']);
      expect(find.text('Saved'), findsOneWidget);
    });

    // The deadline passes while the server cannot be asked: a lost connection,
    // or a server that answers with a temporary error. Either way the learner
    // is told the same, accurate thing, and the server stays the one to end it.
    for (final (name, fail) in <(String, void Function())>[
      ('no connection', () => exam.offline = true),
      ('a 503', () => exam.attemptFailure = const ApiException(503, 'unavailable', 'x')),
      ('a 429', () => exam.attemptFailure = const ApiException(429, 'rate_limited', 'x')),
    ]) {
      testWidgets('when time runs out with $name it says the result will come once the server is reachable', (tester) async {
        exam.begin(mode: AttemptMode.timed, limit: const Duration(seconds: 2));
        final mono = ManualMonotonic();
        final c = await pumpApp(tester, mono: mono);
        await go(tester, c, Routes.mockAttempt('aibe', 'attempt-1'));
        expect(find.text('Question 1 of 4'), findsOneWidget);

        fail();
        // The two seconds run out (the countdown ticks each second).
        for (var i = 0; i < 20; i++) {
          mono.t += const Duration(milliseconds: 150);
          await tester.pump(const Duration(milliseconds: 150));
        }
        const message = 'Time is up. We’ll show your result as soon as we can reach the server.';
        expect(find.text(message), findsOneWidget);
        expect(find.textContaining('Reconnect'), findsNothing, reason: 'the old wording is gone');
        // Only the server can end the attempt: it is still open on screen.
        expect(find.text('Question 1 of 4'), findsOneWidget);

        // The server comes back, and ends it: the result opens and nothing is left waiting.
        exam.offline = false;
        exam.attemptFailure = null;
        exam.now = exam.now.add(const Duration(minutes: 1));
        for (var i = 0; i < 50; i++) {
          mono.t += const Duration(milliseconds: 150);
          await tester.pump(const Duration(milliseconds: 150));
        }
        expect(find.text('Result'), findsOneWidget);
        expect(find.text(message), findsNothing);
        expect(exam.status, 'expired');
      });
    }

    testWidgets('a timed attempt shows the time left from the server deadline', (tester) async {
      exam.begin(mode: AttemptMode.timed, limit: const Duration(minutes: 90));
      final c = await pumpApp(tester);
      await go(tester, c, Routes.mockAttempt('aibe', 'attempt-1'));
      expect(find.textContaining('1:29:5'), findsOneWidget);
      expect(find.text('Practice · no time limit'), findsNothing);
    });

    testWidgets('mark for review is a local reminder: shown in the palette and the submit prompt, never sent to the server', (tester) async {
      exam.begin();
      final c = await pumpApp(tester);
      await go(tester, c, Routes.mockAttempt('aibe', 'attempt-1'));
      expect(find.text('Mark for review'), findsOneWidget);
      await tester.tap(find.text('Mark for review'));
      await settle(tester);
      expect(find.text('Marked for review'), findsOneWidget);
      // Kept on the device, per learner.
      final stored = prefs.getString('mock_exam_marks_v1')!;
      expect(stored, contains('attempt-1'));
      // Nothing about it reached the server.
      expect(exam.saveBatches, isEmpty);
      expect(exam.answers, isEmpty);

      await tester.tap(find.byTooltip('Questions'));
      await settle(tester);
      expect(find.text('Marked'), findsWidgets);
      expect(find.bySemanticsLabel(RegExp('Question 1, Not answered, Marked')), findsOneWidget);
      await tester.tap(find.text('2'));
      await settle(tester);

      await tester.tap(find.text('Submit'));
      await settle(tester);
      expect(find.textContaining('1 marked for review.'), findsOneWidget);
      await tester.tap(find.text('Keep going'));
      await settle(tester);

      // Unmarking removes it.
      await tester.tap(find.byTooltip('Questions'));
      await settle(tester);
      await tester.tap(find.text('1'));
      await settle(tester);
      await tester.tap(find.text('Marked for review'));
      await settle(tester);
      expect(find.text('Mark for review'), findsOneWidget);
      expect(prefs.getString('mock_exam_marks_v1') ?? '', isNot(contains('attempt-1')));
    });

    testWidgets('marks are cleared when the attempt is submitted and with the rest of the mock data on sign-out', (tester) async {
      exam.begin();
      final c = await pumpApp(tester);
      await go(tester, c, Routes.mockAttempt('aibe', 'attempt-1'));
      await tester.tap(find.text('Mark for review'));
      await settle(tester);
      expect(prefs.getString('mock_exam_marks_v1'), isNotNull);
      await tester.tap(find.text('Submit'));
      await settle(tester);
      await tester.tap(find.widgetWithText(FilledButton, 'Submit').last);
      await settle(tester);
      expect(prefs.getString('mock_exam_marks_v1') ?? '', isNot(contains('attempt-1')));

      await c.read(mockExamCacheProvider).clearAll();
      expect(prefs.getString('mock_exam_marks_v1'), isNull);
    });

    testWidgets('submitting asks first, then shows the score ring, a pass verdict and the counts', (tester) async {
      exam.begin();
      final c = await pumpApp(tester);
      await go(tester, c, Routes.mockAttempt('aibe', 'attempt-1'));
      await tester.tap(find.text('Option b of 1'));
      await settle(tester);
      await tester.tap(find.text('Submit'));
      await settle(tester);
      expect(find.text('Submit this mock exam?'), findsOneWidget);
      expect(find.textContaining('You have answered 1 of 3.'), findsOneWidget);
      expect(find.textContaining('2 not answered.'), findsOneWidget);
      // Backing out keeps the attempt open.
      await tester.tap(find.text('Keep going'));
      await settle(tester);
      expect(exam.submitCalls, 0);

      await tester.tap(find.text('Submit'));
      await settle(tester);
      await tester.tap(find.widgetWithText(FilledButton, 'Submit').last);
      await settle(tester);
      expect(exam.submitCalls, 1);
      expect(find.text('Result'), findsOneWidget);
      expect(find.text('Provisional result'), findsOneWidget);
      expect(find.textContaining('provisional because some scoring rules'), findsOneWidget);
      expect(find.textContaining('Pass criteria aren’t available'), findsNothing);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.text('FAIL'), findsOneWidget, reason: '1 of 3 is below 45%');
      expect(find.text('Correct'), findsOneWidget);
      expect(find.text('Incorrect'), findsOneWidget);
      expect(find.text('Unanswered'), findsOneWidget);
      expect(find.text('Withdrawn'), findsOneWidget);
    });

    testWidgets('judges pass at 45% or more, whatever the server says about pass criteria', (tester) async {
      exam.begin();
      exam.provisional = false;
      exam.status = 'submitted';
      final c = await pumpApp(tester);
      await go(tester, c, Routes.mockResult('attempt-1'));
      expect(find.text('Provisional result'), findsNothing);
      expect(find.textContaining('Pass criteria aren’t available'), findsNothing);
      expect(find.textContaining('needed'), findsNothing);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.textContaining(RegExp(r'^(PASS|FAIL)$')), findsOneWidget);
    });

    test('the score and the 45% rule', () {
      AttemptResult result({required int correct, required int total, bool marks = false, double? obtained, double? max}) => AttemptResult.fromJson({
            'attempt_id': 'a',
            'status': 'submitted',
            'submitted_at': '2026-01-01T00:00:00Z',
            'result': {
              'marks_available': marks,
              'provisional': false,
              'provisional_reasons': <String>[],
              'overall': {
                'total_positions': total,
                'scorable_positions': total,
                'correct': correct,
                'incorrect': 0,
                'unanswered': total - correct,
                'withdrawn': 0,
                'marks_obtained': obtained,
                'max_marks': max,
                'percentage': null,
              },
              'sections': <Object>[],
              'pass': {'available': false, 'reason': null, 'general': null, 'reserved': null},
              'positions': <Object>[],
            },
          });
      final unconfigured = mockScore(result(correct: 44, total: 100));
      expect((unconfigured.score, unconfigured.max, unconfigured.pass), (44.0, 100.0, false));
      expect(mockScore(result(correct: 45, total: 100)).pass, isTrue, reason: '45% exactly passes');
      expect(mockScore(result(correct: 0, total: 100)).pass, isFalse);
      final configured = mockScore(result(correct: 50, total: 100, marks: true, obtained: 40, max: 100));
      expect((configured.score, configured.pass), (40.0, false), reason: 'configured marks win when present');
      expect(mockScore(result(correct: 10, total: 0, marks: true, obtained: -3, max: 50)).score, 0.0, reason: 'never below zero');
    });

    testWidgets('an expired attempt says time ran out', (tester) async {
      exam.begin(mode: AttemptMode.timed, limit: const Duration(minutes: 5));
      exam.now = exam.now.add(const Duration(minutes: 6));
      final c = await pumpApp(tester);
      await go(tester, c, Routes.mockAttempt('aibe', 'attempt-1'));
      expect(find.text('This attempt ended when the time ran out.'), findsOneWidget);
    });

    testWidgets('the review, opened after submitting, shows the accepted answer and explanation', (tester) async {
      exam.begin();
      exam.status = 'submitted';
      final c = await pumpApp(tester);
      await go(tester, c, Routes.mockReview('attempt-1'));
      expect(find.text(FakeMockExamApi.secret), findsWidgets);
      expect(find.textContaining('Accepted answer'), findsWidgets);
      expect(find.text('Withdrawn, not scored', skipOffstage: false), findsOneWidget);
    });

    testWidgets('the review is refused while the attempt is open', (tester) async {
      exam.begin();
      final c = await pumpApp(tester);
      await go(tester, c, Routes.mockReview('attempt-1'));
      expect(find.text(FakeMockExamApi.secret), findsNothing);
      expect(find.textContaining('Couldn’t load Mock Exams'), findsOneWidget);
    });

    testWidgets('locked-order exams show only the open section as available', (tester) async {
      exam.begin(locked: true, sections: 2);
      final c = await pumpApp(tester);
      await go(tester, c, Routes.mockAttempt('aibe', 'attempt-1'));
      expect(find.text('Section s1'), findsOneWidget);
      expect(find.text('Finish this section'), findsNothing); // not on the last question yet
      await tester.tap(find.text('Next'));
      await settle(tester);
      expect(find.text('Finish this section'), findsOneWidget);
      await tester.tap(find.text('Finish this section'));
      await settle(tester);
      await tester.tap(find.widgetWithText(FilledButton, 'Finish this section'));
      await settle(tester);
      expect(exam.currentSection, 2);
      expect(find.text('Question 3 of 4'), findsOneWidget);
    });
  });

  group('the offline copy', () {
    testWidgets('is wiped when the learner signs out', (tester) async {
      exam.begin();
      final c = await pumpApp(tester);
      final cache = MockExamCache(LocalStore(prefs));
      await cache.write(
        'user-1',
        'aibe',
        CachedAttempt(
          attempt: await exam.attempt('attempt-1'),
          pending: const [],
          serverNow: exam.now,
          deviceAt: exam.now,
        ),
      );
      expect(cache.read('user-1', 'aibe'), isNotNull);
      await c.read(authProvider.notifier).signOut();
      await settle(tester);
      expect(prefs.getString(MockExamCache.key), isNull);
    });
  });

  group('history', () {
    testWidgets('lists attempts with scores and statistics', (tester) async {
      exam.begin();
      exam.status = 'submitted';
      final c = await pumpApp(tester);
      await go(tester, c, Routes.mockHistory);
      expect(find.textContaining('AIBE · Fixture paper'), findsOneWidget);
      expect(find.textContaining('2.75 / 3'), findsOneWidget);
      expect(find.text('Your statistics'), findsOneWidget);
      expect(find.textContaining('2 finished · best 91.67% · average 70%'), findsOneWidget);
    });
  });

  group('accessibility', () {
    for (final theme in ['light', 'dark']) {
      for (final (name, route, setup) in <(String, String, void Function())>[
        ('exams list', Routes.mockExams, () {}),
        ('exam home', Routes.mockExam('aibe'), () => exam.paperList = [samplePaper()]),
        ('attempt', Routes.mockAttempt('aibe', 'attempt-1'), () => exam.begin(mode: AttemptMode.timed)),
        ('result', Routes.mockResult('attempt-1'), () {
          exam.begin();
          exam.status = 'submitted';
        }),
        ('review', Routes.mockReview('attempt-1'), () {
          exam.begin();
          exam.status = 'submitted';
        }),
        ('history', Routes.mockHistory, () => exam.begin()),
      ]) {
        testWidgets('$name ($theme) meets accessibility guidelines and fits at the largest text size', (tester) async {
          setup();
          final handle = tester.ensureSemantics();
          final c = await pumpApp(tester, theme: theme);
          await go(tester, c, route);
          await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
          await expectLater(tester, meetsGuideline(iOSTapTargetGuideline));
          await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
          await expectLater(tester, meetsGuideline(textContrastGuideline));
          handle.dispose();
        });
      }
    }

    testWidgets('the attempt lays out without overflow at the largest text size', (tester) async {
      exam.begin(mode: AttemptMode.timed);
      final c = await pumpApp(tester, textScale: 2);
      await go(tester, c, Routes.mockAttempt('aibe', 'attempt-1'));
      expect(tester.takeException(), isNull);
      expect(find.text('Question 1 of 4'), findsOneWidget);
    });
  });
}
