import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/storage/local_store.dart';
import '../domain/mock_exam_models.dart';

final mockExamCacheProvider = Provider<MockExamCache>((ref) => MockExamCache(ref.watch(localStoreProvider)));

/// What was last known of an unfinished attempt, so it can be reopened
/// without a connection.
///
/// Only what the server already sent the learner is kept: question text,
/// options and the learner's own answers. The server never sends an answer
/// key or explanation before submission, and nothing from a review is cached.
@immutable
class CachedAttempt {
  const CachedAttempt({
    required this.attempt,
    required this.pending,
    required this.serverNow,
    required this.deviceAt,
  });

  /// The attempt with the learner's latest local answers applied.
  final Attempt attempt;

  /// Answers the server has not confirmed yet.
  final List<PendingAnswer> pending;

  /// The server's clock at the last successful contact, and the device's wall
  /// clock at the same moment. Offline, the gap between them estimates the
  /// time since (the monotonic clock does not survive a restart).
  final DateTime serverNow;
  final DateTime deviceAt;

  Map<String, dynamic> toJson() => {
        'attempt': attempt.toJson(),
        'pending': [for (final p in pending) p.toJson()],
        'server_now': serverNow.toUtc().toIso8601String(),
        'device_at': deviceAt.toUtc().toIso8601String(),
      };

  static CachedAttempt? fromJson(Map<String, dynamic> j) {
    try {
      return CachedAttempt(
        attempt: Attempt.fromJson(j['attempt'] as Map<String, dynamic>),
        pending: [for (final p in (j['pending'] as List).cast<Map<String, dynamic>>()) PendingAnswer.fromJson(p)],
        serverNow: DateTime.parse(j['server_now'] as String),
        deviceAt: DateTime.parse(j['device_at'] as String),
      );
    } catch (_) {
      return null;
    }
  }
}

/// Unfinished attempts cached on the device, for one learner at a time.
/// Another account (or a signed-out device) never reads it, and it is wiped
/// on sign-out and when the account changes.
class MockExamCache {
  MockExamCache(this._store);

  final LocalStore _store;
  static const key = 'mock_exam_cache_v1';

  CachedAttempt? read(String userId, String slug) {
    final root = _store.readJson(key);
    if (root == null || root['user_id'] != userId) return null;
    final entry = (root['entries'] as Map<String, dynamic>?)?[slug];
    return entry is Map<String, dynamic> ? CachedAttempt.fromJson(entry) : null;
  }

  Future<void> write(String userId, String slug, CachedAttempt value) async {
    final root = _store.readJson(key);
    final mine = root != null && root['user_id'] == userId;
    final entries = <String, dynamic>{
      if (mine) ...((root['entries'] as Map<String, dynamic>?) ?? const {}),
      slug: value.toJson(),
    };
    await _store.writeJson(key, {'user_id': userId, 'entries': entries});
  }

  Future<void> remove(String userId, String slug) async {
    final root = _store.readJson(key);
    if (root == null || root['user_id'] != userId) return;
    final entries = {...((root['entries'] as Map<String, dynamic>?) ?? const {})}..remove(slug);
    await _store.writeJson(key, {'user_id': userId, 'entries': entries});
  }

  /// Sign-out, or a different account signing in.
  Future<void> clearAll() async {
    await _store.remove(key);
    // The learner's review marks (see review_marks.dart) go with it.
    await _store.remove('mock_exam_marks_v1');
    await _store.remove('mock_exam_resume_v1');
  }
}
