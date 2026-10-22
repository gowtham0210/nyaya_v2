import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/game_rules.dart';
import '../../../core/storage/local_store.dart';
import '../../gamification/domain/league.dart';
import '../../gamification/domain/reward_summary.dart';
import '../../gamification/domain/xp_calculator.dart';
import '../../journey/application/journey_controller.dart';
import '../../journey/domain/journey.dart';
import '../../profile/application/profile_controller.dart';
import '../domain/quiz_models.dart';

/// Coordinates every side effect of finishing a quiz: stars, XP, coins,
/// streak, energy bonus, duel rating and league position. Lives in the
/// application layer so the controllers it touches stay independent.
class QuizCompletionService {
  QuizCompletionService(this.ref);

  final Ref ref;

  RewardSummary complete(QuizResult result) {
    final profileCtl = ref.read(profileProvider.notifier);
    final journeyCtl = ref.read(journeyProvider.notifier);
    final before = ref.read(profileProvider);
    final now = ref.read(clockProvider)();
    final progress = LeagueSimulator.weekProgress(now);

    int rankFor(int xp) => LeagueSimulator.userRank(LeagueSimulator.cohort(
          weekId: before.weekId,
          tier: before.leagueTier,
          userXp: xp,
          userName: before.name,
          progress: progress,
        ));

    // ── Stars & unlocking (Case Path only) ─────────────────────────────────
    var newStars = 0;
    var replayMastered = false;
    var unlockedNext = false;
    var energyBonus = 0;
    if (result.request.mode == QuizMode.casePath) {
      final id = result.request.levelId!;
      final prevStars = ref.read(journeyProvider).stars[id] ?? 0;
      replayMastered = prevStars == 3;
      final wasDone = prevStars > 0;
      newStars = journeyCtl.recordStars(id, result.stars);
      unlockedNext = !wasDone && result.passed;
      if (result.stars == 3 && prevStars < 3) energyBonus = GameRules.threeStarEnergyBonus;
    }

    // ── XP ─────────────────────────────────────────────────────────────────
    final xp = XpCalculator.session(
      result: result,
      streak: before.streak,
      isReplayOfMastered: replayMastered,
    );

    // ── Coins ──────────────────────────────────────────────────────────────
    var coins = newStars * GameRules.coinsPerNewStar;
    if (result.request.mode == QuizMode.dailyDocket) coins += GameRules.coinsForDailyDocket;
    if (result.duelWon == true) coins += GameRules.coinsForDuelWin;

    // ── Duel rating (hidden Elo) ───────────────────────────────────────────
    int? ratingDelta;
    if (result.request.mode == QuizMode.duel && result.opponent != null) {
      final score = result.duelDraw ? 0.5 : (result.duelWon! ? 1.0 : 0.0);
      final k = before.duelsPlayed < GameRules.provisionalDuels
          ? GameRules.eloKProvisional
          : GameRules.eloKSettled;
      final updated = Elo.update(
        rating: before.duelRating,
        opponent: result.opponent!.rating,
        score: score,
        k: k,
      );
      ratingDelta = updated - before.duelRating;
      profileCtl.applyDuel(newRating: updated, won: result.duelWon!);
    }

    final rankBefore = rankFor(before.weeklyXp);
    final (milestone, extended, goalReached) = profileCtl.applyQuizOutcome(
      xp: xp.total,
      coins: coins,
      answered: result.total,
      correct: result.correct,
      energyBonus: energyBonus,
      isDocket: result.request.mode == QuizMode.dailyDocket,
    );
    final after = ref.read(profileProvider);

    return RewardSummary(
      xp: xp,
      coins: coins,
      newStars: newStars,
      streak: after.streak,
      streakExtended: extended,
      streakMilestone: milestone,
      dailyGoalJustReached: goalReached,
      energyBonus: after.isPremium ? 0 : energyBonus,
      duelRatingDelta: ratingDelta,
      leagueRankBefore: rankBefore,
      leagueRankAfter: rankFor(after.weeklyXp),
      unlockedNext: unlockedNext,
    );
  }

  /// Opens a chapter chest on the map.
  static int openChest(WidgetRef ref, JourneyNode chest) {
    if (!ref.read(journeyProvider.notifier).openChest(chest.id)) return 0;
    ref.read(profileProvider.notifier).addCoins(GameRules.coinsPerChest);
    return GameRules.coinsPerChest;
  }
}
