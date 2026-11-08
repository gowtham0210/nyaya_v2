import 'dart:math' as math;
import 'dart:ui' show lerpDouble;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/l10n/l10n.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/common.dart';
import '../../gamification/presentation/league_emblem.dart';
import '../../leaderboard/data/league_api.dart';

/// A small piece of the weekly league that plays the learner's climb: their
/// row starts at [rankBefore], slides up past the learners they overtook
/// (who each drop one place) and settles at [rankAfter], while the rank and
/// XP count up. Shows a plain badge while the league loads or when it can't.
class LeagueClimb extends ConsumerWidget {
  const LeagueClimb({super.key, required this.rankBefore, required this.rankAfter, required this.xpEarned});

  final int rankBefore;
  final int rankAfter;
  final int xpEarned;

  /// Learners overtaken that are shown; a bigger climb starts lower down.
  static const maxPassed = 4;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final league = ref.watch(leagueProvider).value;
    final standings = league?.standings ?? const <LeagueStanding>[];
    final me = standings.where((s) => s.me).firstOrNull;
    final badge = _Badge(text: context.l10n.levelUpRank(rankBefore, rankAfter));
    if (me == null) return badge;

    // The server's league is the truth after this quiz; the rewards give where it started.
    final after = me.rank;
    final before = math.max(rankBefore, after + 1);
    final above = standings.where((s) => s.rank == after - 1).firstOrNull;
    final passed = [
      for (final s in standings)
        if (s.rank > after && s.rank <= math.min(before, after + maxPassed)) s,
    ];
    if (passed.isEmpty) return badge;
    return _ClimbBoard(
      above: above,
      me: me,
      passed: passed,
      rankBefore: before,
      xpBefore: math.max(0, me.xp - xpEarned),
      label: context.l10n.levelUpRank(before, after),
    );
  }
}

class _ClimbBoard extends StatefulWidget {
  const _ClimbBoard({
    required this.above,
    required this.me,
    required this.passed,
    required this.rankBefore,
    required this.xpBefore,
    required this.label,
  });

  final LeagueStanding? above;
  final LeagueStanding me;
  final List<LeagueStanding> passed;
  final int rankBefore;
  final int xpBefore;
  final String label;

  @override
  State<_ClimbBoard> createState() => _ClimbBoardState();
}

class _ClimbBoardState extends State<_ClimbBoard> with SingleTickerProviderStateMixin {
  late final _climb = AnimationController(vsync: this, duration: const Duration(milliseconds: 1400));
  late final _move = CurvedAnimation(parent: _climb, curve: Curves.easeInOutCubic);
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    if (MediaQuery.disableAnimationsOf(context)) {
      _climb.value = 1;
    } else {
      // Let the badge and stars play first.
      Future<void>.delayed(const Duration(milliseconds: 1100), () {
        if (mounted) _climb.forward();
      });
    }
  }

  @override
  void dispose() {
    _climb.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final rowHeight = MediaQuery.textScalerOf(context).scale(44) + 12;
    final top = widget.above == null ? 0 : 1;
    // Slots, top to bottom: [above], then the climb area of passed.length + 1 rows.
    final slots = top + widget.passed.length + 1;

    return Semantics(
      label: widget.label,
      liveRegion: true,
      child: ExcludeSemantics(
        child: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: context.nyaya.cardBorder.withValues(alpha: 0.18),
            borderRadius: BorderRadius.circular(AppRadius.lg),
          ),
          child: AnimatedBuilder(
            animation: _move,
            builder: (context, _) {
              final t = _move.value;
              return SizedBox(
                height: slots * rowHeight,
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    if (widget.above case final above?)
                      _at(0, rowHeight, _Row(rank: above.rank, name: above.name, xp: above.xp)),
                    // Overtaken learners each slip one place down.
                    for (final (i, s) in widget.passed.indexed)
                      _at(
                        lerpDouble(top + i, top + i + 1, t)!,
                        rowHeight,
                        _Row(rank: s.rank - 1 + t.round(), name: s.name, xp: s.xp),
                      ),
                    // The learner rises from the bottom slot to the top of the climb area, lifted while moving.
                    _at(
                      lerpDouble(slots - 1, top, t)!,
                      rowHeight,
                      Transform.scale(
                        scale: 1 + 0.04 * math.sin(t * math.pi),
                        child: _Row(
                          rank: (lerpDouble(widget.rankBefore, widget.me.rank, t)!).round(),
                          name: widget.me.name,
                          label: '${widget.me.name} (${context.l10n.leaderboardYou})',
                          xp: (lerpDouble(widget.xpBefore, widget.me.xp, _climb.value)!).round(),
                          me: true,
                          lift: math.sin(t * math.pi),
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _at(double slot, double rowHeight, Widget child) =>
      Positioned(left: 0, right: 0, top: slot * rowHeight, height: rowHeight - 6, child: child);
}

class _Row extends StatelessWidget {
  const _Row({required this.rank, required this.name, required this.xp, this.label, this.me = false, this.lift = 0});

  final int rank;
  final String name;

  /// Shown instead of [name] ("Asha K. (You)"); the avatar still uses [name].
  final String? label;
  final int xp;
  final bool me;

  /// 0..1: how high the row floats (a shadow while it moves).
  final double lift;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: me ? context.colors.primaryContainer : context.colors.surface,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: me ? context.colors.primary : context.nyaya.cardBorder, width: me ? 2 : 1),
        boxShadow: [
          if (lift > 0)
            BoxShadow(
              color: context.colors.primary.withValues(alpha: 0.35 * lift),
              blurRadius: 18 * lift,
              offset: Offset(0, 6 * lift),
            ),
        ],
      ),
      child: Row(
        children: [
          SizedBox(
            width: 40,
            child: rank <= 3
                ? Align(alignment: Alignment.centerLeft, child: RankMedal(rank))
                : Text(
                    '#$rank',
                    maxLines: 1,
                    style: context.text.titleSmall?.copyWith(
                      color: me ? context.colors.primary : context.nyaya.textSecondary,
                      fontWeight: me ? FontWeight.w800 : null,
                    ),
                  ),
          ),
          InitialsAvatar(name: name, seed: me ? 0 : name.hashCode, size: 28),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              label ?? name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: context.text.titleSmall?.copyWith(fontWeight: me ? FontWeight.w700 : null),
            ),
          ),
          Text(l.leaderboardXp(xp), style: context.text.labelLarge),
        ],
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final color = context.nyaya.success;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppRadius.xl),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.trending_up_rounded, size: 18, color: color),
          const SizedBox(width: 6),
          Flexible(
            child: Text(text, style: context.text.titleSmall?.copyWith(color: color, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }
}
