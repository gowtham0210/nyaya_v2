import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/l10n/l10n.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../profile/application/profile_controller.dart';
import '../application/quiz_controller.dart';
import '../data/question_repository.dart';
import '../domain/quiz_models.dart';
import 'quiz_view.dart';
import 'result_view.dart';

/// Hosts one quiz session: loading → questions → results, on one route so
/// back-navigation can never land the user mid-way through a finished quiz.
class QuizScreen extends ConsumerWidget {
  const QuizScreen({super.key, required this.request});

  final QuizRequest request;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final bank = ref.watch(questionBankProvider);
    return bank.when(
      loading: () => Scaffold(
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(),
              const SizedBox(height: AppSpacing.md),
              Text(l.quizLoading, style: context.text.bodyLarge),
            ],
          ),
        ),
      ),
      error: (e, _) => _QuizError(request: request),
      data: (_) => _QuizSession(request: request),
    );
  }
}

class _QuizSession extends ConsumerWidget {
  const _QuizSession({required this.request});

  final QuizRequest request;

  Future<bool> _confirmQuit(BuildContext context, WidgetRef ref) async {
    final l = context.l10n;
    final state = ref.read(quizControllerProvider(request));
    final refund = !state.hasStarted;
    final leave = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l.quizQuitTitle),
        content: Text(refund ? l.quizQuitBodyRefund : l.quizQuitBody),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, true), child: Text(l.quizQuitLeave)),
          FilledButton(onPressed: () => Navigator.pop(context, false), child: Text(l.quizQuitStay)),
        ],
      ),
    );
    if (leave == true && refund) {
      ref.read(profileProvider.notifier).refundEnergy(request.mode.energyCost);
    }
    return leave == true;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(quizControllerProvider(request));
    if (state.questions.isEmpty) return _QuizError(request: request, empty: true);
    final finished = state.isFinished;

    return PopScope(
      canPop: finished,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        if (await _confirmQuit(context, ref) && context.mounted) Navigator.of(context).pop();
      },
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 350),
        child: finished
            ? ResultView(key: const ValueKey('result'), state: state)
            : QuizView(
                key: const ValueKey('quiz'),
                request: request,
                onClose: () async {
                  if (await _confirmQuit(context, ref) && context.mounted) Navigator.of(context).pop();
                },
              ),
      ),
    );
  }
}

class _QuizError extends ConsumerWidget {
  const _QuizError({required this.request, this.empty = false});

  final QuizRequest request;
  final bool empty;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.close_rounded),
          onPressed: () {
            // Nothing was played — give the energy back.
            ref.read(profileProvider.notifier).refundEnergy(request.mode.energyCost);
            Navigator.of(context).pop();
          },
        ),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.cloud_off_rounded, size: 56, color: context.nyaya.locked),
              const SizedBox(height: AppSpacing.md),
              Text(empty ? l.quizEmpty : l.commonSomethingWrong, textAlign: TextAlign.center),
              if (!empty) ...[
                const SizedBox(height: AppSpacing.md),
                FilledButton(onPressed: () => ref.invalidate(questionBankProvider), child: Text(l.commonRetry)),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
