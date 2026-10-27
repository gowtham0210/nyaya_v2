import 'dart:convert';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:nyaya/app/app.dart';
import 'package:nyaya/core/storage/local_store.dart';
import 'package:nyaya/core/theme/app_theme.dart';
import 'package:nyaya/features/journey/application/journey_controller.dart';
import 'package:nyaya/features/profile/application/profile_controller.dart';
import 'package:nyaya/features/quiz/application/quiz_controller.dart';
import 'package:nyaya/features/quiz/data/question_repository.dart';
import 'package:nyaya/features/quiz/domain/quiz_models.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// End-to-end user flows on the real widget tree (no network).
void main() {
  setUpAll(() => AppTheme.useGoogleFonts = false);

  Future<ProviderContainer> pumpApp(WidgetTester tester, {Map<String, Object> prefs = const {}}) async {
    tester.view.physicalSize = const Size(1170, 2532);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    SharedPreferences.setMockInitialValues(prefs);
    final sp = await SharedPreferences.getInstance();
    final container = ProviderContainer(overrides: [
      sharedPreferencesProvider.overrideWithValue(sp),
      questionRepositoryProvider.overrideWithValue(
        AssetQuestionRepository(load: (path) async => File(path).readAsStringSync()),
      ),
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
    for (var i = 0; i < 3; i++) {
      await tester.tap(find.text('CONTINUE'));
      await settle(tester);
    }
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
    // Soft paywall is shown and can be dismissed without breaking the flow.
    await tester.pump(const Duration(milliseconds: 600));
    await settle(tester);
    expect(find.text('Maybe later'), findsOneWidget);
    await tester.tap(find.text('Maybe later'));
    await settle(tester);
    expect(find.text('Explore Law'), findsOneWidget);
  });

  testWidgets('playing a Case Path level end to end awards stars and XP', (tester) async {
    final onboarded = jsonEncode({'onboarded': true, 'name': 'Ravi', 'coins': 60, 'persona': 'citizen'});
    final c = await pumpApp(tester, prefs: {'profile_v1': onboarded});
    await settle(tester);

    await tester.tap(find.text('Explore').first); // Constitution "Start here" card
    await settle(tester);
    expect(c.read(profileProvider).energy, 4, reason: 'energy is charged at start');

    // Answer every question correctly by reading the answer key from state.
    for (var i = 0; i < 6; i++) {
      final bankQuestion = find.textContaining('Question ${i + 1} of');
      expect(bankQuestion, findsOneWidget);
      final correct = _currentCorrectOption(c);
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

  testWidgets('out of energy shows free alternatives instead of a dead end', (tester) async {
    final today = DateTime.now();
    final key = '${today.year.toString().padLeft(4, '0')}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';
    final profile = jsonEncode({'onboarded': true, 'name': 'Ravi', 'energy': 0, 'energyDay': key});
    await pumpApp(tester, prefs: {'profile_v1': profile});
    await settle(tester);

    await tester.tap(find.text('Explore').first); // Constitution "Start here" card
    await settle(tester);
    expect(find.text("You're out of energy"), findsOneWidget);
    expect(find.text("Play today's Daily Docket (free)"), findsOneWidget);
    expect(find.text('Ask the AI a legal question'), findsOneWidget);
  });
}

String _currentCorrectOption(ProviderContainer c) {
  final q = c.read(quizControllerProvider(const QuizRequest(QuizMode.casePath, levelId: 'constitution_1'))).current;
  return q.options[q.answerIndex];
}
