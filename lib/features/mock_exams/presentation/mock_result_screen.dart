import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../../app/router.dart';
import '../../../core/api/api_client.dart';
import '../../../core/l10n/l10n.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../application/mock_exam_providers.dart';
import '../domain/mock_exam_models.dart';
import 'mock_exam_format.dart';

/// The result of a finished attempt. A provisional result says so, and a pass
/// is shown only when the server says it could be judged.
class MockResultScreen extends ConsumerWidget {
  const MockResultScreen({super.key, required this.attemptId});

  final String attemptId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final result = ref.watch(attemptResultProvider(attemptId));
    return Scaffold(
      appBar: AppBar(title: Text(l.mockResultTitle)),
      body: SafeArea(
        child: result.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.page),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(e is ApiException && e.isNetwork ? l.mockNetworkError : l.mockLoadError, textAlign: TextAlign.center),
                  const SizedBox(height: AppSpacing.md),
                  FilledButton(onPressed: () => ref.invalidate(attemptResultProvider(attemptId)), child: Text(l.mockRetry)),
                ],
              ),
            ),
          ),
          data: (r) => _ResultBody(result: r),
        ),
      ),
    );
  }
}

/// Pass mark for mock results: 45% or more.
const mockPassPercent = 45;

/// The score shown to the learner. Uses the paper's configured marks when
/// there are any; otherwise one mark per correct answer, no negative marking,
/// out of the paper's questions.
({double score, double max, double percent, bool pass}) mockScore(AttemptResult r) {
  final o = r.overall;
  double score, max;
  if (r.marksAvailable && o.marksObtained != null && o.maxMarks != null && o.maxMarks! > 0) {
    score = o.marksObtained!;
    max = o.maxMarks!;
  } else {
    score = o.correct.toDouble();
    max = (o.totalPositions > 0 ? o.totalPositions : o.correct + o.incorrect + o.unanswered + o.withdrawn).toDouble();
  }
  if (score < 0) score = 0;
  final percent = max > 0 ? score / max * 100 : 0.0;
  return (score: score, max: max, percent: percent, pass: max > 0 && score * 100 >= mockPassPercent * max);
}

class _ResultBody extends StatelessWidget {
  const _ResultBody({required this.result});

  final AttemptResult result;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final theme = Theme.of(context).textTheme;
    final s = mockScore(result);
    return ListView(
      padding: const EdgeInsets.all(AppSpacing.page),
      children: [
        if (result.status == AttemptStatus.expired)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.md),
            child: Text(l.mockExpiredNote, style: theme.titleMedium),
          ),
        if (result.provisional) _Banner(title: l.mockProvisionalTitle, lines: [l.mockProvisionalBody, ...result.provisionalReasons]),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(
              children: [
                _ScoreRing(score: s.score, max: s.max, percent: s.percent),
                const SizedBox(height: AppSpacing.md),
                _PassBadge(pass: s.pass),
                const SizedBox(height: AppSpacing.lg),
                _Counts(tally: result.overall),
              ],
            ),
          ),
        ),
        if (result.sections.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.md),
          Text(l.mockSectionsTitle, style: theme.titleMedium),
          for (final sec in result.sections)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.md),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(l.mockSectionName(sec.code ?? ''), style: theme.titleSmall),
                    const SizedBox(height: AppSpacing.xs),
                    if (result.marksAvailable && sec.marksObtained != null && sec.maxMarks != null)
                      Text(l.mockMarks(formatMarks(sec.marksObtained!), formatMarks(sec.maxMarks!))),
                    _Counts(tally: sec),
                  ],
                ),
              ),
            ),
        ],
        const SizedBox(height: AppSpacing.lg),
        FilledButton(
          onPressed: () => context.push(Routes.mockReview(result.attemptId)),
          child: Text(l.mockViewReview),
        ),
        const SizedBox(height: AppSpacing.sm),
        OutlinedButton(onPressed: () => context.go(Routes.mockExams), child: Text(l.mockBackToMockExams)),
      ],
    );
  }
}

/// A circular gauge with the score out of the maximum in the middle.
class _ScoreRing extends StatelessWidget {
  const _ScoreRing({required this.score, required this.max, required this.percent});

  final double score;
  final double max;
  final double percent;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final theme = Theme.of(context).textTheme;
    final colors = context.colors;
    final label = l.mockMarks(formatMarks(score), formatMarks(max));
    final pct = l.mockPercent(formatMarks(double.parse(percent.toStringAsFixed(1))));
    return Semantics(
      label: '$label, $pct',
      excludeSemantics: true,
      child: SizedBox(
        width: 184,
        height: 184,
        child: Stack(
          alignment: Alignment.center,
          children: [
            SizedBox(
              width: 184,
              height: 184,
              child: CircularProgressIndicator(
                value: (percent / 100).clamp(0.0, 1.0),
                strokeWidth: 14,
                strokeCap: StrokeCap.round,
                backgroundColor: colors.surfaceContainerHighest,
              ),
            ),
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(label, style: theme.displaySmall?.copyWith(fontWeight: FontWeight.w700)),
                Text(pct, style: theme.titleMedium?.copyWith(color: colors.onSurfaceVariant)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _PassBadge extends StatelessWidget {
  const _PassBadge({required this.pass});

  final bool pass;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final colors = context.colors;
    final bg = pass ? context.nyaya.successContainer : colors.errorContainer;
    final fg = pass ? context.nyaya.success : colors.onErrorContainer;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.sm),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(999)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(pass ? Icons.check_circle : Icons.cancel, color: fg, size: 20),
        const SizedBox(width: AppSpacing.sm),
        Text(
          pass ? l.mockResultPass : l.mockResultFail,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(color: fg, fontWeight: FontWeight.w700, letterSpacing: 1),
        ),
      ]),
    );
  }
}

class _Counts extends StatelessWidget {
  const _Counts({required this.tally});

  final Tally tally;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    Widget cell(String label, int n) => Expanded(
          child: Semantics(
            label: '$label: $n',
            excludeSemantics: true,
            child: Column(children: [
              Text('$n', style: Theme.of(context).textTheme.titleLarge),
              Text(label, style: Theme.of(context).textTheme.bodySmall, textAlign: TextAlign.center),
            ]),
          ),
        );
    return Row(children: [
      cell(l.mockCorrect, tally.correct),
      cell(l.mockIncorrect, tally.incorrect),
      cell(l.mockUnanswered, tally.unanswered),
      if (tally.withdrawn > 0) cell(l.mockWithdrawnCount, tally.withdrawn),
    ]);
  }
}

class _Banner extends StatelessWidget {
  const _Banner({required this.title, required this.lines});

  final String title;
  final List<String> lines;

  @override
  Widget build(BuildContext context) => Semantics(
        container: true,
        child: Card(
          color: context.colors.tertiaryContainer,
          margin: const EdgeInsets.only(bottom: AppSpacing.md),
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            // Text on the container colour needs its own "on" colour to stay readable in dark mode.
            child: DefaultTextStyle.merge(
              style: TextStyle(color: context.colors.onTertiaryContainer),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Icon(Icons.info_outline, color: context.colors.onTertiaryContainer),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(child: Text(title, style: Theme.of(context).textTheme.titleMedium?.copyWith(color: context.colors.onTertiaryContainer))),
                  ]),
                  for (final line in lines)
                    Padding(padding: const EdgeInsets.only(top: AppSpacing.xs), child: Text(line)),
                ],
              ),
            ),
          ),
        ),
      );
}

