import 'package:flutter_test/flutter_test.dart';
import 'package:nyaya/core/config/game_rules.dart';
import 'package:nyaya/features/profile/domain/user_profile.dart';
import 'package:nyaya/features/quiz/domain/quiz_builder.dart';
import 'package:nyaya/features/quiz/domain/quiz_models.dart';

/// What each mode asks the server for. Question content and its checks live
/// with the backend's seed data now.
void main() {
  SessionPlan plan(QuizRequest r, {Persona persona = Persona.aspirant, Set<String> reached = const {}}) =>
      QuizBuilder.plan(request: r, reachedChapters: reached, persona: persona);

  test('Case Path asks for one chapter at the level difficulty', () {
    final p = plan(const QuizRequest(QuizMode.casePath, levelId: 'criminal_2'));
    expect(p.chapterIds, ['criminal']);
    expect(p.difficulty, 2);
    expect(p.count, GameRules.casePathQuestions);
    expect(p.revealAtEnd, isFalse);
  });

  test("Daily Docket is today's shared set across every chapter", () {
    final p = plan(const QuizRequest(QuizMode.dailyDocket));
    expect(p.daily, isTrue);
    expect(p.chapterIds, isEmpty);
    expect(p.count, GameRules.dailyDocketQuestions);
  });

  test('Duel draws from the chapters reached so far', () {
    final p = plan(const QuizRequest(QuizMode.duel), reached: {'rights', 'constitution'});
    expect(p.chapterIds, ['constitution', 'rights']);
    expect(p.count, GameRules.duelQuestions);
  });

  test('Exam reveals at the end and follows the persona', () {
    final citizen = plan(const QuizRequest(QuizMode.exam), persona: Persona.citizen);
    expect(citizen.revealAtEnd, isTrue);
    expect(citizen.count, GameRules.examQuestions);
    expect((citizen.minDifficulty, citizen.maxDifficulty), (null, 2));
    final advocate = plan(const QuizRequest(QuizMode.exam), persona: Persona.advocate);
    expect((advocate.minDifficulty, advocate.maxDifficulty), (2, null));
  });
}
