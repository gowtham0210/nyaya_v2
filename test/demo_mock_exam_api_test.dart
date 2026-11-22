import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nyaya/core/api/api_client.dart';
import 'package:nyaya/features/mock_exams/data/demo_mock_exam_api.dart';
import 'package:nyaya/features/mock_exams/data/mock_exam_api.dart';
import 'package:nyaya/features/mock_exams/domain/mock_exam_models.dart';

class _NoClient extends Fake implements ApiClient {}

void main() {
  test('without the debug demo flag the app uses the real API', () {
    final c = ProviderContainer(overrides: [apiClientProvider.overrideWithValue(_NoClient())]);
    addTearDown(c.dispose);
    expect(c.read(mockExamApiProvider), isA<HttpMockExamApi>());
  });

  test('the demo API is labelled and runs an attempt end to end', () async {
    final api = DemoMockExamApi();
    expect(await api.isAvailable(MockExamSlugs.aibe), isTrue);
    expect(await api.isAvailable(MockExamSlugs.clat), isFalse);
    final papers = (await api.papers(MockExamSlugs.aibe)).items;
    expect(papers.every((p) => p.title.contains('[DEMO]')), isTrue);
    final a = await api.startAttempt(MockExamSlugs.aibe, kind: AttemptKind.fixedPaper, paperId: papers.first.id, mode: AttemptMode.practice);
    expect(a.questions.first.stem, contains('[DEMO]'));
    await api.saveAnswers(a.id, [const PendingAnswer(1, ['b'], 1)]);
    final r = await api.submit(a.id);
    expect(r.status, isNotNull);
    expect((await api.stats()).single.attempts, 1);
  });
}
