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
    required this.coins,
    required this.energy,
    required this.premium,
    required this.settings,
    this.duelRating,
    this.duelsPlayed,
    this.duelsWon,
    required this.chatUsedToday,
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
  final int coins;

  /// Energy left today (premium quizzes cost none).
  final int energy;
  final bool premium;

  /// Hidden duel rating and record; null from a server without duels.
  final int? duelRating;
  final int? duelsPlayed;
  final int? duelsWon;

  /// Null until the account has saved settings once.
  final ServerSettings? settings;
  final int chatUsedToday;

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
      coins: j['coins'] as int,
      energy: (j['energy'] as Map<String, dynamic>)['today'] as int,
      premium: j['premium'] as bool,
      settings: j['settings'] == null ? null : ServerSettings.fromJson(j['settings'] as Map<String, dynamic>),
      chatUsedToday: (j['chat'] as Map<String, dynamic>)['used_today'] as int,
      duelRating: (j['duel'] as Map<String, dynamic>?)?['rating'] as int?,
      duelsPlayed: (j['duel'] as Map<String, dynamic>?)?['played'] as int?,
      duelsWon: (j['duel'] as Map<String, dynamic>?)?['won'] as int?,
    );
  }
}

/// Learning settings that follow the account. Theme, sound, haptics and
/// reminders stay on each phone.
@immutable
class ServerSettings {
  const ServerSettings({
    required this.name,
    required this.persona,
    required this.language,
    required this.dailyGoal,
    required this.onboarded,
  });

  final String name;

  /// API names: advocate, aspirant, citizen.
  final String persona;
  final String language;
  final int dailyGoal;
  final bool onboarded;

  factory ServerSettings.fromJson(Map<String, dynamic> j) => ServerSettings(
        name: j['name'] as String,
        persona: j['persona'] as String,
        language: j['language'] as String,
        dailyGoal: j['daily_goal'] as int,
        onboarded: j['onboarded'] as bool,
      );

  Map<String, dynamic> toJson() => {
        'name': name,
        'persona': persona,
        'language': language,
        'daily_goal': dailyGoal,
        'onboarded': onboarded,
      };
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
    required this.coins,
    required this.energyBonus,
    this.duelBonus = 0,
  });

  /// XP added for winning a duel.
  final int duelBonus;

  /// Coins the server paid for this quiz.
  final int coins;

  /// Energy given back for a first 3-star clear.
  final int energyBonus;
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
      coins: (j['coins'] as Map<String, dynamic>)['total'] as int,
      energyBonus: j['energy_bonus'] as int,
      duelBonus: xp['duel_win_bonus'] as int? ?? 0,
    );
  }
}
