import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../../app/router.dart';
import '../../../core/l10n/l10n.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/pressable.dart';

/// A soft premium offer that opens the paywall when tapped.
class PremiumBanner extends StatelessWidget {
  const PremiumBanner({super.key});

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return Pressable(
      onTap: () => context.push(Routes.premium),
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(borderRadius: BorderRadius.circular(AppRadius.lg), color: AppPalette.sand),
        child: Row(
          children: [
            const Icon(Icons.workspace_premium_rounded, size: 36, color: AppPalette.deepEarth),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(l.homeGoPremium, style: context.text.titleMedium?.copyWith(color: AppPalette.deepEarth)),
                  Text(l.homeGoPremiumSub, style: context.text.bodySmall?.copyWith(color: AppPalette.deepEarth)),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_rounded, color: AppPalette.deepEarth),
          ],
        ),
      ),
    );
  }
}
