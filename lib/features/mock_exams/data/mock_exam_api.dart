import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';
import '../domain/mock_exam_models.dart';
import 'demo_mock_exam_api.dart';

/// Debug-only demo switch: `flutter run --dart-define=MOCK_EXAMS_DEMO=true`.
/// In a release or profile build [kDebugMode] is false, so the demo API is
/// never used whatever the flag says.
const _mockExamsDemo = bool.fromEnvironment('MOCK_EXAMS_DEMO');

final mockExamApiProvider = Provider<MockExamApi>(
  (ref) => kDebugMode && _mockExamsDemo ? DemoMockExamApi() : HttpMockExamApi(ref.watch(apiClientProvider)),
);

/// The learner side of the mock exam API. No method here ever returns an
/// answer key before an attempt is submitted: the server does not send one.
abstract interface class MockExamApi {
  /// Whether the learner API shows this exam (it answers 404 for one that is
  /// switched off or unknown). Reads only; it never creates an attempt.
  Future<bool> isAvailable(String slug);

  Future<PaperPage> papers(String slug, {String? cursor});

  /// The unfinished attempt for the exam, or null.
  Future<Attempt?> activeAttempt(String slug);

  Future<Attempt> startAttempt(
    String slug, {
    required AttemptKind kind,
    String? paperId,
    required AttemptMode mode,
    bool practiceTimer = false,
  });

  Future<Attempt> attempt(String id);
  Future<SaveOutcome> saveAnswers(String attemptId, List<PendingAnswer> answers);
  Future<Attempt> advanceSection(String attemptId);
  Future<AttemptResult> submit(String attemptId);
  Future<AttemptResult> result(String attemptId);
  Future<AttemptReview> review(String attemptId);
  Future<AttemptSummaryPage> history({String? exam, String? cursor});
  Future<List<ExamStats>> stats();
}

class HttpMockExamApi implements MockExamApi {
  HttpMockExamApi(this._client);

  final ApiClient _client;

  Map<String, dynamic> _map(Object? j) => j as Map<String, dynamic>;

  @override
  Future<bool> isAvailable(String slug) async {
    try {
      await _client.get('/v1/exams/$slug/papers', query: {'limit': '1'});
      return true;
    } on ApiException catch (e) {
      if (e.status == 404) return false;
      rethrow;
    }
  }

  @override
  Future<PaperPage> papers(String slug, {String? cursor}) async {
    final j = _map(await _client.get('/v1/exams/$slug/papers', query: {'cursor': ?cursor}));
    return PaperPage(
      [for (final p in (j['items'] as List).cast<Map<String, dynamic>>()) PaperSummary.fromJson(p)],
      j['next_cursor'] as String?,
    );
  }

  @override
  Future<Attempt?> activeAttempt(String slug) async {
    try {
      return Attempt.fromJson(_map(await _client.get('/v1/exams/$slug/attempts/active')));
    } on ApiException catch (e) {
      if (e.status == 404) return null;
      rethrow;
    }
  }

  @override
  Future<Attempt> startAttempt(
    String slug, {
    required AttemptKind kind,
    String? paperId,
    required AttemptMode mode,
    bool practiceTimer = false,
  }) async =>
      Attempt.fromJson(_map(await _client.post('/v1/exams/$slug/attempts', body: {
        'kind': kind.api,
        'paper_id': ?paperId,
        'mode': mode.api,
        if (practiceTimer) 'practice_timer': true,
      })));

  @override
  Future<Attempt> attempt(String id) async => Attempt.fromJson(_map(await _client.get('/v1/me/exam-attempts/$id')));

  @override
  Future<SaveOutcome> saveAnswers(String attemptId, List<PendingAnswer> answers) async {
    final j = _map(await _client.put('/v1/me/exam-attempts/$attemptId/answers', body: {
      'answers': [for (final a in answers) a.toJson()],
    }));
    return SaveOutcome(
      [for (final r in (j['results'] as List).cast<Map<String, dynamic>>()) SavedAnswer.fromJson(r)],
      DateTime.parse(j['server_now'] as String),
    );
  }

  @override
  Future<Attempt> advanceSection(String attemptId) async =>
      Attempt.fromJson(_map(await _client.post('/v1/me/exam-attempts/$attemptId/advance-section')));

  @override
  Future<AttemptResult> submit(String attemptId) async =>
      AttemptResult.fromJson(_map(await _client.post('/v1/me/exam-attempts/$attemptId/submit')));

  @override
  Future<AttemptResult> result(String attemptId) async =>
      AttemptResult.fromJson(_map(await _client.get('/v1/me/exam-attempts/$attemptId/result')));

  @override
  Future<AttemptReview> review(String attemptId) async =>
      AttemptReview.fromJson(_map(await _client.get('/v1/me/exam-attempts/$attemptId/review')));

  @override
  Future<AttemptSummaryPage> history({String? exam, String? cursor}) async {
    final j = _map(await _client.get('/v1/me/exam-attempts', query: {
      'exam': ?exam,
      'cursor': ?cursor,
    }));
    return AttemptSummaryPage(
      [for (final a in (j['items'] as List).cast<Map<String, dynamic>>()) AttemptSummary.fromJson(a)],
      j['next_cursor'] as String?,
    );
  }

  @override
  Future<List<ExamStats>> stats() async {
    final j = _map(await _client.get('/v1/me/exam-attempts/stats'));
    return [for (final e in (j['exams'] as List).cast<Map<String, dynamic>>()) ExamStats.fromJson(e)];
  }
}
