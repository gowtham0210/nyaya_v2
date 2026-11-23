import '../../../core/storage/local_store.dart';

/// The question an unfinished attempt was left on, so Resume reopens it.
///
/// Kept on this device per learner. It only moves the learner's view; it has
/// no effect on answers, the timer or the score. Wiped on sign-out (see
/// `MockExamCache.clearAll`).
class ResumePosition {
  ResumePosition(this._store, this._userId);

  final LocalStore _store;
  final String? _userId;

  static const storeKey = 'mock_exam_resume_v1';

  /// The saved question position (0-based index) for [attemptId], if any.
  int? read(String attemptId) {
    final userId = _userId;
    if (userId == null) return null;
    final root = _store.readJson(storeKey);
    if (root == null || root['user_id'] != userId) return null;
    final v = (root['entries'] as Map<String, dynamic>?)?[attemptId];
    return v is int ? v : null;
  }

  void write(String attemptId, int index) {
    final userId = _userId;
    if (userId == null) return;
    final root = _store.readJson(storeKey);
    final mine = root != null && root['user_id'] == userId;
    final entries = <String, dynamic>{if (mine) ...((root['entries'] as Map<String, dynamic>?) ?? const {})};
    entries[attemptId] = index;
    _store.writeJson(storeKey, {'user_id': userId, 'entries': entries});
  }

  void clear(String attemptId) {
    final userId = _userId;
    if (userId == null) return;
    final root = _store.readJson(storeKey);
    if (root == null || root['user_id'] != userId) return;
    final entries = {...((root['entries'] as Map<String, dynamic>?) ?? const {})}..remove(attemptId);
    _store.writeJson(storeKey, {'user_id': userId, 'entries': entries});
  }
}
