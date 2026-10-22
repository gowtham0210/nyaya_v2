import 'package:flutter/foundation.dart';

import 'xp_calculator.dart';

/// Everything the results screen celebrates after a quiz.
@immutable
class RewardSummary {
  const RewardSummary({
    required this.xp,
    required this.coins,
    required this.newStars,
    required this.streak,
    required this.streakExtended,
    required this.streakMilestone,
    required this.dailyGoalJustReached,
    required this.energyBonus,
    required this.duelRatingDelta,
    required this.leagueRankBefore,
    required this.leagueRankAfter,
    required this.unlockedNext,
  });

  final XpBreakdown xp;
  final int coins;
  final int newStars;
  final int streak;
  final bool streakExtended;
  final int? streakMilestone;
  final bool dailyGoalJustReached;
  final int energyBonus;
  final int? duelRatingDelta;
  final int leagueRankBefore;
  final int leagueRankAfter;
  final bool unlockedNext;
}
