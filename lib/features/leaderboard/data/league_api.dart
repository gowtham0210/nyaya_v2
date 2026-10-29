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

final leagueApiProvider = Provider<LeagueApi>((ref) => HttpLeagueApi(ref.watch(apiClientProvider)));

/// Weekly leagues on the Nyaya API: real learners, topped up with practice players.
abstract interface class LeagueApi {
  Future<LeagueView> league();
}

class HttpLeagueApi implements LeagueApi {
  HttpLeagueApi(this._client);

  final ApiClient _client;

  @override
  Future<LeagueView> league() async => LeagueView.fromJson(await _client.get('/v1/me/league') as Map<String, dynamic>);
}

/// The league screen's data: loads (and copies the tier into the profile)
/// each time it is opened. Null when signed out or offline.
final leagueProvider = FutureProvider.autoDispose<LeagueView?>(
  (ref) => ref.read(progressSyncProvider.notifier).league(),
);
