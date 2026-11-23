import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../../app/router.dart';
import '../../../core/l10n/l10n.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/common.dart';
import '../data/daily_tip_repository.dart';

/// Home: today's legal tip. Nothing shows when none is published for today,
/// so Home never has a hole in it; a failed load offers a retry.
class DailyTipCard extends ConsumerWidget {
  const DailyTipCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final async = ref.watch(dailyTipProvider);
    // Keep showing the last tip while a refresh is under way.
    final tip = async.value;

    if (tip == null && async.isLoading) {
      return const Padding(
        padding: EdgeInsets.only(top: AppSpacing.lg),
        child: NyayaCard(
          child: SizedBox(height: 96, child: Center(child: CircularProgressIndicator(strokeWidth: 2.5))),
        ),
      );
    }
    if (async.hasError && tip == null) {
      return Padding(
        padding: const EdgeInsets.only(top: AppSpacing.lg),
        child: NyayaCard(
          child: Row(
            children: [
              Icon(Icons.cloud_off_rounded, color: context.nyaya.textSecondary),
              const SizedBox(width: 12),
              Expanded(child: Text(l.dailyTipLoadFailed, style: context.text.bodyMedium)),
              TextButton(onPressed: () => ref.invalidate(dailyTipProvider), child: Text(l.commonRetry)),
            ],
          ),
        ),
      );
    }
    if (tip == null) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.lg),
      child: NyayaCard(
        onTap: () => context.push(Routes.dailyTip(tip.id), extra: tip),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.lightbulb_rounded, size: 18, color: AppPalette.ochreText),
                const SizedBox(width: 6),
                Text(
                  l.dailyTipLabel.toUpperCase(),
                  style: context.text.labelSmall?.copyWith(
                    color: AppPalette.ochreText,
                    fontWeight: FontWeight.w800,
                    letterSpacing: context.tracking(1.4),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Semantics(header: true, child: Text(tip.title, style: context.text.titleMedium)),
            const SizedBox(height: 4),
            Text(
              tip.summary,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: context.text.bodyMedium?.copyWith(color: context.nyaya.textSecondary, height: 1.4),
            ),
            const SizedBox(height: 10),
            // The whole card opens the tip; this names the action.
            ExcludeSemantics(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    l.dailyTipReadMore,
                    style: context.text.labelLarge?.copyWith(color: context.colors.primary, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(width: 4),
                  Icon(Icons.arrow_forward_rounded, size: 18, color: context.colors.primary),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
