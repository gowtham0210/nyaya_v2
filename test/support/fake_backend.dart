import 'package:nyaya/core/api/api_client.dart';
import 'package:nyaya/core/api/token_store.dart';
import 'package:nyaya/features/auth/data/auth_api.dart';
import 'package:nyaya/features/journey/domain/journey.dart';
import 'package:nyaya/features/quiz/data/quiz_api.dart';
import 'package:nyaya/features/quiz/domain/question.dart';
import 'package:nyaya/features/quiz/domain/quiz_builder.dart';

/// A stand-in for the Nyaya API. Like the real server it keeps the answer
/// key to itself: questions handed to the app carry none.
class FakeQuizApi implements QuizApi {
  FakeQuizApi({this.perLevel = 6}) {
    for (final c in JourneyCatalog.chapters) {
      for (var d = 1; d <= 3; d++) {
        for (var i = 0; i < perLevel; i++) {
          final id = '${c.id}-$d-$i';
          // Put the right answer in a different slot each time.
          final options = ['Wrong A $id', 'Wrong B $id', 'Wrong C $id']..insert(i % 4, 'Right $id');
          _bank.add(_FakeQuestion(id, c.id, d, options, i % 4));
        }
      }
    }
  }

  final int perLevel;
  final _bank = <_FakeQuestion>[];
  final _sessions = <String, _FakeSession>{};

  /// What the server returned per answer, to check nothing leaked early.
  final verdictsSent = <Verdict?>[];
  int sessionsStarted = 0;

  /// Set to make the next answer fail as if offline.
  bool failNextAnswer = false;

  String correctTextFor(String questionId) {
    final q = _bank.firstWhere((q) => q.id == questionId);
    return q.options[q.correct];
  }

  String wrongTextFor(String questionId) {
    final q = _bank.firstWhere((q) => q.id == questionId);
    return q.options[(q.correct + 1) % 4];
  }

  @override
  Future<QuizCatalog> catalog() async => QuizCatalog([
        for (final c in JourneyCatalog.chapters)
          CatalogTopic(topicId: 'topic-${c.id}', chapterId: c.id, byDifficulty: {1: perLevel, 2: perLevel, 3: perLevel}),
      ]);

  @override
  Future<StartedQuiz> start(SessionPlan plan, {required List<String> topicIds, required QuizCatalog catalog}) async {
    final chapters = topicIds.map(catalog.chapterForTopic).toSet();
    final picked = _bank
        .where((q) => topicIds.isEmpty || chapters.contains(q.chapter))
        .where((q) => plan.difficulty == null || q.difficulty == plan.difficulty)
        .where((q) => plan.minDifficulty == null || q.difficulty >= plan.minDifficulty!)
        .where((q) => plan.maxDifficulty == null || q.difficulty <= plan.maxDifficulty!)
        .take(plan.count)
        .toList();
    if (picked.isEmpty) throw const ApiException(422, 'no_questions_available', 'none');
    final id = 'session-${++sessionsStarted}';
    _sessions[id] = _FakeSession(picked, revealAtEnd: plan.revealAtEnd);
    return StartedQuiz(
      sessionId: id,
      questions: [
        for (final q in picked)
          Question(
            id: q.id,
            chapterId: q.chapter,
            difficulty: q.difficulty,
            text: 'Question text ${q.id}',
            options: q.options,
            optionIds: const ['a', 'b', 'c', 'd'],
          ),
      ],
    );
  }

  @override
  Future<Verdict?> answer(String sessionId, {required int position, required Question question, required int option}) async {
    if (failNextAnswer) {
      failNextAnswer = false;
      throw const ApiException(0, 'network', 'offline');
    }
    final s = _sessions[sessionId]!;
    s.selected[position - 1] = option;
    final verdict = s.revealAtEnd ? null : _verdict(s.questions[position - 1], option);
    verdictsSent.add(verdict);
    return verdict;
  }

  @override
  Future<SubmittedQuiz> submit(String sessionId, List<Question> questions) async {
    final s = _sessions[sessionId]!;
    final verdicts = [for (var i = 0; i < s.questions.length; i++) _verdict(s.questions[i], s.selected[i])];
    return SubmittedQuiz(
      score: verdicts.where((v) => v.correct).length,
      total: verdicts.length,
      verdicts: verdicts,
    );
  }

  Verdict _verdict(_FakeQuestion q, int? option) => Verdict(
        correct: option == q.correct,
        reveal: Reveal(correctIndex: q.correct, explanation: 'Because ${q.id}', reference: 'Article ${q.difficulty}'),
      );
}

class _FakeQuestion {
  _FakeQuestion(this.id, this.chapter, this.difficulty, this.options, this.correct);

  final String id;
  final String chapter;
  final int difficulty;
  final List<String> options;
  final int correct;
}

class _FakeSession {
  _FakeSession(this.questions, {required this.revealAtEnd});

  final List<_FakeQuestion> questions;
  final bool revealAtEnd;
  final selected = <int, int>{};
}

/// Accepts any email and password; stores a session like the real one.
class FakeAuthApi implements AuthApi {
  FakeAuthApi(this.tokens);

  final TokenStore tokens;
  final registered = <String>[];

  @override
  Future<Account> signIn({required String email, required String password}) => _session(email, 'Learner');

  @override
  Future<Account> register({required String name, required String email, required String password}) {
    registered.add(email);
    return _session(email, name);
  }

  @override
  Future<void> signOut() => tokens.clear();

  Future<Account> _session(String email, String name) async {
    final user = {'id': 'user-1', 'email': email, 'display_name': name, 'roles': ['learner']};
    await tokens.save(StoredSession(accessToken: 'access', refreshToken: 'refresh', user: user));
    return Account.fromJson(user);
  }
}

/// A token store that already holds a learner session.
MemoryTokenStore signedInTokens() => MemoryTokenStore(const StoredSession(
      accessToken: 'access',
      refreshToken: 'refresh',
      user: {'id': 'user-1', 'email': 'ravi@test.local', 'display_name': 'Ravi', 'roles': ['learner']},
    ));
