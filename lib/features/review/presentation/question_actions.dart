import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/api/api_client.dart';
import '../../../core/l10n/l10n.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/app_colors.dart';
import '../application/review_controller.dart';
import '../data/review_api.dart';

/// Save and Report, shown under a question once its answer is known.
class QuestionActions extends ConsumerWidget {
  const QuestionActions({super.key, required this.questionId, required this.questionVersionId});

  final String questionId;
  final String questionVersionId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final saved = ref.watch(reviewProvider).value?.savedIds.contains(questionId) ?? false;
    // Save on the left, Report on the right; wraps onto two lines at large text sizes.
    return SizedBox(
      width: double.infinity,
      child: Wrap(
      alignment: WrapAlignment.spaceBetween,
      children: [
        if (questionId.isNotEmpty)
          TextButton.icon(
            onPressed: () async {
              final messenger = ScaffoldMessenger.of(context);
              final ok = await ref.read(reviewProvider.notifier).toggleSave(questionId);
              if (!ok) messenger.showSnackBar(SnackBar(content: Text(l.questionSaveFailed)));
            },
            icon: Icon(saved ? Icons.bookmark_rounded : Icons.bookmark_border_rounded, size: 20),
            label: Text(saved ? l.questionSaved : l.questionSave),
          ),
        TextButton.icon(
          onPressed: () => ReportSheet.show(context, questionVersionId: questionVersionId),
          icon: const Icon(Icons.flag_outlined, size: 20),
          label: Text(l.questionReport),
          style: TextButton.styleFrom(foregroundColor: context.nyaya.textSecondary),
        ),
      ],
    ),
    );
  }
}

/// Reason + optional comment. The report goes to staff; it never changes the question.
class ReportSheet extends ConsumerStatefulWidget {
  const ReportSheet({super.key, required this.questionVersionId});

  final String questionVersionId;

  static Future<void> show(BuildContext context, {required String questionVersionId}) => showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        showDragHandle: true,
        builder: (_) => ReportSheet(questionVersionId: questionVersionId),
      );

  static String reasonLabel(AppLocalizations l, ReportReason r) => switch (r) {
        ReportReason.wrongAnswer => l.reportReasonWrongAnswer,
        ReportReason.unclear => l.reportReasonUnclear,
        ReportReason.outdatedLaw => l.reportReasonOutdatedLaw,
        ReportReason.typo => l.reportReasonTypo,
        ReportReason.other => l.reportReasonOther,
      };

  @override
  ConsumerState<ReportSheet> createState() => _ReportSheetState();
}

class _ReportSheetState extends ConsumerState<ReportSheet> {
  ReportReason? _reason;
  final _comment = TextEditingController();
  bool _sending = false;

  /// Shown in the sheet (a snackbar would sit behind it); the reason and
  /// text stay so the learner can send again.
  String? _error;

  @override
  void dispose() {
    _comment.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    // One report at a time; the server also refuses a second one.
    if (_sending) return;
    final l = context.l10n;
    final messenger = ScaffoldMessenger.of(context);
    final nav = Navigator.of(context);
    setState(() {
      _sending = true;
      _error = null;
    });
    String message;
    try {
      await ref.read(reviewApiProvider).report(
            questionVersionId: widget.questionVersionId,
            reason: _reason!,
            comment: _comment.text,
          );
      message = l.reportSent;
    } on ApiException catch (e) {
      message = switch (e.code) {
        'already_reported' => l.reportAlready,
        'report_limit' => l.reportLimit,
        _ => e.isNetwork ? l.quizOffline : l.commonSomethingWrong,
      };
      if (e.isNetwork || (e.code != 'already_reported' && e.code != 'report_limit')) {
        if (mounted) {
          setState(() {
            _sending = false;
            _error = e.isNetwork ? l.reportFailed : message;
          });
        }
        return;
      }
    }
    nav.pop();
    messenger.showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    // Scrolls when the keyboard or large text leaves too little room.
    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(
        AppSpacing.page,
        0,
        AppSpacing.page,
        AppSpacing.page + MediaQuery.viewInsetsOf(context).bottom + MediaQuery.paddingOf(context).bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Semantics(header: true, child: Text(l.reportTitle, style: context.text.titleLarge)),
          const SizedBox(height: AppSpacing.sm),
          RadioGroup<ReportReason>(
            groupValue: _reason,
            onChanged: (r) => setState(() => _reason = r),
            child: Column(
              children: [
                for (final r in ReportReason.values)
                  RadioListTile<ReportReason>(
                    value: r,
                    contentPadding: EdgeInsets.zero,
                    enabled: !_sending,
                    title: Text(ReportSheet.reasonLabel(l, r)),
                  ),
              ],
            ),
          ),
          TextField(
            controller: _comment,
            maxLength: 500,
            maxLines: 3,
            enabled: !_sending,
            decoration: InputDecoration(labelText: l.reportComment),
          ),
          if (_error != null) ...[
            Semantics(
              liveRegion: true,
              child: Text(_error!, style: context.text.bodyMedium?.copyWith(color: context.colors.error)),
            ),
            const SizedBox(height: AppSpacing.sm),
          ],
          const SizedBox(height: AppSpacing.sm),
          FilledButton(
            onPressed: _reason == null || _sending ? null : _send,
            child: _sending
                ? Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const SizedBox.square(dimension: 18, child: CircularProgressIndicator(strokeWidth: 2.5)),
                      const SizedBox(width: 10),
                      Text(l.reportSending),
                    ],
                  )
                : Text(_error != null ? l.commonRetry : l.reportSend),
          ),
        ],
      ),
    );
  }
}
