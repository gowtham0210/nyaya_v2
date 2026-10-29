import 'package:nyaya/core/api/api_client.dart';
import 'package:nyaya/core/api/token_store.dart';
import 'package:nyaya/core/utils/day.dart';
import 'package:nyaya/features/auth/data/auth_api.dart';
import 'package:nyaya/features/journey/domain/journey.dart';
import 'package:nyaya/features/progress/data/progress_api.dart';
import 'package:nyaya/features/progress/domain/server_progress.dart';
import 'package:nyaya/features/quiz/data/quiz_api.dart';
import 'package:nyaya/features/quiz/domain/question.dart';
import 'package:nyaya/features/quiz/domain/quiz_builder.dart';
import 'package:nyaya/features/quiz/domain/quiz_models.dart';

/// A stand-in for the Nyaya API. Like the real server it keeps the answer
/// key to itself (questions handed to the app carry none) and owns stars, XP,
/// the streak, coins and energy, with simpler XP than the real rules.
class FakeQuizApi implements QuizApi, ProgressApi {
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
    final cost = premium ? 0 : plan.mode.energyCost;
    if (energy < cost) throw const ApiException(409, 'not_enough_energy', 'none');
    energy -= cost;
    final id = 'session-${++sessionsStarted}';
    _sessions[id] = _FakeSession(
      picked,
      revealAtEnd: plan.revealAtEnd,
      mode: plan.mode,
      levelId: plan.mode == QuizMode.casePath ? '${plan.chapterIds.single}_${plan.difficulty}' : null,
      negativeMarking: plan.negativeMarking,
      cost: cost,
    );
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
    final correct = verdicts.where((v) => v.correct).length;
    final wrong = s.selected.length - correct;
    final total = verdicts.length;
    final level = s.levelId;
    final before = level == null ? 0 : (stars[level] ?? 0);
    final got = level == null ? null : _stars(correct, total);
    if (level != null && got! > before) stars[level] = got;
    final extended = quizzesCompleted == 0;
    final xp = correct * 10 + 10 + (correct == total ? 10 : 0);
    totalXp += xp;
    quizzesCompleted++;
    if (s.mode == QuizMode.dailyDocket) docketDone = true;
    final newStars = got == null ? 0 : (got - before).clamp(0, 3);
    final coinsEarned = newStars * 5;
    final energyBonus = got == 3 && before < 3 && !premium ? 1 : 0;
    coins += coinsEarned;
    energy += energyBonus;
    return SubmittedQuiz(
      // Exams with minus marks: +1 right, −0.25 wrong, like the real server.
      score: s.negativeMarking ? correct - 0.25 * wrong : correct.toDouble(),
      total: total,
      verdicts: verdicts,
      rewards: ServerRewards(
        questionXp: correct * 10,
        completionBonus: 10,
        perfectBonus: correct == total ? 10 : 0,
        modeMultiplier: 1,
        streakMultiplier: 1,
        xp: xp,
        levelId: level,
        stars: got,
        bestStarsBefore: before,
        newStars: newStars,
        streak: 1,
        streakExtended: extended,
        streakMilestone: null,
        coins: coinsEarned,
        energyBonus: energyBonus,
      ),
    );
  }

  @override
  Future<void> abandon(String sessionId) async {
    final s = _sessions.remove(sessionId);
    if (s != null) energy += s.cost;
  }

  // ── Progress (the server owns it) ──────────────────────────────────────────

  int coins = 60;
  int energy = 5;
  bool premium = false;
  ServerSettings? settings;

  final stars = <String, int>{};
  final openedChests = <String>{};
  int totalXp = 0;
  int quizzesCompleted = 0;
  bool docketDone = false;

  static int _stars(int correct, int total) {
    final a = total == 0 ? 0 : correct / total;
    return a >= 1 ? 3 : (a >= 0.8 ? 2 : (a >= 0.5 ? 1 : 0));
  }

  /// Set to answer progress in a shape the app can't read.
  bool unreadableProgress = false;

  @override
  Future<ServerProgress> fetch() async {
    if (unreadableProgress) throw TypeError();
    return _progress();
  }

  @override
  Future<ServerProgress> openChest(String chestId) async {
    if (openedChests.add(chestId)) coins += 30;
    return _progress();
  }

  @override
  Future<ServerProgress> refillEnergy() async {
    if (coins < 30) throw const ApiException(409, 'not_enough_coins', 'none');
    coins -= 30;
    energy++;
    return _progress();
  }

  @override
  Future<ServerProgress> buyStreakFreeze() async {
    if (coins < 100) throw const ApiException(409, 'not_enough_coins', 'none');
    coins -= 100;
    return _progress();
  }

  @override
  Future<ServerProgress> setPremium(bool on) async {
    premium = on;
    return _progress();
  }

  @override
  Future<void> saveSettings(ServerSettings value) async => settings = value;

  ServerProgress _progress() {
    final now = DateTime.now();
    final today = Day.key(now);
    final played = quizzesCompleted > 0;
    return ServerProgress(
      today: today,
      totalXp: totalXp,
      weekId: Day.weekKey(now),
      weeklyXp: totalXp,
      lastWeekId: '',
      lastWeekXp: 0,
      streak: played ? 1 : 0,
      longestStreak: played ? 1 : 0,
      streakFreezes: 0,
      lastActiveDay: played ? today : null,
      activeDays: played ? [today] : const [],
      frozenDays: const [],
      stars: {...stars},
      openedChests: {...openedChests},
      quizzesCompleted: quizzesCompleted,
      quizzesToday: quizzesCompleted,
      docketDoneToday: docketDone,
      questionsAnswered: 0,
      correct: 0,
      coins: coins,
      energy: energy,
      premium: premium,
      settings: settings,
      chatUsedToday: 0,
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
  _FakeSession(this.questions,
      {required this.revealAtEnd,
      required this.mode,
      required this.levelId,
      required this.negativeMarking,
      required this.cost});

  final List<_FakeQuestion> questions;
  final bool revealAtEnd;
  final QuizMode mode;
  final String? levelId;
  final bool negativeMarking;
  final int cost;
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
