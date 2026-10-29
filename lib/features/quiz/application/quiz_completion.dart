import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';

import '../../../core/config/game_rules.dart';
import '../../../core/storage/local_store.dart';
import '../../gamification/domain/league.dart';
import '../../gamification/domain/reward_summary.dart';
import '../../gamification/domain/xp_calculator.dart';
import '../../journey/application/journey_controller.dart';
import '../../journey/domain/journey.dart';
import '../../profile/application/profile_controller.dart';
import '../../progress/application/progress_sync.dart';
import '../../progress/data/progress_api.dart';
import '../../progress/domain/server_progress.dart';
import '../domain/quiz_models.dart';

/// Coordinates every side effect of finishing a quiz. XP, stars and the
/// streak come from the server ([ServerRewards], [ServerProgress]); coins,
/// energy and the duel rating are still worked out here on the phone.
class QuizCompletionService {
  QuizCompletionService(this.ref);

  final Ref ref;

  /// [progress] is the server's progress after this quiz; null when it could
  /// not be loaded, in which case the rewards are shown on their own.
  RewardSummary complete(QuizResult result, ServerRewards rewards, ServerProgress? progress) {
    final profileCtl = ref.read(profileProvider.notifier);
    final before = ref.read(profileProvider);
    final now = ref.read(clockProvider)();
    final weekProgress = LeagueSimulator.weekProgress(now);

    int rankFor(int xp) => LeagueSimulator.userRank(LeagueSimulator.cohort(
          weekId: before.weekId,
          tier: before.leagueTier,
          userXp: xp,
          userName: before.name,
          progress: weekProgress,
        ));
    final rankBefore = rankFor(before.weeklyXp);

    // ── Progress from the server ───────────────────────────────────────────
    if (progress != null) {
      ref.read(progressSyncProvider.notifier).apply(progress);
    } else if (rewards.levelId != null && rewards.stars != null) {
      ref.read(journeyProvider.notifier).showBest(rewards.levelId!, rewards.stars!);
    }
    final stars = rewards.stars ?? 0;
    final isCasePath = result.request.mode == QuizMode.casePath;
    final unlockedNext = isCasePath && rewards.bestStarsBefore == 0 && stars > 0;
    final energyBonus =
        isCasePath && stars == 3 && rewards.bestStarsBefore < 3 ? GameRules.threeStarEnergyBonus : 0;
    final quizzesToday = progress?.quizzesToday ?? before.quizzesToday + 1;
    final goalReached = quizzesToday == before.dailyGoal;

    // ── Coins (on the phone until the economy moves to the server) ─────────
    var coins = rewards.newStars * GameRules.coinsPerNewStar;
    if (result.request.mode == QuizMode.dailyDocket) coins += GameRules.coinsForDailyDocket;
    if (result.duelWon == true) coins += GameRules.coinsForDuelWin;
    if (rewards.streakMilestone != null) coins += GameRules.streakMilestones[rewards.streakMilestone!] ?? 0;
    if (goalReached) coins += GameRules.coinsForDailyGoal;

    // ── Duel rating (hidden Elo, simulated opponent) ───────────────────────
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

    profileCtl.applyQuizEconomy(coins: coins, energyBonus: energyBonus);
    final weeklyAfter = progress?.weeklyXp ?? before.weeklyXp + rewards.xp;

    return RewardSummary(
      xp: XpBreakdown(
        questionXp: rewards.questionXp,
        completionBonus: rewards.completionBonus,
        perfectBonus: rewards.perfectBonus,
        modeMultiplier: rewards.modeMultiplier,
        streakMultiplier: rewards.streakMultiplier,
        duelBonus: 0,
        total: rewards.xp,
      ),
      coins: coins,
      newStars: rewards.newStars,
      streak: rewards.streak,
      streakExtended: rewards.streakExtended,
      streakMilestone: rewards.streakMilestone,
      dailyGoalJustReached: goalReached,
      energyBonus: before.isPremium ? 0 : energyBonus,
      duelRatingDelta: ratingDelta,
      leagueRankBefore: rankBefore,
      leagueRankAfter: rankFor(weeklyAfter),
      unlockedNext: unlockedNext,
    );
  }

  /// Opens a chapter chest on the map through the server. Returns the coins
  /// won, or 0 when the server refused (locked, already open or offline).
  static Future<int> openChest(WidgetRef ref, JourneyNode chest) async {
    try {
      final progress = await ref.read(progressApiProvider).openChest(chest.id);
      final wasOpen = ref.read(journeyProvider).openedChests.contains(chest.id);
      ref.read(progressSyncProvider.notifier).apply(progress);
      if (wasOpen || !progress.openedChests.contains(chest.id)) return 0;
    } on ApiException {
      return 0;
    }
    ref.read(profileProvider.notifier).addCoins(GameRules.coinsPerChest);
    return GameRules.coinsPerChest;
  }
}
