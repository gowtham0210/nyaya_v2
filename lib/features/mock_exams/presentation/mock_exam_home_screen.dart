import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../../app/router.dart';
import '../../../core/api/api_client.dart';
import '../../../core/l10n/l10n.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/common.dart';
import '../application/mock_exam_providers.dart';
import '../data/mock_exam_api.dart';
import '../domain/mock_exam_models.dart';
import 'mock_exam_format.dart';

/// One exam: the unfinished attempt (to resume), a random mock, and the
/// published previous-year papers.
class MockExamHomeScreen extends ConsumerWidget {
  const MockExamHomeScreen({super.key, required this.slug});

  final String slug;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final papers = ref.watch(mockExamPapersProvider(slug));
    final active = ref.watch(activeMockAttemptProvider(slug)).asData?.value;
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          tooltip: MaterialLocalizations.of(context).backButtonTooltip,
          icon: const Icon(Icons.arrow_back_rounded),
          // Nothing behind it when opened from a link: go Home instead.
          onPressed: () => context.canPop() ? context.pop() : context.go(Routes.home),
        ),
        title: Text(mockExamName(slug)),
        actions: [
          IconButton(
            tooltip: l.mockHistoryTitle,
            icon: const Icon(Icons.history),
            onPressed: () => context.push('${Routes.mockHistory}?exam=$slug'),
          ),
        ],
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(mockExamPapersProvider(slug));
            ref.invalidate(activeMockAttemptProvider(slug));
            await ref.read(mockExamPapersProvider(slug).future).catchError((_) => <PaperSummary>[]);
          },
          child: ListView(
            padding: const EdgeInsets.all(AppSpacing.page),
            children: [
              if (active != null) _ResumeCard(slug: slug, attempt: active),
              const SizedBox(height: AppSpacing.lg),
              Text(
                l.mockPapersTitle,
                style: AppTheme.serif(TextStyle(fontSize: 22, height: 1.2, color: context.colors.onSurface)),
              ),
              const SizedBox(height: AppSpacing.sm),
              papers.when(
                loading: () => const Padding(
                  padding: EdgeInsets.all(AppSpacing.lg),
                  child: Center(child: CircularProgressIndicator()),
                ),
                error: (e, _) => Column(
                  children: [
                    Text(
                      e is ApiException && e.isNetwork ? l.mockNetworkError : l.mockLoadError,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    FilledButton(
                      onPressed: () => ref.invalidate(mockExamPapersProvider(slug)),
                      child: Text(l.mockRetry),
                    ),
                  ],
                ),
                data: (list) => list.isEmpty
                    ? Padding(
                        padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
                        child: Text(l.mockNoPapers),
                      )
                    : Column(children: [for (final p in list) _PaperTile(slug: slug, paper: p)]),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ResumeCard extends StatelessWidget {
  const _ResumeCard({required this.slug, required this.attempt});

  final String slug;
  final Attempt attempt;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return Card(
      color: context.colors.primaryContainer,
      margin: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l.mockResumeTitle, style: Theme.of(context).textTheme.titleMedium),
            Text(attempt.paperTitle ?? l.mockRandomTitle),
            const SizedBox(height: AppSpacing.sm),
            Text(l.mockResumeBody),
            const SizedBox(height: AppSpacing.sm),
            FilledButton(
              onPressed: () => context.push(Routes.mockAttempt(slug, attempt.id)),
              child: Text(l.mockResume),
            ),
          ],
        ),
      ),
    );
  }
}

class _PaperTile extends StatelessWidget {
  const _PaperTile({required this.slug, required this.paper});

  final String slug;
  final PaperSummary paper;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final meta = [
      if (paper.edition != null) paper.edition!,
      if (paper.year != null) '${paper.year}',
      if (paper.setLabel != null) paper.setLabel!,
      l.mockPaperQuestions('${paper.totalQuestions}'),
      if (paper.durationSeconds != null) l.mockPaperMinutes('${paper.durationSeconds! ~/ 60}'),
    ].join(' · ');
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: NyayaCard(
        onTap: () => context.push(Routes.mockInstructions(slug, paperId: paper.id)),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(paper.title, style: context.text.titleMedium),
                  const SizedBox(height: 4),
                  Text(meta, style: context.text.bodySmall?.copyWith(color: context.nyaya.textSecondary)),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded, color: context.colors.onSurface),
          ],
        ),
      ),
    );
  }
}

/// The choice before an attempt: practice, or timed practice when the paper
/// has a clock. Both buttons share one style. Shown on the exam details screen.
class MockStartPanel extends ConsumerStatefulWidget {
  const MockStartPanel({super.key, required this.slug, this.paper});

  final String slug;
  final PaperSummary? paper;

  @override
  ConsumerState<MockStartPanel> createState() => _MockStartPanelState();
}

class _MockStartPanelState extends ConsumerState<MockStartPanel> {
  bool _busy = false;
  String? _error;

  /// The timed button: the official clock when the paper's rules are confirmed,
  /// otherwise the paper's practice timer. A random mock has neither.
  ({int minutes, AttemptMode mode, bool practiceTimer})? get _timed {
    final p = widget.paper;
    if (p == null) return null;
    if (p.timedAvailable && p.durationSeconds != null) {
      return (minutes: p.durationSeconds! ~/ 60, mode: AttemptMode.timed, practiceTimer: false);
    }
    if (p.practiceTimerSeconds != null) {
      return (minutes: p.practiceTimerSeconds! ~/ 60, mode: AttemptMode.practice, practiceTimer: true);
    }
    return null;
  }

  Future<void> _start(AttemptMode mode, {bool practiceTimer = false}) async {
    final l = context.l10n;
    final router = GoRouter.of(context);
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final attempt = await ref.read(mockExamApiProvider).startAttempt(
            widget.slug,
            kind: widget.paper == null ? AttemptKind.randomMock : AttemptKind.fixedPaper,
            paperId: widget.paper?.id,
            mode: mode,
            practiceTimer: practiceTimer,
          );
      ref.invalidate(activeMockAttemptProvider(widget.slug));
      // Replace the details screen, so Back from the attempt returns to the exam.
      router.pushReplacement(Routes.mockAttempt(widget.slug, attempt.id));
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = startErrorMessage(l, e);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final timed = _timed;
    final style = FilledButton.styleFrom(
      minimumSize: const Size.fromHeight(52),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
    );
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        FilledButton(
          style: style,
          onPressed: _busy ? null : () => _start(AttemptMode.practice),
          child: Text(l.mockStartPractice),
        ),
        if (timed != null) ...[
          const SizedBox(height: AppSpacing.sm),
          FilledButton(
            style: style,
            onPressed: _busy ? null : () => _start(timed.mode, practiceTimer: timed.practiceTimer),
            child: Text(l.mockStartPracticeTimer('${timed.minutes}')),
          ),
        ],
        if (_busy) const Padding(padding: EdgeInsets.only(top: AppSpacing.md), child: LinearProgressIndicator()),
        if (_error != null)
          Padding(
            padding: const EdgeInsets.only(top: AppSpacing.md),
            child: Text(
              _error!,
              style: TextStyle(color: context.colors.error),
              semanticsLabel: _error,
            ),
          ),
      ],
    );
  }
}
