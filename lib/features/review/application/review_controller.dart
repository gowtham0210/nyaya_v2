import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';
import '../../auth/application/auth_controller.dart';
import '../data/review_api.dart';

@immutable
class ReviewState {
  const ReviewState({this.mistakes = const [], this.saved = const []});

  final List<Mistake> mistakes;
  final List<SavedQuestion> saved;

  Set<String> get savedIds => {for (final s in saved) s.question.questionId};

  /// Mistakes that can be practised (their question is still in force).
  int get practisable => mistakes.where((m) => m.question.available).length;
}

/// The learner's mistakes and saved questions, from the server. Empty when
/// signed out; reload with `ref.invalidate(reviewProvider)` after a quiz.
final reviewProvider = AsyncNotifierProvider<ReviewController, ReviewState>(ReviewController.new);

class ReviewController extends AsyncNotifier<ReviewState> {
  ReviewApi get _api => ref.read(reviewApiProvider);

  @override
  Future<ReviewState> build() async {
    if (ref.watch(authProvider) == null) return const ReviewState();
    final (mistakes, saved) = await (_api.mistakes(), _api.saved()).wait;
    return ReviewState(mistakes: mistakes, saved: saved);
  }

  /// Saves or un-saves a question; returns false when the server said no.
  Future<bool> toggleSave(String questionId) async {
    final current = state.value ?? const ReviewState();
    final saving = !current.savedIds.contains(questionId);
    try {
      saving ? await _api.save(questionId) : await _api.unsave(questionId);
    } on ApiException {
      return false;
    }
    ref.invalidateSelf();
    return true;
  }
}
