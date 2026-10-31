
import 'package:flutter/foundation.dart';

import '../../../core/config/game_rules.dart';
import '../../profile/domain/user_profile.dart';
import 'quiz_models.dart';

/// What to ask the server for. Empty [chapterIds] means every chapter.
@immutable
class SessionPlan {
  const SessionPlan({
    required this.mode,
    required this.count,
    this.chapterIds = const [],
    this.difficulty,
    this.minDifficulty,
    this.maxDifficulty,
    this.negativeMarking = false,
  });

  /// Tells the server which rules and rewards apply.
  final QuizMode mode;
  final int count;
  final List<String> chapterIds;
  final int? difficulty;
  final int? minDifficulty;
  final int? maxDifficulty;

  /// Exam only: 0.25 off per wrong answer (not for citizens).
  final bool negativeMarking;

  /// Today's shared set (same questions for everyone with these filters).
  bool get daily => mode == QuizMode.dailyDocket;

  /// Exam style: answers can change and nothing is revealed until submit.
  bool get revealAtEnd => mode == QuizMode.exam;
}

/// Turns a quiz request into a [SessionPlan]; the server picks the questions.
/// Pure, so the rules are easy to test.
abstract final class QuizBuilder {
  static SessionPlan plan({
    required QuizRequest request,
    required Set<String> reachedChapters,
    required Persona persona,
  }) {
    final (minD, maxD) = _personaRange(persona);
    switch (request.mode) {
      case QuizMode.casePath:
        final parts = request.levelId!.split('_');
        return SessionPlan(
          mode: request.mode,
          count: GameRules.casePathQuestions,
          chapterIds: [parts[0]],
          difficulty: int.parse(parts[1]),
        );
      case QuizMode.dailyDocket:
        // Same set for everyone with the same persona today → shareable.
        return SessionPlan(
          mode: request.mode,
          count: GameRules.dailyDocketQuestions,
          minDifficulty: minD,
          maxDifficulty: maxD,
        );
      case QuizMode.mistakeReview:
        // The server picks from the learner's own mistakes.
        return SessionPlan(mode: request.mode, count: 10);
      case QuizMode.duel:
        return SessionPlan(mode: request.mode, count: GameRules.duelQuestions, chapterIds: [...reachedChapters]..sort());
      case QuizMode.exam:
        return SessionPlan(
          mode: request.mode,
          count: GameRules.examQuestions,
          minDifficulty: minD,
          maxDifficulty: maxD,
          negativeMarking: persona != Persona.citizen,
        );
    }
  }

  /// Citizens skip the hardest questions; advocates skip the easiest.
  static (int?, int?) _personaRange(Persona persona) => switch (persona) {
        Persona.citizen => (null, 2),
        Persona.aspirant => (null, null),
        Persona.advocate => (2, null),
      };
}
