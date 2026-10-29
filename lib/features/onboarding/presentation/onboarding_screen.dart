import 'dart:async';

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
import '../../../core/widgets/common.dart';
import '../../../core/widgets/pressable.dart';
import '../../profile/application/profile_controller.dart';
import '../../progress/application/progress_sync.dart';
import '../../profile/domain/user_profile.dart';
import 'intro_slides.dart';

/// Language → 3 intro slides → persona → daily goal → name.
/// Target: under 60 seconds to the first quiz.
class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  static const _steps = 5;
  static const _introStep = 1;
  final _page = PageController();
  final _name = TextEditingController();
  int _step = 0;
  Persona? _persona;
  int _goal = 3;

  /// The intro slides are designed on Warm Cream with painted artwork, so they
  /// always render in the light theme.
  late final _light = AppTheme.light();

  @override
  void dispose() {
    _page.dispose();
    _name.dispose();
    super.dispose();
  }

  void _go(int step) {
    FocusScope.of(context).unfocus();
    ref.read(feedbackProvider).play(Haptic.tap);
    setState(() => _step = step);
    _page.animateToPage(step, duration: const Duration(milliseconds: 380), curve: Curves.easeOutCubic);
  }

  bool get _canContinue => switch (_step) {
        2 => _persona != null,
        4 => _name.text.trim().isNotEmpty,
        _ => true,
      };

  void _finish() {
    final p = ref.read(profileProvider);
    ref.read(profileProvider.notifier).completeOnboarding(
          name: _name.text,
          persona: _persona ?? Persona.citizen,
          language: p.language,
          dailyGoal: _goal,
        );
    // Signed in already (e.g. after a reset): save to the account now.
    // Otherwise the first sign-in uploads these settings.
    unawaited(ref.read(progressSyncProvider.notifier).pushSettings());
    ref.read(feedbackProvider).play(Haptic.celebrate);
    context.go(Routes.home);
    // Soft, skippable paywall right after onboarding converts best.
    Future.delayed(const Duration(milliseconds: 450), () {
      final ctx = _rootContext;
      if (ctx != null && ctx.mounted) GoRouter.of(ctx).push(Routes.premium);
    });
  }

  BuildContext? get _rootContext => GoRouter.of(context).routerDelegate.navigatorKey.currentContext;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final intro = _step == _introStep;
    final scaffold = Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            if (!intro)
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 8, AppSpacing.page, 0),
                child: Row(
                  children: [
                    IconButton(
                      tooltip: l.commonBack,
                      onPressed: _step == 0 ? null : () => _go(_step - 1),
                      icon: Icon(Icons.arrow_back_rounded,
                          color: _step == 0 ? Colors.transparent : context.colors.onSurface),
                    ),
                    Expanded(child: GlossyProgressBar(value: (_step + 1) / _steps, color: context.colors.primary)),
                  ],
                ),
              ),
            Expanded(
              // Keyed: the top bar comes and goes around the intro, and without a
              // key the pager would be rebuilt and jump back to the first step.
              key: const ValueKey('onboarding-pager'),
              child: PageView(
                controller: _page,
                physics: const NeverScrollableScrollPhysics(),
                children: [
                  _LanguageStep(onPicked: () => _go(_introStep)),
                  IntroSlides(onDone: () => _go(_introStep + 1)),
                  _PersonaStep(
                    selected: _persona,
                    onSelect: (p) {
                      ref.read(feedbackProvider).play(Haptic.select);
                      setState(() => _persona = p);
                    },
                  ),
                  _GoalStep(
                    goal: _goal,
                    onSelect: (g) {
                      ref.read(feedbackProvider).play(Haptic.select);
                      setState(() => _goal = g);
                    },
                  ),
                  _NameStep(controller: _name, onChanged: () => setState(() {}), onSubmit: _finish),
                ],
              ),
            ),
            if (_step > 0 && !intro)
              Padding(
                padding: const EdgeInsets.fromLTRB(AppSpacing.page, 8, AppSpacing.page, AppSpacing.md),
                child: ChunkyButton(
                  label: _step == _steps - 1 ? l.onbCommit : l.commonContinue,
                  onPressed: _canContinue ? (_step == _steps - 1 ? _finish : () => _go(_step + 1)) : null,
                ),
              ),
          ],
        ),
      ),
    );
    return Theme(data: intro ? _light : Theme.of(context), child: scaffold);
  }
}

class _StepScaffold extends StatelessWidget {
  const _StepScaffold({required this.title, this.subtitle, required this.child});

  final String title;
  final String? subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(AppSpacing.page, AppSpacing.lg, AppSpacing.page, AppSpacing.lg),
      children: [
        Text(title, style: context.text.headlineLarge).animate().fadeIn().slideY(begin: 0.15),
        if (subtitle != null) ...[
          const SizedBox(height: 8),
          Text(subtitle!, style: context.text.bodyLarge?.copyWith(color: context.nyaya.textSecondary))
              .animate()
              .fadeIn(delay: 80.ms),
        ],
        const SizedBox(height: AppSpacing.lg),
        child,
      ],
    );
  }
}

class _LanguageStep extends ConsumerWidget {
  const _LanguageStep({required this.onPicked});

  final VoidCallback onPicked;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final current = ref.watch(profileProvider.select((p) => p.language));
    return _StepScaffold(
      title: context.l10n.onbChooseLanguage,
      subtitle: context.l10n.onbChooseLanguageSub,
      child: Column(
        children: [
          for (final (i, lang) in AppLanguage.values.indexed)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _ChoiceTile(
                selected: lang == current,
                leading: Container(
                  width: 44,
                  height: 44,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: context.colors.primaryContainer,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    lang.nativeName.characters.first,
                    style: context.text.titleLarge?.copyWith(color: context.colors.onPrimaryContainer),
                  ),
                ),
                title: lang.nativeName,
                subtitle: lang.englishName,
                onTap: () {
                  ref.read(profileProvider.notifier).setLanguage(lang);
                  onPicked();
                },
              ).animate().fadeIn(delay: (40 * i).ms).slideX(begin: 0.08),
            ),
        ],
      ),
    );
  }
}

class _PersonaStep extends StatelessWidget {
  const _PersonaStep({required this.selected, required this.onSelect});

  final Persona? selected;
  final ValueChanged<Persona> onSelect;

  static const _icons = {
    Persona.advocate: Icons.gavel_rounded,
    Persona.aspirant: Icons.school_rounded,
    Persona.citizen: Icons.diversity_3_rounded,
  };

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return _StepScaffold(
      title: l.onbWhoAreYou,
      subtitle: l.onbWhoAreYouSub,
      child: Column(
        children: [
          for (final (i, p) in Persona.values.indexed)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _ChoiceTile(
                selected: selected == p,
                leading: Icon(_icons[p], size: 30, color: context.colors.primary),
                title: l.personaName(p),
                subtitle: l.personaDesc(p),
                onTap: () => onSelect(p),
              ).animate().fadeIn(delay: (60 * i).ms).slideX(begin: 0.08),
            ),
        ],
      ),
    );
  }
}

class _GoalStep extends StatelessWidget {
  const _GoalStep({required this.goal, required this.onSelect});

  final int goal;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final options = [(1, l.goalCasual, '🌱'), (3, l.goalRegular, '🔥'), (5, l.goalSerious, '⚖️')];
    return _StepScaffold(
      title: l.onbDailyGoal,
      subtitle: l.onbDailyGoalSub,
      child: Column(
        children: [
          for (final (i, (count, name, emoji)) in options.indexed)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _ChoiceTile(
                selected: goal == count,
                leading: Text(emoji, style: const TextStyle(fontSize: 28)),
                title: name,
                subtitle: l.goalQuizzesPerDay(count),
                onTap: () => onSelect(count),
              ).animate().fadeIn(delay: (60 * i).ms).slideX(begin: 0.08),
            ),
        ],
      ),
    );
  }
}

class _NameStep extends StatelessWidget {
  const _NameStep({required this.controller, required this.onChanged, required this.onSubmit});

  final TextEditingController controller;
  final VoidCallback onChanged;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return _StepScaffold(
      title: l.onbYourName,
      subtitle: l.onbYourNameSub,
      child: TextField(
        controller: controller,
        autofocus: false,
        maxLength: 24,
        textCapitalization: TextCapitalization.words,
        textInputAction: TextInputAction.done,
        style: context.text.titleLarge,
        decoration: InputDecoration(
          hintText: l.onbNameHint,
          prefixIcon: const Icon(Icons.person_rounded),
          counterText: '',
        ),
        onChanged: (_) => onChanged(),
        onSubmitted: (v) {
          if (v.trim().isNotEmpty) onSubmit();
        },
      ),
    );
  }
}

class _ChoiceTile extends StatelessWidget {
  const _ChoiceTile({
    required this.selected,
    required this.leading,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final bool selected;
  final Widget leading;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final primary = context.colors.primary;
    return Semantics(
      selected: selected,
      button: true,
      child: Pressable(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: selected ? context.colors.primaryContainer.withValues(alpha: 0.6) : context.colors.surface,
            borderRadius: BorderRadius.circular(AppRadius.md),
            border: Border.all(color: selected ? primary : context.nyaya.cardBorder, width: selected ? 2 : 1.5),
            boxShadow: [
              BoxShadow(
                color: selected ? primary.withValues(alpha: 0.35) : context.nyaya.cardBorder,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Row(
            children: [
              SizedBox(width: 48, child: Center(child: leading)),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: context.text.titleMedium),
                    const SizedBox(height: 2),
                    Text(subtitle, style: context.text.bodyMedium?.copyWith(color: context.nyaya.textSecondary)),
                  ],
                ),
              ),
              AnimatedOpacity(
                opacity: selected ? 1 : 0,
                duration: const Duration(milliseconds: 200),
                child: Icon(Icons.check_circle_rounded, color: primary),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
