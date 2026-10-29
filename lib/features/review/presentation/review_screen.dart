import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../../app/router.dart';
import '../../../core/l10n/l10n.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/chunky_button.dart';
import '../../../core/widgets/common.dart';
import '../../auth/application/auth_controller.dart';
import '../../quiz/domain/quiz_models.dart';
import '../../quiz/presentation/quiz_launcher.dart';
import '../../quiz/presentation/source_line.dart';
import '../application/review_controller.dart';
import '../data/review_api.dart';

/// Mistakes and saved questions, with free mistake practice.
class ReviewScreen extends ConsumerWidget {
  const ReviewScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final signedIn = ref.watch(authProvider) != null;
    final review = ref.watch(reviewProvider);
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: Text(l.reviewTitle),
          bottom: TabBar(
            labelStyle: context.text.labelLarge,
            tabs: [Tab(text: l.reviewMistakesTab), Tab(text: l.reviewSavedTab)],
          ),
        ),
        body: !signedIn
            ? _Message(text: l.reviewSignIn)
            : review.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (_, _) => _Message(text: l.quizOffline, onRetry: () => ref.invalidate(reviewProvider)),
                data: (s) => TabBarView(
                  children: [
                    _List(
                      empty: l.reviewEmptyMistakes,
                      header: s.practisable == 0
                          ? null
                          : Padding(
                              padding: const EdgeInsets.only(bottom: AppSpacing.md),
                              child: Column(
                                children: [
                                  ChunkyButton(
                                    label: l.reviewPractise,
                                    icon: Icons.replay_rounded,
                                    onPressed: () =>
                                        QuizLauncher.start(context, ref, const QuizRequest(QuizMode.mistakeReview)),
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    l.reviewPractiseFree,
                                    style: context.text.bodySmall?.copyWith(color: context.nyaya.textSecondary),
                                  ),
                                ],
                              ),
                            ),
                      items: [
                        for (final m in s.mistakes)
                          _QuestionCard(
                            question: m.question,
                            saved: s.savedIds.contains(m.question.questionId),
                            note: l.reviewWrongTimes(m.wrongCount),
                          ),
                      ],
                    ),
                    _List(
                      empty: l.reviewEmptySaved,
                      items: [
                        for (final q in s.saved) _QuestionCard(question: q.question, saved: true),
                      ],
                    ),
                  ],
                ),
              ),
      ),
    );
  }
}

class _List extends ConsumerWidget {
  const _List({required this.empty, required this.items, this.header});

  final String empty;
  final List<Widget> items;
  final Widget? header;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return RefreshIndicator(
      onRefresh: () => ref.refresh(reviewProvider.future),
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(AppSpacing.page),
        children: [
          ?header,
          if (items.isEmpty)
            Padding(
              padding: const EdgeInsets.only(top: AppSpacing.xl),
              child: Text(
                empty,
                textAlign: TextAlign.center,
                style: context.text.bodyLarge?.copyWith(color: context.nyaya.textSecondary),
              ),
            ),
          ...items,
        ],
      ),
    );
  }
}

class _QuestionCard extends ConsumerWidget {
  const _QuestionCard({required this.question, required this.saved, this.note});

  final ReviewQuestion question;
  final bool saved;
  final String? note;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final q = question;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: NyayaCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: Text(q.stem, style: context.text.titleSmall)),
                IconButton(
                  tooltip: saved ? l.questionSaved : l.questionSave,
                  visualDensity: VisualDensity.compact,
                  onPressed: () => ref.read(reviewProvider.notifier).toggleSave(q.questionId),
                  icon: Icon(saved ? Icons.bookmark_rounded : Icons.bookmark_border_rounded),
                ),
              ],
            ),
            if (note != null)
              Text(note!, style: context.text.labelSmall?.copyWith(color: context.nyaya.error)),
            if (q.updatedSince)
              Text(l.reviewUpdatedSince, style: context.text.labelSmall?.copyWith(color: context.nyaya.textSecondary)),
            const SizedBox(height: 6),
            if (!q.available)
              Text(l.reviewUnavailable, style: context.text.bodySmall?.copyWith(color: context.nyaya.textSecondary))
            else ...[
              Text(
                '${l.resultCorrectAnswer}: ${q.correctTexts.join(', ')}',
                style: context.text.bodySmall?.copyWith(color: context.nyaya.success, fontWeight: FontWeight.w700),
              ),
              if ((q.explanation ?? '').isNotEmpty) ...[
                const SizedBox(height: 6),
                Text(
                  q.explanation!,
                  style: context.text.bodySmall?.copyWith(color: context.nyaya.textSecondary, height: 1.4),
                ),
              ],
              const SizedBox(height: 6),
              SourceLine(reference: q.reference ?? '', url: q.sourceUrl),
            ],
          ],
        ),
      ),
    );
  }
}

class _Message extends StatelessWidget {
  const _Message({required this.text, this.onRetry});

  final String text;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.page),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(text, textAlign: TextAlign.center, style: context.text.bodyLarge),
            if (onRetry != null) ...[
              const SizedBox(height: AppSpacing.md),
              FilledButton(onPressed: onRetry, child: Text(l.commonRetry)),
            ],
          ],
        ),
      ),
    );
  }
}

/// Home: your mistakes and saved questions at a glance. Hidden until there is
/// something to review.
class ReviewCard extends ConsumerWidget {
  const ReviewCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final s = ref.watch(reviewProvider).value;
    if (s == null || (s.mistakes.isEmpty && s.saved.isEmpty)) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.lg),
      child: NyayaCard(
        onTap: () => context.push(Routes.review),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(shape: BoxShape.circle, color: context.colors.secondaryContainer),
              child: const Icon(Icons.fact_check_rounded, color: AppPalette.burntClay),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(l.reviewTitle, style: context.text.titleMedium),
                  Text(
                    l.reviewCardBody(s.mistakes.length, s.saved.length),
                    style: context.text.bodySmall?.copyWith(color: context.nyaya.textSecondary),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded),
          ],
        ),
      ),
    );
  }
}
