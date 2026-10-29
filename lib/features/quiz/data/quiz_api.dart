import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';
import '../../progress/domain/server_progress.dart';
import '../domain/question.dart';
import '../domain/quiz_builder.dart';
import '../domain/quiz_models.dart';

/// Content is English-only on the server for now; translations come later.
const quizLanguage = 'en';

/// A topic with published questions. Each app chapter is one subject on the
/// server (subject slug = chapter id).
@immutable
class CatalogTopic {
  const CatalogTopic({required this.topicId, required this.chapterId, required this.byDifficulty});

  final String topicId;
  final String chapterId;
  final Map<int, int> byDifficulty;

  int get available => byDifficulty.values.fold(0, (a, b) => a + b);
}

@immutable
class QuizCatalog {
  const QuizCatalog(this.topics);

  final List<CatalogTopic> topics;

  List<String> topicIdsFor(Iterable<String> chapterIds) => [
        for (final t in topics)
          if (chapterIds.contains(t.chapterId)) t.topicId,
      ];

  String? chapterForTopic(String topicId) {
    for (final t in topics) {
      if (t.topicId == topicId) return t.chapterId;
    }
    return null;
  }

  /// Published questions for a chapter (and difficulty, if given).
  int available(String chapterId, {int? difficulty}) => topics
      .where((t) => t.chapterId == chapterId)
      .fold(0, (n, t) => n + (difficulty == null ? t.available : (t.byDifficulty[difficulty] ?? 0)));
}

@immutable
class StartedQuiz {
  const StartedQuiz({required this.sessionId, required this.questions});

  final String sessionId;
  final List<Question> questions;
}

/// The server's verdict on one answer.
@immutable
class Verdict {
  const Verdict({required this.correct, required this.reveal});

  final bool correct;
  final Reveal reveal;
}

@immutable
class SubmittedQuiz {
  const SubmittedQuiz({required this.score, required this.total, required this.verdicts, required this.rewards});

  /// Under the session's scoring rules; an exam with minus marks can be fractional.
  final double score;
  final int total;

  /// What the server awarded: XP, stars and streak.
  final ServerRewards rewards;

  /// One per question, in order.
  final List<Verdict> verdicts;
}

final quizApiProvider = Provider<QuizApi>((ref) => HttpQuizApi(ref.watch(apiClientProvider)));

/// Topics that currently have published questions. Public, so it works signed out.
final quizCatalogProvider = FutureProvider<QuizCatalog>((ref) => ref.watch(quizApiProvider).catalog());

/// Quiz sessions on the Nyaya API. The server picks the questions, keeps the
/// answer key and does the scoring.
abstract interface class QuizApi {
  Future<QuizCatalog> catalog();

  Future<StartedQuiz> start(SessionPlan plan, {required List<String> topicIds, required QuizCatalog catalog});

  /// Saves an answer. Practice sessions return the verdict at once; exam
  /// sessions return null and reveal everything on [submit].
  Future<Verdict?> answer(String sessionId, {required int position, required Question question, required int option});

  Future<SubmittedQuiz> submit(String sessionId, List<Question> questions);

  /// Leaves a quiz before its first answer; the server gives the energy back.
  Future<void> abandon(String sessionId);
}

class HttpQuizApi implements QuizApi {
  HttpQuizApi(this._client);

  final ApiClient _client;

  @override
  Future<QuizCatalog> catalog() async {
    final j = await _client.get('/v1/quizzes', query: {'language': quizLanguage}, auth: false) as Map<String, dynamic>;
    return QuizCatalog([
      for (final t in (j['topics'] as List).cast<Map<String, dynamic>>())
        CatalogTopic(
          topicId: t['topic_id'] as String,
          chapterId: t['subject_slug'] as String,
          byDifficulty: {
            for (final e in (t['by_difficulty'] as Map<String, dynamic>).entries) int.parse(e.key): e.value as int,
          },
        ),
    ]);
  }

  @override
  Future<StartedQuiz> start(SessionPlan plan, {required List<String> topicIds, required QuizCatalog catalog}) async {
    final j = await _client.post('/v1/quiz-sessions', body: {
      'mode': plan.mode.apiName,
      'question_count': plan.count,
      'language': quizLanguage,
      if (plan.mode == QuizMode.exam) 'negative_marking': plan.negativeMarking,
      if (topicIds.isNotEmpty) 'topic_ids': topicIds,
      if (plan.difficulty != null) 'difficulty': plan.difficulty,
      if (plan.minDifficulty != null) 'min_difficulty': plan.minDifficulty,
      if (plan.maxDifficulty != null) 'max_difficulty': plan.maxDifficulty,
    }) as Map<String, dynamic>;
    return StartedQuiz(
      sessionId: j['id'] as String,
      questions: [
        for (final q in (j['questions'] as List).cast<Map<String, dynamic>>())
          Question(
            id: q['question_version_id'] as String,
            chapterId: catalog.chapterForTopic(q['topic_id'] as String) ?? '',
            difficulty: q['difficulty'] as int,
            text: q['stem'] as String,
            options: [for (final o in (q['options'] as List).cast<Map<String, dynamic>>()) o['text'] as String],
            optionIds: [for (final o in (q['options'] as List).cast<Map<String, dynamic>>()) o['id'] as String],
          ),
      ],
    );
  }

  @override
  Future<Verdict?> answer(String sessionId, {required int position, required Question question, required int option}) async {
    final j = await _client.post('/v1/quiz-sessions/$sessionId/answers', body: {
      'position': position,
      'selected_option_ids': [question.optionIds[option]],
    }) as Map<String, dynamic>;
    final feedback = j['feedback'] as Map<String, dynamic>?;
    return feedback == null ? null : _verdict(feedback, question);
  }

  @override
  Future<SubmittedQuiz> submit(String sessionId, List<Question> questions) async {
    final j = await _client.post('/v1/quiz-sessions/$sessionId/submit') as Map<String, dynamic>;
    final byPosition = {
      for (final q in (j['questions'] as List).cast<Map<String, dynamic>>()) q['position'] as int: q,
    };
    return SubmittedQuiz(
      score: (j['score'] as num).toDouble(),
      total: j['total'] as int,
      rewards: ServerRewards.fromJson(j['rewards'] as Map<String, dynamic>),
      verdicts: [
        for (var i = 0; i < questions.length; i++)
          _verdict(byPosition[i + 1]!['feedback'] as Map<String, dynamic>, questions[i]),
      ],
    );
  }

  @override
  Future<void> abandon(String sessionId) => _client.post('/v1/quiz-sessions/$sessionId/abandon');

  static Verdict _verdict(Map<String, dynamic> f, Question q) {
    final correctIds = (f['correct_option_ids'] as List).cast<String>();
    final index = correctIds.isEmpty ? -1 : q.optionIds.indexOf(correctIds.first);
    return Verdict(
      correct: f['correct'] as bool,
      reveal: Reveal(
        correctIndex: index < 0 ? null : index,
        explanation: f['explanation'] as String? ?? '',
        reference: (f['provision_reference'] as String?) ?? (f['source_title'] as String?) ?? '',
      ),
    );
  }
}
