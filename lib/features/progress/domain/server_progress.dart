import 'package:flutter/foundation.dart';

/// Learning progress as the server works it out from submitted quizzes
/// (`GET /v1/me/progress`). The phone keeps a copy only to show it.
@immutable
class ServerProgress {
  const ServerProgress({
    required this.today,
    required this.totalXp,
    required this.weekId,
    required this.weeklyXp,
    required this.lastWeekId,
    required this.lastWeekXp,
    required this.streak,
    required this.longestStreak,
    required this.streakFreezes,
    required this.lastActiveDay,
    required this.activeDays,
    required this.frozenDays,
    required this.stars,
    required this.openedChests,
    required this.quizzesCompleted,
    required this.quizzesToday,
    required this.docketDoneToday,
    required this.questionsAnswered,
    required this.correct,
  });

  /// India date the figures are for (YYYY-MM-DD).
  final String today;
  final int totalXp;
  final String weekId;
  final int weeklyXp;
  final String lastWeekId;
  final int lastWeekXp;
  final int streak;
  final int longestStreak;
  final int streakFreezes;
  final String? lastActiveDay;
  final List<String> activeDays;
  final List<String> frozenDays;

  /// Best Case Path stars per level id (`constitution_2`).
  final Map<String, int> stars;
  final Set<String> openedChests;
  final int quizzesCompleted;
  final int quizzesToday;
  final bool docketDoneToday;
  final int questionsAnswered;
  final int correct;

  factory ServerProgress.fromJson(Map<String, dynamic> j) {
    final week = j['week'] as Map<String, dynamic>;
    final lastWeek = j['last_week'] as Map<String, dynamic>;
    final streak = j['streak'] as Map<String, dynamic>;
    List<String> days(Object? v) => (v as List).cast<String>();
    return ServerProgress(
      today: j['today'] as String,
      totalXp: j['total_xp'] as int,
      weekId: week['week_id'] as String,
      weeklyXp: week['xp'] as int,
      lastWeekId: lastWeek['week_id'] as String,
      lastWeekXp: lastWeek['xp'] as int,
      streak: streak['current'] as int,
      longestStreak: streak['longest'] as int,
      streakFreezes: streak['freezes'] as int,
      lastActiveDay: streak['last_active_day'] as String?,
      activeDays: days(streak['active_days']),
      frozenDays: days(streak['frozen_days']),
      stars: (j['stars'] as Map<String, dynamic>).map((k, v) => MapEntry(k, v as int)),
      openedChests: (j['opened_chests'] as List).cast<String>().toSet(),
      quizzesCompleted: j['quizzes_completed'] as int,
      quizzesToday: j['quizzes_today'] as int,
      docketDoneToday: j['docket_done_today'] as bool,
      questionsAnswered: j['questions_answered'] as int,
      correct: j['correct'] as int,
    );
  }
}

/// What one submitted quiz earned, as the server worked it out.
@immutable
class ServerRewards {
  const ServerRewards({
    required this.questionXp,
    required this.completionBonus,
    required this.perfectBonus,
    required this.modeMultiplier,
    required this.streakMultiplier,
    required this.xp,
    required this.levelId,
    required this.stars,
    required this.bestStarsBefore,
    required this.newStars,
    required this.streak,
    required this.streakExtended,
    required this.streakMilestone,
  });

  final int questionXp;
  final int completionBonus;
  final int perfectBonus;
  final double modeMultiplier;
  final double streakMultiplier;
  final int xp;
  final String? levelId;
  final int? stars;
  final int bestStarsBefore;
  final int newStars;
  final int streak;
  final bool streakExtended;
  final int? streakMilestone;

  factory ServerRewards.fromJson(Map<String, dynamic> j) {
    final xp = j['xp'] as Map<String, dynamic>;
    return ServerRewards(
      questionXp: xp['question_xp'] as int,
      completionBonus: xp['completion_bonus'] as int,
      perfectBonus: xp['perfect_bonus'] as int,
      modeMultiplier: (xp['mode_multiplier'] as num).toDouble(),
      streakMultiplier: (xp['streak_multiplier'] as num).toDouble(),
      xp: xp['total'] as int,
      levelId: j['level_id'] as String?,
      stars: j['stars'] as int?,
      bestStarsBefore: j['best_stars_before'] as int,
      newStars: j['new_stars'] as int,
      streak: j['streak'] as int,
      streakExtended: j['streak_extended'] as bool,
      streakMilestone: j['streak_milestone'] as int?,
    );
  }
}
