import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/api/api_client.dart';
import '../../../core/l10n/l10n.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../application/mock_exam_providers.dart';
import '../domain/mock_exam_models.dart';
import 'mock_exam_format.dart';
import 'mock_exam_home_screen.dart';

/// What a learner sees before an attempt: the paper's details, the
/// instructions, and the buttons that start it. Everything about the paper
/// comes from the server; nothing here is invented.
///
/// [paperId] null means a random mock.
class MockExamInstructionsScreen extends ConsumerWidget {
  const MockExamInstructionsScreen({
    super.key,
    required this.slug,
    this.paperId,
  });

  final String slug;
  final String? paperId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    if (paperId == null) {
      return _page(
        context,
        ref,
        title: l.mockRandomTitle,
        paper: null,
        timedPaper: false,
      );
    }
    final papers = ref.watch(mockExamPapersProvider(slug));
    return papers.when(
      loading: () => Scaffold(
        appBar: AppBar(title: Text(l.mockDetailsTitle)),
        body: const Center(child: CircularProgressIndicator()),
      ),
      error: (e, _) => Scaffold(
        appBar: AppBar(title: Text(l.mockDetailsTitle)),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.page),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  e is ApiException && e.isNetwork
                      ? l.mockNetworkError
                      : l.mockLoadError,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: AppSpacing.sm),
                FilledButton(
                  onPressed: () => ref.invalidate(mockExamPapersProvider(slug)),
                  child: Text(l.mockRetry),
                ),
              ],
            ),
          ),
        ),
      ),
      data: (list) {
        final paper = list.where((p) => p.id == paperId).firstOrNull;
        if (paper == null) {
          return Scaffold(
            appBar: AppBar(title: Text(l.mockDetailsTitle)),
            body: Center(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.page),
                child: Text(l.mockNoPapers),
              ),
            ),
          );
        }
        return _page(
          context,
          ref,
          title: paper.title,
          paper: paper,
          timedPaper: true,
        );
      },
    );
  }

  Widget _page(
    BuildContext context,
    WidgetRef ref, {
    required String title,
    required PaperSummary? paper,
    required bool timedPaper,
  }) {
    final l = context.l10n;
    final theme = Theme.of(context);
    final colors = context.colors;
    final facts = <(IconData, String)>[
      if (paper?.edition != null)
        (Icons.workspace_premium_outlined, paper!.edition!),
      if (paper?.year != null)
        (Icons.calendar_today_outlined, '${paper!.year}'),
      if (paper?.setLabel != null) (Icons.layers_outlined, paper!.setLabel!),
      if (paper != null)
        (Icons.quiz_outlined, l.mockPaperQuestions('${paper.totalQuestions}')),
      if (paper?.durationSeconds != null)
        (
          Icons.timer_outlined,
          l.mockPaperMinutes('${paper!.durationSeconds! ~/ 60}'),
        ),
    ];
    return Scaffold(
      appBar: AppBar(title: Text(l.mockDetailsTitle)),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 640),
            child: Column(
              children: [
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.all(AppSpacing.page),
                    children: [
                      Card(
                        margin: EdgeInsets.zero,
                        child: Padding(
                          padding: const EdgeInsets.all(AppSpacing.lg),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                mockExamName(slug),
                                style: theme.textTheme.labelLarge?.copyWith(
                                  color: colors.primary,
                                ),
                              ),
                              const SizedBox(height: AppSpacing.xs),
                              Semantics(
                                header: true,
                                child: Text(
                                  title,
                                  style: theme.textTheme.headlineSmall,
                                ),
                              ),
                              if (facts.isNotEmpty) ...[
                                const SizedBox(height: AppSpacing.md),
                                Wrap(
                                  spacing: AppSpacing.md,
                                  runSpacing: AppSpacing.sm,
                                  children: [
                                    for (final f in facts)
                                      Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(
                                            f.$1,
                                            size: 18,
                                            color: colors.onSurfaceVariant,
                                          ),
                                          const SizedBox(width: AppSpacing.xs),
                                          Text(
                                            f.$2,
                                            style: theme.textTheme.bodyMedium,
                                          ),
                                        ],
                                      ),
                                  ],
                                ),
                              ],
                              const SizedBox(height: AppSpacing.lg),
                              Row(
                                children: [
                                  Icon(
                                    Icons.check_circle_outline,
                                    size: 18,
                                    color: colors.primary,
                                  ),
                                  const SizedBox(width: AppSpacing.sm),
                                  Expanded(child: Text(l.mockPracticeNote)),
                                ],
                              ),
                              const SizedBox(height: AppSpacing.lg),
                              const Divider(height: 1),
                              const SizedBox(height: AppSpacing.md),
                              Semantics(
                                header: true,
                                child: Text(
                                  l.mockInstructionsHeading,
                                  style: theme.textTheme.titleMedium,
                                ),
                              ),
                              const SizedBox(height: AppSpacing.sm),
                              for (final text in [
                                l.mockInstrAnswer,
                                l.mockInstrNavigate,
                                l.mockInstrMark,
                                l.mockInstrSave,
                                l.mockInstrResume,
                                l.mockInstrReview,
                              ])
                                Padding(
                                  padding: const EdgeInsets.only(
                                    bottom: AppSpacing.sm,
                                  ),
                                  child: Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Padding(
                                        padding: const EdgeInsets.only(top: 2),
                                        child: Icon(
                                          Icons.check_circle_outline,
                                          size: 18,
                                          color: colors.primary,
                                        ),
                                      ),
                                      const SizedBox(width: AppSpacing.sm),
                                      Expanded(
                                        child: Text(
                                          text,
                                          style: theme.textTheme.bodyMedium,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.page,
                    AppSpacing.sm,
                    AppSpacing.page,
                    AppSpacing.page,
                  ),
                  child: MockStartPanel(slug: slug, paper: paper),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
