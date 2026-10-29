import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nyaya/core/api/token_store.dart';
import 'package:nyaya/core/storage/local_store.dart';
import 'package:nyaya/features/auth/data/auth_api.dart';
import 'package:nyaya/features/journey/application/journey_controller.dart';
import 'package:nyaya/features/profile/application/profile_controller.dart';
import 'package:nyaya/features/progress/data/progress_api.dart';
import 'package:nyaya/features/quiz/application/quiz_controller.dart';
import 'package:nyaya/features/quiz/data/quiz_api.dart';
import 'package:nyaya/features/quiz/domain/quiz_models.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/fake_backend.dart';

/// The quiz controller against a fake server, without widgets.
void main() {
  late FakeQuizApi api;
  late ProviderContainer c;
  const exam = QuizRequest(QuizMode.exam);

  Future<ProviderContainer> container(FakeQuizApi fake) async {
    SharedPreferences.setMockInitialValues({
      'profile_v1': jsonEncode({'onboarded': true, 'name': 'Ravi', 'persona': 'aspirant'}),
    });
    final tokens = signedInTokens();
    final c = ProviderContainer(overrides: [
      sharedPreferencesProvider.overrideWithValue(await SharedPreferences.getInstance()),
      tokenStoreProvider.overrideWithValue(tokens),
      quizApiProvider.overrideWithValue(fake),
      progressApiProvider.overrideWithValue(fake),
      authApiProvider.overrideWithValue(FakeAuthApi(tokens)),
    ]);
    addTearDown(c.dispose);
    return c;
  }

  setUp(() async => c = await container(api = FakeQuizApi(perLevel: 2)));

  Future<void> idle() async {
    for (var i = 0; i < 5; i++) {
      await Future<void>.delayed(Duration.zero);
    }
  }

  test('exam reveals nothing until submit, then takes the score from the server', () async {
    final sub = c.listen(quizControllerProvider(exam), (_, _) {});
    addTearDown(sub.close);
    await idle();
    final ctl = c.read(quizControllerProvider(exam).notifier);
    var s = c.read(quizControllerProvider(exam));
    expect(s.phase, QuizPhase.active);
    final total = s.questions.length;

    // Right on the first question, wrong on the second, skip the rest.
    for (var i = 0; i < total; i++) {
      final q = c.read(quizControllerProvider(exam)).current;
      if (i < 2) {
        final text = i == 0 ? api.correctTextFor(q.id) : api.wrongTextFor(q.id);
        await ctl.select(q.options.indexOf(text));
      }
      ctl.next();
      await idle();
    }
    expect(api.verdictsSent, hasLength(2));
    expect(api.verdictsSent.every((v) => v == null), isTrue, reason: 'no verdict before submit');

    s = c.read(quizControllerProvider(exam));
    expect(s.phase, QuizPhase.finished);
    expect(s.result!.correct, 1);
    expect(s.result!.wrong, 1);
    expect(s.result!.skipped, total - 2);
    expect(s.result!.answers.every((a) => a.reveal != null), isTrue, reason: 'everything explained after submit');
    // +1 right, −0.25 wrong for aspirants.
    expect(s.result!.examScore, 0.75);
  });

  test('a level still finishes when progress comes back unreadable', () async {
    api.unreadableProgress = true;
    const level = QuizRequest(QuizMode.casePath, levelId: 'constitution_1');
    final sub = c.listen(quizControllerProvider(level), (_, _) {});
    addTearDown(sub.close);
    await idle();
    final ctl = c.read(quizControllerProvider(level).notifier);
    final total = c.read(quizControllerProvider(level)).questions.length;
    for (var i = 0; i < total; i++) {
      final q = c.read(quizControllerProvider(level)).current;
      await ctl.select(q.options.indexOf(api.correctTextFor(q.id)));
      ctl.next();
      await idle();
    }
    final s = c.read(quizControllerProvider(level));
    expect(s.phase, QuizPhase.finished);
    // The server's rewards still show, and the map shows the stars.
    expect(s.rewards!.newStars, 3);
    expect(c.read(journeyProvider).stars['constitution_1'], 3);
  });

  test('leaving before the first answer gives the energy back on the server', () async {
    const level = QuizRequest(QuizMode.casePath, levelId: 'constitution_1');
    final sub = c.listen(quizControllerProvider(level), (_, _) {});
    addTearDown(sub.close);
    await idle();
    expect(api.energy, 4);
    await c.read(quizControllerProvider(level).notifier).abandon();
    expect(api.energy, 5);
    expect(c.read(profileProvider).energy, 5);
  });

  test('a quiz with nothing published says so', () async {
    final c2 = await container(FakeQuizApi(perLevel: 0));
    const level = QuizRequest(QuizMode.casePath, levelId: 'constitution_1');
    final sub = c2.listen(quizControllerProvider(level), (_, _) {});
    addTearDown(sub.close);
    await idle();
    final s = c2.read(quizControllerProvider(level));
    expect(s.phase, QuizPhase.failed);
    expect(s.failure, QuizFailure.empty);
  });
}
