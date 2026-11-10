import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../../app/router.dart';
import '../../../core/l10n/l10n.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../home/presentation/widgets/explore_sections.dart';
import '../../journey/domain/journey.dart';
import '../../journey/presentation/journey_screen.dart';
import '../../legal_updates/data/legal_updates_repository.dart';
import '../../legal_updates/presentation/updates_screen.dart';

/// Searches what the app already holds, in the learner's language: Journey
/// topics, the main laws and the legal updates. The last row always offers
/// to ask the AI, so a search never ends empty-handed.
class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key});

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  final _query = TextEditingController();

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  /// Every word of the query must appear somewhere in [fields].
  static bool _matches(String query, List<String> fields) {
    final words = query.toLowerCase().split(RegExp(r'\s+')).where((w) => w.isNotEmpty);
    final haystack = fields.join(' ').toLowerCase();
    return words.every(haystack.contains);
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final q = _query.text.trim();
    final updates = ref.watch(legalUpdatesProvider).value ?? const <LegalUpdate>[];

    final topics = [
      for (final c in JourneyCatalog.chapters)
        if (q.isEmpty || _matches(q, [l.chapterTitle(c.id), l.chapterSubtitle(c.id)])) c,
    ];
    final laws = [
      for (final law in coreLaws(l))
        if (q.isNotEmpty && _matches(q, [law.title, law.desc])) law,
      if (q.isNotEmpty && _matches(q, [l.lawLegacyTitle, l.lawLegacyDesc]))
        (icon: Icons.description_outlined, title: l.lawLegacyTitle, desc: l.lawLegacyDesc, chapterId: legacyLawChapter),
    ];
    final news = [
      for (final u in updates)
        if (q.isNotEmpty && _matches(q, [u.title, u.category.label(l)])) u,
    ];
    final nothing = q.isNotEmpty && topics.isEmpty && laws.isEmpty && news.isEmpty;

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        title: TextField(
          controller: _query,
          autofocus: true,
          textInputAction: TextInputAction.search,
          decoration: InputDecoration(
            hintText: l.searchHint,
            border: InputBorder.none,
            enabledBorder: InputBorder.none,
            focusedBorder: InputBorder.none,
            filled: false,
          ),
          onChanged: (_) => setState(() {}),
          onSubmitted: (text) {
            if (text.trim().isNotEmpty && nothing) _askAi(text.trim());
          },
        ),
        actions: [
          if (q.isNotEmpty)
            IconButton(
              tooltip: MaterialLocalizations.of(context).deleteButtonTooltip,
              onPressed: () => setState(_query.clear),
              icon: const Icon(Icons.close_rounded),
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.only(bottom: AppSpacing.xl),
        children: [
          if (nothing)
            Padding(
              padding: const EdgeInsets.fromLTRB(AppSpacing.page, AppSpacing.lg, AppSpacing.page, AppSpacing.sm),
              child: Text(l.searchNoResults(q), style: context.text.bodyLarge),
            ),
          if (topics.isNotEmpty) ...[
            _Heading(l.searchTopics),
            for (final c in topics)
              ListTile(
                leading: Icon(c.icon, color: c.color),
                title: Text(l.chapterTitle(c.id)),
                subtitle: Text(l.chapterSubtitle(c.id), maxLines: 2, overflow: TextOverflow.ellipsis),
                onTap: () => _openChapter(c.id),
              ),
          ],
          if (laws.isNotEmpty) ...[
            _Heading(l.searchLaws),
            for (final law in laws)
              ListTile(
                leading: Icon(law.icon),
                title: Text(law.title),
                subtitle: Text(law.desc, maxLines: 2, overflow: TextOverflow.ellipsis),
                onTap: () => _openChapter(law.chapterId),
              ),
          ],
          if (news.isNotEmpty) ...[
            _Heading(l.searchUpdates),
            for (final u in news)
              ListTile(
                leading: Icon(u.category.icon, color: u.category.tint(context)),
                title: Text(u.title, maxLines: 2, overflow: TextOverflow.ellipsis),
                subtitle: Text(u.category.label(l)),
                onTap: () => context.push(Routes.update(u.id)),
              ),
          ],
          if (q.isNotEmpty) ...[
            const Divider(height: AppSpacing.lg),
            ListTile(
              leading: Icon(Icons.auto_awesome, color: context.colors.primary),
              title: Text(l.searchAskAi(q)),
              onTap: () => _askAi(q),
            ),
          ],
        ],
      ),
    );
  }

  void _openChapter(String chapterId) {
    context.pop();
    openJourneyChapter(context, ref, chapterId);
  }

  void _askAi(String q) {
    context.pop();
    context.go(Uri(path: Routes.chat, queryParameters: {'q': q}).toString());
  }
}

class _Heading extends StatelessWidget {
  const _Heading(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(AppSpacing.page, AppSpacing.md, AppSpacing.page, AppSpacing.xs),
      child: Semantics(
        header: true,
        child: Text(
          text.toUpperCase(),
          style: context.text.labelMedium?.copyWith(
            color: context.colors.primary,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.2,
          ),
        ),
      ),
    );
  }
}
