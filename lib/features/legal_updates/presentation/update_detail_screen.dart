import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:material_ui/material_ui.dart';

import '../../../app/router.dart';
import '../../../core/l10n/l10n.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/chunky_button.dart';
import '../../../core/widgets/common.dart';
import '../../quiz/presentation/source_line.dart';
import '../data/legal_updates_repository.dart';
import 'updates_screen.dart';

class UpdateDetailScreen extends ConsumerWidget {
  const UpdateDetailScreen({super.key, required this.id});

  final String id;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final all = ref.watch(legalUpdatesProvider).value;
    final update = all?.where((u) => u.id == id).firstOrNull;

    if (update == null) {
      return Scaffold(
        appBar: AppBar(),
        body: Center(child: all == null ? const CircularProgressIndicator() : Text(l.updatesEmpty)),
      );
    }

    final c = update.category;
    final date = DateFormat.yMMMMd(Localizations.localeOf(context).languageCode).format(update.date);
    final isEnglishUi = Localizations.localeOf(context).languageCode == 'en';

    return Scaffold(
      appBar: AppBar(),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(AppSpacing.page, 0, AppSpacing.page, AppSpacing.xl),
        children: [
          Row(
            children: [
              Icon(c.icon, size: 18, color: c.tint(context)),
              const SizedBox(width: 6),
              Text(
                c.label(l).toUpperCase(),
                style: context.text.labelMedium?.copyWith(
                  color: c.tint(context),
                  fontWeight: FontWeight.w800,
                  letterSpacing: context.tracking(0.8),
                ),
              ),
              const Spacer(),
              if (!isEnglishUi)
                Text(l.updatesInEnglish, style: context.text.labelSmall?.copyWith(color: context.nyaya.textSecondary)),
            ],
          ),
          const SizedBox(height: 12),
          Text(update.title, style: context.text.headlineMedium?.copyWith(height: 1.2)),
          const SizedBox(height: 8),
          Text(
            '$date · ${l.updatesReadTime(update.readMinutes)}',
            style: context.text.bodyMedium?.copyWith(color: context.nyaya.textSecondary),
          ),
          const SizedBox(height: AppSpacing.lg),
          Text(update.summary, style: context.text.bodyLarge?.copyWith(height: 1.6)),
          const SizedBox(height: AppSpacing.lg),
          NyayaCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(l.updatesKeyPoints, style: context.text.titleMedium),
                const SizedBox(height: 10),
                for (final p in update.keyPoints)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.only(top: 2),
                          child: Icon(Icons.check_circle_rounded, size: 18, color: context.nyaya.success),
                        ),
                        const SizedBox(width: 10),
                        Expanded(child: Text(p, style: context.text.bodyMedium?.copyWith(height: 1.5))),
                      ],
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          NyayaCard(
            color: context.colors.secondaryContainer.withValues(alpha: 0.5),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.lightbulb_rounded, color: AppPalette.ochreText),
                    const SizedBox(width: 8),
                    Text(l.updatesWhyItMatters, style: context.text.titleMedium),
                  ],
                ),
                const SizedBox(height: 8),
                Text(update.whyItMatters, style: context.text.bodyMedium?.copyWith(height: 1.5)),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            '${l.updatesSource}: ${update.source}',
            style: context.text.bodySmall?.copyWith(color: context.nyaya.textSecondary),
          ),
          if (update.sourceUrl != null) Align(alignment: AlignmentDirectional.centerStart, child: SourceLine(reference: '', url: update.sourceUrl)),
          const SizedBox(height: AppSpacing.lg),
          ChunkyButton(
            label: l.updatesAskAi,
            icon: Icons.auto_awesome,
            onPressed: () {
              final q = 'Explain in simple terms: ${update.title}';
              context.go('${Routes.chat}?q=${Uri.encodeQueryComponent(q)}');
            },
          ),
        ],
      ),
    );
  }
}
