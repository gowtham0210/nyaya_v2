import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:nyaya/app/app.dart';
import 'package:nyaya/app/router.dart';
import 'package:nyaya/core/api/token_store.dart';
import 'package:nyaya/core/config/features.dart';
import 'package:nyaya/core/services/sounds.dart';
import 'package:nyaya/core/storage/local_store.dart';
import 'package:nyaya/core/theme/app_theme.dart';
import 'package:nyaya/core/widgets/pressable.dart';
import 'package:nyaya/features/auth/data/auth_api.dart';
import 'package:nyaya/features/leaderboard/data/league_api.dart';
import 'package:nyaya/features/legal_updates/data/legal_updates_repository.dart';
import 'package:nyaya/features/onboarding/presentation/intro_slides.dart';
import 'package:nyaya/features/profile/domain/user_profile.dart';
import 'package:nyaya/features/reminders/data/reminder_notifications.dart';
import 'package:nyaya/features/progress/application/progress_sync.dart';
import 'package:nyaya/features/progress/data/progress_api.dart';
import 'package:nyaya/features/quiz/application/quiz_controller.dart';
import 'package:nyaya/features/quiz/data/quiz_api.dart';
import 'package:nyaya/features/quiz/domain/quiz_models.dart';
import 'package:nyaya/features/review/data/review_api.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/fake_backend.dart';

/// Every main screen, in light and dark, passes Flutter's accessibility
/// checks (tap target size, labelled buttons, text contrast) and still lays
/// out without overflow at the largest text size.
void main() {
  setUpAll(() => AppTheme.useGoogleFonts = false);

  late FakeQuizApi api;

  Future<ProviderContainer> pumpApp(
    WidgetTester tester, {
    required String theme,
    double textScale = 1,
    bool onboarded = true,
    AppLanguage language = AppLanguage.en,
  }) async {
    tester.view.physicalSize = const Size(1170, 2532);
    tester.view.devicePixelRatio = 3;
    tester.platformDispatcher.textScaleFactorTestValue = textScale;
    addTearDown(tester.view.reset);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    final profile = jsonEncode({
      'onboarded': onboarded,
      'name': 'Ravi',
      'coins': 60,
      'persona': 'citizen',
      'themeMode': theme,
      'language': language.code,
    });
    SharedPreferences.setMockInitialValues({'profile_v1': profile});
    final sp = await SharedPreferences.getInstance();
    final tokens = signedInTokens();
    api = FakeQuizApi();
    final container = ProviderContainer(overrides: [
      sharedPreferencesProvider.overrideWithValue(sp),
      tokenStoreProvider.overrideWithValue(tokens),
      quizApiProvider.overrideWithValue(api),
      progressApiProvider.overrideWithValue(api),
      leagueApiProvider.overrideWithValue(api),
      reviewApiProvider.overrideWithValue(api),
      legalUpdatesRepositoryProvider.overrideWithValue(FakeLegalUpdates()),
      reminderNotificationsProvider.overrideWithValue(FakeReminderNotifications()),
      soundPlayerProvider.overrideWithValue(FakeSounds()),
      authApiProvider.overrideWithValue(FakeAuthApi(tokens)),
    ]);
    addTearDown(container.dispose);
    await tester.pumpWidget(UncontrolledProviderScope(container: container, child: const NyayaApp()));
    await settle(tester);
    return container;
  }

  /// Plays the first Case Path level through to its result screen.
  Future<void> finishLevel(WidgetTester tester) async {
    final start = find.text('Start learning').first;
    await tester.ensureVisible(start);
    await tester.pump();
    await tester.tap(start);
    await settle(tester);
    final c = ProviderScope.containerOf(tester.element(find.byType(NyayaApp)));
    for (var i = 0; i < 6; i++) {
      final question = c.read(quizControllerProvider(const QuizRequest(QuizMode.casePath, levelId: 'constitution_1'))).current;
      // Large text pushes answers below the fold.
      final answer = find.text(api.correctTextFor(question.id)).first;
      await tester.ensureVisible(answer);
      await tester.pump();
      await tester.tap(answer);
      await settle(tester);
      await tester.tap(find.text(i == 5 ? 'FINISH' : 'NEXT'));
      await settle(tester);
    }
  }

  const screens = [
    Routes.home,
    Routes.journey,
    Routes.chat,
    Routes.updates,
    Routes.leaderboard,
    Routes.review,
    Routes.settings,
  ];

  for (final theme in ['light', 'dark']) {
    for (final route in screens) {
      testWidgets('$route ($theme) meets accessibility guidelines', (tester) async {
        final handle = tester.ensureSemantics();
        final c = await pumpApp(tester, theme: theme);
        c.read(routerProvider).go(route);
        await settle(tester);
        await expectGuidelines(tester);
        handle.dispose();
      });
    }

    testWidgets('quiz ($theme) meets accessibility guidelines', (tester) async {
      final handle = tester.ensureSemantics();
      await pumpApp(tester, theme: theme);
      await tester.tap(find.text('Start learning').first);
      await settle(tester);
      await expectGuidelines(tester);
      handle.dispose();
    });

    testWidgets('quiz after a wrong answer ($theme) meets accessibility guidelines', (tester) async {
      final handle = tester.ensureSemantics();
      final c = await pumpApp(tester, theme: theme);
      await tester.tap(find.text('Start learning').first);
      await settle(tester);
      final question = c.read(quizControllerProvider(const QuizRequest(QuizMode.casePath, levelId: 'constitution_1'))).current;
      await tester.tap(find.text(api.wrongTextFor(question.id)).first);
      await settle(tester);
      await expectGuidelines(tester);
      handle.dispose();
    });

    testWidgets('sign-in ($theme) meets accessibility guidelines', (tester) async {
      final handle = tester.ensureSemantics();
      final c = await pumpApp(tester, theme: theme);
      c.read(routerProvider).go(Routes.signIn);
      await settle(tester);
      await expectGuidelines(tester);
      handle.dispose();
    });

    testWidgets('every onboarding step ($theme) meets accessibility guidelines', (tester) async {
      final handle = tester.ensureSemantics();
      await pumpApp(tester, theme: theme, onboarded: false);
      await expectGuidelines(tester);
      await tester.tap(find.text('English').first);
      await settle(tester);
      for (var i = 0; i < 2; i++) {
        await expectGuidelines(tester);
        await tester.tap(find.byTooltip('Continue'));
        await settle(tester);
      }
      await expectGuidelines(tester);
      await tester.tap(find.text('Get Started'));
      await settle(tester);
      await expectGuidelines(tester);
      await tester.tap(find.text('Citizen'));
      await settle(tester);
      await expectGuidelines(tester);
      handle.dispose();
    });

    testWidgets('reset password ($theme) meets accessibility guidelines', (tester) async {
      final handle = tester.ensureSemantics();
      final c = await pumpApp(tester, theme: theme);
      c.read(routerProvider).push(Routes.resetPassword);
      await settle(tester);
      await expectGuidelines(tester);
      handle.dispose();
    });

    testWidgets('quiz result ($theme) meets accessibility guidelines', (tester) async {
      final handle = tester.ensureSemantics();
      await pumpApp(tester, theme: theme);
      await finishLevel(tester);
      expect(find.text('Perfect case!'), findsOneWidget);
      await expectGuidelines(tester);
      handle.dispose();
    });

    // Premium is hidden in the beta; run with --dart-define=NYAYA_PREMIUM=true.
    testWidgets('paywall ($theme) meets accessibility guidelines', (tester) async {
      final handle = tester.ensureSemantics();
      final c = await pumpApp(tester, theme: theme);
      c.read(routerProvider).push(Routes.premium);
      await settle(tester);
      await expectGuidelines(tester);
      handle.dispose();
    }, skip: !Features.premium);
  }

  // Long words in Tamil and Malayalam, tall scripts in Hindi: every language
  // at the largest text size.
  for (final language in AppLanguage.values) {
    testWidgets('onboarding in ${language.englishName} lays out at the largest text size', (tester) async {
      await pumpApp(tester, theme: 'light', textScale: 3, onboarded: false, language: language);
      final choice = find.text(language.nativeName).first;
      await tester.ensureVisible(choice);
      await tester.pump();
      await tester.tap(choice);
      await settle(tester);
      for (var i = 0; i < 2; i++) {
        await tester.tap(find.byType(IconButton).last); // the round next button
        await settle(tester);
      }
      await tester.tap(find.byType(FilledButton).last); // Get Started
      await settle(tester);
      expect(find.byType(IntroSlides), findsNothing, reason: 'reached the role step');
      expect(tester.takeException(), isNull);
    });

    for (final route in [Routes.home, Routes.resetPassword, if (Features.premium) Routes.premium]) {
      testWidgets('$route in ${language.englishName} lays out at the largest text size', (tester) async {
        final c = await pumpApp(tester, theme: 'light', textScale: 3, language: language);
        if (route != Routes.home) {
          expect(tester.takeException(), isNull, reason: 'Home under it');
          c.read(routerProvider).push(route);
          await settle(tester);
        }
        expect(tester.takeException(), isNull);
      });
    }
  }

  // A 320-point phone, the smallest in use, and a phone turned sideways.
  for (final (name, size) in [('a 320-point phone', const Size(960, 1704)), ('landscape', const Size(2532, 1170))]) {
    for (final language in AppLanguage.values) {
      for (final textScale in [1.0, 3.0]) {
        testWidgets('Home in ${language.englishName} on $name lays out at text size $textScale', (tester) async {
          await pumpApp(tester, theme: 'light', textScale: textScale, language: language);
          tester.view.physicalSize = size;
          await settle(tester);
          // Every section, top to bottom, a screen at a time.
          for (var i = 0; i < 25; i++) {
            await tester.drag(find.byType(Scrollable).first, const Offset(0, -500));
            await tester.pump();
            expect(tester.takeException(), isNull, reason: 'at step $i');
          }
          await settle(tester);
        });
      }
    }
  }

  // The Case Path map and its sheets on the same phones.
  for (final (name, size) in [('a 320-point phone', const Size(960, 1704)), ('landscape', const Size(2532, 1170))]) {
    for (final language in AppLanguage.values) {
      for (final textScale in [1.0, 3.0]) {
        testWidgets('Case Path in ${language.englishName} on $name lays out at text size $textScale', (tester) async {
          final c = await pumpApp(tester, theme: 'light', textScale: textScale, language: language);
          tester.view.physicalSize = size;
          c.read(routerProvider).go(Routes.journey);
          await settle(tester);
          // The whole road, a screen at a time (level 1 is at the bottom).
          for (var i = 0; i < 30; i++) {
            await tester.drag(find.byType(Scrollable).first, const Offset(0, 500));
            await tester.pump();
            expect(tester.takeException(), isNull, reason: 'map at step $i');
          }
          await settle(tester);

          // Large text can make a sheet fill the screen, so close it directly.
          Future<void> closeSheet() async {
            Navigator.of(tester.element(find.byType(BottomSheet))).pop();
            await settle(tester);
          }

          // Each kind of sheet, opened from the level list.
          Future<void> openFromList(int index) async {
            await tester.tap(find.byIcon(Icons.format_list_bulleted_rounded));
            await settle(tester);
            final rows = find.descendant(of: find.byType(DraggableScrollableSheet), matching: find.byType(InkWell));
            final row = rows.at(index);
            await tester.ensureVisible(row);
            await tester.pump();
            await tester.tap(row);
            await settle(tester);
            expect(tester.takeException(), isNull, reason: 'sheet for row $index');
          }

          await openFromList(0); // level 1: the next step
          final scoring = find.byType(ExpansionTile);
          await tester.ensureVisible(scoring);
          await tester.pump();
          await tester.tap(scoring);
          await settle(tester);
          expect(tester.takeException(), isNull, reason: 'scoring rules open');
          await closeSheet();
          await openFromList(2); // level 3: locked
          await closeSheet();
          await openFromList(3); // the first chest: locked
          await closeSheet();
        });
      }
    }
  }

  testWidgets('screen readers hear each stop on the road and its state', (tester) async {
    final handle = tester.ensureSemantics();
    final c = await pumpApp(tester, theme: 'light');
    api.stars['constitution_1'] = 2;
    await c.read(progressSyncProvider.notifier).refresh();
    c.read(routerProvider).go(Routes.journey);
    await settle(tester);
    expect(find.bySemanticsLabel('Level 1, Completed, 2 of 3 stars'), findsOneWidget);
    expect(find.bySemanticsLabel('Level 2, Next step'), findsOneWidget);
    expect(find.bySemanticsLabel('Level 3, Locked'), findsNWidgets(6), reason: 'one per chapter');
    expect(find.bySemanticsLabel(RegExp(r'^Chapter 1, Constitution Basics, 1 of 3 levels done')), findsOneWidget);
    // Both map buttons are named for screen readers by their tooltips.
    expect(find.byTooltip('Jump to current level'), findsOneWidget);
    expect(find.byTooltip('Show levels as a list'), findsOneWidget);
    handle.dispose();
  });

  testWidgets('quiz result lays out at the largest text size', (tester) async {
    await pumpApp(tester, theme: 'light', textScale: 3);
    await finishLevel(tester);
    expect(tester.takeException(), isNull);
  });

  testWidgets('screen readers hear headings, the slide position and errors', (tester) async {
    final handle = tester.ensureSemantics();
    await pumpApp(tester, theme: 'light', onboarded: false);
    expect(tester.getSemantics(find.text('Choose your language')), matchesSemantics(label: 'Choose your language', isHeader: true));
    await tester.tap(find.text('English').first);
    await settle(tester);
    expect(find.bySemanticsLabel('Slide 1 of 3'), findsOneWidget);
    await tester.tap(find.byTooltip('Continue'));
    await settle(tester);
    expect(find.bySemanticsLabel('Slide 2 of 3'), findsOneWidget);
    handle.dispose();
  });

  testWidgets('choice cards work from a keyboard', (tester) async {
    await pumpApp(tester, theme: 'light', onboarded: false);
    // Tab to the first language card, then press it with Enter.
    for (var i = 0; i < 5 && FocusManager.instance.primaryFocus?.context?.findAncestorWidgetOfExactType<Pressable>() == null; i++) {
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
    }
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await settle(tester);
    expect(find.byType(IntroSlides), findsOneWidget);
  });

  // The phone's largest sizes are capped at maxTextScale; check a bit above it.
  for (final route in [...screens, Routes.signIn]) {
    testWidgets('$route lays out at the largest text size', (tester) async {
      final c = await pumpApp(tester, theme: 'light', textScale: 3);
      if (route != Routes.home) {
        tester.takeException(); // Home is checked on its own.
        c.read(routerProvider).go(route);
        await settle(tester);
      }
      expect(tester.takeException(), isNull);
    });
  }

  for (final route in [Routes.home, Routes.settings]) {
    testWidgets('$route lays out at the smallest text size', (tester) async {
      final c = await pumpApp(tester, theme: 'light', textScale: 0.8);
      c.read(routerProvider).go(route);
      await settle(tester);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('quiz lays out at the largest text size', (tester) async {
    await pumpApp(tester, theme: 'light', textScale: 3);
    tester.takeException();
    await tester.tap(find.text('Start learning').first);
    await settle(tester);
    expect(tester.takeException(), isNull);
  });
}

Future<void> settle(WidgetTester tester) async {
  for (var i = 0; i < 12; i++) {
    await tester.pump(const Duration(milliseconds: 150));
  }
}

Future<void> expectGuidelines(WidgetTester tester) async {
  await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
  await expectLater(tester, meetsGuideline(iOSTapTargetGuideline));
  await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
  await expectLater(tester, meetsGuideline(textContrastGuideline));
}
