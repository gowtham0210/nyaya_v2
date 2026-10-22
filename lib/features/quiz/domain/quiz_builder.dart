import 'dart:math';

import '../../../core/config/game_rules.dart';
import '../../profile/domain/user_profile.dart';
import 'question.dart';
import 'quiz_models.dart';

/// Picks the questions for a quiz request. Pure and seedable for tests.
abstract final class QuizBuilder {
  static List<Question> build({
    required QuizRequest request,
    required QuestionBank bank,
    required Set<String> reachedChapters,
    required Persona persona,
    required String dayKey,
    Random? random,
  }) {
    final rng = random ?? Random();
    switch (request.mode) {
      case QuizMode.casePath:
        final parts = request.levelId!.split('_');
        final qs = [...bank.forLevel(parts[0], int.parse(parts[1]))]..shuffle(rng);
        return qs;

      case QuizMode.dailyDocket:
        // Same set for everyone with the same persona today → shareable.
        final seeded = Random(_stableHash(dayKey) ^ persona.index);
        final pool = _personaPool(bank.questions, persona)..sort((a, b) => a.id.compareTo(b.id));
        pool.shuffle(seeded);
        return pool.take(GameRules.dailyDocketQuestions).toList();

      case QuizMode.duel:
        final pool = bank.forChapters(reachedChapters)..shuffle(rng);
        return pool.take(GameRules.duelQuestions).toList();

      case QuizMode.exam:
        final pool = _personaPool(bank.questions, persona)..shuffle(rng);
        final picked = pool.take(GameRules.examQuestions).toList();
        if (picked.length < GameRules.examQuestions) {
          final rest = bank.questions.where((q) => !picked.contains(q)).toList()..shuffle(rng);
          picked.addAll(rest.take(GameRules.examQuestions - picked.length));
        }
        return picked;
    }
  }

  /// FNV-1a — unlike String.hashCode, stable across devices and releases.
  static int _stableHash(String s) {
    var h = 0x811c9dc5;
    for (final c in s.codeUnits) {
      h = ((h ^ c) * 0x01000193) & 0xffffffff;
    }
    return h;
  }

  static List<Question> _personaPool(List<Question> all, Persona persona) {
    final filtered = switch (persona) {
      Persona.citizen => all.where((q) => q.difficulty <= 2),
      Persona.aspirant => all,
      Persona.advocate => all.where((q) => q.difficulty >= 2),
    };
    return filtered.toList();
  }

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
