import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';
import '../../progress/application/progress_sync.dart';

/// One row of a weekly league group.
@immutable
class LeagueStanding {
  const LeagueStanding({
    required this.rank,
    required this.name,
    required this.xp,
    required this.me,
    required this.practice,
  });

  final int rank;

  /// First name and last initial ("Asha K.").
  final String name;
  final int xp;
  final bool me;

  /// A simulated player topping up a small group.
  final bool practice;

  factory LeagueStanding.fromJson(Map<String, dynamic> j) => LeagueStanding(
        rank: j['rank'] as int,
        name: j['name'] as String,
        xp: j['xp'] as int,
        me: j['me'] as bool,
        practice: j['practice'] as bool,
      );
}

/// How a learner's latest finished week ended.
@immutable
class LeagueResult {
  const LeagueResult({
    required this.weekId,
    required this.rank,
    required this.fromTier,
    required this.toTier,
    required this.bonusCoins,
  });

  final String weekId;
  final int rank;
  final int fromTier;
  final int toTier;
  final int bonusCoins;

  factory LeagueResult.fromJson(Map<String, dynamic> j) => LeagueResult(
        weekId: j['week_id'] as String,
        rank: j['rank'] as int,
        fromTier: j['from_tier'] as int,
        toTier: j['to_tier'] as int,
        bonusCoins: j['bonus_coins'] as int,
      );
}

/// This week's league as the server sees it (`GET /v1/me/league`).
@immutable
class LeagueView {
  const LeagueView({
    required this.weekId,
    required this.endsAt,
    required this.tier,
    required this.joined,
    required this.promote,
    required this.demote,
    required this.cohortSize,
    required this.standings,
    required this.lastResult,
  });

  final String weekId;
  final DateTime endsAt;
  final int tier;

  /// Joined with a finished quiz this week; until then [standings] is empty.
  final bool joined;
  final int promote;
  final int demote;
  final int cohortSize;
  final List<LeagueStanding> standings;
  final LeagueResult? lastResult;

  int? get myRank {
    for (final s in standings) {
      if (s.me) return s.rank;
    }
    return null;
  }

  factory LeagueView.fromJson(Map<String, dynamic> j) => LeagueView(
        weekId: j['week_id'] as String,
        endsAt: DateTime.parse(j['ends_at'] as String),
        tier: j['tier'] as int,
        joined: j['joined'] as bool,
        promote: j['promote'] as int,
        demote: j['demote'] as int,
        cohortSize: j['cohort_size'] as int,
        standings: [
          for (final s in (j['standings'] as List).cast<Map<String, dynamic>>()) LeagueStanding.fromJson(s),
        ],
        lastResult:
            j['last_result'] == null ? null : LeagueResult.fromJson(j['last_result'] as Map<String, dynamic>),
      );
}

/// One row of the all-time board.
@immutable
class AllTimeRow {
  const AllTimeRow({required this.rank, required this.name, required this.xp, required this.me});

  final int rank;

  /// First name and last initial ("Asha K.").
  final String name;

  /// XP from every finished quiz.
  final int xp;
  final bool me;

  factory AllTimeRow.fromJson(Map<String, dynamic> j) => AllTimeRow(
        rank: j['rank'] as int,
        name: j['name'] as String,
        xp: j['xp'] as int,
        me: j['me'] as bool,
      );
}

/// Every learner with XP, by total XP (`GET /v1/me/leaderboard/all-time`).
@immutable
class AllTimeBoard {
  const AllTimeBoard({required this.total, required this.top, required this.me});

  /// Learners on the board.
  final int total;

  /// The top 50.
  final List<AllTimeRow> top;

  /// The learner, also when outside [top]; null until they earn XP.
  final AllTimeRow? me;

  factory AllTimeBoard.fromJson(Map<String, dynamic> j) => AllTimeBoard(
        total: j['total'] as int,
        top: [for (final r in (j['top'] as List).cast<Map<String, dynamic>>()) AllTimeRow.fromJson(r)],
        me: j['me'] == null ? null : AllTimeRow.fromJson(j['me'] as Map<String, dynamic>),
      );
}

final leagueApiProvider = Provider<LeagueApi>((ref) => HttpLeagueApi(ref.watch(apiClientProvider)));

/// Weekly leagues on the Nyaya API (real learners, topped up with practice
/// players) and the all-time board (real learners only).
abstract interface class LeagueApi {
  Future<LeagueView> league();
  Future<AllTimeBoard> allTime();
}

class HttpLeagueApi implements LeagueApi {
  HttpLeagueApi(this._client);

  final ApiClient _client;

  @override
  Future<LeagueView> league() async => LeagueView.fromJson(await _client.get('/v1/me/league') as Map<String, dynamic>);

  @override
  Future<AllTimeBoard> allTime() async =>
      AllTimeBoard.fromJson(await _client.get('/v1/me/leaderboard/all-time') as Map<String, dynamic>);
}

/// The league screen's data: loads (and copies the tier into the profile)
/// each time it is opened. Null when signed out or offline.
final leagueProvider = FutureProvider.autoDispose<LeagueView?>(
  (ref) => ref.read(progressSyncProvider.notifier).league(),
);

/// The all-time tab's data, loaded each time it is opened. Null when signed
/// out or offline.
final allTimeProvider = FutureProvider.autoDispose<AllTimeBoard?>(
  (ref) => ref.read(progressSyncProvider.notifier).allTime(),
);
