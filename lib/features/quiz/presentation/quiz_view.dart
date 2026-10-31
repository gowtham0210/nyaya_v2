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
import '../../../core/widgets/pressable.dart';
import '../../journey/domain/journey.dart';
import '../../profile/application/profile_controller.dart';
import '../../review/presentation/question_actions.dart';
import '../application/quiz_controller.dart';
import '../domain/quiz_models.dart';
import 'source_line.dart';

/// The question screen: progress + timer, question, four options, feedback
/// and the Next button.
class QuizView extends ConsumerWidget {
  const QuizView({super.key, required this.request, required this.onClose});

  final QuizRequest request;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final provider = quizControllerProvider(request);
    final s = ref.watch(provider);
    final ctl = ref.read(provider.notifier);
    final q = s.current;
    final mode = request.mode;
    final chapter = JourneyCatalog.chapter(q.chapterId);
    final chapterTitle = l.chapterTitle(chapter.id);

    // Haptics, sound + combo toast on answer reveal.
    ref.listen(provider.select((st) => st.answers.length), (prev, next) {
      if (prev == null || next <= prev || !mode.instantFeedback) return;
      final last = ref.read(provider).answers.last;
      ref.read(feedbackProvider).play(last.isCorrect ? Haptic.success : Haptic.error);
      ref.read(soundsProvider).play(last.isCorrect ? Sfx.correct : Sfx.wrong);
    });

    // A soft tick each of the last seconds on a running clock.
    ref.listen(provider.select((st) => st.secondsLeft), (prev, next) {
      if (prev == null || next == null || next >= prev) return;
      if (next < 1 || next > GameRules.tickFromSeconds) return;
      ref.read(soundsProvider).play(Sfx.tick);
    });

    // An answer that could not reach the server.
    ref.listen(provider.select((st) => st.problem), (prev, next) {
      if (prev != null && next > prev) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l.quizSendFailed)));
      }
    });

    final last = s.revealed ? s.lastAnswer : null;
    final answeredCount = mode == QuizMode.exam ? s.index + (s.selected != null ? 1 : 0) : s.answers.length;

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            // ── Top bar ────────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 8, AppSpacing.page, 0),
              child: Row(
                children: [
                  IconButton(tooltip: l.commonClose, onPressed: onClose, icon: const Icon(Icons.close_rounded)),
                  Expanded(child: GlossyProgressBar(value: s.progress)),
                  const SizedBox(width: 12),
                  if (mode == QuizMode.exam)
                    _ExamClock(seconds: s.secondsLeft ?? 0)
                  else if (s.combo >= GameRules.comboStart)
                    _ComboBadge(count: s.combo)
                  else
                    Text('${s.index + 1}/${s.questions.length}', style: context.text.labelLarge),
                ],
              ),
            ),
            if (mode.secondsPerQuestion != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(AppSpacing.page, 10, AppSpacing.page, 0),
                child: _QuestionTimer(seconds: s.secondsLeft ?? 0, total: mode.secondsPerQuestion!, paused: s.revealed),
              ),
            if (mode == QuizMode.duel && s.opponent != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(AppSpacing.page, 12, AppSpacing.page, 0),
                child: _DuelHeader(state: s),
              ),

            // ── Question + options ─────────────────────────────────────────
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(AppSpacing.page, AppSpacing.lg, AppSpacing.page, AppSpacing.lg),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Align(
                            alignment: AlignmentDirectional.centerStart,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: chapter.color.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(AppRadius.xl),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(chapter.icon, size: 14, color: context.readable(chapter.color)),
                                  const SizedBox(width: 6),
                                  Flexible(
                                    child: Text(
                                      chapterTitle,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: context.text.labelMedium?.copyWith(
                                        color: context.readable(chapter.color),
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          l.quizQuestionOf(s.index + 1, s.questions.length),
                          style: context.text.labelMedium?.copyWith(color: context.nyaya.textSecondary),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.md),
                    Text(
                      q.text,
                      style: context.text.titleLarge?.copyWith(height: 1.35, fontWeight: FontWeight.w700),
                    ).animate(key: ValueKey(q.id)).fadeIn(duration: 250.ms).slideX(begin: 0.04),
                    const SizedBox(height: AppSpacing.lg),
                    for (var i = 0; i < q.options.length; i++)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child:
                            OptionTile(
                                  letter: String.fromCharCode(65 + i),
                                  text: q.options[i],
                                  state: _optionState(s, i),
                                  onTap: () {
                                    ref.read(feedbackProvider).play(Haptic.select);
                                    ctl.select(i);
                                  },
                                )
                                .animate(key: ValueKey('${q.id}-$i'))
                                .fadeIn(delay: (60 * i).ms, duration: 250.ms)
                                .slideY(begin: 0.15),
                      ),
                    if (last != null && (last.reveal != null || mode == QuizMode.duel)) ...[
                      const SizedBox(height: 4),
                      _Explanation(answer: last, opponent: mode == QuizMode.duel ? s : null),
                    ],
                  ],
                ),
              ),
            ),

            // ── Bottom bar with Next ───────────────────────────────────────
            _BottomBar(
              state: s,
              answered: answeredCount,
              onNext: () {
                ref.read(feedbackProvider).play(Haptic.tap);
                ctl.next();
              },
              onRetry: ctl.retrySubmit,
            ),
          ],
        ),
      ),
    );
  }

  OptionState _optionState(QuizState s, int i) {
    if (!s.request.mode.instantFeedback || s.sending) {
      return s.selected == i ? OptionState.selected : OptionState.idle;
    }
    if (!s.revealed) return OptionState.idle;
    // The correct option is only known once the server has revealed it.
    final correct = s.lastAnswer?.reveal?.correctIndex;
    if (i == correct) return OptionState.correct;
    if (i == s.selected) return OptionState.wrong;
    return OptionState.dimmed;
  }
}

enum OptionState { idle, selected, correct, wrong, dimmed }

class OptionTile extends StatelessWidget {
  const OptionTile({super.key, required this.letter, required this.text, required this.state, required this.onTap});

  final String letter;
  final String text;
  final OptionState state;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final n = context.nyaya;
    final scheme = context.colors;
    final (border, fill, badge, badgeText) = switch (state) {
      OptionState.idle => (n.cardBorder, scheme.surface, scheme.surfaceContainerLow, scheme.onSurface),
      OptionState.selected => (
        scheme.primary,
        scheme.primaryContainer.withValues(alpha: 0.55),
        scheme.primary,
        scheme.onPrimary,
      ),
      OptionState.correct => (n.success, n.successContainer, n.success, Colors.white),
      OptionState.wrong => (n.error, n.errorContainer, n.error, Colors.white),
      OptionState.dimmed => (n.cardBorder, scheme.surface, scheme.surfaceContainerLow, n.textSecondary),
    };
    final icon = switch (state) {
      OptionState.correct => Icons.check_rounded,
      OptionState.wrong => Icons.close_rounded,
      _ => null,
    };
    final interactive = state == OptionState.idle || state == OptionState.selected;

    Widget tile = AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      decoration: BoxDecoration(
        color: fill,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: border, width: 2),
        boxShadow: [BoxShadow(color: border, offset: const Offset(0, 3))],
      ),
      child: Row(
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: 34,
            height: 34,
            alignment: Alignment.center,
            decoration: BoxDecoration(color: badge, borderRadius: BorderRadius.circular(10)),
            child: icon != null
                ? Icon(icon, size: 20, color: badgeText)
                : Text(letter, style: context.text.labelLarge?.copyWith(color: badgeText)),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              text,
              style: context.text.bodyLarge?.copyWith(
                fontWeight: FontWeight.w600,
                color: state == OptionState.dimmed ? n.textSecondary : null,
              ),
            ),
          ),
        ],
      ),
    );

    if (state == OptionState.wrong) tile = tile.animate().shakeX(hz: 5, amount: 5, duration: 380.ms);
    if (state == OptionState.correct) {
      tile = tile.animate().scale(begin: const Offset(0.97, 0.97), end: const Offset(1, 1), curve: Curves.elasticOut);
    }

    return Semantics(
      button: interactive,
      selected: state == OptionState.selected,
      label: '$letter. $text',
      child: Pressable(onTap: interactive ? onTap : null, scale: 0.98, child: tile),
    );
  }
}

class _Explanation extends StatelessWidget {
  const _Explanation({required this.answer, this.opponent});

  final AnswerRecord answer;
  final QuizState? opponent;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final reveal = answer.reveal;
    final duel = opponent;
    return NyayaCard(
      color: context.colors.surfaceContainerLow,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (duel != null && duel.opponent != null) ...[
            Row(
              children: [
                InitialsAvatar(name: duel.opponent!.name, seed: duel.opponent!.avatarSeed, size: 26),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    l.quizOpponentAnswered(
                      duel.opponent!.name,
                      (duel.opponentAnswers[duel.index].elapsedMs / 1000).round(),
                    ),
                    style: context.text.bodySmall,
                  ),
                ),
                Icon(
                  duel.opponentAnswers[duel.index].correct ? Icons.check_circle_rounded : Icons.cancel_rounded,
                  color: duel.opponentAnswers[duel.index].correct ? context.nyaya.success : context.nyaya.error,
                  size: 20,
                ),
              ],
            ),
            const Divider(height: 20),
          ],
          if (reveal != null) ...[
            Row(
              children: [
                const Icon(Icons.menu_book_rounded, size: 18, color: AppPalette.ochreText),
                const SizedBox(width: 6),
                Text(l.quizWhy, style: context.text.titleSmall),
              ],
            ),
            const SizedBox(height: 6),
            Text(reveal.explanation, style: context.text.bodyMedium?.copyWith(height: 1.5)),
            const SizedBox(height: 8),
            SourceLine(reference: reveal.reference, url: reveal.sourceUrl),
            const SizedBox(height: 4),
            QuestionActions(questionId: answer.question.questionId, questionVersionId: answer.question.id),
          ],
        ],
      ),
    ).animate().fadeIn(duration: 250.ms).slideY(begin: 0.1);
  }
}

class _BottomBar extends StatelessWidget {
  const _BottomBar({required this.state, required this.answered, required this.onNext, required this.onRetry});

  final QuizState state;
  final int answered;
  final VoidCallback onNext;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final n = context.nyaya;
    final mode = state.request.mode;
    final last = state.revealed ? state.lastAnswer : null;
    final Color? tint;
    final String? title;
    final IconData? icon;
    if (last == null) {
      tint = null;
      title = null;
      icon = null;
    } else if (last.isCorrect) {
      tint = n.success;
      title = l.quizCorrect;
      icon = Icons.check_circle_rounded;
    } else {
      tint = n.error;
      title = last.isSkipped ? l.quizTimeUp : l.quizWrong;
      icon = last.isSkipped ? Icons.timer_off_rounded : Icons.cancel_rounded;
    }

    if (state.phase == QuizPhase.submitting || state.submitFailed) {
      final failed = state.submitFailed;
      return Container(
        padding: const EdgeInsets.fromLTRB(AppSpacing.page, AppSpacing.md, AppSpacing.page, AppSpacing.md),
        decoration: BoxDecoration(
          color: context.colors.surface,
          border: Border(top: BorderSide(color: n.cardBorder)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              failed ? l.quizSubmitFailed : l.quizScoring,
              textAlign: TextAlign.center,
              style: context.text.labelMedium?.copyWith(color: failed ? n.error : n.textSecondary),
            ),
            const SizedBox(height: 8),
            ChunkyButton(label: l.quizRetry, color: context.colors.primary, onPressed: failed ? onRetry : null),
          ],
        ),
      );
    }

    final String label;
    if (mode == QuizMode.exam) {
      label = state.isLast ? l.quizSubmit : (state.selected == null ? l.quizSkipQuestion : l.commonNext);
    } else {
      label = state.isLast && state.revealed ? l.quizFinish : l.commonNext;
    }

    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      padding: const EdgeInsets.fromLTRB(AppSpacing.page, AppSpacing.md, AppSpacing.page, AppSpacing.md),
      decoration: BoxDecoration(
        color: tint == null ? context.colors.surface : (tint == n.success ? n.successContainer : n.errorContainer),
        border: Border(
          top: BorderSide(color: tint ?? n.cardBorder, width: tint == null ? 1 : 2),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (title != null) ...[
            Row(
              children: [
                Icon(icon, color: tint, size: 28),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(title, style: context.text.titleLarge?.copyWith(color: tint)),
                ),
              ],
            ).animate().fadeIn(duration: 200.ms).slideY(begin: 0.3),
            if (!last!.isCorrect && last.reveal?.correctIndex != null) ...[
              const SizedBox(height: 4),
              Text(
                l.quizAnswerWas(last.question.options[last.reveal!.correctIndex!]),
                style: context.text.bodyMedium?.copyWith(color: tint, fontWeight: FontWeight.w600),
              ),
            ],
            const SizedBox(height: 12),
          ] else if (mode == QuizMode.exam) ...[
            Text(
              l.quizMarkedAnswers(answered, state.questions.length),
              textAlign: TextAlign.center,
              style: context.text.labelMedium?.copyWith(color: n.textSecondary),
            ),
            const SizedBox(height: 8),
          ] else if (!state.revealed) ...[
            Text(
              l.quizSelectAnswer,
              textAlign: TextAlign.center,
              style: context.text.labelMedium?.copyWith(color: n.textSecondary),
            ),
            const SizedBox(height: 8),
          ],
          ChunkyButton(
            label: label,
            color: tint ?? context.colors.primary,
            onPressed: state.canAdvance ? onNext : null,
          ),
        ],
      ),
    );
  }
}

class _QuestionTimer extends StatelessWidget {
  const _QuestionTimer({required this.seconds, required this.total, required this.paused});

  final int seconds;
  final int total;
  final bool paused;

  @override
  Widget build(BuildContext context) {
    final urgent = seconds <= 5 && !paused;
    final color = urgent ? context.nyaya.error : AppPalette.ochre;
    return Row(
      children: [
        Icon(Icons.timer_rounded, size: 18, color: color),
        const SizedBox(width: 6),
        Expanded(
          child: GlossyProgressBar(value: seconds / total, color: color, height: 8),
        ),
        const SizedBox(width: 8),
        SizedBox(
          width: 28,
          child: Text(
            '${seconds}s',
            textAlign: TextAlign.end,
            style: context.text.labelMedium?.copyWith(color: color),
          ),
        ),
      ],
    );
  }
}

class _ExamClock extends StatelessWidget {
  const _ExamClock({required this.seconds});

  final int seconds;

  @override
  Widget build(BuildContext context) {
    final mm = (seconds ~/ 60).toString().padLeft(2, '0');
    final ss = (seconds % 60).toString().padLeft(2, '0');
    final urgent = seconds < 60;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: (urgent ? context.nyaya.error : context.colors.primary).withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppRadius.xl),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.timer_rounded, size: 16, color: urgent ? context.nyaya.error : context.colors.primary),
          const SizedBox(width: 4),
          Text('$mm:$ss', style: context.text.labelLarge?.copyWith(fontFeatures: const [FontFeature.tabularFigures()])),
        ],
      ),
    );
  }
}

class _ComboBadge extends StatelessWidget {
  const _ComboBadge({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: AppPalette.burntClay,
        borderRadius: BorderRadius.circular(AppRadius.xl),
      ),
      child: Text(
        context.l10n.quizCombo(count),
        style: context.text.labelMedium?.copyWith(color: Colors.white, fontWeight: FontWeight.w900),
      ),
    ).animate(key: ValueKey(count)).scale(begin: const Offset(1.3, 1.3), curve: Curves.elasticOut, duration: 500.ms);
  }
}

class _DuelHeader extends ConsumerWidget {
  const _DuelHeader({required this.state});

  final QuizState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final name = ref.watch(profileProvider.select((p) => p.name));
    final o = state.opponent!;
    Widget side(String n, int seed, int points, bool alignEnd, {String? tag}) => Expanded(
      child: Row(
        mainAxisAlignment: alignEnd ? MainAxisAlignment.end : MainAxisAlignment.start,
        children: [
          if (!alignEnd) ...[InitialsAvatar(name: n, seed: seed, size: 34), const SizedBox(width: 8)],
          Flexible(
            child: Column(
              crossAxisAlignment: alignEnd ? CrossAxisAlignment.end : CrossAxisAlignment.start,
              children: [
                Text(n, maxLines: 1, overflow: TextOverflow.ellipsis, style: context.text.labelMedium),
                if (tag != null)
                  Text(
                    tag,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: context.text.labelSmall?.copyWith(color: context.nyaya.textSecondary),
                  ),
                Text(
                  '$points',
                  style: context.text.titleMedium?.copyWith(fontFeatures: const [FontFeature.tabularFigures()]),
                ),
              ],
            ),
          ),
          if (alignEnd) ...[const SizedBox(width: 8), InitialsAvatar(name: n, seed: seed, size: 34)],
        ],
      ),
    );
    return NyayaCard(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Row(
        children: [
          side(name.isEmpty ? l.leaderboardYou : name, 0, state.playerPoints, false),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Text(l.quizVs, style: context.text.titleSmall?.copyWith(color: AppPalette.burntClay)),
          ),
          // A practice player stands in when no learner's run fitted; say so.
          side(o.name, o.avatarSeed, state.opponentPoints, true, tag: o.practice ? l.leaderboardPractice : null),
        ],
      ),
    );
  }
}
