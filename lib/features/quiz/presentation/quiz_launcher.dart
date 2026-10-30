import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../../app/router.dart';
import '../../../core/config/features.dart';
import '../../../core/config/game_rules.dart';
import '../../../core/l10n/l10n.dart';
import '../../../core/services/feedback.dart';
import '../../../core/storage/local_store.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/day.dart';
import '../../../core/widgets/chunky_button.dart';
import '../../auth/application/auth_controller.dart';
import '../../profile/application/profile_controller.dart';
import '../../progress/application/progress_sync.dart';
import '../application/quiz_controller.dart';
import '../domain/quiz_models.dart';

/// The single entry point for starting any quiz. Guards sign-in (the server
/// runs every quiz), energy and the once-a-day docket so no screen can start
/// a quiz the user can't finish.
abstract final class QuizLauncher {
  /// With [replace], swaps the current quiz route (used by "Next level" and
  /// "Play again" on the results screen).
  static Future<void> start(BuildContext context, WidgetRef ref, QuizRequest request, {bool replace = false}) async {
    final profile = ref.read(profileProvider.notifier);
    ref.read(feedbackProvider).play(Haptic.tap);

    if (!ref.read(authProvider.notifier).isSignedIn) {
      final signedIn = await context.push<bool>(Routes.signIn);
      if (signedIn != true || !context.mounted) return;
    }

    if (request.mode == QuizMode.dailyDocket && profile.docketDoneToday) {
      final now = ref.read(clockProvider)();
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(context.l10n.docketNextIn(formatCountdown(Day.untilMidnight(now)))),
      ));
      return;
    }

    final cost = request.mode.energyCost;
    if (!profile.canAfford(cost)) {
      await OutOfEnergySheet.show(context, needed: cost);
      return;
    }
    profile.spendEnergy(cost);
    if (replace) {
      // "Play again" opens the same quiz: drop the finished one so a new
      // attempt starts (its state is kept per quiz request).
      ref.invalidate(quizControllerProvider(request));
      context.pushReplacement(Routes.quiz, extra: request);
    } else {
      await context.push(Routes.quiz, extra: request);
    }
  }
}

class OutOfEnergySheet extends ConsumerWidget {
  const OutOfEnergySheet({super.key, required this.needed});

  final int needed;

  static Future<void> show(BuildContext context, {required int needed}) => showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        useRootNavigator: true,
        builder: (_) => OutOfEnergySheet(needed: needed),
      );

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final p = ref.watch(profileProvider);
    final ctl = ref.read(profileProvider.notifier);
    final now = ref.read(clockProvider)();
    final docketAvailable = !ctl.docketDoneToday;
    final canBuy = p.coins >= GameRules.energyRefillCoinCost;

    void close() => Navigator.of(context).pop();

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(AppSpacing.page, 0, AppSpacing.page, AppSpacing.md),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 88,
                height: 88,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: context.nyaya.energy.withValues(alpha: 0.15),
                ),
                child: Icon(Icons.bolt_rounded, size: 52, color: context.nyaya.energy),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            Text(l.energyOutTitle, textAlign: TextAlign.center, style: context.text.headlineSmall),
            const SizedBox(height: 6),
            Text(
              l.energyOutBody(formatCountdown(Day.untilMidnight(now))),
              textAlign: TextAlign.center,
              style: context.text.bodyLarge?.copyWith(color: context.nyaya.textSecondary),
            ),
            const SizedBox(height: AppSpacing.lg),
            if (Features.premium) ...[
              ChunkyButton(
                label: l.energyGoUnlimited,
                icon: Icons.workspace_premium_rounded,
                color: AppPalette.ochre,
                foreground: AppPalette.deepEarth,
                onPressed: () {
                  close();
                  context.push(Routes.premium);
                },
              ),
              const SizedBox(height: 12),
            ],
            OutlinedButton.icon(
              onPressed: () async {
                final messenger = ScaffoldMessenger.of(context);
                if (!canBuy) {
                  messenger.showSnackBar(SnackBar(content: Text(l.energyNotEnoughCoins)));
                  return;
                }
                final failed = await ref.read(progressSyncProvider.notifier).refillEnergy();
                if (failed != null) {
                  messenger.showSnackBar(SnackBar(
                    content: Text(failed == 'not_enough_coins' ? l.energyNotEnoughCoins : l.commonSomethingWrong),
                  ));
                  return;
                }
                ref.read(feedbackProvider).play(Haptic.success);
                if (ref.read(profileProvider).energy >= needed) close();
                messenger.showSnackBar(SnackBar(content: Text(l.energyRefilled)));
              },
              icon: const Icon(Icons.monetization_on_rounded),
              label: Text(l.energyRefillCoins(GameRules.energyRefillCoinCost)),
            ),
            const SizedBox(height: AppSpacing.lg),
            Text(l.energyFreeOptions, style: context.text.titleSmall?.copyWith(color: context.nyaya.textSecondary)),
            const SizedBox(height: 4),
            if (docketAvailable)
              _FreeOption(
                icon: Icons.today_rounded,
                label: l.energyPlayDocket,
                onTap: () {
                  close();
                  QuizLauncher.start(context, ref, const QuizRequest(QuizMode.dailyDocket));
                },
              ),
            _FreeOption(
              icon: Icons.auto_awesome,
              label: l.energyAskAi,
              onTap: () {
                close();
                context.go(Routes.chat);
              },
            ),
            _FreeOption(
              icon: Icons.newspaper_rounded,
              label: l.energyReadUpdates,
              onTap: () {
                close();
                context.go(Routes.updates);
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _FreeOption extends StatelessWidget {
  const _FreeOption({required this.icon, required this.label, required this.onTap});

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: CircleAvatar(
        backgroundColor: context.colors.primaryContainer,
        child: Icon(icon, color: context.colors.onPrimaryContainer, size: 20),
      ),
      title: Text(label, style: context.text.titleSmall),
      trailing: const Icon(Icons.chevron_right_rounded),
      onTap: onTap,
    );
  }
}
