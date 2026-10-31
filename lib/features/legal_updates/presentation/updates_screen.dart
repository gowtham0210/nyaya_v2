import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:material_ui/material_ui.dart';

import '../../../app/router.dart';
import '../../../core/l10n/l10n.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/common.dart';
import '../../../core/widgets/pressable.dart';
import '../data/legal_updates_repository.dart';

extension UpdateCategoryX on UpdateCategory {
  String label(AppLocalizations l) => switch (this) {
    UpdateCategory.supremeCourt => l.updatesSupremeCourt,
    UpdateCategory.highCourts => l.updatesHighCourts,
    UpdateCategory.legislation => l.updatesLegislation,
    UpdateCategory.explainer => l.updatesExplainer,
  };

  IconData get icon => switch (this) {
    UpdateCategory.supremeCourt => Icons.account_balance_rounded,
    UpdateCategory.highCourts => Icons.balance_rounded,
    UpdateCategory.legislation => Icons.chrome_reader_mode_rounded,
    UpdateCategory.explainer => Icons.lightbulb_rounded,
  };

  /// Outline icon for the filter chips.
  IconData get chipIcon => switch (this) {
    UpdateCategory.supremeCourt => Icons.account_balance_outlined,
    UpdateCategory.highCourts => Icons.balance_outlined,
    UpdateCategory.legislation => Icons.article_outlined,
    UpdateCategory.explainer => Icons.lightbulb_outline_rounded,
  };

  Color get color => switch (this) {
    UpdateCategory.supremeCourt => AppPalette.ink,
    UpdateCategory.highCourts => AppPalette.slate,
    UpdateCategory.legislation => AppPalette.moss,
    UpdateCategory.explainer => AppPalette.burntClay,
  };

  /// [color] lifted for text and icons on dark surfaces.
  Color tint(BuildContext context) => context.isDark ? Color.lerp(color, Colors.white, 0.45)! : color;

  /// Journey painting a card shows until its own thumbnail is added.
  String get fallbackImage => switch (this) {
    UpdateCategory.supremeCourt => 'assets/images/journey_constitution_landmark.webp',
    UpdateCategory.highCourts => 'assets/images/journey_criminal_landmark.webp',
    UpdateCategory.legislation => 'assets/images/journey_rights_prop.webp',
    UpdateCategory.explainer => 'assets/images/journey_constitution_prop.webp',
  };
}

class UpdatesScreen extends ConsumerStatefulWidget {
  const UpdatesScreen({super.key});

  @override
  ConsumerState<UpdatesScreen> createState() => _UpdatesScreenState();
}

class _UpdatesScreenState extends ConsumerState<UpdatesScreen> {
  UpdateCategory? _filter;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final async = ref.watch(legalUpdatesProvider);

    return Scaffold(
      body: RefreshIndicator(
        onRefresh: () => ref.refresh(legalUpdatesProvider.future),
        child: CustomScrollView(
          slivers: [
            const SliverToBoxAdapter(child: _Header()),
            SliverToBoxAdapter(
              child: SizedBox(
                height: 52,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: AppSpacing.page),
                  children: [
                    for (final c in [null, ...UpdateCategory.values])
                      Padding(
                        padding: const EdgeInsets.only(right: 10),
                        child: _FilterPill(
                          icon: c?.chipIcon ?? Icons.grid_view_rounded,
                          label: c == null ? l.updatesAll : c.label(l),
                          selected: _filter == c,
                          onTap: () => setState(() => _filter = c),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            ...async.when(
              loading: () => [const SliverFillRemaining(child: Center(child: CircularProgressIndicator()))],
              error: (e, _) => [
                SliverFillRemaining(
                  child: _Empty(
                    text: l.commonSomethingWrong,
                    action: l.commonRetry,
                    onAction: () => ref.invalidate(legalUpdatesProvider),
                  ),
                ),
              ],
              data: (all) {
                final items = [
                  for (final u in all)
                    if (_filter == null || u.category == _filter) u,
                ];
                if (items.isEmpty) return [SliverFillRemaining(child: _Empty(text: l.updatesEmpty))];
                return [
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(AppSpacing.page, AppSpacing.lg, AppSpacing.page, AppSpacing.xl),
                    sliver: SliverList.separated(
                      itemCount: items.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 14),
                      itemBuilder: (context, i) =>
                          UpdateTile(update: items[i]).animate().fadeIn(delay: (30 * i).ms).slideY(begin: 0.05),
                    ),
                  ),
                ];
              },
            ),
          ],
        ),
      ),
    );
  }
}

/// Serif title over a faded painting of the Supreme Court.
class _Header extends StatelessWidget {
  const _Header();

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final titleColor = context.isDark ? context.colors.primary : AppPalette.terracottaDeep;
    return Stack(
      children: [
        Positioned(
          top: MediaQuery.paddingOf(context).top + 4,
          right: -20,
          width: 210,
          child: IgnorePointer(
            child: Opacity(
              opacity: context.isDark ? 0.22 : 0.9,
              child: ShaderMask(
                blendMode: BlendMode.dstIn,
                shaderCallback: (bounds) => const LinearGradient(
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                  colors: [Colors.transparent, Colors.black],
                  stops: [0, 0.45],
                ).createShader(bounds),
                child: Image.asset(
                  'assets/images/journey_constitution_landmark.webp',
                  fit: BoxFit.fitWidth,
                  excludeFromSemantics: true,
                  errorBuilder: (_, _, _) => const SizedBox.shrink(),
                ),
              ),
            ),
          ),
        ),
        SafeArea(
          bottom: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(AppSpacing.page, AppSpacing.lg, AppSpacing.page, AppSpacing.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 28),
                Text(l.updatesTitle, style: AppTheme.serif(TextStyle(fontSize: 42, height: 1.05, color: titleColor))),
                const SizedBox(height: 6),
                Text(
                  l.updatesSubtitle,
                  style: AppTheme.serif(
                    TextStyle(fontSize: 16, height: 1.3, color: context.colors.onSurface),
                    display: false,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _FilterPill extends StatelessWidget {
  const _FilterPill({required this.icon, required this.label, required this.selected, required this.onTap});

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final fg = selected ? context.colors.onPrimary : context.colors.onSurface;
    return Semantics(
      button: true,
      selected: selected,
      child: Pressable(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 18),
          decoration: BoxDecoration(
            color: selected ? context.colors.primary : context.colors.surface,
            borderRadius: BorderRadius.circular(30),
            border: Border.all(color: selected ? context.colors.primary : context.nyaya.cardBorder),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 22, color: fg),
              const SizedBox(width: 10),
              Text(label, style: AppTheme.serif(TextStyle(fontSize: 16, color: fg), display: false)),
            ],
          ),
        ),
      ),
    );
  }
}

/// News card: category tag, serif headline, date and read time, with a
/// thumbnail carrying a save button in its notched corner.
class UpdateTile extends ConsumerWidget {
  const UpdateTile({super.key, required this.update});

  final LegalUpdate update;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final c = update.category;
    final tint = c.tint(context);
    final muted = context.nyaya.textSecondary;
    final date = DateFormat.yMMMd(Localizations.localeOf(context).languageCode).format(update.date);
    return NyayaCard(
      onTap: () => context.push(Routes.update(update.id)),
      padding: const EdgeInsets.fromLTRB(AppSpacing.md, 14, 14, 14),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(color: c.color.withValues(alpha: 0.12), shape: BoxShape.circle),
                      child: Icon(c.icon, color: tint, size: 22),
                    ),
                    const SizedBox(width: 12),
                    Flexible(
                      child: Text(
                        c.label(l).toUpperCase(),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: context.text.labelSmall?.copyWith(
                          color: tint,
                          fontWeight: FontWeight.w700,
                          letterSpacing: context.tracking(1.6),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  update.title,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: AppTheme.serif(
                    TextStyle(fontSize: 17, height: 1.25, color: context.colors.onSurface),
                    display: false,
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Icon(Icons.calendar_today_outlined, size: 15, color: muted),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        '$date · ${l.updatesReadTime(update.readMinutes)}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: context.text.bodySmall?.copyWith(color: muted),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          _Thumbnail(update: update),
        ],
      ),
    );
  }
}

class _Thumbnail extends ConsumerWidget {
  const _Thumbnail({required this.update});

  final LegalUpdate update;

  static const width = 118.0;
  static const height = 104.0;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final saved = ref.watch(savedUpdatesProvider).contains(update.id);
    final surface = context.colors.surface;
    return SizedBox(
      width: width,
      height: height,
      child: Stack(
        // The notch sits 1 point past the corner; don't trim its tap area.
        clipBehavior: Clip.none,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(AppRadius.md),
            child: Image.asset(
              update.image,
              width: width,
              height: height,
              fit: BoxFit.cover,
              excludeFromSemantics: true,
              errorBuilder: (_, _, _) => UpdateFallbackArt(category: update.category),
            ),
          ),
          // Notch cut into the corner, holding the save button.
          Positioned(
            top: -1,
            right: -1,
            child: Container(
              padding: const EdgeInsets.fromLTRB(2, 0, 0, 2),
              decoration: BoxDecoration(
                color: surface,
                borderRadius: const BorderRadius.only(bottomLeft: Radius.circular(AppRadius.md)),
              ),
              child: Semantics(
                button: true,
                toggled: saved,
                label: saved ? l.updatesUnsave : l.updatesSave,
                child: Pressable(
                  onTap: () => ref.read(savedUpdatesProvider.notifier).toggle(update.id),
                  scale: 0.85,
                  // 48 x 48 tap area around the 34 point circle.
                  child: SizedBox.square(
                    dimension: 48,
                    child: Center(
                      child: Container(
                        width: 34,
                        height: 34,
                        decoration: BoxDecoration(
                          color: context.colors.surfaceContainerHigh.withValues(alpha: 0.6),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          saved ? Icons.bookmark_rounded : Icons.bookmark_border_rounded,
                          size: 20,
                          color: context.colors.primary,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// The category's Journey painting on a sand tile.
class UpdateFallbackArt extends StatelessWidget {
  const UpdateFallbackArt({super.key, required this.category});

  final UpdateCategory category;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: context.colors.surfaceContainerHigh,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(6, 14, 6, 4),
        child: Image.asset(
          category.fallbackImage,
          fit: BoxFit.contain,
          alignment: Alignment.bottomCenter,
          excludeFromSemantics: true,
          errorBuilder: (_, _, _) => Center(child: Icon(category.icon, size: 36, color: category.tint(context))),
        ),
      ),
    );
  }
}

class _Empty extends StatelessWidget {
  const _Empty({required this.text, this.action, this.onAction});

  final String text;
  final String? action;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.inbox_rounded, size: 56, color: context.nyaya.locked),
            const SizedBox(height: 12),
            Text(text, textAlign: TextAlign.center, style: context.text.bodyLarge),
            if (action != null) ...[
              const SizedBox(height: 12),
              FilledButton(onPressed: onAction, child: Text(action!)),
            ],
          ],
        ),
      ),
    );
  }
}
