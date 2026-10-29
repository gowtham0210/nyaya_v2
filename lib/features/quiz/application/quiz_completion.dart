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

/// Coordinates every side effect of finishing a quiz. XP, stars, the streak,
/// coins and energy come from the server ([ServerRewards], [ServerProgress]);
/// only the duel rating (simulated opponent) is worked out on the phone.
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
    final goalReached = (progress?.quizzesToday ?? before.quizzesToday + 1) == before.dailyGoal;

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

    // Coins and energy come with the server's progress; without it, show the rewards.
    if (progress == null) profileCtl.applyQuizEconomy(coins: rewards.coins, energyBonus: rewards.energyBonus);
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
      coins: rewards.coins,
      newStars: rewards.newStars,
      streak: rewards.streak,
      streakExtended: rewards.streakExtended,
      streakMilestone: rewards.streakMilestone,
      dailyGoalJustReached: goalReached,
      energyBonus: rewards.energyBonus,
      duelRatingDelta: ratingDelta,
      leagueRankBefore: rankBefore,
      leagueRankAfter: rankFor(weeklyAfter),
      unlockedNext: unlockedNext,
    );
  }

  /// Opens a chapter chest on the map through the server. Returns the coins
  /// won, or 0 when the server refused (locked, already open or offline).
  static Future<int> openChest(WidgetRef ref, JourneyNode chest) async {
    final coinsBefore = ref.read(profileProvider).coins;
    try {
      final progress = await ref.read(progressApiProvider).openChest(chest.id);
      ref.read(progressSyncProvider.notifier).apply(progress);
      return (progress.coins - coinsBefore).clamp(0, GameRules.coinsPerChest);
    } on ApiException {
      return 0;
    }
  }
}
