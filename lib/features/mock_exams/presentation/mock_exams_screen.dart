import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../../app/router.dart';
import '../../../core/l10n/l10n.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/common.dart';
import '../application/mock_exam_providers.dart';
import 'mock_exam_format.dart';

/// The exams open to learners right now (only those the API shows).
class MockExamsScreen extends ConsumerWidget {
  const MockExamsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final open = ref.watch(availableMockExamsProvider);
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          tooltip: MaterialLocalizations.of(context).backButtonTooltip,
          icon: const Icon(Icons.arrow_back_rounded),
          // Nothing behind it when opened from a link: go Home instead.
          onPressed: () => context.canPop() ? context.pop() : context.go(Routes.home),
        ),
        title: Text(l.mockExamsTitle),
        actions: [
          IconButton(
            tooltip: l.mockHistoryTitle,
            icon: const Icon(Icons.history),
            onPressed: () => context.push(Routes.mockHistory),
          ),
        ],
      ),
      body: SafeArea(
        child: open.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => _Message(
            text: l.mockLoadError,
            action: l.mockRetry,
            onAction: () => ref.invalidate(availableMockExamsProvider),
          ),
          data: (slugs) => slugs.isEmpty
              ? _Message(text: l.mockExamsEmpty, detail: l.mockExamsEmptyBody)
              : ListView(
                  padding: const EdgeInsets.all(AppSpacing.page),
                  children: [
                    Text(
                      l.mockExamsIntro,
                      style: context.text.bodyLarge?.copyWith(color: context.nyaya.textSecondary),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    for (final slug in slugs)
                      Padding(
                        padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                        child: NyayaCard(
                          onTap: () => context.push(Routes.mockExam(slug)),
                          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: 18),
                          child: Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      mockExamName(slug),
                                      style: AppTheme.serif(
                                        TextStyle(
                                          fontSize: 24,
                                          height: 1.15,
                                          letterSpacing: context.tracking(1),
                                          color: context.colors.onSurface,
                                        ),
                                      ),
                                    ),
                                    if (mockExamFullName(slug) case final full?) ...[
                                      const SizedBox(height: 4),
                                      Text(
                                        full,
                                        style: context.text.bodyMedium?.copyWith(color: context.nyaya.textSecondary),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                              Icon(Icons.chevron_right_rounded, color: context.colors.onSurface),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
        ),
      ),
    );
  }
}

class _Message extends StatelessWidget {
  const _Message({required this.text, this.detail, this.action, this.onAction});

  final String text;
  final String? detail;
  final String? action;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.page),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.assignment_outlined, size: 48, color: context.colors.onSurfaceVariant),
              const SizedBox(height: AppSpacing.md),
              Text(text, textAlign: TextAlign.center, style: Theme.of(context).textTheme.titleMedium),
              if (detail != null) ...[
                const SizedBox(height: AppSpacing.sm),
                Text(detail!, textAlign: TextAlign.center),
              ],
              if (action != null) ...[
                const SizedBox(height: AppSpacing.md),
                FilledButton(onPressed: onAction, child: Text(action!)),
              ],
            ],
          ),
        ),
      );
}
