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
import '../../../gamification/presentation/league_emblem.dart';
import '../../../journey/application/journey_controller.dart';
import '../../../journey/domain/journey.dart';
import '../../../profile/application/profile_controller.dart';
import '../../../profile/domain/user_profile.dart';
import '../../../quiz/domain/quiz_models.dart';
import '../../../quiz/presentation/quiz_launcher.dart';

/// Hero card: the single most important action — continue the Case Path.
class ContinueJourneyCard extends ConsumerWidget {
  const ContinueJourneyCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final journey = ref.watch(journeyProvider);
    final node = journey.current;
    final chapter = node?.chapter ?? JourneyCatalog.chapters.last;
    final chapterTitle = l.chapterTitle(chapter.id);
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
      onPlay = () => QuizLauncher.start(
        context,
        ref,
        QuizRequest(QuizMode.casePath, levelId: node.id),
      );
    }

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppRadius.lg),
        color: context.nyaya.hero,
        boxShadow: [
          BoxShadow(
            color: AppPalette.terracotta.withValues(alpha: 0.25),
            blurRadius: 24,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned(
            right: -18,
            top: -10,
            child: Icon(
              chapter.icon,
              size: 140,
              color: Colors.white.withValues(alpha: 0.08),
            ),
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
                    letterSpacing: context.tracking(1.2),
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  chapterTitle,
                  style: context.text.headlineSmall?.copyWith(
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: context.text.bodyMedium?.copyWith(
                    color: Colors.white70,
                  ),
                ),
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
                      style: context.text.labelLarge?.copyWith(
                        color: Colors.white,
                      ),
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
    final dayLetters = DateFormat.E(
      Localizations.localeOf(context).languageCode,
    );

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
                      goalMet
                          ? l.homeGoalDone
                          : l.homeGoalProgress(doneToday, p.dailyGoal),
                      style: context.text.bodyMedium?.copyWith(
                        color: context.nyaya.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Icon(
                          Icons.local_fire_department_rounded,
                          color: context.nyaya.streak,
                          size: 20,
                        ),
                        const SizedBox(width: 4),
                        Flexible(
                          child: Text(
                            activeToday ? l.homeStreakSafe : l.homeStreakAtRisk,
                            style: context.text.labelMedium?.copyWith(
                              color: activeToday
                                  ? context.nyaya.success
                                  : context.nyaya.streak,
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
                          color: isToday
                              ? context.colors.primary
                              : context.nyaya.textSecondary,
                          fontWeight: isToday
                              ? FontWeight.w800
                              : FontWeight.w600,
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
                              ? Border.all(
                                  color: context.nyaya.streak,
                                  width: 2,
                                )
                              : null,
                        ),
                        child: Icon(
                          frozen
                              ? Icons.ac_unit_rounded
                              : Icons.local_fire_department_rounded,
                          size: 18,
                          color: active || frozen
                              ? Colors.white
                              : context.nyaya.locked,
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
      onTap: done
          ? null
          : () => QuizLauncher.start(
              context,
              ref,
              const QuizRequest(QuizMode.dailyDocket),
            ),
      child: Row(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppRadius.md),
              color: AppPalette.burntClay,
            ),
            child: Icon(
              done ? Icons.check_rounded : Icons.today_rounded,
              color: Colors.white,
              size: 30,
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        l.modeDailyDocket,
                        style: context.text.titleMedium,
                      ),
                    ),
                    const SizedBox(width: 8),
                    _Badge(text: l.modeFree, color: context.nyaya.success),
                  ],
                ),
                const SizedBox(height: 2),
                if (done)
                  TickingBuilder(
                    builder: (context) => Text(
                      '${l.docketDoneToday} · ${l.docketNextIn(formatCountdown(Day.untilMidnight(ref.read(clockProvider)())))}',
                      style: context.text.bodyMedium?.copyWith(
                        color: context.nyaya.textSecondary,
                      ),
                    ),
                  )
                else
                  Text(
                    l.modeDailyDocketDesc,
                    style: context.text.bodyMedium?.copyWith(
                      color: context.nyaya.textSecondary,
                    ),
                  ),
              ],
            ),
          ),
          if (!done)
            Icon(
              Icons.chevron_right_rounded,
              color: context.nyaya.textSecondary,
            ),
        ],
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge({required this.text, required this.color, this.icon});

  final String text;
  final Color color;

  /// Drawn after the text; the app's fonts have no emoji such as ⚡.
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(AppRadius.xl),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            text,
            style: context.text.labelSmall?.copyWith(
              color: color,
              fontWeight: FontWeight.w800,
            ),
          ),
          if (icon != null) Icon(icon, size: 14, color: color),
        ],
      ),
    );
  }
}

/// The four quiz modes, two per row.
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
        // Same serif heading as the other Explore Law sections.
        // Full width, so the scales sit at the right edge and not beside the text.
        Stack(
          children: [
            // The painted scales behind the heading's right side; absent until added.
            PositionedDirectional(
              end: 0,
              bottom: 0,
              child: ExcludeSemantics(
                child: Image.asset(
                  'assets/images/modes_scales.webp',
                  height: 76,
                  errorBuilder: (_, _, _) => const SizedBox.shrink(),
                ),
              ),
            ),
            SizedBox(
              width: double.infinity,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Room above the heading for the scales.
                  const SizedBox(height: 30),
                  Semantics(
                    header: true,
                    child: Text(
                      l.homeModesTitle,
                      style: AppTheme.serif(
                        TextStyle(
                          fontSize: 26,
                          height: 1.15,
                          color: context.colors.onSurface,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  // A short brush-stroke underline.
                  ExcludeSemantics(
                    child: Container(
                      width: 120,
                      height: 3,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(2),
                        gradient: LinearGradient(
                          colors: [
                            AppPalette.terracotta,
                            AppPalette.terracotta.withValues(alpha: 0),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        // Two columns of equal-height tiles that fit their text; one column on
        // very narrow screens.
        LayoutBuilder(
          builder: (context, box) {
            final oneColumn = box.maxWidth < 300;
            final tileWidth = oneColumn ? box.maxWidth : (box.maxWidth - 12) / 2;
            final tiles = [
              for (final (mode, name, desc, icon, color) in modes)
                _ModeTile(
                  mode: mode,
                  name: name,
                  desc: desc,
                  icon: icon,
                  color: color,
                  // Tile padding (14 + 14) and the arrow (8 + 34) take the rest.
                  nameWidth: tileWidth - 70,
                  onTap: () => mode == QuizMode.casePath
                      ? context.go(Routes.journey)
                      : QuizLauncher.start(context, ref, QuizRequest(mode)),
                ),
            ];
            const gap = SizedBox(width: 12, height: 12);
            if (oneColumn) {
              return Column(
                children: [
                  for (final (i, t) in tiles.indexed) ...[if (i > 0) gap, t],
                ],
              );
            }
            return Column(
              children: [
                for (var i = 0; i < tiles.length; i += 2) ...[
                  if (i > 0) gap,
                  IntrinsicHeight(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Expanded(child: tiles[i]),
                        gap,
                        Expanded(
                          child: i + 1 < tiles.length
                              ? tiles[i + 1]
                              : const SizedBox.shrink(),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            );
          },
        ),
      ],
    );
  }
}

/// One quiz mode: a picture on top with the energy cost on it, then the name,
/// what it is and an arrow. The Case Path tile is filled, as the main mode.
class _ModeTile extends StatelessWidget {
  const _ModeTile({
    required this.mode,
    required this.name,
    required this.desc,
    required this.icon,
    required this.color,
    required this.nameWidth,
    required this.onTap,
  });

  /// Room for the name beside the arrow; long words shrink to fit it.
  final double nameWidth;
  final QuizMode mode;
  final String name;
  final String desc;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  static String _asset(QuizMode mode) => switch (mode) {
    QuizMode.casePath => 'assets/images/mode_case_path.webp',
    QuizMode.dailyDocket => 'assets/images/mode_daily_docket.webp',
    QuizMode.duel => 'assets/images/mode_duel.webp',
    QuizMode.exam => 'assets/images/mode_exam.webp',
    QuizMode.mistakeReview => '',
  };

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final cost = mode.energyCost;
    final featured = mode == QuizMode.casePath;
    final fg = featured ? AppPalette.creamLight : context.colors.onSurface;
    final fgSoft = featured
        ? AppPalette.creamLight.withValues(alpha: 0.85)
        : context.nyaya.textSecondary;
    final badge = cost == 0
        ? _Badge(text: l.modeFree, color: context.nyaya.success)
        : _Badge(
            text: l.modeEnergyCost(cost),
            icon: Icons.bolt_rounded,
            color: AppPalette.ochreText,
          );

    return Pressable(
      onTap: onTap,
      scale: 0.98,
      child: Container(
        decoration: BoxDecoration(
          color: featured ? AppPalette.terracotta : context.colors.surface,
          borderRadius: BorderRadius.circular(AppRadius.lg),
          border: Border.all(
            color: featured ? AppPalette.ochre : context.nyaya.cardBorder,
            width: featured ? 1.5 : 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(
                alpha: context.isDark ? 0.25 : 0.04,
              ),
              blurRadius: 18,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Stack(
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ClipRRect(
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(AppRadius.lg - 1),
                  ),
                  child: Stack(
                    alignment: Alignment.bottomLeft,
                    children: [
                      AspectRatio(
                        aspectRatio: 1.45,
                        // Until the painting is added the tile shows its icon.
                        child: ExcludeSemantics(
                          child: Image.asset(
                            _asset(mode),
                            fit: BoxFit.cover,
                            errorBuilder: (_, _, _) => ColoredBox(
                              color: color.withValues(alpha: 0.14),
                              child: Icon(
                                icon,
                                color: featured ? AppPalette.creamLight : color,
                                size: 44,
                              ),
                            ),
                          ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(10, 0, 10, 8),
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: AlignmentDirectional.centerStart,
                          // Solid behind the pill so it reads on any picture.
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              color: featured
                                  ? AppPalette.ochreSoft
                                  : AppPalette.creamLight,
                              borderRadius: BorderRadius.circular(AppRadius.xl),
                            ),
                            child: badge,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(14, 10, 14, 14),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _WholeWordsText(
                              name,
                              maxWidth: nameWidth,
                              style: AppTheme.serif(
                                TextStyle(
                                  fontSize: 20,
                                  height: 1.15,
                                  fontWeight: FontWeight.w700,
                                  color: fg,
                                ),
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              desc,
                              style: context.text.bodySmall?.copyWith(
                                color: fgSoft,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      ExcludeSemantics(
                        child: Container(
                          width: 34,
                          height: 34,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: featured
                                ? AppPalette.creamLight
                                : AppPalette.terracotta.withValues(alpha: 0.12),
                          ),
                          child: const Icon(
                            Icons.arrow_forward_rounded,
                            size: 20,
                            color: AppPalette.terracotta,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (featured)
              // A bookmark ribbon: this is the main mode.
              PositionedDirectional(
                top: 0,
                end: 14,
                child: ExcludeSemantics(
                  child: ClipPath(
                    clipper: _RibbonClipper(),
                    child: const SizedBox(
                      width: 26,
                      height: 36,
                      child: ColoredBox(color: AppPalette.ochre),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _RibbonClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) => Path()
    ..lineTo(size.width, 0)
    ..lineTo(size.width, size.height)
    ..lineTo(size.width / 2, size.height - 9)
    ..lineTo(0, size.height)
    ..close();

  @override
  bool shouldReclip(_RibbonClipper oldClipper) => false;
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
            child: LeagueEmblem(tier, size: 28),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l.homeLeagueTitle,
                  style: context.text.labelMedium?.copyWith(
                    color: context.nyaya.textSecondary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  p.weeklyXp == 0
                      ? l.tierName(tier)
                      : l.homeLeagueRank(rank, l.tierName(tier)),
                  style: context.text.titleMedium,
                ),
                const SizedBox(height: 2),
                Text(
                  p.weeklyXp == 0
                      ? l.leaderboardEarnToJoin
                      : l.homeLeagueEnds(
                          formatCountdown(Day.untilWeekEnd(now)),
                        ),
                  style: context.text.bodySmall?.copyWith(
                    color: context.nyaya.textSecondary,
                  ),
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

/// Text that may wrap between words but never inside one: when the longest
/// word is wider than [maxWidth] (narrow phones, long translations), the font
/// shrinks until it fits, down to 70%. Takes the width from its parent because
/// the tiles sit in an IntrinsicHeight, where LayoutBuilder cannot be used.
class _WholeWordsText extends StatelessWidget {
  const _WholeWordsText(this.text, {required this.style, required this.maxWidth});

  final String text;
  final TextStyle style;
  final double maxWidth;

  @override
  Widget build(BuildContext context) {
    final scaler = MediaQuery.textScalerOf(context);
    final direction = Directionality.of(context);
    var widest = 0.0;
    for (final word in text.split(RegExp(r'\s+'))) {
      final painter = TextPainter(
        text: TextSpan(text: word, style: style),
        textScaler: scaler,
        textDirection: direction,
        maxLines: 1,
      )..layout();
      widest = widest > painter.width ? widest : painter.width;
      painter.dispose();
    }
    final size = style.fontSize ?? 14;
    final fit = maxWidth > 0 && widest > maxWidth ? (maxWidth / widest).clamp(0.7, 1.0) : 1.0;
    return Text(text, style: style.copyWith(fontSize: size * fit));
  }
}
