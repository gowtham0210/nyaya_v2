import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../app/router.dart';
import '../../../../core/l10n/l10n.dart';
import '../../../../core/storage/local_store.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/day.dart';
import '../../../../core/widgets/common.dart';
import '../../../profile/application/profile_controller.dart';
import '../../../quiz/presentation/quiz_launcher.dart';

class HomeHeader extends ConsumerWidget {
  const HomeHeader({super.key});

  String _greeting(BuildContext context, DateTime now) {
    final l = context.l10n;
    if (now.hour < 12) return l.greetingMorning;
    if (now.hour < 17) return l.greetingAfternoon;
    return l.greetingEvening;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final p = ref.watch(profileProvider);
    final now = ref.watch(clockProvider)();

    return SafeArea(
      bottom: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(AppSpacing.page, AppSpacing.sm, AppSpacing.sm, 0),
        child: Column(
          children: [
            Row(
              children: [
                GestureDetector(
                  onTap: () => context.push(Routes.settings),
                  child: InitialsAvatar(name: p.name, size: 46, ring: AppPalette.gold),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _greeting(context, now),
                        style: context.text.bodyMedium?.copyWith(color: context.nyaya.textSecondary),
                      ),
                      Text(
                        p.name.isEmpty ? l.appName : p.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: context.text.titleLarge,
                      ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: l.leaderboardTitle,
                  onPressed: () => context.push(Routes.leaderboard),
                  icon: const Icon(Icons.emoji_events_outlined),
                ),
                IconButton(
                  tooltip: l.settingsTitle,
                  onPressed: () => context.push(Routes.settings),
                  icon: const Icon(Icons.settings_outlined),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            Padding(
              padding: const EdgeInsets.only(right: AppSpacing.page - AppSpacing.sm),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  StatPill(
                    icon: Icons.local_fire_department_rounded,
                    value: '${p.streak}',
                    color: context.nyaya.streak,
                    semanticLabel: l.homeStreakDays(p.streak),
                    onTap: () => _snack(context, l.homeStreakDays(p.streak)),
                  ),
                  StatPill(
                    icon: Icons.bolt_rounded,
                    value: p.isPremium ? '∞' : '${p.energy}',
                    color: context.nyaya.energy,
                    semanticLabel: p.isPremium ? l.energyUnlimited : l.energyLeft(p.energy),
                    onTap: () {
                      if (!p.isPremium && p.energy == 0) {
                        OutOfEnergySheet.show(context, needed: 1);
                      } else {
                        _snack(
                          context,
                          p.isPremium
                              ? l.energyUnlimited
                              : '${l.energyLeft(p.energy)} · ${l.energyOutBody(formatCountdown(Day.untilMidnight(now)))}',
                        );
                      }
                    },
                  ),
                  StatPill(
                    icon: Icons.monetization_on_rounded,
                    value: '${p.coins}',
                    color: AppPalette.gold,
                    semanticLabel: '${p.coins} ${l.statCoins}',
                    onTap: () => context.push(Routes.settings),
                  ),
                  StatPill(
                    icon: Icons.diamond_rounded,
                    value: '${p.totalXp}',
                    color: context.colors.primary,
                    semanticLabel: '${p.totalXp} ${l.statXp}',
                    onTap: () => context.push(Routes.leaderboard),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _snack(BuildContext context, String msg) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(msg), duration: const Duration(seconds: 2)));
  }
}
