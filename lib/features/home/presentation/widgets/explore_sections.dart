import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../app/router.dart';
import '../../../../core/l10n/l10n.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../journey/application/journey_controller.dart';
import '../../../journey/domain/journey.dart';
import '../../../quiz/domain/quiz_models.dart';
import '../../../quiz/presentation/quiz_launcher.dart';
import 'law_illustration.dart';

/// Editorial serif used for Explore Law headings (DM Serif Display for large
/// titles, DM Serif Text for list rows).
TextStyle _serif(BuildContext context, double size, {bool display = true}) {
  final base = TextStyle(fontSize: size, height: 1.15, color: context.colors.onSurface);
  if (!AppTheme.useGoogleFonts) return base;
  return display ? GoogleFonts.dmSerifDisplay(textStyle: base) : GoogleFonts.dmSerifText(textStyle: base);
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
            Text(
              l.exploreSubtitle,
              style: context.text.bodyLarge?.copyWith(color: context.nyaya.textSecondary),
            ),
          ],
        ),
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
      (l.lawConstitutionTitle, l.lawConstitutionDesc, LawArt.court, 'constitution'),
      (l.lawBnsShort, l.lawBnsFeatured, LawArt.scales, 'criminal'),
      (l.lawEverydayTitle, l.lawEverydayFeatured, LawArt.people, 'everyday'),
    ];

    return Column(
      children: [
        SizedBox(
          height: 268,
          child: PageView(
            controller: _controller,
            onPageChanged: (i) => setState(() => _page = i),
            children: [
              for (final (title, desc, art, chapter) in slides)
                _FeaturedCard(
                  title: title,
                  desc: desc,
                  art: art,
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

class _FeaturedCard extends StatelessWidget {
  const _FeaturedCard({required this.title, required this.desc, required this.art, required this.onExplore});

  final String title;
  final String desc;
  final LawArt art;
  final VoidCallback onExplore;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: context.isDark ? context.colors.surfaceContainerHigh : context.colors.primaryContainer,
        borderRadius: BorderRadius.circular(AppRadius.lg),
      ),
      child: Stack(
        children: [
          Positioned(
            right: 0,
            bottom: 0,
            width: 200,
            height: 220,
            child: ExcludeSemantics(child: LawIllustration(art: art)),
          ),
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
        Row(
          children: [
            Expanded(child: Text(l.exploreCoreLaws, style: _serif(context, 26))),
            TextButton(
              onPressed: () => context.go(Routes.journey),
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                minimumSize: const Size(0, 36),
                textStyle: context.text.labelLarge?.copyWith(fontWeight: FontWeight.w600),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(l.exploreViewAll),
                  const SizedBox(width: 4),
                  const Icon(Icons.arrow_forward_rounded, size: 16),
                ],
              ),
            ),
          ],
        ),
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
