import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:material_ui/material_ui.dart';

import '../../../app/router.dart';
import '../../../core/api/api_client.dart';
import '../../../core/l10n/l10n.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/common.dart';
import '../../quiz/presentation/source_line.dart';
import '../data/daily_tip_repository.dart';

/// The whole tip: title, explanation, the Act and section it rests on, a link
/// to the official text and when it was last checked. [initial] is the tip
/// Home already loaded; opened from a link it is fetched by [id].
class DailyTipDetailScreen extends ConsumerWidget {
  const DailyTipDetailScreen({super.key, required this.id, this.initial});

  final String id;
  final DailyTip? initial;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final loaded = initial?.id == id ? initial : null;
    final async = loaded == null ? ref.watch(dailyTipByIdProvider(id)) : AsyncData(loaded);

    return Scaffold(
      appBar: AppBar(
        // A link can open this with nothing behind it.
        leading: context.canPop()
            ? null
            : IconButton(icon: const Icon(Icons.close_rounded), onPressed: () => context.go(Routes.home)),
      ),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) {
          // 404: withdrawn, not yet due, or never existed.
          final gone = e is ApiException && e.status == 404;
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.page),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(gone ? l.dailyTipUnavailable : l.dailyTipLoadFailed, textAlign: TextAlign.center),
                  if (!gone) ...[
                    const SizedBox(height: AppSpacing.md),
                    FilledButton(
                      onPressed: () => ref.invalidate(dailyTipByIdProvider(id)),
                      child: Text(l.commonRetry),
                    ),
                  ],
                ],
              ),
            ),
          );
        },
        data: (tip) => _TipBody(tip: tip),
      ),
    );
  }
}

class _TipBody extends StatelessWidget {
  const _TipBody({required this.tip});

  final DailyTip tip;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final locale = Localizations.localeOf(context).languageCode;
    final verified = DateFormat.yMMMMd(locale).format(tip.lastVerified);
    return ListView(
      padding: const EdgeInsets.fromLTRB(AppSpacing.page, 0, AppSpacing.page, AppSpacing.xl),
      children: [
        Row(
          children: [
            const Icon(Icons.lightbulb_rounded, size: 18, color: AppPalette.ochreText),
            const SizedBox(width: 6),
            Text(
              l.dailyTipLabel.toUpperCase(),
              style: context.text.labelMedium?.copyWith(
                color: AppPalette.ochreText,
                fontWeight: FontWeight.w800,
                letterSpacing: context.tracking(0.8),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Semantics(header: true, child: Text(tip.title, style: context.text.headlineMedium?.copyWith(height: 1.2))),
        const SizedBox(height: AppSpacing.md),
        Text(tip.explanation, style: context.text.bodyLarge?.copyWith(height: 1.6)),
        const SizedBox(height: AppSpacing.lg),
        NyayaCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(l.dailyTipLegalReference, style: context.text.titleMedium),
              const SizedBox(height: 6),
              Text(tip.legalReference, style: context.text.bodyMedium?.copyWith(height: 1.5)),
              const SizedBox(height: 4),
              SourceLine(reference: '', url: tip.sourceUrl),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        Text(
          l.dailyTipLastVerified(verified),
          style: context.text.bodySmall?.copyWith(color: context.nyaya.textSecondary),
        ),
      ],
    );
  }
}
