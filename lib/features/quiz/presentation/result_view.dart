import 'package:confetti/confetti.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../../app/router.dart';
import '../../../core/l10n/l10n.dart';
import '../../../core/services/feedback.dart';
import '../../../core/storage/local_store.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/day.dart';
import '../../../core/widgets/chunky_button.dart';
import '../../../core/widgets/common.dart';
import '../../journey/application/journey_controller.dart';
import '../../journey/domain/journey.dart';
import '../application/quiz_controller.dart';
import '../domain/quiz_models.dart';
import '../../review/presentation/question_actions.dart';
import 'quiz_launcher.dart';
import 'source_line.dart';

class ResultView extends ConsumerStatefulWidget {
  const ResultView({super.key, required this.state});

  final QuizState state;

  @override
  ConsumerState<ResultView> createState() => _ResultViewState();
}

class _ResultViewState extends ConsumerState<ResultView> {
  final _confetti = ConfettiController(duration: const Duration(milliseconds: 1500));
  bool _showReview = false;

  QuizResult get r => widget.state.result!;

  bool get _celebrate =>
      (r.request.mode == QuizMode.casePath && r.stars >= 2) ||
      r.duelWon == true ||
      r.isPerfect ||
      widget.state.rewards?.streakMilestone != null;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (_celebrate) {
        _confetti.play();
        ref.read(feedbackProvider).play(Haptic.celebrate);
      }
    });
  }

  @override
  void dispose() {
    _confetti.dispose();
    super.dispose();
  }

  String _headline(AppLocalizations l) {
    switch (r.request.mode) {
      case QuizMode.duel:
        if (r.duelDraw) return l.resultDuelDraw;
        return r.duelWon! ? l.resultDuelWon : l.resultDuelLost;
      case QuizMode.casePath:
        if (!r.passed) return l.resultTryAgain;
        return r.isPerfect ? l.resultPerfect : (r.stars >= 2 ? l.resultGreat : l.resultGood);
      case QuizMode.dailyDocket:
      case QuizMode.exam:
      case QuizMode.mistakeReview:
        if (r.isPerfect) return l.resultPerfect;
        return r.accuracy >= 0.5 ? l.resultGreat : l.resultTryAgain;
    }
  }

  void _shareDocket() {
    final now = ref.read(clockProvider)();
    final grid = r.answers.map((a) => a.isCorrect ? '🟩' : '🟥').join();
    Clipboard.setData(ClipboardData(text: 'Nyaya Daily Docket ${Day.key(now)}\n$grid  ${r.correct}/${r.total} ⚖️'));
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(context.l10n.chatCopy)));
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final rewards = widget.state.rewards;
    final mode = r.request.mode;
    final next = ref.watch(journeyProvider).current;
    final failedCasePath = mode == QuizMode.casePath && !r.passed;
    final hasNextLevel = mode == QuizMode.casePath && r.passed && next != null && next.kind == NodeKind.level;
    final minutes = r.durationMs ~/ 60000;
    final seconds = (r.durationMs ~/ 1000) % 60;

    final chips = <(IconData, String, Color)>[
      if (rewards != null && rewards.streakMilestone != null)
        (Icons.local_fire_department_rounded, l.resultMilestone(rewards.streakMilestone!), context.nyaya.streak)
      else if (rewards != null && rewards.streakExtended)
        (Icons.local_fire_department_rounded, l.resultStreakExtended(rewards.streak), context.nyaya.streak),
      if (rewards != null && rewards.dailyGoalJustReached)
        (Icons.flag_rounded, l.resultGoalReached, context.nyaya.success),
      if (rewards != null && rewards.energyBonus > 0)
        (Icons.bolt_rounded, l.resultEnergyBonus(rewards.energyBonus), context.nyaya.energy),
      if (rewards != null && rewards.leagueRankAfter < rewards.leagueRankBefore)
        (Icons.trending_up_rounded, l.resultLeagueUp(rewards.leagueRankAfter), context.colors.primary),
    ];

    return Scaffold(
      body: Stack(
        alignment: Alignment.topCenter,
        children: [
          SafeArea(
            child: Column(
              children: [
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(AppSpacing.page, AppSpacing.xl, AppSpacing.page, AppSpacing.lg),
                    children: [
                      _Hero(result: r),
                      const SizedBox(height: AppSpacing.md),
                      Text(
                        _headline(l),
                        textAlign: TextAlign.center,
                        style: context.text.headlineLarge,
                      ).animate().fadeIn(delay: 200.ms).slideY(begin: 0.2),
                      const SizedBox(height: 6),
                      Text(
                        switch (mode) {
                          QuizMode.exam => l.resultExamBreakdown(r.correct, r.wrong, r.skipped),
                          QuizMode.duel => l.resultDuelPoints(r.duelPlayerPoints!, r.duelOpponentPoints!),
                          _ => failedCasePath ? l.resultTryAgainBody : l.resultScore(r.correct, r.total),
                        },
                        textAlign: TextAlign.center,
                        style: context.text.bodyLarge?.copyWith(color: context.nyaya.textSecondary),
                      ).animate().fadeIn(delay: 300.ms),
                      const SizedBox(height: AppSpacing.lg),
                      Row(
                        children: [
                          _StatTile(
                            label: l.resultXp,
                            value: '+${rewards?.xp.total ?? 0}',
                            icon: Icons.diamond_rounded,
                            color: context.colors.primary,
                            delay: 350,
                          ),
                          const SizedBox(width: 10),
                          _StatTile(
                            label: l.resultAccuracy,
                            value: '${(r.accuracy * 100).round()}%',
                            icon: Icons.track_changes_rounded,
                            color: context.nyaya.success,
                            delay: 450,
                          ),
                          const SizedBox(width: 10),
                          _StatTile(
                            label: mode == QuizMode.exam ? l.resultTime : l.resultCoins,
                            value: mode == QuizMode.exam
                                ? '$minutes:${seconds.toString().padLeft(2, '0')}'
                                : '+${rewards?.coins ?? 0}',
                            icon: mode == QuizMode.exam ? Icons.timer_rounded : Icons.monetization_on_rounded,
                            color: AppPalette.ochreText,
                            delay: 550,
                          ),
                        ],
                      ),
                      if (chips.isNotEmpty) ...[
                        const SizedBox(height: AppSpacing.md),
                        for (final (i, (icon, text, color)) in chips.indexed)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                              decoration: BoxDecoration(
                                color: color.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(AppRadius.md),
                              ),
                              child: Row(
                                children: [
                                  Icon(icon, color: color),
                                  const SizedBox(width: 10),
                                  Expanded(child: Text(text, style: context.text.titleSmall)),
                                ],
                              ),
                            ).animate().fadeIn(delay: (650 + 120 * i).ms).slideX(begin: 0.1),
                          ),
                      ],
                      const SizedBox(height: AppSpacing.sm),
                      TextButton.icon(
                        onPressed: () => setState(() => _showReview = !_showReview),
                        icon: Icon(_showReview ? Icons.expand_less_rounded : Icons.fact_check_rounded),
                        label: Text(l.resultReview),
                      ),
                      if (_showReview) ...[
                        for (final (i, a) in r.answers.indexed) _ReviewItem(index: i + 1, answer: a),
                      ],
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(AppSpacing.page, 0, AppSpacing.page, AppSpacing.md),
                  child: Column(
                    children: [
                      if (hasNextLevel)
                        ChunkyButton(
                          label: l.resultNextLevel,
                          icon: Icons.arrow_forward_rounded,
                          color: next.chapter.color,
                          onPressed: () => QuizLauncher.start(
                            context,
                            ref,
                            QuizRequest(QuizMode.casePath, levelId: next.id),
                            replace: true,
                          ),
                        )
                      else if (failedCasePath || mode == QuizMode.duel)
                        ChunkyButton(
                          label: l.resultPlayAgain,
                          icon: Icons.replay_rounded,
                          onPressed: () => QuizLauncher.start(context, ref, r.request, replace: true),
                        )
                      else if (mode == QuizMode.dailyDocket)
                        ChunkyButton(
                          label: l.resultDocketShare,
                          icon: Icons.ios_share_rounded,
                          color: AppPalette.burntClay,
                          onPressed: _shareDocket,
                        )
                      else
                        ChunkyButton(label: l.commonContinue, onPressed: () => context.pop()),
                      const SizedBox(height: 10),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton(
                          onPressed: () => mode == QuizMode.casePath ? context.go(Routes.journey) : context.pop(),
                          child: Text(mode == QuizMode.casePath ? l.resultBackToMap : l.resultBackHome),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          ConfettiWidget(
            confettiController: _confetti,
            blastDirectionality: BlastDirectionality.explosive,
            numberOfParticles: 36,
            maxBlastForce: 30,
            colors: const [
              AppPalette.ochre,
              AppPalette.burntClay,
              AppPalette.mossLight,
              AppPalette.burntClay,
              Colors.white,
            ],
          ),
        ],
      ),
    );
  }
}

/// Stars for Case Path, trophy for duels, score dial for exams.
class _Hero extends StatelessWidget {
  const _Hero({required this.result});

  final QuizResult result;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    switch (result.request.mode) {
      case QuizMode.casePath:
        return Row(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            for (var i = 0; i < 3; i++)
              Padding(
                padding: EdgeInsets.only(bottom: i == 1 ? 18 : 0, left: 4, right: 4),
                child:
                    Icon(
                          Icons.star_rounded,
                          size: i == 1 ? 96 : 72,
                          color: i < result.stars ? AppPalette.ochre : context.nyaya.locked,
                        )
                        .animate()
                        .scale(
                          delay: (250 * i).ms,
                          begin: const Offset(0, 0),
                          curve: Curves.elasticOut,
                          duration: 800.ms,
                        )
                        .rotate(begin: -0.2, delay: (250 * i).ms),
              ),
          ],
        );
      case QuizMode.duel:
        final won = result.duelWon == true;
        return Icon(
          won ? Icons.emoji_events_rounded : Icons.sports_kabaddi_rounded,
          size: 110,
          color: won ? AppPalette.ochre : context.colors.primary,
        ).animate().scale(begin: const Offset(0.3, 0.3), curve: Curves.elasticOut, duration: 900.ms);
      case QuizMode.exam:
        final max = result.total;
        return Center(
          child: ProgressRing(
            value: ((result.examScore ?? 0) / max).clamp(0, 1),
            size: 150,
            stroke: 14,
            color: AppPalette.ochre,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text((result.examScore ?? 0).toStringAsFixed(2), style: context.text.headlineMedium),
                Text('/ $max', style: context.text.labelLarge?.copyWith(color: context.nyaya.textSecondary)),
              ],
            ),
          ),
        ).animate().fadeIn().scale(begin: const Offset(0.8, 0.8));
      case QuizMode.dailyDocket:
      case QuizMode.mistakeReview:
        return Column(
          children: [
            Icon(
              result.request.mode == QuizMode.dailyDocket ? Icons.today_rounded : Icons.fact_check_rounded,
              size: 84,
              color: AppPalette.burntClay,
            ).animate().scale(begin: const Offset(0.4, 0.4), curve: Curves.elasticOut, duration: 800.ms),
            const SizedBox(height: 8),
            Text(
              result.answers.map((a) => a.isCorrect ? '🟩' : '🟥').join(' '),
              style: const TextStyle(fontSize: 22),
              semanticsLabel: l.resultScore(result.correct, result.total),
            ),
          ],
        );
    }
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
    required this.delay,
  });

  final String label;
  final String value;
  final IconData icon;
  final Color color;
  final int delay;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: Border.all(color: color, width: 2),
        ),
        child: Column(
          children: [
            Text(
              label.toUpperCase(),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: context.text.labelSmall?.copyWith(color: color, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 6),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, color: color, size: 20),
                const SizedBox(width: 4),
                Flexible(child: Text(value, maxLines: 1, style: context.text.titleLarge)),
              ],
            ),
          ],
        ),
      ).animate().fadeIn(delay: delay.ms).slideY(begin: 0.3),
    );
  }
}

class _ReviewItem extends StatelessWidget {
  const _ReviewItem({required this.index, required this.answer});

  final int index;
  final AnswerRecord answer;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final q = answer.question;
    final ok = answer.isCorrect;
    final color = ok ? context.nyaya.success : context.nyaya.error;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: NyayaCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(ok ? Icons.check_circle_rounded : Icons.cancel_rounded, color: color, size: 22),
                const SizedBox(width: 8),
                Expanded(child: Text('$index. ${q.text}', style: context.text.titleSmall)),
              ],
            ),
            const SizedBox(height: 8),
            if (!ok)
              Text(
                '${l.resultYourAnswer}: ${answer.isSkipped ? l.resultSkipped : q.options[answer.selectedIndex!]}',
                style: context.text.bodySmall?.copyWith(color: context.nyaya.error),
              ),
            if (answer.reveal?.correctIndex case final correct?)
              Text(
                '${l.resultCorrectAnswer}: ${q.options[correct]}',
                style: context.text.bodySmall?.copyWith(color: context.nyaya.success, fontWeight: FontWeight.w700),
              ),
            const SizedBox(height: 6),
            Text(
              answer.reveal?.explanation ?? '',
              style: context.text.bodySmall?.copyWith(color: context.nyaya.textSecondary, height: 1.4),
            ),
            if (answer.reveal case final reveal?) ...[
              const SizedBox(height: 6),
              SourceLine(reference: reveal.reference, url: reveal.sourceUrl),
            ],
            if (answer.reveal != null) QuestionActions(questionId: q.questionId, questionVersionId: q.id),
          ],
        ),
      ),
    );
  }
}
