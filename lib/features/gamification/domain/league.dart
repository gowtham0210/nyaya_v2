import 'dart:math';

import 'package:flutter/foundation.dart';

import '../../../core/utils/day.dart';

/// Weekly league tiers, themed on the Indian court hierarchy.
/// Cohorts of 30, Monday 00:00 → Sunday 23:59 local time, max one tier move
/// per week. No demotion in the two entry tiers (anti-discouragement).
@immutable
class LeagueTier {
  const LeagueTier({
    required this.level,
    required this.key,
    required this.promote,
    required this.demote,
    required this.emblem,
  });

  final int level;

  /// Localization key suffix, e.g. `tier_nyayaPanchayat`.
  final String key;
  final int promote;
  final int demote;
  final String emblem;
}

abstract final class Leagues {
  static const cohortSize = 30;

  static const tiers = <LeagueTier>[
    LeagueTier(level: 1, key: 'nyayaPanchayat', promote: 15, demote: 0, emblem: '🌿'),
    LeagueTier(level: 2, key: 'gramNyayalaya', promote: 12, demote: 0, emblem: '🏡'),
    LeagueTier(level: 3, key: 'munsiffCourt', promote: 10, demote: 5, emblem: '📜'),
    LeagueTier(level: 4, key: 'magistrateCourt', promote: 10, demote: 5, emblem: '🔨'),
    LeagueTier(level: 5, key: 'districtCourt', promote: 7, demote: 5, emblem: '🏛️'),
    LeagueTier(level: 6, key: 'sessionsCourt', promote: 7, demote: 5, emblem: '⚖️'),
    LeagueTier(level: 7, key: 'highCourt', promote: 5, demote: 5, emblem: '🦁'),
    LeagueTier(level: 8, key: 'supremeCourt', promote: 0, demote: 5, emblem: '👑'),
  ];

  static LeagueTier tier(int level) => tiers[(level - 1).clamp(0, tiers.length - 1)];

  /// Tier after the week closes at [rank] (1-based).
  static int nextTier(int currentTier, int rank) {
    final t = tier(currentTier);
    if (t.promote > 0 && rank <= t.promote) return min(currentTier + 1, tiers.length);
    if (t.demote > 0 && rank > cohortSize - t.demote) return max(currentTier - 1, 1);
    return currentTier;
  }
}

@immutable
class LeagueEntry {
  const LeagueEntry({
    required this.name,
    required this.xp,
    required this.avatarSeed,
    required this.isUser,
    required this.city,
  });

  final String name;
  final int xp;
  final int avatarSeed;
  final bool isUser;
  final String city;
}

/// Deterministic simulated cohort. Production swaps this for a backend
/// (`LeagueRepository`) — the UI only depends on [LeagueEntry] lists.
abstract final class LeagueSimulator {
  static const _first = [
    'Aarav', 'Ananya', 'Vihaan', 'Diya', 'Arjun', 'Meera', 'Karthik', 'Lakshmi',
    'Rohan', 'Priya', 'Sai', 'Kavya', 'Aditya', 'Nandini', 'Harish', 'Fathima',
    'Vikram', 'Sneha', 'Rahul', 'Divya', 'Manoj', 'Aishwarya', 'Gurpreet', 'Anjali',
    'Siddharth', 'Revathi', 'Imran', 'Pooja', 'Naveen', 'Swathi', 'Joseph', 'Tanvi',
    'Deepak', 'Keerthana', 'Arun', 'Shruti', 'Varun', 'Bhavana', 'Suresh', 'Nikhil',
  ];
  static const _last = [
    'S', 'K', 'R', 'Iyer', 'Nair', 'Reddy', 'Rao', 'Sharma', 'Verma', 'Gowda',
    'Menon', 'Pillai', 'Singh', 'Das', 'Patel', 'Khan', 'Joshi', 'Kumar',
  ];
  static const _cities = [
    'Chennai', 'Bengaluru', 'Hyderabad', 'Kochi', 'Delhi', 'Mumbai', 'Lucknow',
    'Madurai', 'Mysuru', 'Vijayawada', 'Thiruvananthapuram', 'Jaipur', 'Patna',
    'Coimbatore', 'Pune', 'Bhopal', 'Visakhapatnam', 'Mangaluru',
  ];

  /// Fraction of the week elapsed, 0..1.
  static double weekProgress(DateTime now) {
    final start = Day.weekStart(now);
    final p = now.difference(start).inMinutes / (7 * 24 * 60);
    return p.clamp(0.0, 1.0);
  }

  static List<LeagueEntry> cohort({
    required String weekId,
    required int tier,
    required int userXp,
    required String userName,
    required double progress,
  }) {
    final rng = Random(Object.hash(weekId, tier));
    // Higher tiers are faster-paced.
    final base = 140 + tier * 70;
    final entries = <LeagueEntry>[];
    final usedNames = <String>{};
    for (var i = 0; i < Leagues.cohortSize - 1; i++) {
      String name;
      do {
        name = '${_first[rng.nextInt(_first.length)]} ${_last[rng.nextInt(_last.length)]}';
      } while (!usedNames.add(name));
      final pace = base * (0.15 + rng.nextDouble() * 2.1);
      // Players progress unevenly through the week.
      final curve = pow(progress, 0.6 + rng.nextDouble() * 0.9).toDouble();
      final xp = (pace * curve).round();
      entries.add(LeagueEntry(
        name: name,
        xp: xp,
        avatarSeed: rng.nextInt(1 << 20),
        isUser: false,
        city: _cities[rng.nextInt(_cities.length)],
      ));
    }
    entries.add(LeagueEntry(
      name: userName.isEmpty ? 'You' : userName,
      xp: userXp,
      avatarSeed: 0,
      isUser: true,
      city: '',
    ));
    // Ties go to the user — a small kindness that keeps motivation up.
    entries.sort((a, b) {
      final c = b.xp.compareTo(a.xp);
      if (c != 0) return c;
      return a.isUser ? -1 : (b.isUser ? 1 : 0);
    });
    return entries;
  }

  static int userRank(List<LeagueEntry> entries) =>
      entries.indexWhere((e) => e.isUser) + 1;
}

/// Hidden duel skill rating — kept separate from XP (effort).
abstract final class Elo {
  static double expected(int a, int b) => 1 / (1 + pow(10, (b - a) / 400));

  static int update({required int rating, required int opponent, required double score, required int k}) =>
      (rating + k * (score - expected(rating, opponent))).round();
}
