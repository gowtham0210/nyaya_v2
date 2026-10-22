import 'dart:math';

import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/l10n/l10n.dart';
import '../../../core/storage/local_store.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/day.dart';
import '../../../core/widgets/common.dart';
import '../../../core/widgets/ticking_builder.dart';
import '../../gamification/domain/league.dart';
import '../../profile/application/profile_controller.dart';
import '../../profile/domain/user_profile.dart';

class LeaderboardScreen extends ConsumerWidget {
  const LeaderboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: Text(l.leaderboardTitle),
          bottom: TabBar(
            labelStyle: context.text.labelLarge,
            tabs: [Tab(text: l.leaderboardWeekly), Tab(text: l.leaderboardAllTime)],
          ),
        ),
        body: const TabBarView(children: [_WeeklyLeague(), _AllTime()]),
      ),
    );
  }
}

class _WeeklyLeague extends ConsumerWidget {
  const _WeeklyLeague();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final p = ref.watch(profileProvider);
    final now = ref.watch(clockProvider)();
    final tier = Leagues.tier(p.leagueTier);
    final cohort = LeagueSimulator.cohort(
      weekId: p.weekId,
      tier: p.leagueTier,
      userXp: p.weeklyXp,
      userName: p.name,
      progress: LeagueSimulator.weekProgress(now),
    );
    final nextTier = p.leagueTier < Leagues.tiers.length ? Leagues.tier(p.leagueTier + 1) : null;
    final demoteFrom = Leagues.cohortSize - tier.demote;

    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(AppSpacing.page, AppSpacing.md, AppSpacing.page, 0),
            child: Column(
              children: [
                _TierStrip(current: p.leagueTier),
                const SizedBox(height: AppSpacing.md),
                Text(l.tierName(tier), style: context.text.headlineMedium),
                const SizedBox(height: 4),
                TickingBuilder(
                  builder: (context) => Text(
                    l.leaderboardEndsIn(formatCountdown(Day.untilWeekEnd(ref.read(clockProvider)()))),
                    style: context.text.bodyMedium?.copyWith(color: context.nyaya.textSecondary),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  nextTier != null && tier.promote > 0
                      ? l.leaderboardTopPromote(tier.promote, l.tierName(nextTier))
                      : '',
                  style: context.text.bodySmall?.copyWith(color: context.nyaya.success, fontWeight: FontWeight.w700),
                ),
                if (tier.demote == 0)
                  Text(l.leaderboardNoDemotion, style: context.text.bodySmall?.copyWith(color: context.nyaya.textSecondary)),
                if (p.weeklyXp == 0) ...[
                  const SizedBox(height: AppSpacing.md),
                  NyayaCard(
                    color: context.colors.primaryContainer.withValues(alpha: 0.5),
                    child: Row(
                      children: [
                        Icon(Icons.info_outline_rounded, color: context.colors.primary),
                        const SizedBox(width: 10),
                        Expanded(child: Text(l.leaderboardEarnToJoin, style: context.text.bodyMedium)),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: AppSpacing.md),
              ],
            ),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(AppSpacing.page, 0, AppSpacing.page, AppSpacing.xl),
          sliver: SliverList.builder(
            itemCount: cohort.length,
            itemBuilder: (context, i) {
              final rank = i + 1;
              final e = cohort[i];
              final row = _LeagueRow(rank: rank, entry: e);
              final children = <Widget>[];
              if (tier.promote > 0 && rank == tier.promote + 1) {
                children.add(_ZoneDivider(label: l.leaderboardPromotionZone, color: context.nyaya.success, up: true));
              }
              if (tier.demote > 0 && rank == demoteFrom + 1) {
                children.add(_ZoneDivider(label: l.leaderboardDemotionZone, color: context.nyaya.error, up: false));
              }
              children.add(row.animate().fadeIn(delay: (min(i, 12) * 25).ms));
              return Column(children: children);
            },
          ),
        ),
      ],
    );
  }
}

class _TierStrip extends StatelessWidget {
  const _TierStrip({required this.current});

  final int current;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 64,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          for (final t in Leagues.tiers)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                width: t.level == current ? 64 : 48,
                height: t.level == current ? 64 : 48,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: t.level <= current ? context.colors.secondaryContainer : context.colors.surfaceContainerLow,
                  border: Border.all(
                    color: t.level == current ? AppPalette.gold : context.nyaya.cardBorder,
                    width: t.level == current ? 3 : 1,
                  ),
                ),
                child: Opacity(
                  opacity: t.level <= current ? 1 : 0.35,
                  child: Text(t.emblem, style: TextStyle(fontSize: t.level == current ? 28 : 20)),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _ZoneDivider extends StatelessWidget {
  const _ZoneDivider({required this.label, required this.color, required this.up});

  final String label;
  final Color color;
  final bool up;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          Expanded(child: Divider(color: color, thickness: 1.5)),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Row(
              children: [
                Icon(up ? Icons.arrow_upward_rounded : Icons.arrow_downward_rounded, size: 16, color: color),
                const SizedBox(width: 4),
                Text(label, style: context.text.labelMedium?.copyWith(color: color, fontWeight: FontWeight.w800)),
              ],
            ),
          ),
          Expanded(child: Divider(color: color, thickness: 1.5)),
        ],
      ),
    );
  }
}

class _LeagueRow extends StatelessWidget {
  const _LeagueRow({required this.rank, required this.entry});

  final int rank;
  final LeagueEntry entry;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final medal = switch (rank) { 1 => '🥇', 2 => '🥈', 3 => '🥉', _ => null };
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: entry.isUser ? context.colors.primaryContainer.withValues(alpha: 0.7) : context.colors.surface,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: entry.isUser ? context.colors.primary : context.nyaya.cardBorder, width: entry.isUser ? 2 : 1),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 32,
            child: medal != null
                ? Text(medal, style: const TextStyle(fontSize: 22))
                : Text('$rank', style: context.text.titleSmall?.copyWith(color: context.nyaya.textSecondary)),
          ),
          InitialsAvatar(name: entry.name, seed: entry.isUser ? 0 : entry.avatarSeed, size: 38),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  entry.isUser ? '${entry.name} (${l.leaderboardYou})' : entry.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: context.text.titleSmall,
                ),
                if (entry.city.isNotEmpty)
                  Text(entry.city, style: context.text.bodySmall?.copyWith(color: context.nyaya.textSecondary)),
              ],
            ),
          ),
          Text(l.leaderboardXp(entry.xp), style: context.text.labelLarge),
        ],
      ),
    );
  }
}

/// All-time board (simulated around the user's total XP until a backend exists).
class _AllTime extends ConsumerWidget {
  const _AllTime();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = ref.watch(profileProvider);
    final entries = _allTime(p);
    final rank = entries.indexWhere((e) => e.isUser) + 1;
    return ListView(
      padding: const EdgeInsets.fromLTRB(AppSpacing.page, AppSpacing.md, AppSpacing.page, AppSpacing.xl),
      children: [
        if (entries.length >= 3) _Podium(top: entries.take(3).toList()),
        const SizedBox(height: AppSpacing.md),
        for (final (i, e) in entries.indexed.skip(3)) _LeagueRow(rank: i + 1, entry: e),
        if (rank > 3) const SizedBox.shrink(),
      ],
    );
  }

  static List<LeagueEntry> _allTime(UserProfile p) {
    final rng = Random(42);
    final list = <LeagueEntry>[
      for (var i = 0; i < 24; i++)
        LeagueEntry(
          name: '${['Adv.', '', '', ''][rng.nextInt(4)]} ${[
            'Meera Nair', 'Arjun Rao', 'Kavya Iyer', 'Rohan Sharma', 'Lakshmi Menon', 'Imran Khan',
            'Divya Reddy', 'Siddharth Joshi', 'Ananya Das', 'Harish Gowda', 'Fathima N', 'Vikram Singh',
          ][i % 12]}'.trim(),
          xp: (18000 * pow(0.86, i)).round() + rng.nextInt(120),
          avatarSeed: rng.nextInt(1 << 20),
          isUser: false,
          city: ['Kochi', 'Hyderabad', 'Chennai', 'Delhi', 'Bengaluru', 'Lucknow'][rng.nextInt(6)],
        ),
      LeagueEntry(name: p.name.isEmpty ? 'You' : p.name, xp: p.totalXp, avatarSeed: 0, isUser: true, city: ''),
    ]..sort((a, b) => b.xp.compareTo(a.xp));
    return list;
  }
}

class _Podium extends StatelessWidget {
  const _Podium({required this.top});

  final List<LeagueEntry> top;

  @override
  Widget build(BuildContext context) {
    Widget column(LeagueEntry e, int place, double height, Color color) => Expanded(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              InitialsAvatar(name: e.name, seed: e.isUser ? 0 : e.avatarSeed, size: place == 1 ? 64 : 52, ring: color),
              const SizedBox(height: 6),
              Text(e.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: context.text.labelLarge),
              Text(context.l10n.leaderboardXp(e.xp), style: context.text.labelSmall),
              const SizedBox(height: 6),
              Container(
                height: height,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.85),
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
                ),
                child: Text('$place', style: context.text.headlineMedium?.copyWith(color: Colors.white)),
              ).animate().scaleY(begin: 0, alignment: Alignment.bottomCenter, duration: 600.ms, curve: Curves.easeOutBack),
            ],
          ),
        );
    return SizedBox(
      height: 230,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          column(top[1], 2, 80, const Color(0xFF94A3B8)),
          const SizedBox(width: 8),
          column(top[0], 1, 110, AppPalette.gold),
          const SizedBox(width: 8),
          column(top[2], 3, 60, const Color(0xFFCD7F32)),
        ],
      ),
    );
  }
}
