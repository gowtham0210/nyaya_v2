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
        UpdateCategory.highCourts => Icons.location_city_rounded,
        UpdateCategory.legislation => Icons.menu_book_rounded,
        UpdateCategory.explainer => Icons.lightbulb_rounded,
      };

  Color get color => switch (this) {
        UpdateCategory.supremeCourt => AppPalette.terracotta,
        UpdateCategory.highCourts => AppPalette.slate,
        UpdateCategory.legislation => AppPalette.moss,
        UpdateCategory.explainer => AppPalette.burntClay,
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
      body: SafeArea(
        bottom: false,
        child: RefreshIndicator(
          onRefresh: () => ref.refresh(legalUpdatesProvider.future),
          child: CustomScrollView(
            slivers: [
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(AppSpacing.page, AppSpacing.md, AppSpacing.page, 0),
                sliver: SliverToBoxAdapter(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(l.updatesTitle, style: context.text.headlineMedium),
                      Text(l.updatesSubtitle, style: context.text.bodyMedium?.copyWith(color: context.nyaya.textSecondary)),
                      const SizedBox(height: AppSpacing.md),
                    ],
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: SizedBox(
                  height: 44,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: AppSpacing.page),
                    children: [
                      for (final c in [null, ...UpdateCategory.values])
                        Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: ChoiceChip(
                            label: Text(c == null ? l.updatesAll : c.label(l)),
                            selected: _filter == c,
                            onSelected: (_) => setState(() => _filter = c),
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
                  final items = _filter == null ? all : all.where((u) => u.category == _filter).toList();
                  if (items.isEmpty) return [SliverFillRemaining(child: _Empty(text: l.updatesEmpty))];
                  return [
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(AppSpacing.page, AppSpacing.md, AppSpacing.page, AppSpacing.xl),
                      sliver: SliverList.separated(
                        itemCount: items.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 12),
                        itemBuilder: (context, i) => UpdateTile(update: items[i])
                            .animate()
                            .fadeIn(delay: (30 * i).ms)
                            .slideY(begin: 0.05),
                      ),
                    ),
                  ];
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class UpdateTile extends StatelessWidget {
  const UpdateTile({super.key, required this.update});

  final LegalUpdate update;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final c = update.category;
    final date = DateFormat.yMMMd(Localizations.localeOf(context).languageCode).format(update.date);
    return NyayaCard(
      onTap: () => context.push(Routes.update(update.id)),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: c.color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(c.icon, color: c.color),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  c.label(l).toUpperCase(),
                  style: context.text.labelSmall?.copyWith(color: c.color, fontWeight: FontWeight.w800, letterSpacing: 0.8),
                ),
                const SizedBox(height: 4),
                Text(update.title, style: context.text.titleSmall, maxLines: 3, overflow: TextOverflow.ellipsis),
                const SizedBox(height: 6),
                Text(
                  '$date · ${l.updatesReadTime(update.readMinutes)}',
                  style: context.text.bodySmall?.copyWith(color: context.nyaya.textSecondary),
                ),
              ],
            ),
          ),
        ],
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
