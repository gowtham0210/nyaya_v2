import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/storage/local_store.dart';
import '../../auth/application/auth_controller.dart';
import 'attempt_controller.dart';

/// Questions the learner has marked for review in an unfinished attempt.
///
/// A reminder for the learner only. It lives on this device, is not sent to
/// the server, and has no effect on the answers, the timer or the score. It
/// is kept per learner and wiped with the rest of the mock exam data on
/// sign-out (see `MockExamCache.clearAll`).
final reviewMarksProvider = NotifierProvider.autoDispose.family<ReviewMarks, Set<int>, AttemptKey>(ReviewMarks.new);

class ReviewMarks extends Notifier<Set<int>> {
  ReviewMarks(this.key);

  final AttemptKey key;

  static const storeKey = 'mock_exam_marks_v1';

  LocalStore get _store => ref.read(localStoreProvider);
  String? get _userId => ref.read(authProvider)?.id;

  @override
  Set<int> build() {
    final userId = _userId;
    if (userId == null) return const {};
    final root = _store.readJson(storeKey);
    if (root == null || root['user_id'] != userId) return const {};
    final list = (root['entries'] as Map<String, dynamic>?)?[key.id];
    return list is List ? {for (final p in list) if (p is int) p} : const {};
  }

  /// Marks the position, or unmarks it if it was marked.
  void toggle(int position) {
    final next = {...state};
    if (!next.remove(position)) next.add(position);
    state = next;
    _save();
  }

  /// The attempt is over: its marks are no longer needed.
  void clear() {
    state = const {};
    _save();
  }

  void _save() {
    final userId = _userId;
    if (userId == null) return;
    final root = _store.readJson(storeKey);
    final mine = root != null && root['user_id'] == userId;
    final entries = <String, dynamic>{if (mine) ...((root['entries'] as Map<String, dynamic>?) ?? const {})};
    if (state.isEmpty) {
      entries.remove(key.id);
    } else {
      entries[key.id] = state.toList()..sort();
    }
    _store.writeJson(storeKey, {'user_id': userId, 'entries': entries});
  }
}
