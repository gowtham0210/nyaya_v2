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
import '../../search/presentation/search_screen.dart' show searchMatches;
import '../data/legal_updates_repository.dart';
import 'updates_screen.dart';

enum _Status { all, unread, read }

/// "My Library": the updates the learner saved, with a search, Unread / Read
/// views, one collection per category and the most recently saved first.
/// Shown in place of the list when the Saved pill is chosen.
class SavedLibrary extends ConsumerStatefulWidget {
  const SavedLibrary({super.key, required this.updates});

  /// Every published update; the saved ones are picked from it.
  final List<LegalUpdate> updates;

  @override
  ConsumerState<SavedLibrary> createState() => _SavedLibraryState();
}

class _SavedLibraryState extends ConsumerState<SavedLibrary> {
  final _query = TextEditingController();
  _Status _status = _Status.all;
  UpdateCategory? _collection;

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final savedIds = ref.watch(savedUpdatesProvider);
    final read = ref.watch(readUpdatesProvider);
    final byId = {for (final u in widget.updates) u.id: u};
    // The set keeps the order they were saved in: newest last.
    final saved = [
      for (final id in savedIds.toList().reversed)
        if (byId[id] != null) byId[id]!,
    ];
    final unread = saved.where((u) => !read.contains(u.id)).length;

    final q = _query.text.trim();
    final shown = [
      for (final u in saved)
        if ((_collection == null || u.category == _collection) &&
            switch (_status) {
              _Status.all => true,
              _Status.unread => !read.contains(u.id),
              _Status.read => read.contains(u.id),
            } &&
            (q.isEmpty || searchMatches(q, [u.title, u.summary, u.category.label(l)])))
          u,
    ];
    final collections = [
      for (final c in UpdateCategory.values) (category: c, count: saved.where((u) => u.category == c).length),
    ].where((e) => e.count > 0).toList();

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: AppSpacing.sm),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.page),
            child: TextField(
              controller: _query,
              textInputAction: TextInputAction.search,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                hintText: l.librarySearchHint,
                prefixIcon: const Icon(Icons.search_rounded),
                suffixIcon: q.isEmpty
                    ? null
                    : IconButton(
                        tooltip: MaterialLocalizations.of(context).deleteButtonTooltip,
                        onPressed: () => setState(_query.clear),
                        icon: const Icon(Icons.close_rounded),
                      ),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.page),
            child: SizedBox(
              height: 48,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (final (i, (status, icon, label)) in [
                    (_Status.all, Icons.bookmark_rounded, l.libraryAll(saved.length)),
                    (_Status.unread, Icons.circle, l.libraryUnread(unread)),
                    (_Status.read, Icons.check_rounded, l.libraryRead(saved.length - unread)),
                  ].indexed) ...[
                    if (i > 0) const SizedBox(width: 8),
                    Expanded(
                      child: FilterPill(
                        icon: icon,
                        iconSize: icon == Icons.circle ? 10 : 18,
                        label: label,
                        compact: true,
                        selected: _status == status,
                        onTap: () => setState(() => _status = status),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          _Heading(l.libraryCollections),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.page),
            child: LayoutBuilder(
              builder: (context, box) {
                const gap = 12.0;
                final width = (box.maxWidth - gap) / 2;
                return Wrap(
                  spacing: gap,
                  runSpacing: gap,
                  children: [
                    for (final e in collections)
                      SizedBox(
                        width: width,
                        child: _CollectionCard(
                          category: e.category,
                          count: e.count,
                          selected: _collection == e.category,
                          onTap: () => setState(() => _collection = _collection == e.category ? null : e.category),
                        ),
                      ),
                  ],
                );
              },
            ),
          ),
          _Heading(l.libraryRecent),
          if (shown.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.page),
              child: Text(
                l.libraryNoMatches,
                style: context.text.bodyLarge?.copyWith(color: context.nyaya.textSecondary),
              ),
            )
          else
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.page),
              child: Column(
                children: [
                  for (final u in shown)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: _SavedRow(update: u, isRead: read.contains(u.id)),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _Heading extends StatelessWidget {
  const _Heading(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    final color = context.isDark ? context.colors.primary : AppPalette.terracottaDeep;
    return Padding(
      padding: const EdgeInsets.fromLTRB(AppSpacing.page, AppSpacing.lg, AppSpacing.page, AppSpacing.sm),
      child: Semantics(
        header: true,
        child: Text(text, style: AppTheme.serif(TextStyle(fontSize: 22, height: 1.15, color: color), display: false)),
      ),
    );
  }
}

class _CollectionCard extends StatelessWidget {
  const _CollectionCard({
    required this.category,
    required this.count,
    required this.selected,
    required this.onTap,
  });

  final UpdateCategory category;
  final int count;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final tint = category.tint(context);
    return Semantics(
      button: true,
      selected: selected,
      child: Pressable(
        onTap: onTap,
        child: Container(
          constraints: const BoxConstraints(minHeight: 76),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: selected ? context.colors.primary.withValues(alpha: 0.08) : context.colors.surface,
            borderRadius: BorderRadius.circular(AppRadius.lg),
            border: Border.all(
              color: selected ? context.colors.primary : context.nyaya.cardBorder,
              width: selected ? 1.5 : 1,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(color: category.color.withValues(alpha: 0.12), shape: BoxShape.circle),
                child: Icon(category.icon, color: tint, size: 22),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      category.label(l),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: AppTheme.serif(
                        TextStyle(fontSize: 15, height: 1.2, color: context.colors.onSurface),
                        display: false,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      l.libraryUpdateCount(count),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: context.text.labelSmall?.copyWith(color: context.nyaya.textSecondary),
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

/// One saved update: picture, title, date, Unread / Read and the bookmark to remove it.
class _SavedRow extends ConsumerWidget {
  const _SavedRow({required this.update, required this.isRead});

  final LegalUpdate update;
  final bool isRead;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final n = context.nyaya;
    final date = DateFormat.yMMMd(Localizations.localeOf(context).languageCode).format(update.date);
    return NyayaCard(
      onTap: () => context.push(Routes.update(update.id)),
      padding: const EdgeInsets.all(10),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(AppRadius.md),
            child: SizedBox(width: 84, height: 84, child: UpdatePicture(update: update)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  update.title,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: AppTheme.serif(
                    TextStyle(fontSize: 15, height: 1.25, color: context.colors.onSurface),
                    display: false,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(Icons.calendar_today_outlined, size: 14, color: n.textSecondary),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        '$date · ${l.updatesReadTime(update.readMinutes)}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: context.text.labelSmall?.copyWith(color: n.textSecondary),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                  decoration: BoxDecoration(
                    color: isRead ? null : n.successContainer,
                    borderRadius: BorderRadius.circular(20),
                    border: isRead ? Border.all(color: n.cardBorder) : null,
                  ),
                  child: Text(
                    isRead ? l.libraryReadBadge : l.libraryUnreadBadge,
                    style: context.text.labelSmall?.copyWith(
                      color: isRead ? n.textSecondary : n.success,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Semantics(
            button: true,
            toggled: true,
            label: l.updatesUnsave,
            child: Pressable(
              onTap: () => ref.read(savedUpdatesProvider.notifier).toggle(update.id),
              scale: 0.85,
              child: SizedBox.square(
                dimension: 48,
                child: Icon(Icons.bookmark_rounded, color: context.colors.primary),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
