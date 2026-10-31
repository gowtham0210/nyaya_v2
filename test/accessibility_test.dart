import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:nyaya/app/app.dart';
import 'package:nyaya/app/router.dart';
import 'package:nyaya/core/api/token_store.dart';
import 'package:nyaya/core/storage/local_store.dart';
import 'package:nyaya/core/theme/app_theme.dart';
import 'package:nyaya/features/auth/data/auth_api.dart';
import 'package:nyaya/features/leaderboard/data/league_api.dart';
import 'package:nyaya/features/legal_updates/data/legal_updates_repository.dart';
import 'package:nyaya/features/reminders/data/reminder_notifications.dart';
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
  }) async {
    tester.view.physicalSize = const Size(1170, 2532);
    tester.view.devicePixelRatio = 3;
    tester.platformDispatcher.textScaleFactorTestValue = textScale;
    addTearDown(tester.view.reset);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    final profile = jsonEncode({'onboarded': onboarded, 'name': 'Ravi', 'coins': 60, 'persona': 'citizen', 'themeMode': theme});
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
      authApiProvider.overrideWithValue(FakeAuthApi(tokens)),
    ]);
    addTearDown(container.dispose);
    await tester.pumpWidget(UncontrolledProviderScope(container: container, child: const NyayaApp()));
    await settle(tester);
    return container;
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
      await tester.tap(find.text('Explore').first);
      await settle(tester);
      await expectGuidelines(tester);
      handle.dispose();
    });

    testWidgets('quiz after a wrong answer ($theme) meets accessibility guidelines', (tester) async {
      final handle = tester.ensureSemantics();
      final c = await pumpApp(tester, theme: theme);
      await tester.tap(find.text('Explore').first);
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

    testWidgets('onboarding ($theme) meets accessibility guidelines', (tester) async {
      final handle = tester.ensureSemantics();
      await pumpApp(tester, theme: theme, onboarded: false);
      await expectGuidelines(tester);
      await tester.tap(find.text('English').first);
      await settle(tester);
      await expectGuidelines(tester);
      handle.dispose();
    });
  }

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
    await tester.tap(find.text('Explore').first);
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
