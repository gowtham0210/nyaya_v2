import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../../app/router.dart';
import '../../../core/l10n/l10n.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/ticking_builder.dart';
import '../application/attempt_controller.dart';
import '../application/mock_exam_providers.dart';
import '../application/resume_position.dart';
import '../application/review_marks.dart';
import '../../../core/storage/local_store.dart';
import '../../auth/application/auth_controller.dart';
import '../domain/mock_exam_models.dart';
import 'mock_exam_format.dart';

/// A formal exam attempt. The server owns the questions, the deadline and the
/// scoring; this screen shows them, keeps the learner's answers saved as they
/// go, and never holds an answer key (none is ever sent before submission).
class MockAttemptScreen extends ConsumerStatefulWidget {
  const MockAttemptScreen({super.key, required this.slug, required this.id});

  final String slug;
  final String id;

  @override
  ConsumerState<MockAttemptScreen> createState() => _MockAttemptScreenState();
}

class _MockAttemptScreenState extends ConsumerState<MockAttemptScreen> with WidgetsBindingObserver {
  int _index = 0;
  bool _positioned = false;
  bool _left = false;
  bool _deadlineFired = false;

  AttemptKey get _key => (slug: widget.slug, id: widget.id);
  AttemptController get _ctrl => ref.read(attemptControllerProvider(_key).notifier);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _ctrl.onResumed();
  }

  /// Indexes of the questions the learner may move between: all of them, or in
  /// a locked-order exam only those of the open section.
  List<int> _reachable(Attempt a) {
    final open = !a.lockedOrder
        ? null
        : a.sections.where((s) => s.position == a.currentSectionPosition).map((s) => s.code).firstOrNull;
    return [
      for (final (i, q) in a.questions.indexed)
        if (open == null || q.sectionCode == open) i,
    ];
  }

  ResumePosition get _resume => ResumePosition(ref.read(localStoreProvider), ref.read(authProvider)?.id);

  void _goTo(int index) {
    setState(() => _index = index);
    _resume.write(widget.id, index);
  }

  /// Where to open: the question the learner left on, else the first one not
  /// yet answered, else the first.
  int _initialIndex(Attempt a) {
    final reach = _reachable(a);
    if (reach.isEmpty) return 0;
    final saved = _resume.read(widget.id);
    if (saved != null && reach.contains(saved)) return saved;
    final unanswered = reach.where((i) => !a.questions[i].withdrawn && !a.questions[i].answered);
    return unanswered.isNotEmpty ? unanswered.first : reach.first;
  }

  void _leaveToResult() {
    if (_left || !mounted) return;
    _left = true;
    ref.invalidate(activeMockAttemptProvider(widget.slug));
    ref.invalidate(attemptResultProvider(widget.id));
    ref.read(reviewMarksProvider(_key).notifier).clear();
    _resume.clear(widget.id);
    context.pushReplacement(Routes.mockResult(widget.id));
  }

  void _onState(AttemptState? before, AttemptState next) {
    final l = context.l10n;
    if (next.phase == AttemptPhase.finished) {
      _leaveToResult();
      return;
    }
    final a = next.attempt;
    if (a != null && before?.attempt != null && before?.attempt?.currentSectionPosition != a.currentSectionPosition) {
      // A new section opened: start at its first question.
      final reach = _reachable(a);
      if (reach.isNotEmpty && a.lockedOrder) {
        setState(() {
          _index = reach.first;
          _positioned = true;
        });
        _resume.write(widget.id, reach.first);
      }
    }
    if (next.notice != null && next.notice != before?.notice) {
      final text = switch (next.notice) {
        'section_locked' => l.mockSectionClosed,
        'network' => l.mockNetworkError,
        _ => null,
      };
      if (text != null) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
    }
    if (next.submitFailed && !(before?.submitFailed ?? false)) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l.mockSubmitFailed)));
    }
  }

  Future<void> _confirmSubmit(Attempt a) async {
    final l = context.l10n;
    final unanswered = a.questions.where((q) => !q.withdrawn && !q.answered).length;
    final scorable = a.questions.where((q) => !q.withdrawn).length;
    final marked = ref.read(reviewMarksProvider(_key)).length;
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l.mockSubmitTitle),
        content: Text([
          l.mockSubmitBody('${scorable - unanswered}', '$scorable'),
          if (unanswered > 0) l.mockSubmitUnanswered('$unanswered'),
          if (marked > 0) l.mockSubmitMarked('$marked'),
        ].join(' ')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: Text(l.mockKeepGoing)),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: Text(l.mockSubmit)),
        ],
      ),
    );
    if (ok == true) await _ctrl.submit();
  }

  Future<void> _confirmAdvance() async {
    final l = context.l10n;
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l.mockAdvanceTitle),
        content: Text(l.mockAdvanceBody),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: Text(l.mockKeepGoing)),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: Text(l.mockAdvanceSection)),
        ],
      ),
    );
    if (ok == true) await _ctrl.advanceSection();
  }

  void _showPalette(Attempt a, List<int> reachable) {
    final marked = ref.read(reviewMarksProvider(_key));
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (context) => _Palette(
        attempt: a,
        current: _index,
        reachable: reachable.toSet(),
        marked: marked,
        onPick: (i) {
          Navigator.pop(context);
          _goTo(i);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    ref.listen(attemptControllerProvider(_key), _onState);
    final state = ref.watch(attemptControllerProvider(_key));
    final marked = ref.watch(reviewMarksProvider(_key));
    final a = state.attempt;

    if (state.phase == AttemptPhase.failed || (a == null && state.phase != AttemptPhase.loading)) {
      return _Failure(failure: state.failure, onRetry: _ctrl.load);
    }
    if (a == null) {
      return Scaffold(appBar: AppBar(), body: const Center(child: CircularProgressIndicator()));
    }

    if (!_positioned) {
      _index = _initialIndex(a);
      _positioned = true;
    }
    final reachable = _reachable(a);
    final index = reachable.contains(_index) ? _index : (reachable.isEmpty ? 0 : reachable.first);
    final q = a.questions[index];
    final pos = reachable.indexOf(index);
    final submitting = state.phase == AttemptPhase.submitting;
    final lastOfSection = pos == reachable.length - 1;
    final moreSections = a.lockedOrder &&
        a.sections.any((s) => s.position > (a.currentSectionPosition ?? 0));

    return PopScope(
      // Leaving is fine: the attempt keeps running and everything is saved.
      child: Scaffold(
        appBar: AppBar(
          title: Text(a.paperTitle ?? l.mockRandomTitle, overflow: TextOverflow.ellipsis),
          actions: [
            IconButton(
              tooltip: l.mockPalette,
              icon: const Icon(Icons.grid_view_rounded),
              onPressed: () => _showPalette(a, reachable),
            ),
          ],
        ),
        body: SafeArea(
          child: Column(
            children: [
              _StatusBar(
                state: state,
                remaining: _ctrl.remaining,
                onDeadline: () {
                  if (_deadlineFired) return;
                  _deadlineFired = true;
                  _ctrl.onDeadlineReached();
                },
              ),
              if (a.sections.isNotEmpty)
                _SectionBar(
                  attempt: a,
                  currentCode: q.sectionCode,
                  onPick: (code) {
                    final i = a.questions.indexWhere((x) => x.sectionCode == code);
                    if (i >= 0) _goTo(i);
                  },
                ),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.all(AppSpacing.page),
                  children: [
                    // A Wrap, so the button drops below the label at large text sizes.
                    Wrap(
                      alignment: WrapAlignment.spaceBetween,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Semantics(
                          header: true,
                          child: Text(
                            l.mockQuestionOf('${index + 1}', '${a.questions.length}'),
                            style: Theme.of(context).textTheme.labelLarge,
                          ),
                        ),
                        if (!q.withdrawn)
                          TextButton.icon(
                            onPressed: submitting ? null : () => ref.read(reviewMarksProvider(_key).notifier).toggle(q.position),
                            icon: Icon(marked.contains(q.position) ? Icons.flag : Icons.outlined_flag),
                            label: Text(marked.contains(q.position) ? l.mockMarkedForReview : l.mockMarkForReview),
                          ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    if (q.withdrawn)
                      _Withdrawn()
                    else ...[
                      Text(q.stem ?? '', style: Theme.of(context).textTheme.titleMedium),
                      const SizedBox(height: AppSpacing.md),
                      for (final o in q.options)
                        _OptionTile(
                          option: o,
                          selected: q.selected.contains(o.id),
                          enabled: !submitting && _ctrl.canAnswer(q),
                          onTap: () {
                            HapticFeedback.selectionClick();
                            _ctrl.select(q.position, o.id);
                          },
                        ),
                    ],
                  ],
                ),
              ),
              _BottomBar(
                canPrevious: pos > 0 && !submitting,
                canNext: pos < reachable.length - 1 && !submitting,
                onPrevious: () => _goTo(reachable[pos - 1]),
                onNext: () => _goTo(reachable[pos + 1]),
                advance: lastOfSection && moreSections && !submitting ? _confirmAdvance : null,
                onSubmit: submitting ? null : () => _confirmSubmit(a),
                busy: submitting,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatusBar extends StatelessWidget {
  const _StatusBar({required this.state, required this.remaining, required this.onDeadline});

  final AttemptState state;
  final Duration? Function() remaining;
  final VoidCallback onDeadline;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final a = state.attempt!;
    final saving = switch (state.saveStatus) {
      SaveStatus.saved => (Icons.cloud_done_outlined, l.mockSaved),
      SaveStatus.saving => (Icons.cloud_upload_outlined, l.mockSaving),
      SaveStatus.offline => (Icons.cloud_off_outlined, l.mockOffline),
      SaveStatus.serverIssue => (Icons.sync_problem_outlined, l.mockServerIssue),
    };
    return Material(
      color: context.colors.surfaceContainerLow,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.page, vertical: AppSpacing.sm),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: a.mode == AttemptMode.timed || a.practiceTimed
                      ? TickingBuilder(
                          interval: const Duration(seconds: 1),
                          builder: (context) {
                            final left = remaining() ?? Duration.zero;
                            if (left == Duration.zero) {
                              WidgetsBinding.instance.addPostFrameCallback((_) => onDeadline());
                            }
                            final urgent = left < const Duration(minutes: 5);
                            final text = formatCountdown(left);
                            return Semantics(
                              // Read the time on request, not every second.
                              label: l.mockTimeLeftSemantic(text),
                              excludeSemantics: true,
                              child: Text(
                                l.mockTimeLeft(text),
                                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                      color: urgent ? context.colors.error : null,
                                      fontFeatures: const [FontFeature.tabularFigures()],
                                    ),
                              ),
                            );
                          },
                        )
                      : Text(l.mockPracticeLabel, style: Theme.of(context).textTheme.titleMedium),
                ),
                Text(l.mockAnsweredCount('${a.answeredCount}', '${a.questions.where((q) => !q.withdrawn).length}')),
              ],
            ),
            Row(
              children: [
                Icon(saving.$1, size: 16),
                const SizedBox(width: AppSpacing.xs),
                Expanded(
                  child: Semantics(
                    liveRegion: true,
                    child: Text(saving.$2, style: Theme.of(context).textTheme.bodySmall),
                  ),
                ),
              ],
            ),
            if (a.practiceTimed)
              Text(l.mockPracticeTimerLabel, style: Theme.of(context).textTheme.bodySmall),
            if (state.estimatedClock && a.deadlineAt != null)
              Text(l.mockOfflineEstimate, style: Theme.of(context).textTheme.bodySmall),
            if (state.endedOffline)
              Text(l.mockEndedOffline, style: TextStyle(color: context.colors.error)),
          ],
        ),
      ),
    );
  }
}

class _SectionBar extends StatelessWidget {
  const _SectionBar({required this.attempt, required this.currentCode, required this.onPick});

  final Attempt attempt;
  final String? currentCode;
  final void Function(String code) onPick;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return SizedBox(
      height: 56,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.page, vertical: AppSpacing.xs),
        children: [
          for (final s in attempt.sections)
            Padding(
              padding: const EdgeInsets.only(right: AppSpacing.sm),
              child: ChoiceChip(
                label: Text(l.mockSectionName(s.code)),
                selected: s.code == currentCode,
                // A locked-order exam only opens its current section.
                onSelected: attempt.lockedOrder && s.position != attempt.currentSectionPosition
                    ? null
                    : (_) => onPick(s.code),
              ),
            ),
        ],
      ),
    );
  }
}

class _OptionTile extends StatelessWidget {
  const _OptionTile({required this.option, required this.selected, required this.enabled, required this.onTap});

  final ExamOption option;
  final bool selected;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Semantics(
        inMutuallyExclusiveGroup: true,
        checked: selected,
        enabled: enabled,
        label: option.text,
        onTap: enabled ? onTap : null,
        child: ExcludeSemantics(
          child: Material(
            color: selected ? colors.primaryContainer : colors.surfaceContainerLowest,
            borderRadius: BorderRadius.circular(AppRadius.md),
            child: InkWell(
              borderRadius: BorderRadius.circular(AppRadius.md),
              onTap: enabled ? onTap : null,
              child: Container(
                constraints: const BoxConstraints(minHeight: 56),
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(AppRadius.md),
                  border: Border.all(color: selected ? colors.primary : context.nyaya.cardBorder, width: selected ? 2 : 1),
                ),
                child: Row(
                  children: [
                    Icon(
                      selected ? Icons.radio_button_checked : Icons.radio_button_unchecked,
                      color: selected ? colors.primary : colors.onSurfaceVariant,
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(child: Text(option.text, style: Theme.of(context).textTheme.bodyLarge)),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Withdrawn extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              const Icon(Icons.block),
              const SizedBox(width: AppSpacing.sm),
              Expanded(child: Text(l.mockWithdrawnTitle, style: Theme.of(context).textTheme.titleMedium)),
            ]),
            const SizedBox(height: AppSpacing.sm),
            Text(l.mockWithdrawnBody),
          ],
        ),
      ),
    );
  }
}

class _BottomBar extends StatelessWidget {
  const _BottomBar({
    required this.canPrevious,
    required this.canNext,
    required this.onPrevious,
    required this.onNext,
    required this.advance,
    required this.onSubmit,
    required this.busy,
  });

  final bool canPrevious, canNext, busy;
  final VoidCallback onPrevious, onNext;
  final VoidCallback? advance;
  final VoidCallback? onSubmit;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return Material(
      elevation: 4,
      color: context.colors.surface,
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.sm),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (busy) const LinearProgressIndicator(),
            // Two short rows, so nothing overflows at large text sizes.
            Row(
              children: [
                TextButton.icon(
                  onPressed: canPrevious ? onPrevious : null,
                  icon: const Icon(Icons.chevron_left),
                  label: Text(l.mockPrevious),
                ),
                const Spacer(),
                TextButton.icon(
                  onPressed: canNext ? onNext : null,
                  iconAlignment: IconAlignment.end,
                  icon: const Icon(Icons.chevron_right),
                  label: Text(l.mockNext),
                ),
              ],
            ),
            if (advance != null) ...[
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(onPressed: advance, child: Text(l.mockAdvanceSection)),
              ),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(onPressed: onSubmit, child: Text(l.mockSubmit)),
              ),
            ] else
              SizedBox(
                width: double.infinity,
                child: FilledButton(onPressed: onSubmit, child: Text(l.mockSubmit)),
              ),
          ],
        ),
      ),
    );
  }
}

class _Palette extends StatelessWidget {
  const _Palette({required this.attempt, required this.current, required this.reachable, required this.marked, required this.onPick});

  final Attempt attempt;
  final int current;
  final Set<int> reachable;
  final Set<int> marked;
  final void Function(int index) onPick;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final colors = context.colors;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(AppSpacing.page, 0, AppSpacing.page, AppSpacing.page),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l.mockPalette, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: AppSpacing.sm),
            Wrap(spacing: AppSpacing.md, children: [
              _Legend(color: colors.primary, label: l.mockPaletteAnswered),
              _Legend(color: colors.outline, label: l.mockPaletteUnanswered),
              _Legend(color: colors.onSurfaceVariant, label: l.mockPaletteWithdrawn),
              Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.flag, size: 14, color: colors.tertiary),
                const SizedBox(width: 6),
                Text(l.mockPaletteMarked, style: Theme.of(context).textTheme.bodySmall),
              ]),
            ]),
            const SizedBox(height: AppSpacing.md),
            Flexible(
              child: SingleChildScrollView(
                child: Wrap(
                  spacing: AppSpacing.sm,
                  runSpacing: AppSpacing.sm,
                  children: [
                    for (final (i, q) in attempt.questions.indexed)
                      _PaletteCell(
                        number: i + 1,
                        state: [
                          q.withdrawn
                              ? l.mockPaletteWithdrawn
                              : (q.answered ? l.mockPaletteAnswered : l.mockPaletteUnanswered),
                          if (marked.contains(q.position)) l.mockPaletteMarked,
                        ].join(', '),
                        marked: marked.contains(q.position),
                        filled: q.answered,
                        withdrawn: q.withdrawn,
                        current: i == current,
                        enabled: reachable.contains(i),
                        onTap: () => onPick(i),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Legend extends StatelessWidget {
  const _Legend({required this.color, required this.label});
  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) => Row(mainAxisSize: MainAxisSize.min, children: [
        Container(width: 14, height: 14, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 6),
        Text(label, style: Theme.of(context).textTheme.bodySmall),
      ]);
}

class _PaletteCell extends StatelessWidget {
  const _PaletteCell({
    required this.number,
    required this.state,
    required this.filled,
    required this.withdrawn,
    required this.marked,
    required this.current,
    required this.enabled,
    required this.onTap,
  });

  final int number;
  final String state;
  final bool filled, withdrawn, marked, current, enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final l = context.l10n;
    final bg = filled ? colors.primary : colors.surfaceContainerHigh;
    final fg = filled ? colors.onPrimary : colors.onSurface;
    return Semantics(
      button: true,
      enabled: enabled,
      selected: current,
      label: l.mockPaletteItem('$number', state),
      child: ExcludeSemantics(
        child: SizedBox(
          width: 48,
          height: 48,
          child: Material(
            color: enabled ? bg : colors.surfaceContainerLow,
            shape: CircleBorder(side: BorderSide(color: current ? colors.primary : colors.outline, width: current ? 3 : 1)),
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap: enabled ? onTap : null,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Center(
                    child: withdrawn
                        ? Icon(Icons.block, size: 18, color: colors.onSurfaceVariant)
                        : Text('$number', style: TextStyle(color: enabled ? fg : colors.onSurfaceVariant)),
                  ),
                  if (marked) Positioned(top: 2, right: 6, child: Icon(Icons.flag, size: 14, color: colors.tertiary)),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Failure extends StatelessWidget {
  const _Failure({required this.failure, required this.onRetry});

  final AttemptFailure? failure;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final text = switch (failure) {
      AttemptFailure.network => l.mockNetworkError,
      AttemptFailure.signedOut => l.mockSignedOut,
      AttemptFailure.notFound => l.mockAttemptNotFound,
      _ => l.mockLoadError,
    };
    return Scaffold(
      appBar: AppBar(),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.page),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(text, textAlign: TextAlign.center),
              if (failure == AttemptFailure.network || failure == AttemptFailure.other) ...[
                const SizedBox(height: AppSpacing.md),
                FilledButton(onPressed: onRetry, child: Text(l.mockRetry)),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
