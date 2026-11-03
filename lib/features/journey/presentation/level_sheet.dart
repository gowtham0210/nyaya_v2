import 'dart:math';

import 'package:confetti/confetti.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/config/game_rules.dart';
import '../../../core/l10n/l10n.dart';
import '../../../core/services/feedback.dart';
import '../../../core/services/sounds.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/chunky_button.dart';
import '../../../core/widgets/common.dart';
import '../../quiz/application/quiz_completion.dart';
import '../../quiz/data/quiz_api.dart';
import '../../quiz/domain/quiz_models.dart';
import '../../profile/application/profile_controller.dart';
import '../../quiz/presentation/quiz_launcher.dart';
import '../application/journey_controller.dart';
import '../domain/journey.dart';

/// Opens the sheet for a stop on the road. [onShowNext] moves the map to the
/// learner's next step (offered from locked stops).
Future<void> showNodeSheet(BuildContext context, WidgetRef ref, JourneyNode node, {VoidCallback? onShowNext}) {
  ref.read(feedbackProvider).play(Haptic.tap);
  return showModalBottomSheet(
    context: context,
    useRootNavigator: true,
    isScrollControlled: true,
    builder: (_) => node.kind == NodeKind.chest
        ? _ChestSheet(node: node, onShowNext: onShowNext)
        : _LevelSheet(node: node, onShowNext: onShowNext),
  );
}

/// "Level 2 · Constitution Basics" — how a locked sheet names the next step.
String _stepName(AppLocalizations l, JourneyNode n) =>
    '${n.kind == NodeKind.chest ? l.journeyChest : l.journeyLevel(n.level)} · ${l.chapterTitle(n.chapter.id)}';

/// Sheet body that scrolls when large text makes it taller than the screen.
class _SheetBody extends StatelessWidget {
  const _SheetBody({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(AppSpacing.page, 0, AppSpacing.page, AppSpacing.md),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: children,
        ),
      ),
    );
  }
}

/// "CHAPTER 1 · CONSTITUTION BASICS" above a sheet's title.
class _ChapterEyebrow extends StatelessWidget {
  const _ChapterEyebrow({required this.node});

  final JourneyNode node;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return Text(
      '${l.journeyChapter(node.chapterIndex + 1)} · ${l.chapterTitle(node.chapter.id)}'.toUpperCase(),
      textAlign: TextAlign.center,
      style: context.text.labelMedium?.copyWith(
        color: context.readable(node.chapter.color),
        fontWeight: FontWeight.w600,
        letterSpacing: context.tracking(1.2),
      ),
    );
  }
}

class _LevelSheet extends ConsumerWidget {
  const _LevelSheet({required this.node, this.onShowNext});

  final JourneyNode node;
  final VoidCallback? onShowNext;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final progress = ref.watch(journeyProvider);
    final premium = ref.watch(profileProvider.select((p) => p.isPremium));
    final status = progress.status(node);
    final stars = progress.stars[node.id] ?? 0;
    // Published questions at this level; until the catalog loads, assume a full level.
    final catalog = ref.watch(quizCatalogProvider).value;
    final count = catalog == null
        ? GameRules.casePathQuestions
        : min(catalog.available(node.chapter.id, difficulty: node.level), GameRules.casePathQuestions);
    final locked = status == NodeStatus.locked;
    final cost = QuizMode.casePath.energyCost;
    final replay = status == NodeStatus.completed;
    final next = progress.current;

    return _SheetBody(
      children: [
        Center(
          child: Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: locked ? context.nyaya.locked : node.chapter.color,
              border: node.isLandmark ? Border.all(color: AppPalette.ochre, width: 4) : null,
            ),
            child: Icon(
              locked ? Icons.lock_rounded : (node.isLandmark ? Icons.gavel_rounded : node.chapter.icon),
              color: Colors.white,
              size: 30,
            ),
          ),
        ),
        const SizedBox(height: 12),
        _ChapterEyebrow(node: node),
        const SizedBox(height: 4),
        Semantics(
          header: true,
          child: Text(
            locked ? '${l.journeyLevel(node.level)} · ${l.journeyLocked}' : l.journeyLevel(node.level),
            textAlign: TextAlign.center,
            style: context.text.headlineSmall,
          ),
        ),
        if (node.isLandmark)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.workspace_premium_rounded, size: 18, color: AppPalette.ochreText),
                const SizedBox(width: 4),
                Flexible(
                  child: Text(
                    l.journeyLandmark,
                    textAlign: TextAlign.center,
                    style: context.text.labelLarge?.copyWith(color: AppPalette.ochreText),
                  ),
                ),
              ],
            ),
          ),
        const SizedBox(height: AppSpacing.md),
        if (locked) ...[
          Text(
            l.journeyLockedNext(next == null ? '' : _stepName(l, next)),
            textAlign: TextAlign.center,
            style: context.text.bodyLarge?.copyWith(color: context.nyaya.textSecondary),
          ),
          const SizedBox(height: AppSpacing.lg),
          if (onShowNext != null && next != null)
            OutlinedButton.icon(
              onPressed: () {
                Navigator.pop(context);
                onShowNext!();
              },
              icon: const Icon(Icons.my_location_rounded),
              label: Text(l.journeyGoToNext),
            )
          else
            OutlinedButton(onPressed: () => Navigator.pop(context), child: Text(l.commonOk)),
        ] else ...[
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 8,
            runSpacing: 8,
            children: [
              _Fact(icon: Icons.help_outline_rounded, text: l.journeyQuestions(count)),
              _Fact(icon: Icons.bolt_rounded, text: premium ? l.energyUnlimited : l.modeEnergyCost(cost)),
              _Fact(icon: Icons.timer_off_outlined, text: l.journeyNoTimer),
            ],
          ),
          if (stars > 0) ...[
            const SizedBox(height: AppSpacing.md),
            Center(child: Text(l.journeyBestStars, style: context.text.labelMedium)),
            const SizedBox(height: 4),
            Center(child: StarRow(stars: stars, size: 30)),
          ],
          const SizedBox(height: AppSpacing.md),
          const _StarRules(),
          const SizedBox(height: AppSpacing.sm),
          _ScoringRules(cost: cost),
          const SizedBox(height: AppSpacing.md),
          ChunkyButton(
            label: premium
                ? (replay ? l.journeyReplay : l.commonStart)
                : (replay ? l.journeyReplayCost(cost) : l.journeyStartCost(cost)),
            icon: Icons.play_arrow_rounded,
            color: node.chapter.color,
            onPressed: count == 0
                ? null
                : () {
                    Navigator.pop(context);
                    QuizLauncher.start(context, ref, QuizRequest(QuizMode.casePath, levelId: node.id));
                  },
          ),
        ],
      ],
    );
  }
}

/// What score earns each star, from [GameRules].
class _StarRules extends StatelessWidget {
  const _StarRules();

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final rows = [
      (1, l.journeyPassMark((GameRules.oneStarAccuracy * 100).round())),
      (2, l.journeyStarMark((GameRules.twoStarAccuracy * 100).round())),
      (3, l.journeyStarMark(100)),
    ];
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
      decoration: BoxDecoration(
        color: context.colors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(l.journeyStarsTitle, style: context.text.labelLarge?.copyWith(fontWeight: FontWeight.w600)),
          for (final (stars, text) in rows)
            Semantics(
              label: '${l.journeyStarsOf(stars, 3)}: $text',
              excludeSemantics: true,
              child: Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Row(
                  children: [
                    StarRow(stars: stars, size: 18),
                    const SizedBox(width: 12),
                    Expanded(child: Text(text, style: context.text.bodyMedium)),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// The attempt rules the app and server really apply, folded away.
class _ScoringRules extends StatelessWidget {
  const _ScoringRules({required this.cost});

  final int cost;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final rules = [
      l.journeyRuleEnergy(cost),
      l.journeyRuleRetry,
      l.journeyRuleBest,
      l.journeyRuleNoMinus,
      l.journeyRuleBonus(GameRules.threeStarEnergyBonus, GameRules.coinsPerNewStar),
    ];
    return Theme(
      // No divider lines above and below the folded section.
      data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
      child: ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(horizontal: 4),
        childrenPadding: const EdgeInsets.fromLTRB(4, 0, 4, 8),
        expandedCrossAxisAlignment: CrossAxisAlignment.start,
        leading: Icon(Icons.info_outline_rounded, color: context.nyaya.textSecondary),
        title: Text(l.journeyHowScoring, style: context.text.titleSmall),
        children: [
          for (final rule in rules)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ExcludeSemantics(child: Text('•  ', style: context.text.bodyMedium)),
                  Expanded(
                    child: Text(rule, style: context.text.bodyMedium?.copyWith(color: context.nyaya.textSecondary)),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _Fact extends StatelessWidget {
  const _Fact({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: context.colors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(AppRadius.xl),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          ExcludeSemantics(child: Icon(icon, size: 18, color: context.nyaya.textSecondary)),
          const SizedBox(width: 6),
          Flexible(child: Text(text, style: context.text.labelLarge)),
        ],
      ),
    );
  }
}

class _ChestSheet extends ConsumerStatefulWidget {
  const _ChestSheet({required this.node, this.onShowNext});

  final JourneyNode node;
  final VoidCallback? onShowNext;

  @override
  ConsumerState<_ChestSheet> createState() => _ChestSheetState();
}

class _ChestSheetState extends ConsumerState<_ChestSheet> {
  final _confetti = ConfettiController(duration: const Duration(milliseconds: 900));
  int? _won;
  bool _opening = false;
  bool _failed = false;

  @override
  void dispose() {
    _confetti.dispose();
    super.dispose();
  }

  Future<void> _open() async {
    // One claim at a time; the server also refuses a second opening.
    if (_opening) return;
    setState(() {
      _opening = true;
      _failed = false;
    });
    final coins = await QuizCompletionService.openChest(ref, widget.node);
    if (!mounted) return;
    setState(() {
      _opening = false;
      _failed = coins == null;
    });
    if (coins == null) return;
    ref.read(feedbackProvider).play(Haptic.celebrate);
    ref.read(soundsProvider).play(Sfx.chest);
    _confetti.play();
    setState(() => _won = coins > 0 ? coins : GameRules.coinsPerChest);
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final node = widget.node;
    final progress = ref.watch(journeyProvider);
    final status = progress.status(node);
    // Only the server's answer makes a chest collected.
    final collected = _won != null || status == NodeStatus.completed;
    final ready = !collected && status == NodeStatus.current;
    final done = progress.completedLevelsIn(node.chapter.id);

    void close() => Navigator.pop(context);

    return Stack(
      alignment: Alignment.topCenter,
      children: [
        _SheetBody(
          children: [
            Icon(
              collected ? Icons.inventory_2_outlined : Icons.redeem_rounded,
              size: 88,
              color: ready || collected ? AppPalette.ochre : context.nyaya.locked,
            ).animate(target: _won != null ? 1 : 0).scale(end: const Offset(1.2, 1.2), curve: Curves.elasticOut),
            const SizedBox(height: 12),
            _ChapterEyebrow(node: node),
            const SizedBox(height: 4),
            Semantics(
              header: true,
              liveRegion: true,
              child: Text(
                collected
                    ? l.journeyChestCollectedTitle
                    : (ready ? l.journeyChestReadyTitle : l.journeyChestLockedTitle),
                textAlign: TextAlign.center,
                style: context.text.headlineSmall,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              collected
                  ? l.journeyChestCollectedText(_won ?? GameRules.coinsPerChest)
                  : (ready ? l.journeyChestReadyText : l.journeyChestLockedText),
              textAlign: TextAlign.center,
              style: (_won != null ? context.text.titleLarge : context.text.bodyLarge)?.copyWith(
                color: _won != null ? AppPalette.ochreText : context.nyaya.textSecondary,
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            if (!collected && !ready) ...[
              Semantics(
                label: l.homeLevelsDone(done, node.chapter.levels),
                excludeSemantics: true,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    GlossyProgressBar(value: done / node.chapter.levels, height: 8, color: context.colors.primary),
                    const SizedBox(height: 6),
                    Text(
                      l.homeLevelsDone(done, node.chapter.levels),
                      textAlign: TextAlign.center,
                      style: context.text.labelLarge,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              ChunkyButton(
                label: l.journeyContinueLearning,
                icon: Icons.arrow_forward_rounded,
                onPressed: () {
                  close();
                  widget.onShowNext?.call();
                },
              ),
            ] else if (ready) ...[
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const ExcludeSemantics(
                    child: Icon(Icons.monetization_on_rounded, color: AppPalette.ochre, size: 22),
                  ),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text(
                      l.journeyChestReward(GameRules.coinsPerChest),
                      style: context.text.titleMedium?.copyWith(fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
              if (_failed) ...[
                const SizedBox(height: AppSpacing.sm),
                Semantics(
                  liveRegion: true,
                  child: Text(
                    l.journeyChestFailed,
                    textAlign: TextAlign.center,
                    style: context.text.bodyMedium?.copyWith(color: context.colors.error),
                  ),
                ),
              ],
              const SizedBox(height: AppSpacing.lg),
              ChunkyButton(
                label: l.journeyOpenChest,
                icon: Icons.lock_open_rounded,
                color: AppPalette.ochre,
                foreground: AppPalette.deepEarth,
                // Disabled while the claim is on its way, so it can't be sent twice.
                onPressed: _opening ? null : _open,
              ),
              if (_opening)
                const Padding(
                  padding: EdgeInsets.only(top: AppSpacing.sm),
                  child: Center(child: SizedBox.square(dimension: 24, child: CircularProgressIndicator(strokeWidth: 3))),
                ),
            ] else ...[
              const SizedBox(height: AppSpacing.sm),
              OutlinedButton(onPressed: close, child: Text(l.journeyBackToMap)),
            ],
          ],
        ),
        ConfettiWidget(
          confettiController: _confetti,
          blastDirectionality: BlastDirectionality.explosive,
          numberOfParticles: 24,
          colors: const [AppPalette.ochre, AppPalette.burntClay, AppPalette.mossLight, AppPalette.burntClay],
        ),
      ],
    );
  }
}
