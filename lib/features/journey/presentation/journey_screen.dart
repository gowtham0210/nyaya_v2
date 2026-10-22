import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/l10n/l10n.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/common.dart';
import '../../profile/application/profile_controller.dart';
import '../../quiz/data/question_repository.dart';
import '../application/journey_controller.dart';
import '../domain/journey.dart';
import 'journey_layout.dart';
import 'journey_painter.dart';
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
    final bank = ref.watch(questionBankProvider).value;
    final nodes = JourneyCatalog.nodes;
    final current = progress.current;
    final completedUpTo = current?.globalIndex ?? nodes.length;

    return Scaffold(
      body: Stack(
        children: [
          LayoutBuilder(
            builder: (context, box) {
              final layout = _layout?.width == box.maxWidth ? _layout! : JourneyLayout(width: box.maxWidth, nodes: nodes);
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
                      // Chapter-tinted background bands.
                      for (final (c, band) in layout.chapterBands.indexed)
                        Positioned(
                          left: 0,
                          right: 0,
                          top: band.top,
                          height: band.bottom - band.top,
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [
                                  JourneyCatalog.chapters[c].color.withValues(alpha: context.isDark ? 0.10 : 0.07),
                                  JourneyCatalog.chapters[c].color.withValues(alpha: context.isDark ? 0.22 : 0.16),
                                ],
                              ),
                            ),
                          ),
                        ),
                      Positioned.fill(
                        child: MapDecorations(
                          width: box.maxWidth,
                          height: layout.height,
                          color: context.colors.onSurface.withValues(alpha: 0.05),
                        ),
                      ),
                      Positioned.fill(
                        child: CustomPaint(
                          painter: RoadPainter(
                            centers: layout.centers,
                            completedUpTo: completedUpTo,
                            roadColor: context.isDark ? const Color(0xFF2B3566) : const Color(0xFFE6DFCD),
                            edgeColor: context.isDark ? const Color(0xFF1C2448) : const Color(0xFFD3CAB3),
                            doneColor: AppPalette.gold,
                          ),
                        ),
                      ),
                      for (final (c, chapter) in JourneyCatalog.chapters.indexed)
                        Positioned(
                          left: 24,
                          right: 24,
                          top: layout.bannerTop(c) + 22,
                          child: ChapterBanner(
                            number: c + 1,
                            title: bank?.chapters[chapter.id]?.title ?? '',
                            subtitle: bank?.chapters[chapter.id]?.subtitle ?? '',
                            chapter: chapter,
                            done: progress.completedLevelsIn(chapter.id),
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
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: _MapHeader(totalStars: progress.totalStars),
          ),
          Positioned(
            right: AppSpacing.page,
            bottom: AppSpacing.md,
            child: FloatingActionButton.small(
              heroTag: 'jump',
              tooltip: l.journeyJumpToCurrent,
              backgroundColor: context.colors.surface,
              foregroundColor: context.colors.primary,
              onPressed: _scrollToCurrent,
              child: const Icon(Icons.my_location_rounded),
            ),
          ),
        ],
      ),
    );
  }
}

class _MapHeader extends ConsumerWidget {
  const _MapHeader({required this.totalStars});

  final int totalStars;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final p = ref.watch(profileProvider);
    return ClipRect(
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Theme.of(context).scaffoldBackgroundColor,
              Theme.of(context).scaffoldBackgroundColor.withValues(alpha: 0.0),
            ],
            stops: const [0.7, 1],
          ),
        ),
        child: SafeArea(
          bottom: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(AppSpacing.page, AppSpacing.sm, AppSpacing.page, AppSpacing.lg),
            child: Row(
              children: [
                Expanded(child: Text(l.journeyTitle, style: context.text.headlineMedium)),
                StatPill(icon: Icons.star_rounded, value: '$totalStars', color: AppPalette.gold),
                const SizedBox(width: 8),
                StatPill(
                  icon: Icons.bolt_rounded,
                  value: p.isPremium ? '∞' : '${p.energy}',
                  color: context.nyaya.energy,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class ChapterBanner extends StatelessWidget {
  const ChapterBanner({
    super.key,
    required this.number,
    required this.title,
    required this.subtitle,
    required this.chapter,
    required this.done,
  });

  final int number;
  final String title;
  final String subtitle;
  final ChapterMeta chapter;
  final int done;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return Center(
      child: Container(
        constraints: const BoxConstraints(maxWidth: 340),
        padding: const EdgeInsets.fromLTRB(14, 10, 16, 10),
        decoration: BoxDecoration(
          color: chapter.color,
          borderRadius: BorderRadius.circular(AppRadius.md),
          boxShadow: [
            BoxShadow(color: Color.lerp(chapter.color, Colors.black, 0.35)!, offset: const Offset(0, 4)),
            BoxShadow(color: chapter.color.withValues(alpha: 0.3), blurRadius: 16, offset: const Offset(0, 8)),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.18),
                shape: BoxShape.circle,
              ),
              child: Icon(chapter.icon, color: Colors.white, size: 22),
            ),
            const SizedBox(width: 12),
            Flexible(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '${l.journeyChapter(number).toUpperCase()} · $done/${chapter.levels}',
                    style: context.text.labelSmall?.copyWith(
                      color: AppPalette.goldSoft,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1,
                    ),
                  ),
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: context.text.titleMedium?.copyWith(color: Colors.white),
                  ),
                  if (subtitle.isNotEmpty)
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: context.text.bodySmall?.copyWith(color: Colors.white70),
                    ),
                ],
              ),
            ),
          ],
        ),
      ).animate().fadeIn(duration: 400.ms),
    );
  }
}
