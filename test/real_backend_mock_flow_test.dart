import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:nyaya/core/api/api_client.dart';
import 'package:nyaya/core/api/token_store.dart';
import 'package:nyaya/features/mock_exams/data/mock_exam_api.dart';
import 'package:nyaya/features/mock_exams/domain/mock_exam_models.dart';

/// The Mock Exams client against a REAL backend, no fakes.
///
/// Opt-in: it needs a running API with a published paper and an active exam,
/// and a learner account on it. Run it only against a scratch copy of the
/// database, never against live learner data:
///
///   NYAYA_REAL_API=http://localhost:3100 flutter test test/real_backend_mock_flow_test.dart
///
/// It registers its own throwaway learner on that API. Without the variable the
/// test is skipped.
class _MemoryTokens implements TokenStore {
  StoredSession? _s;
  @override
  StoredSession? get current => _s;
  @override
  Future<void> save(StoredSession session) async => _s = session;
  @override
  Future<void> clear() async => _s = null;
}

void main() {
  final base = Platform.environment['NYAYA_REAL_API'];
  final skip = base == null ? 'set NYAYA_REAL_API to a scratch API to run' : null;

  test('a learner takes a paper from listing to history on the real backend', () async {
    final raw = http.Client();
    addTearDown(raw.close);
    final email = 'flow-${DateTime.now().microsecondsSinceEpoch}@test.local';
    const password = 'Scratch-pass-12345';
    final reg = await raw.post(Uri.parse('$base/v1/auth/register'),
        headers: {'content-type': 'application/json'}, body: jsonEncode({'email': email, 'password': password, 'display_name': 'Flow Test'}));
    expect(reg.statusCode, lessThan(300), reason: reg.body);
    final res = await raw.post(Uri.parse('$base/v1/auth/session'),
        headers: {'content-type': 'application/json'}, body: jsonEncode({'email': email, 'password': password}));
    expect(res.statusCode, 200, reason: res.body);
    final j = jsonDecode(res.body) as Map<String, dynamic>;
    final tokens = _MemoryTokens();
    await tokens.save(StoredSession(accessToken: j['access_token'] as String, refreshToken: j['refresh_token'] as String, user: j['user'] as Map<String, dynamic>));
    final client = ApiClient(baseUrl: base!, client: raw, tokens: tokens);
    final api = HttpMockExamApi(client);

    // Listing and instructions data.
    expect(await api.isAvailable(MockExamSlugs.aibe), isTrue);
    expect(await api.isAvailable(MockExamSlugs.clat), isFalse, reason: 'switched off exams stay hidden');
    final papers = (await api.papers(MockExamSlugs.aibe)).items;
    expect(papers, hasLength(1));
    final paper = papers.single;
    expect(paper.edition, 'XVIII');
    expect(paper.year, 2023);
    expect(paper.totalQuestions, 100);
    expect(paper.timedAvailable, isFalse, reason: 'no duration and unverified rules: timed mode stays off');
    expect(paper.verified, isFalse);

    // Start; a second start is refused while one is open.
    expect(await api.activeAttempt(MockExamSlugs.aibe), isNull);
    final attempt = await api.startAttempt(MockExamSlugs.aibe, kind: AttemptKind.fixedPaper, paperId: paper.id, mode: AttemptMode.practice);
    expect(attempt.questions, hasLength(100));
    expect(attempt.questions.every((q) => !q.withdrawn && q.options.length >= 2 && (q.stem ?? '').isNotEmpty), isTrue);
    expect(attempt.deadlineAt, isNull, reason: 'practice has no deadline');
    await expectLater(
      api.startAttempt(MockExamSlugs.aibe, kind: AttemptKind.fixedPaper, paperId: paper.id, mode: AttemptMode.practice),
      throwsA(isA<ApiException>().having((e) => e.status, 'status', 409)),
    );

    // Autosave, then resume from a fresh fetch (the app reopened).
    final first = attempt.questions[0], second = attempt.questions[1], third = attempt.questions[2];
    final saved = await api.saveAnswers(attempt.id, [
      PendingAnswer(first.position, [first.options.first.id], 1),
      PendingAnswer(second.position, [second.options[1].id], 1),
      PendingAnswer(third.position, [third.options[2].id], 1),
    ]);
    expect(saved.results.every((r) => r.applied), isTrue);
    // A write with the same counter but a different choice is refused, not applied.
    final stale = await api.saveAnswers(attempt.id, [PendingAnswer(first.position, [first.options.last.id], 1)]);
    expect(stale.results.single.applied, isFalse);
    final resumed = await api.activeAttempt(MockExamSlugs.aibe);
    expect(resumed?.id, attempt.id);
    final again = await api.attempt(attempt.id);
    expect(again.answeredCount, 3);
    expect(again.questions[0].selected, [first.options.first.id]);

    // No result or review while the attempt is open.
    await expectLater(api.result(attempt.id), throwsA(isA<ApiException>()));
    await expectLater(api.review(attempt.id), throwsA(isA<ApiException>()));

    // Submit, score and review.
    final result = await api.submit(attempt.id);
    expect(result.overall.totalPositions, 100);
    expect(result.overall.withdrawn, 0);
    expect(result.overall.correct + result.overall.incorrect, 3);
    expect(result.overall.unanswered, 97);
    // The paper has no marks configured (none is officially confirmed), so the
    // result shows counts only: no marks, percentage or pass claim are invented.
    expect(result.marksAvailable, isFalse);
    expect(result.overall.marksObtained, isNull);
    expect(result.overall.percentage, isNull);
    expect(result.pass.available, isFalse);
    final review = await api.review(attempt.id);
    expect(review.items, hasLength(100));
    // The score agrees with the accepted answers the review shows.
    var expectedCorrect = 0;
    for (final it in review.items) {
      expect(it.accepted, isNotEmpty);
      expect((it.explanation ?? '').isNotEmpty, isTrue, reason: 'question ${it.position} has an explanation');
      if (it.selected.isNotEmpty && it.accepted.contains(it.selected.first)) expectedCorrect++;
    }
    expect(result.overall.correct, expectedCorrect);
    // AIBE 18 Q63: the key was corrected to the official BCI key (A.K. Kraipak, option A).
    final q63 = review.items.firstWhere((i) => i.position == 63);
    expect(q63.accepted, ['a']);

    // History and statistics.
    expect(await api.activeAttempt(MockExamSlugs.aibe), isNull);
    final history = (await api.history(exam: MockExamSlugs.aibe)).items;
    expect(history.map((h) => h.id), contains(attempt.id));
    final stats = (await api.stats()).where((s) => s.exam == MockExamSlugs.aibe).single;
    expect(stats.attempts, greaterThanOrEqualTo(1));
    // Reading the result again gives the same counts.
    final reread = await api.result(attempt.id);
    expect(reread.overall.correct, result.overall.correct);
  }, skip: skip);
}
