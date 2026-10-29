import '../../../core/config/game_rules.dart';
import '../../../core/utils/day.dart';
import '../../profile/domain/user_profile.dart';
import 'league.dart';

/// Pure day/week rollover rules. Called on launch and on every resume, so the
/// app is always consistent no matter how long it was closed.
abstract final class DailyPolicy {
  static UserProfile rollover(UserProfile p, DateTime now) {
    final today = Day.key(now);
    var next = p;

    // ── Energy & daily counters ─────────────────────────────────────────────
    if (next.energyDay != today) {
      next = next.copyWith(
        energy: GameRules.freeDailyEnergy,
        energyDay: today,
        quizzesToday: 0,
        quizzesTodayDay: today,
        aiMessagesToday: 0,
      );
    }

    // The streak is worked out by the server (see ProfileController.applyServerProgress).

    // ── Weekly league close ─────────────────────────────────────────────────
    final week = Day.weekKey(now);
    if (next.weekId != week) {
      if (next.weekId.isNotEmpty && next.weeklyXp > 0) {
        final finalStandings = LeagueSimulator.cohort(
          weekId: next.weekId,
          tier: next.leagueTier,
          userXp: next.weeklyXp,
          userName: next.name,
          progress: 1,
        );
        final rank = LeagueSimulator.userRank(finalStandings);
        final to = Leagues.nextTier(next.leagueTier, rank);
        next = next.copyWith(
          pendingLeagueOutcome: LeagueOutcome(rank: rank, fromTier: next.leagueTier, toTier: to),
          leagueTier: to,
          // The top-3 coin bonus returns with real leagues (coins are on the server).
        );
      }
      next = next.copyWith(weekId: week, weeklyXp: 0);
    }
    return next;
  }
}
