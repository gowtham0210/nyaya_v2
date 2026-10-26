import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../app/router.dart';
import '../../../../core/l10n/l10n.dart';
import '../../../../core/storage/local_store.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/day.dart';
import '../../../../core/widgets/chunky_button.dart';
import '../../../../core/widgets/common.dart';
import '../../../../core/widgets/pressable.dart';
import '../../../../core/widgets/ticking_builder.dart';
import '../../../gamification/domain/league.dart';
import '../../../journey/application/journey_controller.dart';
import '../../../journey/domain/journey.dart';
import '../../../legal_updates/data/legal_updates_repository.dart';
import '../../../legal_updates/presentation/updates_screen.dart';
import '../../../profile/application/profile_controller.dart';
import '../../../profile/domain/user_profile.dart';
import '../../../quiz/data/question_repository.dart';
import '../../../quiz/domain/quiz_models.dart';
import '../../../quiz/presentation/quiz_launcher.dart';

/// Hero card: the single most important action — continue the Case Path.
class ContinueJourneyCard extends ConsumerWidget {
  const ContinueJourneyCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final journey = ref.watch(journeyProvider);
    final bank = ref.watch(questionBankProvider).value;
    final node = journey.current;
    final chapter = node?.chapter ?? JourneyCatalog.chapters.last;
    final chapterTitle = bank?.chapters[chapter.id]?.title ?? '';
    final done = journey.completedLevelsIn(chapter.id);

    final String subtitle;
    final VoidCallback onPlay;
    if (node == null) {
      subtitle = l.homeAllDone;
      onPlay = () => context.go(Routes.journey);
    } else if (node.kind == NodeKind.chest) {
      subtitle = l.homeChestReady;
      onPlay = () => context.go(Routes.journey);
    } else {
      subtitle = l.homeChapterLevel(node.chapterIndex + 1, node.level);
      onPlay = () => QuizLauncher.start(context, ref, QuizRequest(QuizMode.casePath, levelId: node.id));
    }

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppRadius.lg),
        color: context.nyaya.hero,
        boxShadow: [
          BoxShadow(color: AppPalette.terracotta.withValues(alpha: 0.25), blurRadius: 24, offset: const Offset(0, 12)),
        ],
      ),
      child: Stack(
        children: [
          Positioned(
            right: -18,
            top: -10,
            child: Icon(chapter.icon, size: 140, color: Colors.white.withValues(alpha: 0.08)),
          ),
          Padding(
            padding: const EdgeInsets.all(AppSpacing.lg - 4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l.homeContinueJourney.toUpperCase(),
                  style: context.text.labelMedium?.copyWith(
                    color: AppPalette.ochreSoft,
                    letterSpacing: 1.2,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  chapterTitle,
                  style: context.text.headlineSmall?.copyWith(color: Colors.white),
                ),
                const SizedBox(height: 4),
                Text(subtitle, style: context.text.bodyMedium?.copyWith(color: Colors.white70)),
                const SizedBox(height: AppSpacing.md),
                Row(
                  children: [
                    Expanded(
                      child: GlossyProgressBar(
                        value: done / chapter.levels,
                        color: AppPalette.ochre,
                        track: Colors.white.withValues(alpha: 0.18),
                        height: 10,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      '$done/${chapter.levels}',
                      style: context.text.labelLarge?.copyWith(color: Colors.white),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.md),
                ChunkyButton(
                  label: l.homePlay,
                  icon: Icons.play_arrow_rounded,
                  color: AppPalette.ochre,
                  foreground: AppPalette.deepEarth,
                  onPressed: onPlay,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Daily goal ring + streak + this week's activity strip.
class DailyGoalStreakCard extends ConsumerWidget {
  const DailyGoalStreakCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final p = ref.watch(profileProvider);
    final now = ref.watch(clockProvider)();
    final today = Day.key(now);
    final doneToday = p.quizzesTodayDay == today ? p.quizzesToday : 0;
    final goalMet = doneToday >= p.dailyGoal;
    final activeToday = p.lastActiveDay == today;
    final monday = Day.weekStart(now);
    final dayLetters = DateFormat.E(Localizations.localeOf(context).languageCode);

    return NyayaCard(
      child: Column(
        children: [
          Row(
            children: [
              ProgressRing(
                value: doneToday / p.dailyGoal,
                size: 68,
                child: Text(
                  '$doneToday/${p.dailyGoal}',
                  style: context.text.titleSmall,
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(l.homeDailyGoal, style: context.text.titleMedium),
                    const SizedBox(height: 2),
                    Text(
                      goalMet ? l.homeGoalDone : l.homeGoalProgress(doneToday, p.dailyGoal),
                      style: context.text.bodyMedium?.copyWith(color: context.nyaya.textSecondary),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Icon(Icons.local_fire_department_rounded, color: context.nyaya.streak, size: 20),
                        const SizedBox(width: 4),
                        Flexible(
                          child: Text(
                            activeToday ? l.homeStreakSafe : l.homeStreakAtRisk,
                            style: context.text.labelMedium?.copyWith(
                              color: activeToday ? context.nyaya.success : context.nyaya.streak,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              for (var i = 0; i < 7; i++)
                () {
                  final d = monday.add(Duration(days: i));
                  final key = Day.key(d);
                  final active = p.activeDays.contains(key);
                  final frozen = p.frozenDays.contains(key);
                  final isToday = key == today;
                  return Column(
                    children: [
                      Text(
                        dayLetters.format(d).characters.take(2).toString(),
                        style: context.text.labelSmall?.copyWith(
                          color: isToday ? context.colors.primary : context.nyaya.textSecondary,
                          fontWeight: isToday ? FontWeight.w800 : FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Container(
                        width: 34,
                        height: 34,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: active
                              ? context.nyaya.streak
                              : frozen
                                  ? AppPalette.frost
                                  : context.colors.surfaceContainerLow,
                          border: isToday && !active
                              ? Border.all(color: context.nyaya.streak, width: 2)
                              : null,
                        ),
                        child: Icon(
                          frozen ? Icons.ac_unit_rounded : Icons.local_fire_department_rounded,
                          size: 18,
                          color: active || frozen ? Colors.white : context.nyaya.locked,
                        ),
                      ),
                    ],
                  );
                }(),
            ],
          ),
        ],
      ),
    );
  }
}

class DailyDocketCard extends ConsumerWidget {
  const DailyDocketCard({super.key, required this.now});

  final DateTime now;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    ref.watch(profileProvider.select((p) => p.lastDocketDay));
    final done = ref.read(profileProvider.notifier).docketDoneToday;

    return NyayaCard(
      onTap: done ? null : () => QuizLauncher.start(context, ref, const QuizRequest(QuizMode.dailyDocket)),
      child: Row(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppRadius.md),
              color: AppPalette.burntClay,
            ),
            child: Icon(done ? Icons.check_rounded : Icons.today_rounded, color: Colors.white, size: 30),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(child: Text(l.modeDailyDocket, style: context.text.titleMedium)),
                    const SizedBox(width: 8),
                    _Badge(text: l.modeFree, color: context.nyaya.success),
                  ],
                ),
                const SizedBox(height: 2),
                if (done)
                  TickingBuilder(
                    builder: (context) => Text(
                      '${l.docketDoneToday} · ${l.docketNextIn(formatCountdown(Day.untilMidnight(ref.read(clockProvider)())))}',
                      style: context.text.bodyMedium?.copyWith(color: context.nyaya.textSecondary),
                    ),
                  )
                else
                  Text(
                    l.modeDailyDocketDesc,
                    style: context.text.bodyMedium?.copyWith(color: context.nyaya.textSecondary),
                  ),
              ],
            ),
          ),
          if (!done) Icon(Icons.chevron_right_rounded, color: context.nyaya.textSecondary),
        ],
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge({required this.text, required this.color});

  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(AppRadius.xl),
      ),
      child: Text(text, style: context.text.labelSmall?.copyWith(color: color, fontWeight: FontWeight.w800)),
    );
  }
}

/// The four quiz modes as a 2×2 grid.
class QuizModesGrid extends ConsumerWidget {
  const QuizModesGrid({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final persona = ref.watch(profileProvider.select((p) => p.persona));
    final modes = [
      (
        QuizMode.casePath,
        l.modeCasePath,
        l.modeCasePathDesc,
        Icons.route_rounded,
        AppPalette.terracotta,
      ),
      (
        QuizMode.dailyDocket,
        l.modeDailyDocket,
        l.modeDailyDocketDesc,
        Icons.today_rounded,
        AppPalette.burntClay,
      ),
      (
        QuizMode.duel,
        l.modeDuel,
        l.modeDuelDesc,
        Icons.sports_kabaddi_rounded,
        AppPalette.moss,
      ),
      (
        QuizMode.exam,
        l.modeExam,
        persona == Persona.citizen ? l.modeExamDescCitizen : l.modeExamDesc,
        Icons.assignment_rounded,
        AppPalette.umber,
      ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeader(title: l.homeModesTitle),
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          childAspectRatio: 0.95,
          children: [
            for (final (mode, name, desc, icon, color) in modes)
              NyayaCard(
                padding: const EdgeInsets.all(14),
                onTap: () => mode == QuizMode.casePath
                    ? context.go(Routes.journey)
                    : QuizLauncher.start(context, ref, QuizRequest(mode)),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: color.withValues(alpha: 0.14),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Icon(icon, color: color, size: 26),
                        ),
                        const Spacer(),
                        _Badge(
                          text: mode.energyCost == 0 ? l.modeFree : l.modeEnergyCost(mode.energyCost),
                          color: mode.energyCost == 0 ? context.nyaya.success : AppPalette.ochreText,
                        ),
                      ],
                    ),
                    const Spacer(),
                    Text(name, style: context.text.titleSmall, maxLines: 2, overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 2),
                    Text(
                      desc,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: context.text.bodySmall?.copyWith(color: context.nyaya.textSecondary),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ],
    );
  }
}

class LeagueCard extends ConsumerWidget {
  const LeagueCard({super.key, required this.now});

  final DateTime now;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final p = ref.watch(profileProvider);
    final tier = Leagues.tier(p.leagueTier);
    final cohort = LeagueSimulator.cohort(
      weekId: p.weekId,
      tier: p.leagueTier,
      userXp: p.weeklyXp,
      userName: p.name,
      progress: LeagueSimulator.weekProgress(now),
    );
    final rank = LeagueSimulator.userRank(cohort);

    return NyayaCard(
      onTap: () => context.push(Routes.leaderboard),
      child: Row(
        children: [
          Container(
            width: 56,
            height: 56,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: context.colors.secondaryContainer,
              border: Border.all(color: AppPalette.ochre, width: 2),
            ),
            child: Text(tier.emblem, style: const TextStyle(fontSize: 26)),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(l.homeLeagueTitle, style: context.text.labelMedium?.copyWith(color: context.nyaya.textSecondary)),
                const SizedBox(height: 2),
                Text(
                  p.weeklyXp == 0 ? l.tierName(tier) : l.homeLeagueRank(rank, l.tierName(tier)),
                  style: context.text.titleMedium,
                ),
                const SizedBox(height: 2),
                Text(
                  p.weeklyXp == 0
                      ? l.leaderboardEarnToJoin
                      : l.homeLeagueEnds(formatCountdown(Day.untilWeekEnd(now))),
                  style: context.text.bodySmall?.copyWith(color: context.nyaya.textSecondary),
                ),
              ],
            ),
          ),
          Icon(Icons.chevron_right_rounded, color: context.nyaya.textSecondary),
        ],
      ),
    );
  }
}

class PremiumBanner extends StatelessWidget {
  const PremiumBanner({super.key});

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return Pressable(
      onTap: () => context.push(Routes.premium),
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppRadius.lg),
          color: AppPalette.sand,
        ),
        child: Row(
          children: [
            const Icon(Icons.workspace_premium_rounded, size: 36, color: AppPalette.deepEarth),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(l.homeGoPremium, style: context.text.titleMedium?.copyWith(color: AppPalette.deepEarth)),
                  Text(l.homeGoPremiumSub, style: context.text.bodySmall?.copyWith(color: AppPalette.deepEarth)),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_rounded, color: AppPalette.deepEarth),
          ],
        ),
      ),
    );
  }
}

/// Picks a question per day from the (localized) bank and presents its
/// answer as a bite-sized fact — free learning even with zero energy.
class FactOfTheDayCard extends ConsumerWidget {
  const FactOfTheDayCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final bank = ref.watch(questionBankProvider).value;
    if (bank == null || bank.questions.isEmpty) return const SizedBox.shrink();
    final now = ref.watch(clockProvider)();
    final dayIndex = DateTime.utc(now.year, now.month, now.day).millisecondsSinceEpoch ~/ 86400000;
    final q = bank.questions[(dayIndex * 7) % bank.questions.length];

    return NyayaCard(
      onTap: () => context.go('${Routes.chat}?q=${Uri.encodeQueryComponent(q.text)}'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.lightbulb_rounded, color: AppPalette.ochre),
              const SizedBox(width: 8),
              Text(l.homeFactTitle, style: context.text.titleSmall),
            ],
          ),
          const SizedBox(height: 10),
          Text(q.options[q.answerIndex], style: context.text.titleMedium),
          const SizedBox(height: 6),
          Text(
            q.explanation,
            style: context.text.bodyMedium?.copyWith(color: context.nyaya.textSecondary, height: 1.45),
          ),
          if (q.reference.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(q.reference, style: context.text.labelSmall?.copyWith(color: context.colors.primary)),
          ],
        ],
      ),
    );
  }
}

class LatestUpdatesSection extends ConsumerWidget {
  const LatestUpdatesSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final updates = ref.watch(legalUpdatesProvider).value ?? const [];
    if (updates.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeader(
          title: l.homeUpdatesTitle,
          action: l.commonSeeAll,
          onAction: () => context.go(Routes.updates),
        ),
        for (final u in updates.take(2))
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: UpdateTile(update: u),
          ),
      ],
    );
  }
}
