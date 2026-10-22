import 'dart:math';

import '../../../core/config/game_rules.dart';
import '../../quiz/domain/quiz_models.dart';

class XpBreakdown {
  const XpBreakdown({
    required this.questionXp,
    required this.completionBonus,
    required this.perfectBonus,
    required this.modeMultiplier,
    required this.streakMultiplier,
    required this.duelBonus,
    required this.total,
  });

  final int questionXp;
  final int completionBonus;
  final int perfectBonus;
  final double modeMultiplier;
  final double streakMultiplier;
  final int duelBonus;
  final int total;
}

/// XP rewards effort (leagues). It is never negative — negative marking only
/// affects the exam *score*, not XP.
abstract final class XpCalculator {
  /// qXP = (10 + speedBonus + comboBonus) × difficulty
  static double questionXp({
    required int difficulty,
    required int elapsedMs,
    required int referenceSeconds,
    required int comboBefore,
  }) {
    final t = elapsedMs / 1000;
    final speed = (GameRules.maxSpeedBonus * max(0, 1 - t / referenceSeconds)).round();
    final combo = comboBefore + 1 >= GameRules.comboStart
        ? min(
            GameRules.maxComboBonus,
            (comboBefore + 2 - GameRules.comboStart) * GameRules.comboBonusStep,
          )
        : 0;
    final d = GameRules.difficultyMultiplier[difficulty.clamp(1, 4)]!;
    return (GameRules.xpPerCorrect + speed + combo) * d;
  }

  static XpBreakdown session({
    required QuizResult result,
    required int streak,
    bool isReplayOfMastered = false,
  }) {
    var sum = 0.0;
    var combo = 0;
    for (final a in result.answers) {
      if (a.isCorrect) {
        sum += questionXp(
          difficulty: a.question.difficulty,
          elapsedMs: a.elapsedMs,
          referenceSeconds: result.request.mode.speedReferenceSeconds,
          comboBefore: combo,
        );
        combo++;
      } else {
        combo = 0;
      }
    }
    final completion = result.total > 0 ? GameRules.xpCompletionBonus : 0;
    final perfect = result.isPerfect ? GameRules.xpPerfectBonus : 0;
    final modeMul = switch (result.request.mode) {
      QuizMode.dailyDocket => GameRules.dailyDocketMultiplier,
      _ => isReplayOfMastered ? GameRules.replayMultiplier : 1.0,
    };
    final streakMul = GameRules.streakMultiplier(streak);
    final duel = result.duelWon == true ? GameRules.duelWinXp : 0;
    final total = ((sum + completion + perfect) * modeMul * streakMul).round() + duel;
    return XpBreakdown(
      questionXp: sum.round(),
      completionBonus: completion,
      perfectBonus: perfect,
      modeMultiplier: modeMul,
      streakMultiplier: streakMul,
      duelBonus: duel,
      total: total,
    );
  }

  /// Kahoot-style duel points: 500–1000 per correct answer, faster = more.
  static int duelPoints({required bool correct, required int elapsedMs, required int limitSeconds}) {
    if (!correct) return 0;
    final t = (elapsedMs / 1000).clamp(0, limitSeconds);
    return (1000 * (1 - t / (2 * limitSeconds))).round();
  }
}
