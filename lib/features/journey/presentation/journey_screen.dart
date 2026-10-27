import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/l10n/l10n.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/common.dart';
import '../../../core/widgets/pressable.dart';
import '../../profile/application/profile_controller.dart';
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

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
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
              final layout = _layout?.width == box.maxWidth
                  ? _layout!
                  : JourneyLayout(width: box.maxWidth, nodes: nodes);
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
                      ...sceneryLayer(context, layout),
                      Positioned.fill(
                        child: CustomPaint(
                          painter: RoadPainter(
                            layout: layout,
                            completedUpTo: completedUpTo,
                            roadColor: context.isDark ? const Color(0xFF3A3029) : AppPalette.sandLight,
                            edgeColor: (context.isDark ? const Color(0xFF2A221C) : AppPalette.sand).withValues(
                              alpha: 0.45,
                            ),
                            doneColor: context.isDark ? const Color(0xFF4A3B30) : AppPalette.ochreSoft,
                            dashColor: Colors.white.withValues(alpha: context.isDark ? 0.25 : 0.85),
                          ),
                        ),
                      ),
                      ...marginNotes(context, layout, current),
                      for (final (c, chapter) in JourneyCatalog.chapters.indexed)
                        Positioned(
                          left: AppSpacing.page,
                          right: AppSpacing.page,
                          top: layout.bannerTop(c) + 30,
                          child: ChapterBanner(
                            number: c + 1,
                            title: l.chapterTitle(chapter.id),
                            subtitle: l.chapterSubtitle(chapter.id),
                            chapter: chapter,
                            done: progress.completedLevelsIn(chapter.id),
                            active: (current?.chapterIndex ?? -1) == c,
                            onTap: () => showNodeSheet(context, ref, _chapterFocus(progress, c)),
                          ),
                        ),
                      for (final node in nodes)
                        MapNode.positioned(
                          center: layout.centers[node.globalIndex],
                          node: node,
                          status: progress.status(node),
                          stars: progress.stars[node.id] ?? 0,
                          userName: profile.name,
                          onTap: () => showNodeSheet(context, ref, node),
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
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [bg, bg.withValues(alpha: 0.0)],
          stops: const [0.72, 1],
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(AppSpacing.page, AppSpacing.md, AppSpacing.page, AppSpacing.lg),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l.journeyTitle,
                      style: AppTheme.serif(TextStyle(fontSize: 38, height: 1.1, color: context.colors.primary)),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      l.journeySubtitle,
                      style: context.text.bodyLarge?.copyWith(color: context.nyaya.textSecondary),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Row(
                  children: [
                    StatPill(icon: Icons.star_rounded, value: '$totalStars', color: AppPalette.ochre),
                    const SizedBox(width: 8),
                    StatPill(
                      icon: Icons.bolt_rounded,
                      value: p.isPremium ? '∞' : '${p.energy}',
                      color: context.nyaya.energy,
                    ),
                  ],
                ),
              ),
            ],
          ),
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
                        '${l.journeyChapter(number).toUpperCase()} · $done/${chapter.levels}',
                        style: context.text.labelSmall?.copyWith(
                          color: accent,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 1.4,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        title,
                        maxLines: 1,
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
