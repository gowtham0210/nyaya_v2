import 'dart:math';

import 'package:flutter/foundation.dart';

import '../../../core/config/game_rules.dart';
import '../../profile/domain/user_profile.dart';
import 'question.dart';
import 'quiz_models.dart';

/// What to ask the server for. Empty [chapterIds] means every chapter.
@immutable
class SessionPlan {
  const SessionPlan({
    required this.count,
    this.chapterIds = const [],
    this.difficulty,
    this.minDifficulty,
    this.maxDifficulty,
    this.daily = false,
    this.revealAtEnd = false,
  });

  final int count;
  final List<String> chapterIds;
  final int? difficulty;
  final int? minDifficulty;
  final int? maxDifficulty;

  /// Today's shared set (same questions for everyone with these filters).
  final bool daily;

  /// Exam style: answers can change and nothing is revealed until submit.
  final bool revealAtEnd;
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
          count: GameRules.casePathQuestions,
          chapterIds: [parts[0]],
          difficulty: int.parse(parts[1]),
        );
      case QuizMode.dailyDocket:
        // Same set for everyone with the same persona today → shareable.
        return SessionPlan(
          count: GameRules.dailyDocketQuestions,
          minDifficulty: minD,
          maxDifficulty: maxD,
          daily: true,
        );
      case QuizMode.duel:
        return SessionPlan(count: GameRules.duelQuestions, chapterIds: [...reachedChapters]..sort());
      case QuizMode.exam:
        return SessionPlan(
          count: GameRules.examQuestions,
          minDifficulty: minD,
          maxDifficulty: maxD,
          revealAtEnd: true,
        );
    }
  }

  /// Citizens skip the hardest questions; advocates skip the easiest.
  static (int?, int?) _personaRange(Persona persona) => switch (persona) {
        Persona.citizen => (null, 2),
        Persona.aspirant => (null, null),
        Persona.advocate => (2, null),
      };

  /// Duel opponent near the player's hidden rating.
  static DuelOpponent opponent(int rating, Random rng) {
    const names = [
      ('Adv. Kavya R', 'Kochi'),
      ('Arjun Menon', 'Bengaluru'),
      ('Priya Sharma', 'Delhi'),
      ('Karthik S', 'Chennai'),
      ('Sneha Reddy', 'Hyderabad'),
      ('Rahul Verma', 'Lucknow'),
      ('Fathima N', 'Kozhikode'),
      ('Harish Gowda', 'Mysuru'),
      ('Divya Iyer', 'Coimbatore'),
      ('Vikram Rao', 'Vijayawada'),
    ];
    final pick = names[rng.nextInt(names.length)];
    return DuelOpponent(
      name: pick.$1,
      city: pick.$2,
      avatarSeed: rng.nextInt(1 << 20),
      rating: (rating + rng.nextInt(301) - 150).clamp(600, 2400),
    );
  }

  /// Simulated opponent answer: (correct, elapsedMs).
  static (bool, int) opponentAnswer(DuelOpponent o, Question q, Random rng) {
    final skill = ((o.rating - 600) / 1400).clamp(0.0, 1.0);
    final p = (0.4 + skill * 0.5 - (q.difficulty - 1) * 0.08).clamp(0.25, 0.92);
    final correct = rng.nextDouble() < p;
    final ms = 2500 + rng.nextInt(9000);
    return (correct, ms);
  }
}
