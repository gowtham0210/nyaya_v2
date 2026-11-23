import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/api/api_client.dart';
import '../../../core/l10n/l10n.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../application/mock_exam_providers.dart';
import '../domain/mock_exam_models.dart';
import 'mock_exam_format.dart';

/// Every question of a finished attempt with the accepted answers and the
/// explanation. The server only sends this once the attempt is submitted, and
/// the app never stores it.
class MockReviewScreen extends ConsumerWidget {
  const MockReviewScreen({super.key, required this.attemptId});

  final String attemptId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final review = ref.watch(attemptReviewProvider(attemptId));
    return Scaffold(
      appBar: AppBar(title: Text(l.mockReviewTitle)),
      body: SafeArea(
        child: review.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.page),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(e is ApiException && e.isNetwork ? l.mockNetworkError : l.mockLoadError, textAlign: TextAlign.center),
                  const SizedBox(height: AppSpacing.md),
                  FilledButton(onPressed: () => ref.invalidate(attemptReviewProvider(attemptId)), child: Text(l.mockRetry)),
                ],
              ),
            ),
          ),
          data: (r) => ListView(
            padding: const EdgeInsets.all(AppSpacing.page),
            children: [
              if (r.provisional)
                Card(
                  color: context.colors.tertiaryContainer,
                  child: Padding(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    child: Text(
                      [l.mockProvisionalBody, ...r.reasons].join('\n'),
                      style: TextStyle(color: context.colors.onTertiaryContainer),
                    ),
                  ),
                ),
              for (final item in r.items) _ReviewCard(item: item, total: r.items.length),
            ],
          ),
        ),
      ),
    );
  }
}

class _ReviewCard extends StatelessWidget {
  const _ReviewCard({required this.item, required this.total});

  final ReviewItem item;
  final int total;

  String _texts(List<String> ids) =>
      [for (final o in item.options) if (ids.contains(o.id)) o.text].join(', ');

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final theme = Theme.of(context).textTheme;
    final outcome = switch (item.outcome) {
      'correct' => l.mockCorrect,
      'incorrect' => l.mockIncorrect,
      'unanswered' => l.mockUnanswered,
      'withdrawn_unscored' || 'withdrawn_awarded' => l.mockOutcomeWithdrawn,
      _ => item.outcome,
    };
    final good = item.outcome == 'correct';
    return Card(
      margin: const EdgeInsets.only(top: AppSpacing.md),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Expanded(child: Text(l.mockQuestionOf('${item.position}', '$total'), style: theme.labelLarge)),
              Icon(good ? Icons.check_circle : Icons.circle_outlined, size: 18),
              const SizedBox(width: 4),
              Text(outcome),
              if (item.marks != null) Text('  ${item.marks! > 0 ? '+' : ''}${formatMarks(item.marks!)}'),
            ]),
            if (!item.withdrawn) ...[
              const SizedBox(height: AppSpacing.sm),
              Text(item.stem ?? '', style: theme.titleSmall),
              const SizedBox(height: AppSpacing.sm),
              Text('${l.mockYourAnswer}: ${item.selected.isEmpty ? l.mockNotAnswered : _texts(item.selected)}'),
              Text('${l.mockAcceptedAnswer}: ${_texts(item.accepted)}'),
              if (item.explanation != null && item.explanation!.isNotEmpty) ...[
                const SizedBox(height: AppSpacing.sm),
                Text(l.mockExplanation, style: theme.labelLarge),
                Text(item.explanation!),
              ],
            ],
          ],
        ),
      ),
    );
  }
}
