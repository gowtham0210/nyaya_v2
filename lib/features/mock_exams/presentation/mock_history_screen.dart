import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:material_ui/material_ui.dart';

import '../../../app/router.dart';
import '../../../core/l10n/l10n.dart';
import '../../../core/theme/app_theme.dart';
import '../application/mock_exam_providers.dart';
import '../domain/mock_exam_models.dart';
import 'mock_exam_format.dart';

/// A learner's attempts, newest first, with basic statistics.
class MockHistoryScreen extends ConsumerWidget {
  const MockHistoryScreen({super.key, this.exam});

  /// Limits the list to one exam (its slug).
  final String? exam;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final history = ref.watch(attemptHistoryProvider(exam));
    final stats = ref.watch(examStatsProvider).asData?.value ?? const <ExamStats>[];
    final shown = exam == null ? stats : stats.where((s) => s.exam == exam).toList();
    return Scaffold(
      appBar: AppBar(title: Text(l.mockHistoryTitle)),
      body: SafeArea(
        child: history.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Text(l.mockLoadError, textAlign: TextAlign.center),
              const SizedBox(height: AppSpacing.md),
              FilledButton(
                onPressed: () {
                  ref.invalidate(attemptHistoryProvider(exam));
                  ref.invalidate(examStatsProvider);
                },
                child: Text(l.mockRetry),
              ),
            ]),
          ),
          data: (items) => items.isEmpty
              ? Center(child: Text(l.mockHistoryEmpty))
              : ListView(
                  padding: const EdgeInsets.all(AppSpacing.page),
                  children: [
                    if (shown.isNotEmpty) ...[
                      Text(l.mockStatsTitle, style: Theme.of(context).textTheme.titleMedium),
                      for (final s in shown)
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          title: Text(mockExamName(s.exam)),
                          subtitle: Text(
                            s.withMarks == 0
                                ? l.mockStatsNoMarks('${s.attempts}')
                                : l.mockStatsLine(
                                    '${s.attempts}',
                                    '${formatMarks(s.bestPercentage ?? 0)}%',
                                    '${formatMarks(s.averagePercentage ?? 0)}%',
                                  ),
                          ),
                        ),
                      const Divider(),
                    ],
                    for (final a in items) _AttemptTile(attempt: a),
                  ],
                ),
        ),
      ),
    );
  }
}

class _AttemptTile extends StatelessWidget {
  const _AttemptTile({required this.attempt});

  final AttemptSummary attempt;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final a = attempt;
    final date = DateFormat.yMMMd().add_jm().format(a.startedAt.toLocal());
    final score = a.status == AttemptStatus.inProgress
        ? l.mockInProgress
        : (a.marksObtained != null && a.maxMarks != null
            ? l.mockMarks(formatMarks(a.marksObtained!), formatMarks(a.maxMarks!))
            : '');
    return ListTile(
      contentPadding: EdgeInsets.zero,
      minVerticalPadding: AppSpacing.sm,
      title: Text('${mockExamName(a.exam)} · ${a.paperTitle ?? l.mockRandomTitle}'),
      subtitle: Text([
        date,
        a.mode == AttemptMode.timed ? l.mockModeTimed : l.mockModePractice,
        if (score.isNotEmpty) score,
        if (a.provisional == true) l.mockProvisionalTitle,
      ].join(' · ')),
      trailing: const Icon(Icons.chevron_right),
      onTap: () => context.push(
        a.status == AttemptStatus.inProgress ? Routes.mockAttempt(a.exam, a.id) : Routes.mockResult(a.id),
      ),
    );
  }
}
