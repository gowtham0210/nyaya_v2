import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/l10n/l10n.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/common.dart';
import '../../profile/application/profile_controller.dart';
import '../data/constitution_repository.dart';
import '../domain/constitution_edition.dart';
import 'constitution_open.dart';

/// The Constitution of India as published on India Code: every edition it
/// lists, each opening its official PDF outside the app. Separate from the
/// Constitution chapter on the Journey map.
class ConstitutionScreen extends ConsumerWidget {
  const ConstitutionScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final async = ref.watch(constitutionProvider);
    final library = async.value;

    return Scaffold(
      appBar: AppBar(),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(AppSpacing.page, 0, AppSpacing.page, AppSpacing.xl),
        children: [
          Semantics(
            header: true,
            child: Text(
              l.constitutionTitle,
              style: AppTheme.serif(TextStyle(fontSize: 30, height: 1.15, color: context.colors.onSurface)),
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            l.constitutionAttribution,
            style: context.text.bodyLarge?.copyWith(color: context.nyaya.textSecondary, height: 1.4),
          ),
          const SizedBox(height: 6),
          Text(l.constitutionNotice, style: context.text.bodyMedium?.copyWith(height: 1.4)),
          const SizedBox(height: 6),
          Text(
            l.constitutionOpensExternally,
            style: context.text.bodySmall?.copyWith(color: context.nyaya.textSecondary),
          ),
          const SizedBox(height: AppSpacing.md),
          if (library != null && library.maybeOutOfDate) ...[
            _StaleNotice(text: l.constitutionStale),
            const SizedBox(height: AppSpacing.md),
          ],
          if (library != null)
            ..._content(context, ref, library)
          else if (async.hasError)
            _Message(
              text: l.constitutionLoadFailed,
              icon: Icons.cloud_off_rounded,
              onRetry: () => ref.invalidate(constitutionProvider),
            )
          else
            const Padding(
              padding: EdgeInsets.symmetric(vertical: AppSpacing.xl),
              child: Center(child: CircularProgressIndicator()),
            ),
        ],
      ),
    );
  }

  List<Widget> _content(BuildContext context, WidgetRef ref, ConstitutionLibrary library) {
    final l = context.l10n;
    if (library.isEmpty) {
      return [
        _Message(
          text: l.constitutionEmpty,
          icon: Icons.menu_book_outlined,
          onRetry: () => ref.invalidate(constitutionProvider),
        ),
      ];
    }
    final app = ref.watch(profileProvider.select((p) => p.language));
    final mine = library.forLanguage(app.code);
    final original = library.original;
    final collection = library.collectionUri;

    return [
      if (mine.edition != null) ...[
        _SectionTitle(l.constitutionYourLanguage),
        if (mine.fellBack)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.sm),
            child: Text(
              l.constitutionFallbackEnglish(app.englishName),
              style: context.text.bodyMedium?.copyWith(color: context.nyaya.textSecondary),
            ),
          ),
        _Group(children: [_EditionRow(edition: mine.edition!)]),
        const SizedBox(height: AppSpacing.lg),
      ],
      if (library.editions.isNotEmpty) ...[
        _SectionTitle(l.constitutionAllEditions),
        _Group(children: [for (final e in library.editions) _EditionRow(edition: e)]),
        const SizedBox(height: AppSpacing.lg),
      ],
      if (original != null) ...[
        _SectionTitle(l.constitutionOriginalSection),
        _Group(children: [_EditionRow(edition: original)]),
        const SizedBox(height: AppSpacing.lg),
      ],
      if (collection != null)
        Align(
          alignment: AlignmentDirectional.centerStart,
          child: TextButton.icon(
            onPressed: () => openSourcePage(context, ref, collection),
            icon: const Icon(Icons.open_in_new_rounded, size: 18),
            label: Text(l.constitutionSourceLink),
          ),
        ),
    ];
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: AppSpacing.sm),
    child: Semantics(
      header: true,
      child: Text(text, style: AppTheme.serif(TextStyle(fontSize: 22, height: 1.2, color: context.colors.onSurface))),
    ),
  );
}

/// A bordered list of rows, like Home's Core Laws.
class _Group extends StatelessWidget {
  const _Group({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Container(
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
          for (final (i, c) in children.indexed) ...[if (i > 0) Divider(height: 1, color: context.nyaya.cardBorder), c],
        ],
      ),
    ),
  );
}

/// One edition: its name in English and in its own language, then what the
/// API says about the file. Tapping opens the PDF (after a warning when large
/// or scanned). Long names wrap instead of overflowing.
class _EditionRow extends ConsumerWidget {
  const _EditionRow({required this.edition});

  final ConstitutionEdition edition;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final muted = context.nyaya.textSecondary;
    final native = edition.nativeName;
    // The original copy is a document, not a language: it shows its title.
    final heading = edition.languageCode == null ? edition.title : edition.languageName;
    final locale = Localizations.localeOf(context).languageCode;
    final facts = <String>[
      ?edition.script,
      l.constitutionSize(formatFileSize(edition.sizeBytes)),
      if (edition.modified != null) l.constitutionUpdated(DateFormat.yMMMd(locale).format(edition.modified!)),
    ];

    return InkWell(
      onTap: () => openEdition(context, ref, edition),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 64),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(AppSpacing.md, 12, AppSpacing.sm, 12),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(heading, style: context.text.titleMedium),
                    if (native != null && native != heading)
                      Text(native, style: context.text.bodyLarge?.copyWith(height: 1.3)),
                    const SizedBox(height: 4),
                    Text(facts.join(' · '), style: context.text.bodySmall?.copyWith(color: muted, height: 1.35)),
                    if (edition.large || edition.scanned) ...[
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 6,
                        runSpacing: 4,
                        children: [
                          if (edition.large) _Badge(icon: Icons.data_usage_rounded, label: l.constitutionLarge),
                          if (edition.scanned) _Badge(icon: Icons.image_search_rounded, label: l.constitutionScanned),
                        ],
                      ),
                    ],
                    // Only shown when the API provides reviewed wording.
                    if (edition.authorityNote != null) ...[
                      const SizedBox(height: 6),
                      Text(edition.authorityNote!, style: context.text.bodySmall?.copyWith(color: muted)),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.xs),
              Icon(Icons.open_in_new_rounded, size: 20, color: context.colors.primary),
            ],
          ),
        ),
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
    decoration: BoxDecoration(
      color: context.colors.surfaceContainerHigh,
      borderRadius: BorderRadius.circular(AppRadius.xl),
      border: Border.all(color: context.colors.outline),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: AppPalette.ochreText),
        const SizedBox(width: 4),
        Flexible(
          child: Text(label, style: context.text.labelMedium?.copyWith(color: context.colors.onSurface)),
        ),
      ],
    ),
  );
}

class _StaleNotice extends StatelessWidget {
  const _StaleNotice({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) => NyayaCard(
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Icon(Icons.info_outline_rounded, size: 20, color: AppPalette.ochreText),
        const SizedBox(width: 10),
        Expanded(child: Text(text, style: context.text.bodyMedium)),
      ],
    ),
  );
}

class _Message extends StatelessWidget {
  const _Message({required this.text, required this.icon, required this.onRetry});

  final String text;
  final IconData icon;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: AppSpacing.lg),
    child: Column(
      children: [
        Icon(icon, size: 36, color: context.nyaya.textSecondary),
        const SizedBox(height: AppSpacing.sm),
        Text(text, textAlign: TextAlign.center, style: context.text.bodyLarge),
        const SizedBox(height: AppSpacing.md),
        FilledButton(onPressed: onRetry, child: Text(context.l10n.commonRetry)),
      ],
    ),
  );
}
