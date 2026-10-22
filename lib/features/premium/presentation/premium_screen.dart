import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../../app/router.dart';
import '../../../core/l10n/l10n.dart';
import '../../../core/services/feedback.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/chunky_button.dart';
import '../../../core/widgets/pressable.dart';
import '../../profile/application/profile_controller.dart';
import '../data/purchase_service.dart';

class PremiumScreen extends ConsumerStatefulWidget {
  const PremiumScreen({super.key});

  @override
  ConsumerState<PremiumScreen> createState() => _PremiumScreenState();
}

class _PremiumScreenState extends ConsumerState<PremiumScreen> {
  PremiumPlan _plan = PremiumPlan.yearly;
  bool _busy = false;

  void _close() {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go(Routes.home);
    }
  }

  Future<void> _buy() async {
    setState(() => _busy = true);
    final ok = await ref.read(purchaseServiceProvider).purchase(_plan);
    if (!mounted) return;
    setState(() => _busy = false);
    if (ok) {
      ref.read(profileProvider.notifier).activatePremium();
      ref.read(feedbackProvider).play(Haptic.celebrate);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(context.l10n.premiumActivated)));
      _close();
    }
  }

  Future<void> _restore() async {
    final ok = await ref.read(purchaseServiceProvider).restore();
    if (!mounted) return;
    if (ok) ref.read(profileProvider.notifier).activatePremium();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(ok ? context.l10n.premiumActivated : context.l10n.premiumNothingToRestore)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final isPremium = ref.watch(profileProvider.select((p) => p.isPremium));
    final benefits = [
      (Icons.bolt_rounded, l.premiumBenefitEnergy, l.premiumBenefitEnergySub, AppPalette.amber),
      (Icons.auto_awesome, l.premiumBenefitAi, l.premiumBenefitAiSub, AppPalette.darkPrimary),
      (Icons.ac_unit_rounded, l.premiumBenefitFreeze, l.premiumBenefitFreezeSub, const Color(0xFF7DD3FC)),
      (Icons.assignment_rounded, l.premiumBenefitExam, l.premiumBenefitExamSub, AppPalette.greenBright),
    ];

    return Scaffold(
      backgroundColor: AppPalette.darkBg,
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF1E2A78), AppPalette.darkBg],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              Align(
                alignment: Alignment.centerRight,
                child: IconButton(
                  tooltip: l.commonClose,
                  onPressed: _close,
                  icon: const Icon(Icons.close_rounded, color: Colors.white70),
                ),
              ),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.symmetric(horizontal: AppSpacing.page),
                  children: [
                    const Icon(Icons.workspace_premium_rounded, size: 84, color: AppPalette.gold)
                        .animate(onPlay: (c) => c.repeat(reverse: true))
                        .scale(begin: const Offset(1, 1), end: const Offset(1.06, 1.06), duration: 1200.ms),
                    const SizedBox(height: 8),
                    Text(
                      l.premiumTitle.toUpperCase(),
                      textAlign: TextAlign.center,
                      style: context.text.labelLarge?.copyWith(color: AppPalette.gold, letterSpacing: 2),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      l.premiumHeadline,
                      textAlign: TextAlign.center,
                      style: context.text.headlineLarge?.copyWith(color: Colors.white),
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    for (final (i, (icon, title, sub, color)) in benefits.indexed)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 14),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: color.withValues(alpha: 0.16),
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: Icon(icon, color: color),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(title, style: context.text.titleSmall?.copyWith(color: Colors.white)),
                                  Text(sub, style: context.text.bodySmall?.copyWith(color: AppPalette.darkTextSecondary)),
                                ],
                              ),
                            ),
                          ],
                        ).animate().fadeIn(delay: (100 * i).ms).slideX(begin: 0.1),
                      ),
                    const SizedBox(height: 4),
                    Text(
                      l.premiumFair,
                      textAlign: TextAlign.center,
                      style: context.text.labelSmall?.copyWith(color: AppPalette.darkTextSecondary),
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    if (!isPremium) ...[
                      _PlanCard(
                        title: l.premiumYearly,
                        price: l.premiumYearlyPrice,
                        sub: l.premiumPerMonth,
                        badge: l.premiumSave,
                        selected: _plan == PremiumPlan.yearly,
                        onTap: () => setState(() => _plan = PremiumPlan.yearly),
                      ),
                      const SizedBox(height: 12),
                      _PlanCard(
                        title: l.premiumMonthly,
                        price: l.premiumMonthlyPrice,
                        selected: _plan == PremiumPlan.monthly,
                        onTap: () => setState(() => _plan = PremiumPlan.monthly),
                      ),
                    ],
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(AppSpacing.page, AppSpacing.sm, AppSpacing.page, AppSpacing.sm),
                child: isPremium
                    ? ChunkyButton(
                        label: l.premiumAlready,
                        icon: Icons.verified_rounded,
                        color: AppPalette.gold,
                        foreground: AppPalette.ink,
                        onPressed: _close,
                      )
                    : Column(
                        children: [
                          ChunkyButton(
                            label: _busy ? '…' : l.premiumStartTrial,
                            color: AppPalette.gold,
                            foreground: AppPalette.ink,
                            onPressed: _busy ? null : _buy,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            l.premiumTrialNote,
                            textAlign: TextAlign.center,
                            style: context.text.labelSmall?.copyWith(color: AppPalette.darkTextSecondary),
                          ),
                          Wrap(
                            alignment: WrapAlignment.center,
                            children: [
                              TextButton(
                                onPressed: _restore,
                                style: TextButton.styleFrom(foregroundColor: Colors.white70),
                                child: Text(l.premiumRestore),
                              ),
                              TextButton(
                                onPressed: _close,
                                style: TextButton.styleFrom(foregroundColor: Colors.white70),
                                child: Text(l.commonLater),
                              ),
                            ],
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

class _PlanCard extends StatelessWidget {
  const _PlanCard({
    required this.title,
    required this.price,
    required this.selected,
    required this.onTap,
    this.sub,
    this.badge,
  });

  final String title;
  final String price;
  final String? sub;
  final String? badge;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      selected: selected,
      button: true,
      child: Pressable(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: selected ? AppPalette.gold.withValues(alpha: 0.12) : Colors.white.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(AppRadius.md),
            border: Border.all(color: selected ? AppPalette.gold : Colors.white24, width: 2),
          ),
          child: Row(
            children: [
              Icon(
                selected ? Icons.radio_button_checked_rounded : Icons.radio_button_off_rounded,
                color: selected ? AppPalette.gold : Colors.white54,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            title,
                            overflow: TextOverflow.ellipsis,
                            style: context.text.titleMedium?.copyWith(color: Colors.white),
                          ),
                        ),
                        if (badge != null) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppPalette.gold,
                              borderRadius: BorderRadius.circular(AppRadius.xl),
                            ),
                            child: Text(
                              badge!,
                              style: context.text.labelSmall?.copyWith(color: AppPalette.ink, fontWeight: FontWeight.w800),
                            ),
                          ),
                        ],
                      ],
                    ),
                    if (sub != null)
                      Text(sub!, style: context.text.bodySmall?.copyWith(color: AppPalette.darkTextSecondary)),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Text(price, style: context.text.titleSmall?.copyWith(color: Colors.white)),
            ],
          ),
        ),
      ),
    );
  }
}
