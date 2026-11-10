import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:nyaya/core/theme/app_theme.dart';
import 'package:nyaya/features/leaderboard/data/league_api.dart';
import 'package:nyaya/features/quiz/presentation/league_climb.dart';
import 'package:nyaya/l10n/app_localizations.dart';

/// The Level up screen plays the learner's league climb on a small slice of
/// the league: their row starts at the old rank and ends at the new one, and
/// the learners they passed each drop one place.
void main() {
  LeagueView league({required int myRank, required int myXp}) => LeagueView(
        weekId: '2026-W45',
        endsAt: DateTime(2026, 11, 9),
        tier: 1,
        joined: true,
        promote: 15,
        demote: 0,
        cohortSize: 30,
        standings: [
          for (var rank = 1; rank <= 30; rank++)
            rank == myRank
                ? LeagueStanding(rank: rank, name: 'Demo L.', xp: myXp, me: true, practice: false)
                : LeagueStanding(rank: rank, name: 'Player $rank', xp: 400 - rank * 10, me: false, practice: true),
        ],
        lastResult: null,
      );

  Future<void> pump(WidgetTester tester, LeagueView? view, {int before = 28, int after = 20}) async {
    await tester.pumpWidget(ProviderScope(
      overrides: [leagueProvider.overrideWith((ref) async => view)],
      child: MaterialApp(
        theme: AppTheme.light(),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(body: LeagueClimb(rankBefore: before, rankAfter: after, xpEarned: 138)),
      ),
    ));
  }

  testWidgets('the learner moves from the old rank to the new one past the learners they overtook', (tester) async {
    await pump(tester, league(myRank: 20, myXp: 249));
    await tester.pump(); // league loaded

    // Start: the learner is at #28 with their XP before this quiz; the others are one place higher.
    expect(find.text('Demo L. (You)'), findsOneWidget);
    expect(find.text('#28'), findsOneWidget);
    expect(find.text('111 XP'), findsOneWidget);
    expect(find.text('#19'), findsOneWidget, reason: 'the learner just above the new rank stays put');
    expect(find.text('#20'), findsOneWidget, reason: 'Player 21 was #20 before being passed');
    expect(find.text('#24'), findsNothing);

    await tester.pump(const Duration(seconds: 2)); // the climb waits for the badge and stars
    await tester.pumpAndSettle();

    // End: the learner is at #20 with their new XP, and the passed learners dropped one place.
    final me = tester.getTopLeft(find.text('Demo L. (You)')).dy;
    expect(find.text('#28'), findsNothing);
    expect(find.text('249 XP'), findsOneWidget);
    for (final rank in [19, 20, 21, 22, 23, 24]) {
      expect(find.text('#$rank'), findsOneWidget);
    }
    expect(me, lessThan(tester.getTopLeft(find.text('Player 21')).dy));
    expect(me, greaterThan(tester.getTopLeft(find.text('Player 19')).dy));
    expect(tester.takeException(), isNull);
  });

  testWidgets('falls back to a plain badge when the league cannot load', (tester) async {
    await pump(tester, null);
    await tester.pumpAndSettle();
    expect(find.text('League rank #28 → #20'), findsOneWidget);
    expect(find.text('Demo L. (You)'), findsNothing);
  });
}
