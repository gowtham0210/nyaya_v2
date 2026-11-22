import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../../app/router.dart';
import '../../../core/l10n/l10n.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../application/mock_exam_providers.dart';

/// Home's way in to Mock Exams. It shows only while at least one exam is open
/// to learners: with every exam switched off (or while loading, or offline)
/// it takes no space at all. Styled like the Core Laws rows around it.
class MockExamsCard extends ConsumerWidget {
  const MockExamsCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final open = ref.watch(availableMockExamsProvider).asData?.value ?? const <String>[];
    if (open.isEmpty) return const SizedBox.shrink();
    final l = context.l10n;
    final colors = context.colors;
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Semantics(
        button: true,
        label: '${l.mockExamsTitle}. ${l.mockHomeCardBody}',
        child: Container(
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            color: colors.surface,
            borderRadius: BorderRadius.circular(AppRadius.md),
            border: Border.all(color: context.nyaya.cardBorder),
          ),
          child: Material(
            type: MaterialType.transparency,
            child: InkWell(
              onTap: () => context.push(Routes.mockExams),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(AppSpacing.md, 14, AppSpacing.sm, 14),
                child: ExcludeSemantics(
                  child: Row(
                    children: [
                      SizedBox(width: 44, child: Icon(Icons.assignment_outlined, size: 34, color: colors.primary)),
                      const SizedBox(width: AppSpacing.md),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              l.mockExamsTitle,
                              style: AppTheme.serif(
                                TextStyle(fontSize: 18, height: 1.15, color: colors.onSurface),
                                display: false,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              l.mockHomeCardBody,
                              style: context.text.bodyMedium?.copyWith(color: context.nyaya.textSecondary),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: AppSpacing.xs),
                      Icon(Icons.chevron_right_rounded, color: colors.onSurface),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
