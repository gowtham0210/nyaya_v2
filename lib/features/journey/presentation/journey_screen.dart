import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../../app/router.dart';
import '../../../core/config/game_rules.dart';
import '../../../core/l10n/l10n.dart';
import '../../../core/storage/local_store.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/day.dart';
import '../../../core/widgets/common.dart';
import '../../../core/widgets/pressable.dart';
import '../../profile/application/profile_controller.dart';
import '../../profile/domain/user_profile.dart';
import '../../quiz/domain/quiz_models.dart';
import '../application/journey_controller.dart';
import '../domain/journey.dart';
import 'journey_layout.dart';
import 'journey_painter.dart';
import 'journey_scenery.dart';
import 'level_sheet.dart';
import 'map_node.dart';

/// Candy-Crush-style level map: a winding road from the bottom up, chapter
/// signposts, starred nodes, a pulsing "you are here" marker and chests.
class JourneyScreen extends ConsumerStatefulWidget {
  const JourneyScreen({super.key});

  @override
  ConsumerState<JourneyScreen> createState() => _JourneyScreenState();
}

class _JourneyScreenState extends ConsumerState<JourneyScreen> {
  final _scroll = ScrollController();
  JourneyLayout? _layout;
  double _viewport = 0;
  bool _didInitialScroll = false;

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  void _scrollToCurrent({bool animate = true}) {
    final layout = _layout;
    if (layout == null || !_scroll.hasClients) return;
    final current = ref.read(journeyProvider).current;
    final index = current?.globalIndex ?? JourneyCatalog.nodes.length - 1;
    final target = layout.scrollOffsetFor(index, _viewport);
    if (animate) {
      _scroll.animateTo(target, duration: const Duration(milliseconds: 700), curve: Curves.easeInOutCubic);
    } else {
      _scroll.jumpTo(target);
    }
  }

  void _openSheet(JourneyNode node) => showNodeSheet(context, ref, node, onShowNext: _scrollToCurrent);

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    // After a level or chest, bring the new next step into view.
    ref.listen(journeyProvider.select((p) => p.current?.id), (before, now) {
      if (before != now) WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToCurrent());
    });
    final progress = ref.watch(journeyProvider);
    final profile = ref.watch(profileProvider);
    final nodes = JourneyCatalog.nodes;
    final current = progress.current;
    final completedUpTo = current?.globalIndex ?? nodes.length;

    return Scaffold(
      body: Stack(
        children: [
          LayoutBuilder(
            builder: (context, box) {
              final scale = MediaQuery.textScalerOf(context).scale(1);
              final layout = _layout?.width == box.maxWidth && _layout?.textScale == scale
                  ? _layout!
                  : JourneyLayout(width: box.maxWidth, nodes: nodes, textScale: scale);
              _layout = layout;
              _viewport = box.maxHeight;
              if (!_didInitialScroll) {
                _didInitialScroll = true;
                WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToCurrent(animate: false));
              }
              return SingleChildScrollView(
                controller: _scroll,
                reverse: true,
                child: SizedBox(
                  width: box.maxWidth,
                  height: layout.height,
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      ...darkBackdrop(context, layout),
                      ...sceneryLayer(context, layout),
                      Positioned.fill(
                        child: CustomPaint(
                          painter: context.isDark
                              ? RoadPainter(
                                  layout: layout,
                                  completedUpTo: completedUpTo,
                                  roadColor: AppPalette.darkRoad,
                                  edgeColor: AppPalette.darkRoadRim,
                                  doneColor: AppPalette.darkRoadDone,
                                  dashColor: AppPalette.cream.withValues(alpha: 0.45),
                                  shadowColor: Colors.black.withValues(alpha: 0.35),
                                )
                              : RoadPainter(
                                  layout: layout,
                                  completedUpTo: completedUpTo,
                                  roadColor: AppPalette.sandLight,
                                  edgeColor: AppPalette.sand.withValues(alpha: 0.45),
                                  doneColor: AppPalette.ochreSoft,
                                  dashColor: Colors.white.withValues(alpha: 0.85),
                                ),
                        ),
                      ),
                      ...marginNotes(context, layout, current),
                      for (final (c, chapter) in JourneyCatalog.chapters.indexed)
                        Positioned(
                          left: AppSpacing.page,
                          right: AppSpacing.page,
                          top: layout.bannerTop(c) + 20,
                          child: ChapterBanner(
                            number: c + 1,
                            title: l.chapterTitle(chapter.id),
                            subtitle: l.chapterSubtitle(chapter.id),
                            chapter: chapter,
                            done: progress.completedLevelsIn(chapter.id),
                            active: (current?.chapterIndex ?? -1) == c,
                            onTap: () => _openSheet(_chapterFocus(progress, c)),
                          ),
                        ),
                      for (final node in nodes)
                        MapNode.positioned(
                          center: layout.centers[node.globalIndex],
                          node: node,
                          status: progress.status(node),
                          stars: progress.stars[node.id] ?? 0,
                          userName: profile.name,
                          onTap: () => _openSheet(node),
                          mapWidth: layout.width,
                        ),
                    ],
                  ),
                ),
              );
            },
          ),
          // Floating header.
          Positioned(top: 0, left: 0, right: 0, child: _MapHeader(totalStars: progress.totalStars)),
          Positioned(
            right: AppSpacing.page,
            bottom: AppSpacing.md + 56 + AppSpacing.sm,
            child: FloatingActionButton.small(
              heroTag: 'list',
              tooltip: l.journeyListView,
              elevation: 3,
              backgroundColor: context.colors.surface,
              foregroundColor: context.colors.primary,
              onPressed: () => _LevelList.show(context, onOpen: _openSheet),
              child: const Icon(Icons.format_list_bulleted_rounded),
            ),
          ),
          Positioned(
            right: AppSpacing.page,
            bottom: AppSpacing.md,
            child: FloatingActionButton(
              heroTag: 'jump',
              tooltip: l.journeyJumpToCurrent,
              shape: const CircleBorder(),
              elevation: 3,
              backgroundColor: context.colors.surface,
              foregroundColor: context.colors.primary,
              onPressed: _scrollToCurrent,
              child: const Icon(Icons.my_location_rounded, size: 28),
            ),
          ),
        ],
      ),
    );
  }

  /// The stop a chapter card opens: the current one if it is in this
  /// chapter, otherwise the chapter's first level.
  JourneyNode _chapterFocus(JourneyProgress progress, int chapter) {
    final current = progress.current;
    if (current != null && current.chapterIndex == chapter) return current;
    return JourneyCatalog.nodes.firstWhere((n) => n.chapterIndex == chapter);
  }
}

class _MapHeader extends ConsumerWidget {
  const _MapHeader({required this.totalStars});

  final int totalStars;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final p = ref.watch(profileProvider);
    final bg = Theme.of(context).scaffoldBackgroundColor;
    // Solid behind the text however many lines it wraps to, then a short fade onto the map.
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ColoredBox(color: bg, child: _content(context, l, p)),
        IgnorePointer(
          child: Container(
            height: AppSpacing.lg,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [bg, bg.withValues(alpha: 0.0)],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _content(BuildContext context, AppLocalizations l, UserProfile p) {
    return SafeArea(
      bottom: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(AppSpacing.page, AppSpacing.md, AppSpacing.page, AppSpacing.sm),
        // Title and stats share the first line; the subtitle gets the full width below.
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    l.journeyTitle,
                    style: AppTheme.serif(
                      TextStyle(
                        fontSize: 38,
                        height: 1.1,
                        color: context.isDark ? AppPalette.darkTitle : context.colors.primary,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Row(
                    children: [
                      // Each chip opens a short note on what it counts and how it changes.
                      StatPill(
                        icon: Icons.star_rounded,
                        value: '$totalStars',
                        color: AppPalette.ochre,
                        semanticLabel: '$totalStars ${l.statStars}',
                        onTap: () => _ResourceSheet.show(context, _Resource.stars),
                      ),
                      const SizedBox(width: 4),
                      StatPill(
                        icon: Icons.bolt_rounded,
                        value: p.isPremium ? '∞' : '${p.energy}',
                        color: context.nyaya.energy,
                        semanticLabel: p.isPremium ? l.energyUnlimited : l.energyLeft(p.energy),
                        onTap: () => _ResourceSheet.show(context, _Resource.energy),
                      ),
                      const SizedBox(width: 4),
                      StatPill(
                        icon: Icons.monetization_on_rounded,
                        value: '${p.coins}',
                        color: AppPalette.ochre,
                        semanticLabel: '${p.coins} ${l.statCoins}',
                        onTap: () => _ResourceSheet.show(context, _Resource.coins),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              l.journeySubtitle,
              style: context.text.bodyLarge?.copyWith(color: context.nyaya.textSecondary),
            ),
          ],
        ),
      ),
    );
  }
}

/// Chapter signpost on the road. The chapter you are in reads as a calm
/// cream card; the others are solid clay so they stand out as milestones.
class ChapterBanner extends StatelessWidget {
  const ChapterBanner({
    super.key,
    required this.number,
    required this.title,
    required this.subtitle,
    required this.chapter,
    required this.done,
    required this.active,
    required this.onTap,
  });

  final int number;
  final String title;
  final String subtitle;
  final ChapterMeta chapter;
  final int done;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final fill = active ? context.colors.surface : (context.isDark ? AppPalette.terracotta : AppPalette.burntClay);
    final ink = active ? context.colors.onSurface : Colors.white;
    final soft = active ? context.nyaya.textSecondary : Colors.white.withValues(alpha: 0.85);
    final accent = active ? context.colors.primary : Colors.white.withValues(alpha: 0.9);

    return Center(
      child: Semantics(
        button: true,
        label: [l.journeyChapter(number), title, l.homeLevelsDone(done, chapter.levels), subtitle]
            .where((s) => s.isNotEmpty)
            .join(', '),
        excludeSemantics: true,
        child: Pressable(
          onTap: onTap,
          scale: 0.97,
          child: Container(
            constraints: const BoxConstraints(maxWidth: 380),
            padding: const EdgeInsets.fromLTRB(14, 14, 12, 14),
            decoration: BoxDecoration(
              color: fill,
              borderRadius: BorderRadius.circular(AppRadius.lg),
              border: active ? Border.all(color: context.nyaya.cardBorder) : null,
              boxShadow: [
                BoxShadow(
                  color: (active ? Colors.black : AppPalette.terracottaDeep).withValues(alpha: active ? 0.08 : 0.28),
                  blurRadius: 18,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: active ? context.colors.primaryContainer : Colors.white.withValues(alpha: 0.16),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(chapter.icon, color: active ? context.colors.primary : Colors.white, size: 26),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        l.journeyChapterProgress(number, done, chapter.levels).toUpperCase(),
                        style: context.text.labelSmall?.copyWith(
                          color: accent,
                          fontWeight: FontWeight.w600,
                          letterSpacing: context.tracking(1.4),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: AppTheme.serif(TextStyle(fontSize: 22, height: 1.2, color: ink), display: false),
                      ),
                      if (subtitle.isNotEmpty)
                        Text(
                          subtitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: context.text.bodySmall?.copyWith(color: soft),
                        ),
                    ],
                  ),
                ),
                Icon(Icons.chevron_right_rounded, color: soft),
              ],
            ),
          ),
        ),
      ),
    ).animate().fadeIn(duration: 400.ms);
  }
}

enum _Resource { stars, energy, coins }

/// What a header chip counts, how it is earned and what it is for — only the
/// rules the app and server really apply.
class _ResourceSheet extends ConsumerWidget {
  const _ResourceSheet(this.resource);

  final _Resource resource;

  static Future<void> show(BuildContext context, _Resource resource) => showModalBottomSheet(
    context: context,
    useRootNavigator: true,
    isScrollControlled: true,
    builder: (_) => _ResourceSheet(resource),
  );

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final p = ref.watch(profileProvider);
    final stars = ref.watch(journeyProvider).totalStars;
    final maxStars = JourneyCatalog.nodes.where((n) => n.kind == NodeKind.level).length * 3;
    final now = ref.read(clockProvider)();
    final (icon, color, title, value, body) = switch (resource) {
      _Resource.stars => (
        Icons.star_rounded,
        AppPalette.ochre,
        l.statStars,
        l.journeyStarsOf(stars, maxStars),
        l.journeyStarsInfo((GameRules.oneStarAccuracy * 100).round(), (GameRules.twoStarAccuracy * 100).round()),
      ),
      _Resource.energy => (
        Icons.bolt_rounded,
        context.nyaya.energy,
        l.statEnergy,
        p.isPremium ? l.energyUnlimited : l.energyLeft(p.energy),
        l.journeyEnergyInfo(
          QuizMode.casePath.energyCost,
          GameRules.freeDailyEnergy,
          formatCountdown(Day.untilMidnight(now)),
        ),
      ),
      _Resource.coins => (
        Icons.monetization_on_rounded,
        AppPalette.ochre,
        l.statCoins,
        '${p.coins} ${l.statCoins}',
        l.journeyCoinsInfo,
      ),
    };

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(AppSpacing.page, 0, AppSpacing.page, AppSpacing.md),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(shape: BoxShape.circle, color: color.withValues(alpha: 0.15)),
                child: Icon(icon, size: 36, color: color),
              ),
            ),
            const SizedBox(height: 12),
            Semantics(
              header: true,
              child: Text(title, textAlign: TextAlign.center, style: context.text.headlineSmall),
            ),
            const SizedBox(height: 4),
            Text(value, textAlign: TextAlign.center, style: context.text.titleMedium),
            const SizedBox(height: AppSpacing.md),
            Text(
              body,
              textAlign: TextAlign.center,
              style: context.text.bodyLarge?.copyWith(color: context.nyaya.textSecondary),
            ),
            const SizedBox(height: AppSpacing.lg),
            if (resource == _Resource.coins)
              FilledButton(
                onPressed: () {
                  Navigator.pop(context);
                  context.push(Routes.store);
                },
                child: Text(l.journeyOpenStore),
              )
            else
              OutlinedButton(onPressed: () => Navigator.pop(context), child: Text(l.commonOk)),
          ],
        ),
      ),
    );
  }
}

/// The whole road as a plain list: the same stops and states as the map, for
/// screen readers and anyone who finds the painted map hard to follow.
class _LevelList extends ConsumerWidget {
  const _LevelList({required this.onOpen});

  final void Function(JourneyNode node) onOpen;

  static Future<void> show(BuildContext context, {required void Function(JourneyNode node) onOpen}) =>
      showModalBottomSheet(
        context: context,
        useRootNavigator: true,
        isScrollControlled: true,
        builder: (_) => _LevelList(onOpen: onOpen),
      );

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final progress = ref.watch(journeyProvider);

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.75,
      maxChildSize: 0.95,
      // Only 24 rows: build them all so every one is in the reading order.
      builder: (context, scroll) => SingleChildScrollView(
        controller: scroll,
        padding: const EdgeInsets.fromLTRB(AppSpacing.page, 0, AppSpacing.page, AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
          Semantics(header: true, child: Text(l.journeyAllLevels, style: context.text.headlineSmall)),
          for (final (c, chapter) in JourneyCatalog.chapters.indexed) ...[
            const SizedBox(height: AppSpacing.md),
            Semantics(
              header: true,
              child: Text(
                '${l.journeyChapter(c + 1)} · ${l.chapterTitle(chapter.id)}',
                style: context.text.titleMedium?.copyWith(fontWeight: FontWeight.w600),
              ),
            ),
            Text(
              l.homeLevelsDone(progress.completedLevelsIn(chapter.id), chapter.levels),
              style: context.text.bodySmall?.copyWith(color: context.nyaya.textSecondary),
            ),
            for (final node in JourneyCatalog.nodes.where((n) => n.chapterIndex == c))
              _LevelListRow(
                node: node,
                status: progress.status(node),
                stars: progress.stars[node.id] ?? 0,
                onTap: () {
                  Navigator.pop(context);
                  onOpen(node);
                },
              ),
          ],
          ],
        ),
      ),
    );
  }
}

class _LevelListRow extends StatelessWidget {
  const _LevelListRow({required this.node, required this.status, required this.stars, required this.onTap});

  final JourneyNode node;
  final NodeStatus status;
  final int stars;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final chest = node.kind == NodeKind.chest;
    final title = chest ? l.journeyChest : l.journeyLevel(node.level);
    final state = switch (status) {
      NodeStatus.locked => l.journeyLocked,
      NodeStatus.current => chest ? l.journeyChestReadyTitle : l.journeyNext,
      NodeStatus.completed => chest ? l.journeyChestCollectedTitle : l.journeyDone,
    };
    final icon = switch (status) {
      NodeStatus.locked => Icons.lock_rounded,
      NodeStatus.current => Icons.play_arrow_rounded,
      NodeStatus.completed => Icons.check_rounded,
    };
    final active = status != NodeStatus.locked;

    return Semantics(
      button: true,
      label: [title, state, if (!chest && stars > 0) l.journeyStarsOf(stars, 3)].join(', '),
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.md),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 56),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: active ? context.colors.primary : context.colors.surfaceContainerHigh,
                  ),
                  child: Icon(
                    chest ? Icons.redeem_rounded : icon,
                    size: 20,
                    color: active ? context.colors.onPrimary : context.nyaya.textSecondary,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: context.text.titleSmall),
                      Text(state, style: context.text.bodySmall?.copyWith(color: context.nyaya.textSecondary)),
                    ],
                  ),
                ),
                if (!chest && stars > 0) StarRow(stars: stars, size: 16),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
