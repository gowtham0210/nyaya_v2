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

    // ── Streak: protect with freezes, otherwise reset ───────────────────────
    final last = next.lastActiveDay;
    if (last != null && next.streak > 0) {
      final gap = Day.between(last, today);
      if (gap > 1) {
        final missed = gap - 1;
        if (next.streakFreezes >= missed) {
          final frozen = [
            for (var i = 1; i <= missed; i++)
              Day.key(Day.parse(last).add(Duration(days: i))),
          ];
          next = next.copyWith(
            streakFreezes: next.streakFreezes - missed,
            frozenDays: _recent([...next.frozenDays, ...frozen]),
            // Pretend yesterday was active so today's quiz extends the streak.
            lastActiveDay: Day.key(now.subtract(const Duration(days: 1))),
          );
        } else {
          next = next.copyWith(streak: 0);
        }
      }
    }

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
          coins: next.coins + (rank <= 3 ? 50 : 0),
        );
      }
      next = next.copyWith(weekId: week, weeklyXp: 0);
    }
    return next;
  }

  /// Registers a completed quiz for streak purposes. Returns the updated
  /// profile and the milestone hit (if any).
  static (UserProfile, int? milestone, bool extended) onQuizCompleted(
    UserProfile p,
    DateTime now,
  ) {
    final today = Day.key(now);
    if (p.lastActiveDay == today) return (p, null, false);
    final streak = p.streak + 1;
    final milestone = GameRules.streakMilestones.containsKey(streak) ? streak : null;
    var freezes = p.streakFreezes;
    if (GameRules.freezeMilestones.contains(streak)) {
      freezes = (freezes + 1).clamp(0, GameRules.maxStreakFreezes);
    }
    final next = p.copyWith(
      streak: streak,
      longestStreak: streak > p.longestStreak ? streak : p.longestStreak,
      lastActiveDay: today,
      activeDays: _recent([...p.activeDays, today]),
      streakFreezes: freezes,
      coins: p.coins + (milestone != null ? GameRules.streakMilestones[milestone]! : 0),
    );
    return (next, milestone, true);
  }

  static List<String> _recent(List<String> days) {
    final unique = days.toSet().toList()..sort();
    return unique.length > 21 ? unique.sublist(unique.length - 21) : unique;
  }
}
