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
    return Row(
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
        const Spacer(),
        TextButton.icon(
          onPressed: () => ReportSheet.show(context, questionVersionId: questionVersionId),
          icon: const Icon(Icons.flag_outlined, size: 20),
          label: Text(l.questionReport),
          style: TextButton.styleFrom(foregroundColor: context.nyaya.textSecondary),
        ),
      ],
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

  @override
  void dispose() {
    _comment.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final l = context.l10n;
    final messenger = ScaffoldMessenger.of(context);
    final nav = Navigator.of(context);
    setState(() => _sending = true);
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
        if (mounted) setState(() => _sending = false);
        messenger.showSnackBar(SnackBar(content: Text(message)));
        return;
      }
    }
    nav.pop();
    messenger.showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return Padding(
      padding: EdgeInsets.fromLTRB(
        AppSpacing.page,
        0,
        AppSpacing.page,
        AppSpacing.page + MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(l.reportTitle, style: context.text.titleLarge),
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
                    title: Text(ReportSheet.reasonLabel(l, r)),
                  ),
              ],
            ),
          ),
          TextField(
            controller: _comment,
            maxLength: 500,
            maxLines: 3,
            decoration: InputDecoration(labelText: l.reportComment),
          ),
          const SizedBox(height: AppSpacing.sm),
          FilledButton(
            onPressed: _reason == null || _sending ? null : _send,
            child: Text(l.reportSend),
          ),
        ],
      ),
    );
  }
}
