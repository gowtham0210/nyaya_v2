import 'package:confetti/confetti.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/l10n/l10n.dart';
import '../../../core/services/feedback.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/chunky_button.dart';
import '../../../core/widgets/common.dart';
import '../../quiz/application/quiz_completion.dart';
import '../../quiz/data/question_repository.dart';
import '../../quiz/domain/quiz_models.dart';
import '../../quiz/presentation/quiz_launcher.dart';
import '../application/journey_controller.dart';
import '../domain/journey.dart';

Future<void> showNodeSheet(BuildContext context, WidgetRef ref, JourneyNode node) {
  ref.read(feedbackProvider).play(Haptic.tap);
  return showModalBottomSheet(
    context: context,
    useRootNavigator: true,
    isScrollControlled: true,
    builder: (_) => node.kind == NodeKind.chest ? _ChestSheet(node: node) : _LevelSheet(node: node),
  );
}

class _LevelSheet extends ConsumerWidget {
  const _LevelSheet({required this.node});

  final JourneyNode node;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final progress = ref.watch(journeyProvider);
    final status = progress.status(node);
    final stars = progress.stars[node.id] ?? 0;
    final bank = ref.watch(questionBankProvider).value;
    final chapterTitle = bank?.chapters[node.chapter.id]?.title ?? '';
    final count = bank?.forLevel(node.chapter.id, node.level).length ?? 0;
    final locked = status == NodeStatus.locked;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(AppSpacing.page, 0, AppSpacing.page, AppSpacing.md),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 76,
                height: 76,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: locked ? context.nyaya.locked : node.chapter.color,
                  border: node.isLandmark ? Border.all(color: AppPalette.ochre, width: 4) : null,
                ),
                child: Icon(
                  locked ? Icons.lock_rounded : (node.isLandmark ? Icons.gavel_rounded : node.chapter.icon),
                  color: Colors.white,
                  size: 36,
                ),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              '${l.journeyChapter(node.chapterIndex + 1)} · $chapterTitle',
              textAlign: TextAlign.center,
              style: context.text.labelLarge?.copyWith(color: node.chapter.color),
            ),
            const SizedBox(height: 4),
            Text(l.journeyLevel(node.level), textAlign: TextAlign.center, style: context.text.headlineSmall),
            if (node.isLandmark)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  '👑 ${l.journeyLandmark}',
                  textAlign: TextAlign.center,
                  style: context.text.labelLarge?.copyWith(color: AppPalette.ochreText),
                ),
              ),
            const SizedBox(height: AppSpacing.md),
            if (locked)
              Text(
                l.journeyLockedBody,
                textAlign: TextAlign.center,
                style: context.text.bodyLarge?.copyWith(color: context.nyaya.textSecondary),
              )
            else ...[
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _Fact(icon: Icons.help_outline_rounded, text: l.journeyQuestions(count)),
                  const SizedBox(width: 12),
                  _Fact(icon: Icons.bolt_rounded, text: l.modeEnergyCost(QuizMode.casePath.energyCost)),
                ],
              ),
              if (stars > 0) ...[
                const SizedBox(height: AppSpacing.md),
                Center(child: Text(l.journeyBestStars, style: context.text.labelMedium)),
                const SizedBox(height: 4),
                Center(child: StarRow(stars: stars, size: 30)),
              ],
              const SizedBox(height: AppSpacing.md),
              Text(
                l.journeyPassHint,
                textAlign: TextAlign.center,
                style: context.text.bodySmall?.copyWith(color: context.nyaya.textSecondary),
              ),
            ],
            const SizedBox(height: AppSpacing.lg),
            if (locked)
              OutlinedButton(onPressed: () => Navigator.pop(context), child: Text(l.commonOk))
            else
              ChunkyButton(
                label: status == NodeStatus.completed ? l.journeyReplay : l.commonStart,
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
        ),
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
          Icon(icon, size: 18, color: context.nyaya.textSecondary),
          const SizedBox(width: 6),
          Text(text, style: context.text.labelLarge),
        ],
      ),
    );
  }
}

class _ChestSheet extends ConsumerStatefulWidget {
  const _ChestSheet({required this.node});

  final JourneyNode node;

  @override
  ConsumerState<_ChestSheet> createState() => _ChestSheetState();
}

class _ChestSheetState extends ConsumerState<_ChestSheet> {
  final _confetti = ConfettiController(duration: const Duration(milliseconds: 900));
  int? _won;

  @override
  void dispose() {
    _confetti.dispose();
    super.dispose();
  }

  void _open() {
    final coins = QuizCompletionService.openChest(ref, widget.node);
    if (coins == 0) return;
    ref.read(feedbackProvider).play(Haptic.celebrate);
    _confetti.play();
    setState(() => _won = coins);
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final status = ref.watch(journeyProvider).status(widget.node);
    final opened = _won != null || status == NodeStatus.completed;
    final canOpen = status == NodeStatus.current && _won == null;

    return SafeArea(
      child: Stack(
        alignment: Alignment.topCenter,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(AppSpacing.page, 0, AppSpacing.page, AppSpacing.md),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Icon(
                  opened ? Icons.inventory_2_outlined : Icons.redeem_rounded,
                  size: 96,
                  color: status == NodeStatus.locked ? context.nyaya.locked : AppPalette.ochre,
                ).animate(target: _won != null ? 1 : 0).scale(end: const Offset(1.2, 1.2), curve: Curves.elasticOut),
                const SizedBox(height: 12),
                Text(l.journeyChest, textAlign: TextAlign.center, style: context.text.headlineSmall),
                const SizedBox(height: 8),
                Text(
                  _won != null
                      ? l.journeyChestOpened(_won!)
                      : (status == NodeStatus.locked ? l.journeyChestLocked : l.journeyChestBody),
                  textAlign: TextAlign.center,
                  style: (_won != null ? context.text.titleLarge : context.text.bodyLarge)
                      ?.copyWith(color: _won != null ? AppPalette.ochreText : context.nyaya.textSecondary),
                ),
                const SizedBox(height: AppSpacing.lg),
                if (canOpen)
                  ChunkyButton(
                    label: l.journeyOpenChest,
                    icon: Icons.lock_open_rounded,
                    color: AppPalette.ochre,
                    foreground: AppPalette.deepEarth,
                    onPressed: _open,
                  )
                else
                  OutlinedButton(onPressed: () => Navigator.pop(context), child: Text(l.commonContinue)),
              ],
            ),
          ),
          ConfettiWidget(
            confettiController: _confetti,
            blastDirectionality: BlastDirectionality.explosive,
            numberOfParticles: 24,
            colors: const [AppPalette.ochre, AppPalette.burntClay, AppPalette.mossLight, AppPalette.burntClay],
          ),
        ],
      ),
    );
  }
}
