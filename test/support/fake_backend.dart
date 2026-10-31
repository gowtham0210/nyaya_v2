import 'package:nyaya/core/api/api_client.dart';
import 'package:nyaya/core/api/token_store.dart';
import 'package:nyaya/core/utils/day.dart';
import 'package:nyaya/features/auth/data/auth_api.dart';
import 'package:nyaya/features/gamification/domain/xp_calculator.dart';
import 'package:nyaya/features/journey/domain/journey.dart';
import 'package:nyaya/features/leaderboard/data/league_api.dart';
import 'package:nyaya/features/legal_updates/data/legal_updates_repository.dart';
import 'package:nyaya/features/progress/data/progress_api.dart';
import 'package:nyaya/features/review/data/review_api.dart';
import 'package:nyaya/features/progress/domain/server_progress.dart';
import 'package:nyaya/features/quiz/data/quiz_api.dart';
import 'package:nyaya/features/quiz/domain/question.dart';
import 'package:nyaya/features/quiz/domain/quiz_builder.dart';
import 'package:nyaya/features/quiz/domain/quiz_models.dart';
import 'package:nyaya/features/reminders/data/reminder_notifications.dart';

/// A stand-in for the Nyaya API. Like the real server it keeps the answer
/// key to itself (questions handed to the app carry none) and owns stars, XP,
/// the streak, coins and energy, with simpler XP than the real rules.
class FakeQuizApi implements QuizApi, ProgressApi, LeagueApi, ReviewApi {
  /// The next duel's opponent is a practice player (no learner's run fitted).
  bool practiceOpponent = false;
  int duelRating = 1000;
  int duelsPlayed = 0;
  int duelsWon = 0;

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
    // Duels race a recorded run: every answer wrong, so a learner who knows the answers wins.
    final duel = plan.mode == QuizMode.duel;
    return StartedQuiz(
      sessionId: id,
      opponent: duel
          ? DuelOpponent(name: practiceOpponent ? 'Meera K.' : 'Asha K.', rating: 1000, practice: practiceOpponent)
          : null,
      opponentAnswers: [
        if (duel)
          for (final _ in picked) const OpponentAnswer(correct: false, elapsedMs: 5000),
      ],
      questions: [
        for (final q in picked)
          Question(
            id: q.id,
            questionId: 'q-${q.id}',
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
  Future<Verdict?> answer(
    String sessionId, {
    required int position,
    required Question question,
    required int option,
    int? elapsedMs,
  }) async {
    if (failNextAnswer) {
      failNextAnswer = false;
      throw const ApiException(0, 'network', 'offline');
    }
    final s = _sessions[sessionId]!;
    s.selected[position - 1] = option;
    if (elapsedMs != null) s.elapsed[position - 1] = elapsedMs;
    final verdict = s.revealAtEnd ? null : _verdict(s.questions[position - 1], option);
    verdictsSent.add(verdict);
    return verdict;
  }

  @override
  Future<SubmittedQuiz> submit(String sessionId, List<Question> questions) async {
    final s = _sessions[sessionId]!;
    final verdicts = [for (var i = 0; i < s.questions.length; i++) _verdict(s.questions[i], s.selected[i])];
    for (var i = 0; i < s.questions.length; i++) {
      final id = s.questions[i].id;
      if (verdicts[i].correct) {
        wrongCounts.remove(id);
      } else {
        wrongCounts[id] = (wrongCounts[id] ?? 0) + 1;
      }
    }
    final correct = verdicts.where((v) => v.correct).length;
    final wrong = s.selected.length - correct;
    final total = verdicts.length;
    final level = s.levelId;
    final before = level == null ? 0 : (stars[level] ?? 0);
    final got = level == null ? null : _stars(correct, total);
    if (level != null && got! > before) stars[level] = got;
    final extended = quizzesCompleted == 0;
    // Duels: the opponent got nothing, so any right answer wins.
    DuelOutcome? duel;
    if (s.mode == QuizMode.duel) {
      final points = [
        for (var i = 0; i < verdicts.length; i++)
          XpCalculator.duelPoints(correct: verdicts[i].correct, elapsedMs: s.elapsed[i] ?? 15000, limitSeconds: 15),
      ].fold(0, (a, b) => a + b);
      final won = points > 0;
      duel = DuelOutcome(
        playerPoints: points,
        opponentPoints: 0,
        ratingBefore: duelRating,
        ratingAfter: duelRating + (won ? 16 : -16),
      );
      duelRating = duel.ratingAfter;
      duelsPlayed++;
      if (won) duelsWon++;
    }
    final duelBonus = duel != null && duel.playerPoints > duel.opponentPoints ? 15 : 0;
    final xp = correct * 10 + 10 + (correct == total ? 10 : 0) + duelBonus;
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
      duel: duel,
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
        duelBonus: duelBonus,
      ),
    );
  }

  @override
  Future<void> abandon(String sessionId) async {
    final s = _sessions.remove(sessionId);
    if (s != null) energy += s.cost;
  }

  // ── Review (saved questions, mistakes, reports) ───────────────────────────

  /// Version id → times answered wrong, while the latest answer is wrong.
  final wrongCounts = <String, int>{};
  final savedQuestions = <String>{};
  final reports = <({String versionId, ReportReason reason, String? comment})>[];

  ReviewQuestion _reviewQuestion(String versionId) {
    final q = _bank.firstWhere((q) => q.id == versionId);
    return ReviewQuestion(
      questionId: 'q-${q.id}',
      available: true,
      stem: 'Question text ${q.id}',
      options: [for (final (i, o) in q.options.indexed) (id: 'abcd'[i], text: o)],
      correctOptionIds: ['abcd'[q.correct]],
      explanation: 'Because ${q.id}',
      reference: 'Article ${q.difficulty}',
      sourceUrl: 'https://www.indiacode.nic.in/',
    );
  }

  @override
  Future<List<Mistake>> mistakes() async => [
        for (final e in wrongCounts.entries)
          Mistake(
            question: _reviewQuestion(e.key),
            wrongCount: e.value,
            lastWrongAt: DateTime.now(),
            saved: savedQuestions.contains('q-${e.key}'),
          ),
      ];

  @override
  Future<List<SavedQuestion>> saved() async => [
        for (final id in savedQuestions) SavedQuestion(question: _reviewQuestion(id.substring(2)), savedAt: DateTime.now()),
      ];

  @override
  Future<void> save(String questionId) async => savedQuestions.add(questionId);

  @override
  Future<void> unsave(String questionId) async => savedQuestions.remove(questionId);

  @override
  Future<void> report({required String questionVersionId, required ReportReason reason, String? comment}) async {
    if (reports.any((r) => r.versionId == questionVersionId)) {
      throw const ApiException(409, 'already_reported', 'none');
    }
    reports.add((versionId: questionVersionId, reason: reason, comment: comment));
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

  /// The fake league: you join with your first quiz; 29 practice players.
  LeagueResult? lastResult;

  @override
  Future<LeagueView> league() async => _league();

  LeagueView _league() {
    final joined = quizzesCompleted > 0;
    final rows = <({String name, int xp, bool me})>[
      if (joined) (name: 'Ravi', xp: totalXp, me: true),
      if (joined)
        for (var i = 0; i < 29; i++) (name: 'Practice $i', xp: 300 - i * 10, me: false),
    ]..sort((a, b) => b.xp != a.xp ? b.xp.compareTo(a.xp) : (a.me ? -1 : 1));
    return LeagueView(
      weekId: Day.weekKey(DateTime.now()),
      endsAt: DateTime.now().add(const Duration(days: 3)),
      tier: 1,
      joined: joined,
      promote: 15,
      demote: 0,
      cohortSize: 30,
      standings: [
        for (final (i, r) in rows.indexed)
          LeagueStanding(rank: i + 1, name: r.name, xp: r.xp, me: r.me, practice: !r.me),
      ],
      lastResult: lastResult,
    );
  }

  /// How many times the app told the server it was opened.
  var appOpens = 0;

  @override
  Future<void> markAppOpen() async => appOpens++;

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
      duelRating: duelRating,
      duelsPlayed: duelsPlayed,
      duelsWon: duelsWon,
    );
  }

  Verdict _verdict(_FakeQuestion q, int? option) => Verdict(
        correct: option == q.correct,
        reveal: Reveal(
          correctIndex: q.correct,
          explanation: 'Because ${q.id}',
          reference: 'Article ${q.difficulty}',
          sourceUrl: 'https://www.indiacode.nic.in/',
        ),
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
  final elapsed = <int, int>{};
}

/// Accepts any email and password; stores a session like the real one.
class FakeAuthApi implements AuthApi {
  FakeAuthApi(this.tokens);

  final TokenStore tokens;
  final registered = <String>[];
  var deleted = 0;

  /// Makes [deleteAccount] answer as the API does for a wrong password.
  var wrongPassword = false;

  @override
  Future<Account> signIn({required String email, required String password}) => _session(email, 'Learner');

  @override
  Future<Account> register({required String name, required String email, required String password}) {
    registered.add(email);
    return _session(email, name);
  }

  @override
  Future<void> signOut() => tokens.clear();

  @override
  Future<void> deleteAccount({required String password}) async {
    if (wrongPassword) throw const ApiException(403, 'wrong_password', 'The password is not right');
    deleted++;
    await tokens.clear();
  }

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

/// Two published articles, as the API would send them.
class FakeLegalUpdates implements LegalUpdatesRepository {
  @override
  Future<List<LegalUpdate>> fetch() async => [
        LegalUpdate(
          id: 'news-1',
          category: UpdateCategory.supremeCourt,
          title: 'Supreme Court sets timelines for Governors on State Bills',
          summary: 'A Governor cannot sit on Bills indefinitely.',
          keyPoints: const ['There is no pocket veto.'],
          whyItMatters: 'Elected legislatures are not stalled.',
          source: 'Supreme Court of India, 8 April 2025',
          sourceUrl: 'https://main.sci.gov.in/',
          date: DateTime(2025, 4, 8),
          readMinutes: 3,
        ),
        LegalUpdate(
          id: 'news-2',
          category: UpdateCategory.legislation,
          title: 'Waqf (Amendment) Act, 2025 receives Presidential assent',
          summary: 'Parliament amended the Waqf Act, 1995.',
          keyPoints: const ['Changes how waqf boards are formed.'],
          whyItMatters: 'It affects how waqf land is managed.',
          source: 'Gazette of India, April 2025',
          date: DateTime(2025, 4, 5),
          readMinutes: 3,
        ),
      ];
}

/// Records what would be scheduled instead of touching the phone.
class FakeReminderNotifications implements ReminderNotifications {
  FakeReminderNotifications({this.allow = true});

  /// The answer to the permission question.
  bool allow;
  int permissionAsks = 0;
  List<ReminderNotice> scheduled = const [];

  @override
  Future<bool> requestPermission() async {
    permissionAsks++;
    return allow;
  }

  @override
  Future<void> replaceAll(List<ReminderNotice> notices) async => scheduled = notices;
}
