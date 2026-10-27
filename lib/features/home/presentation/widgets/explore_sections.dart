import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../app/router.dart';
import '../../../../core/l10n/l10n.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/common.dart';
import '../../../journey/application/journey_controller.dart';
import '../../../journey/domain/journey.dart';
import '../../../legal_updates/data/legal_updates_repository.dart';
import '../../../legal_updates/presentation/updates_screen.dart';
import '../../../quiz/domain/quiz_models.dart';
import '../../../quiz/presentation/quiz_launcher.dart';
import 'law_illustration.dart';

/// Editorial serif used for Explore Law headings (DM Serif Display for large
/// titles, DM Serif Text for list rows).
TextStyle _serif(BuildContext context, double size, {bool display = true}) {
  return AppTheme.serif(
    TextStyle(fontSize: size, height: 1.15, color: context.colors.onSurface),
    display: display,
  );
}

/// Opens the AI chat with a ready-made question about [law].
void _askAbout(BuildContext context, String law) {
  final q = context.l10n.exploreAskPrompt(law);
  context.go(Uri(path: Routes.chat, queryParameters: {'q': q}).toString());
}

/// Starts the next Case Path level when it belongs to [chapterId]; otherwise
/// shows the Journey map so locked chapters are never skipped.
void _exploreChapter(BuildContext context, WidgetRef ref, String chapterId) {
  final next = ref.read(journeyProvider).current;
  if (next != null && next.kind == NodeKind.level && next.chapter.id == chapterId) {
    QuizLauncher.start(context, ref, QuizRequest(QuizMode.casePath, levelId: next.id));
  } else {
    context.go(Routes.journey);
  }
}

class ExploreHeader extends StatelessWidget {
  const ExploreHeader({super.key});

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return SafeArea(
      bottom: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(AppSpacing.page, AppSpacing.md, AppSpacing.sm, AppSpacing.sm),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(child: Text(l.exploreTitle, style: _serif(context, 36))),
                IconButton(
                  tooltip: l.exploreAskAi,
                  onPressed: () => context.go(Routes.chat),
                  icon: const Icon(Icons.search_rounded, size: 28),
                ),
                IconButton(
                  tooltip: l.settingsTitle,
                  onPressed: () => context.push(Routes.settings),
                  icon: const Icon(Icons.settings_outlined, size: 26),
                ),
              ],
            ),
            const SizedBox(height: 2),
            Text(l.exploreSubtitle, style: context.text.bodyLarge?.copyWith(color: context.nyaya.textSecondary)),
          ],
        ),
      ),
    );
  }
}

/// "Continue where you left off", below the "Start here" carousel: the next
/// Case Path level, with its chapter's painting. Hidden until the first level is finished, since the
/// "Start here" carousel covers new users.
class ContinueLearningCard extends ConsumerWidget {
  const ContinueLearningCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final journey = ref.watch(journeyProvider);
    if (journey.stars.isEmpty) return const SizedBox.shrink();

    final l = context.l10n;
    final node = journey.current;
    final chapter = node?.chapter ?? JourneyCatalog.chapters.last;
    final done = journey.completedLevelsIn(chapter.id);
    final subtitle = switch (node) {
      null => l.homeAllDone,
      JourneyNode(kind: NodeKind.chest) => l.homeChestReady,
      _ => l.homeChapterLevel(node.chapterIndex + 1, node.level),
    };
    void onContinue() => node != null && node.kind == NodeKind.level
        ? QuizLauncher.start(context, ref, QuizRequest(QuizMode.casePath, levelId: node.id))
        : context.go(Routes.journey);

    return Container(
      margin: const EdgeInsets.only(top: AppSpacing.lg),
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: context.colors.surface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: context.nyaya.cardBorder),
      ),
      child: Stack(
        children: [
          Positioned(
            top: 0,
            right: -10,
            bottom: 0,
            width: 170,
            child: IgnorePointer(
              child: Opacity(
                opacity: context.isDark ? 0.35 : 1,
                child: ShaderMask(
                  blendMode: BlendMode.dstIn,
                  shaderCallback: (bounds) => const LinearGradient(
                    colors: [Colors.transparent, Colors.black],
                    stops: [0, 0.5],
                  ).createShader(bounds),
                  child: Image.asset(
                    'assets/images/journey_${chapter.id}_landmark.webp',
                    fit: BoxFit.contain,
                    alignment: Alignment.bottomRight,
                    excludeFromSemantics: true,
                    errorBuilder: (_, _, _) => Align(
                      alignment: Alignment.centerRight,
                      child: Padding(
                        padding: const EdgeInsets.only(right: AppSpacing.lg),
                        child: Icon(chapter.icon, size: 72, color: context.colors.primary.withValues(alpha: 0.25)),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // The label sits above the painting, so it may span the card.
                Text(
                  l.homeContinueLeftOff.toUpperCase(),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: context.text.labelMedium?.copyWith(
                    color: context.colors.primary,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.6,
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                FractionallySizedBox(
                  widthFactor: 0.66,
                  alignment: Alignment.centerLeft,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(l.chapterTitle(chapter.id), style: _serif(context, 24)),
                      const SizedBox(height: 4),
                      Text(subtitle, style: context.text.bodyMedium?.copyWith(color: context.nyaya.textSecondary)),
                      const SizedBox(height: AppSpacing.md),
                      Row(
                        children: [
                          Expanded(
                            child: GlossyProgressBar(
                              value: done / chapter.levels,
                              color: context.colors.primary,
                              track: context.colors.surfaceContainerHigh,
                              height: 6,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Text('$done/${chapter.levels}', style: context.text.labelMedium),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.md),
                      FilledButton(
                        onPressed: onContinue,
                        style: FilledButton.styleFrom(
                          minimumSize: const Size(0, 44),
                          padding: const EdgeInsets.symmetric(horizontal: 22),
                          shape: const StadiumBorder(),
                          textStyle: context.text.labelLarge?.copyWith(fontWeight: FontWeight.w600, fontSize: 15),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(l.commonContinue),
                            const SizedBox(width: AppSpacing.sm),
                            const Icon(Icons.arrow_forward_rounded, size: 18),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// "Start here" carousel of featured laws with a dash page indicator.
class FeaturedLawsCarousel extends ConsumerStatefulWidget {
  const FeaturedLawsCarousel({super.key});

  @override
  ConsumerState<FeaturedLawsCarousel> createState() => _FeaturedLawsCarouselState();
}

class _FeaturedLawsCarouselState extends ConsumerState<FeaturedLawsCarousel> {
  final _controller = PageController();
  int _page = 0;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final slides = [
      (l.lawConstitutionTitle, l.lawConstitutionDesc, LawArt.court, 'constitution', _FeaturedImage.constitution),
      (l.lawBnsShort, l.lawBnsFeatured, LawArt.scales, 'criminal', _FeaturedImage.bns),
      (l.lawEverydayTitle, l.lawEverydayFeatured, LawArt.people, 'everyday', _FeaturedImage.everyday),
    ];

    return Column(
      children: [
        SizedBox(
          height: 268,
          child: PageView(
            controller: _controller,
            onPageChanged: (i) => setState(() => _page = i),
            children: [
              for (final (title, desc, art, chapter, image) in slides)
                _FeaturedCard(
                  title: title,
                  desc: desc,
                  art: art,
                  image: image,
                  onExplore: () => _exploreChapter(context, ref, chapter),
                ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            for (var i = 0; i < slides.length; i++)
              AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                margin: const EdgeInsets.symmetric(horizontal: 3),
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: i == _page ? context.colors.primary : context.colors.outlineVariant,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
          ],
        ),
      ],
    );
  }
}

/// A painted illustration and the flat colour its left edge fades into, so
/// the card background continues the picture without a seam.
enum _FeaturedImage {
  constitution('assets/images/explore_constitution.webp', Color(0xFFF0D5C5)),
  bns('assets/images/explore_bns.webp', Color(0xFFF1D0BB)),
  everyday('assets/images/explore_everyday.webp', Color(0xFFF0CFBA));

  const _FeaturedImage(this.asset, this.background);

  final String asset;
  final Color background;
}

class _FeaturedCard extends StatelessWidget {
  const _FeaturedCard({
    required this.title,
    required this.desc,
    required this.art,
    required this.onExplore,
    this.image,
  });

  final String title;
  final String desc;
  final LawArt art;
  final _FeaturedImage? image;
  final VoidCallback onExplore;

  @override
  Widget build(BuildContext context) {
    final image = this.image;
    // Painted images have a light background, so their card keeps light-theme
    // text colours in dark mode too.
    if (image != null && context.isDark) {
      return Theme(
        data: AppTheme.light(),
        child: Builder(builder: _build),
      );
    }
    return _build(context);
  }

  Widget _build(BuildContext context) {
    final l = context.l10n;
    final image = this.image;
    final fallback = ExcludeSemantics(child: LawIllustration(art: art));
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color:
            image?.background ??
            (context.isDark ? context.colors.surfaceContainerHigh : context.colors.primaryContainer),
        borderRadius: BorderRadius.circular(AppRadius.lg),
      ),
      child: Stack(
        children: [
          if (image != null)
            Positioned(
              top: 0,
              right: 0,
              bottom: 0,
              child: AspectRatio(
                aspectRatio: 1,
                child: Image.asset(
                  image.asset,
                  fit: BoxFit.cover,
                  excludeFromSemantics: true,
                  errorBuilder: (context, error, stack) => fallback,
                ),
              ),
            )
          else
            Positioned(right: 0, bottom: 0, width: 200, height: 220, child: fallback),
          Padding(
            padding: const EdgeInsets.fromLTRB(AppSpacing.page, AppSpacing.page, 0, AppSpacing.page),
            child: FractionallySizedBox(
              widthFactor: 0.56,
              alignment: Alignment.centerLeft,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l.exploreStartHere.toUpperCase(),
                    style: context.text.labelMedium?.copyWith(
                      color: context.colors.primary,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 2,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Text(title, maxLines: 3, overflow: TextOverflow.ellipsis, style: _serif(context, 30)),
                  const SizedBox(height: AppSpacing.sm),
                  Expanded(
                    child: Text(
                      desc,
                      overflow: TextOverflow.fade,
                      style: context.text.bodyMedium?.copyWith(color: context.nyaya.textSecondary, height: 1.4),
                    ),
                  ),
                  FilledButton(
                    onPressed: onExplore,
                    style: FilledButton.styleFrom(
                      minimumSize: const Size(0, 44),
                      padding: const EdgeInsets.symmetric(horizontal: 22),
                      shape: const StadiumBorder(),
                      textStyle: context.text.labelLarge?.copyWith(fontWeight: FontWeight.w600, fontSize: 15),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(l.exploreButton),
                        const SizedBox(width: AppSpacing.sm),
                        const Icon(Icons.arrow_forward_rounded, size: 18),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Serif section heading with a "View All" link.
class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.title, required this.onViewAll});

  final String title;
  final VoidCallback onViewAll;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(child: Text(title, style: _serif(context, 26))),
        TextButton(
          onPressed: onViewAll,
          style: TextButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            minimumSize: const Size(0, 36),
            textStyle: context.text.labelLarge?.copyWith(fontWeight: FontWeight.w600),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(context.l10n.exploreViewAll),
              const SizedBox(width: 4),
              const Icon(Icons.arrow_forward_rounded, size: 16),
            ],
          ),
        ),
      ],
    );
  }
}

/// "Latest legal updates": the newest updates as a horizontal strip of cards
/// that runs edge to edge, so it pads its own heading. Hidden while the feed
/// loads or when it is empty.
class LatestUpdatesSection extends ConsumerWidget {
  const LatestUpdatesSection({super.key});

  static const _count = 5;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final updates = ref.watch(legalUpdatesProvider).value ?? const [];
    if (updates.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.page),
            child: _SectionTitle(title: context.l10n.homeUpdatesTitle, onViewAll: () => context.go(Routes.updates)),
          ),
          const SizedBox(height: AppSpacing.sm),
          SizedBox(
            height: 292,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              // Room for the card shadow.
              padding: const EdgeInsets.fromLTRB(AppSpacing.page, 0, AppSpacing.page, AppSpacing.md),
              itemCount: updates.length.clamp(0, _count),
              separatorBuilder: (_, _) => const SizedBox(width: 14),
              itemBuilder: (context, i) => _UpdateCard(update: updates[i]),
            ),
          ),
        ],
      ),
    );
  }
}

/// Painting on top, then category, serif headline and date.
class _UpdateCard extends StatelessWidget {
  const _UpdateCard({required this.update});

  final LegalUpdate update;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final c = update.category;
    final tint = c.tint(context);
    final muted = context.nyaya.textSecondary;
    final date = DateFormat.yMMMd(Localizations.localeOf(context).languageCode).format(update.date);
    return SizedBox(
      width: 248,
      child: NyayaCard(
        onTap: () => context.push(Routes.update(update.id)),
        padding: EdgeInsets.zero,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(AppRadius.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                height: 124,
                width: double.infinity,
                child: Image.asset(
                  update.image,
                  fit: BoxFit.cover,
                  excludeFromSemantics: true,
                  errorBuilder: (_, _, _) => UpdateFallbackArt(category: c),
                ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(AppSpacing.md, 12, AppSpacing.md, 14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(c.icon, size: 16, color: tint),
                          const SizedBox(width: 6),
                          Flexible(
                            child: Text(
                              c.label(l).toUpperCase(),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: context.text.labelSmall?.copyWith(
                                color: tint,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 1.4,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Expanded(
                        child: Text(
                          update.title,
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                          style: _serif(context, 17, display: false).copyWith(height: 1.25),
                        ),
                      ),
                      Text(
                        '$date · ${l.updatesReadTime(update.readMinutes)}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: context.text.bodySmall?.copyWith(color: muted),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// "Core Laws" header, the list of current codes and the legacy row.
class CoreLawsSection extends StatelessWidget {
  const CoreLawsSection({super.key});

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final laws = [
      (Icons.balance_outlined, l.lawBnsTitle, l.lawBnsDesc),
      (Icons.policy_outlined, l.lawBnssTitle, l.lawBnssDesc),
      (Icons.folder_outlined, l.lawBsaTitle, l.lawBsaDesc),
      (Icons.groups_outlined, l.lawEverydayTitle, l.lawEverydayDesc),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _SectionTitle(title: l.exploreCoreLaws, onViewAll: () => context.go(Routes.journey)),
        const SizedBox(height: AppSpacing.sm),
        Container(
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            color: context.colors.surface,
            borderRadius: BorderRadius.circular(AppRadius.md),
            border: Border.all(color: context.nyaya.cardBorder),
          ),
          child: Material(
            type: MaterialType.transparency,
            child: Column(
              children: [
                for (final (i, (icon, title, desc)) in laws.indexed) ...[
                  if (i > 0) Divider(height: 1, indent: 76, color: context.nyaya.cardBorder),
                  _LawRow(icon: icon, title: title, desc: desc, onTap: () => _askAbout(context, title)),
                ],
              ],
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        Container(
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            color: context.colors.surfaceContainer,
            borderRadius: BorderRadius.circular(AppRadius.md),
          ),
          child: Material(
            type: MaterialType.transparency,
            child: _LawRow(
              icon: Icons.description_outlined,
              title: l.lawLegacyTitle,
              desc: l.lawLegacyDesc,
              badge: l.exploreLegacy,
              onTap: () => _askAbout(context, l.lawLegacyTitle),
            ),
          ),
        ),
      ],
    );
  }
}

class _LawRow extends StatelessWidget {
  const _LawRow({required this.icon, required this.title, required this.desc, required this.onTap, this.badge});

  final IconData icon;
  final String title;
  final String desc;
  final String? badge;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(AppSpacing.md, 14, AppSpacing.sm, 14),
        child: Row(
          children: [
            SizedBox(width: 44, child: Icon(icon, size: 34, color: context.colors.primary)),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: _serif(context, 18, display: false)),
                  const SizedBox(height: 3),
                  Text(desc, style: context.text.bodyMedium?.copyWith(color: context.nyaya.textSecondary)),
                ],
              ),
            ),
            if (badge != null)
              Container(
                margin: const EdgeInsets.only(left: AppSpacing.sm),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  color: context.colors.surfaceContainerHigh,
                  borderRadius: BorderRadius.circular(AppRadius.xl),
                  border: Border.all(color: context.colors.outline),
                ),
                child: Text(badge!, style: context.text.labelMedium?.copyWith(color: context.nyaya.textSecondary)),
              ),
            Icon(Icons.chevron_right_rounded, color: context.colors.onSurface),
          ],
        ),
      ),
    );
  }
}
