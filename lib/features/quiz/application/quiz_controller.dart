import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';
import '../../../core/config/game_rules.dart';
import '../../../core/storage/local_store.dart';
import '../../gamification/domain/reward_summary.dart';
import '../../gamification/domain/xp_calculator.dart';
import '../../journey/application/journey_controller.dart';
import '../../profile/application/profile_controller.dart';
import '../../progress/application/progress_sync.dart';
import '../../review/application/review_controller.dart';
import '../data/quiz_api.dart';
import '../domain/question.dart';
import '../domain/quiz_builder.dart';
import '../domain/quiz_models.dart';
import 'quiz_completion.dart';

enum QuizPhase {
  /// Asking the server for questions.
  starting,
  active,

  /// Waiting for the server to score the quiz.
  submitting,
  finished,

  /// The quiz could not start; see [QuizState.failure].
  failed,
}

enum QuizFailure {
  /// No published questions match (yet).
  empty,

  /// The server says there isn't enough energy today.
  noEnergy,
  network,
  signedOut,
  other,
}

@immutable
class QuizState {
  const QuizState({
    required this.request,
    this.phase = QuizPhase.starting,
    this.failure,
    this.questions = const [],
    this.index = 0,
    this.viewing,
    this.selected,
    this.sending = false,
    this.revealed = false,
    this.answers = const [],
    this.combo = 0,
    this.secondsLeft,
    this.opponent,
    this.opponentAnswers = const [],
    this.playerPoints = 0,
    this.opponentPoints = 0,
    this.problem = 0,
    this.submitFailed = false,
    this.result,
    this.rewards,
  });

  final QuizRequest request;
  final QuizPhase phase;
  final QuizFailure? failure;
  final List<Question> questions;
  final int index;

  /// An earlier, already answered question being looked at (read-only, in the
  /// modes that lock each answer); null when the current question is shown.
  final int? viewing;
  final int? selected;

  /// An answer is on its way to the server.
  final bool sending;

  /// True once the current question's answer is locked and feedback shown.
  final bool revealed;
  final List<AnswerRecord> answers;
  final int combo;

  /// Per-question countdown (timed modes) or whole-exam countdown.
  final int? secondsLeft;

  final DuelOpponent? opponent;
  final List<OpponentAnswer> opponentAnswers;
  final int playerPoints;
  final int opponentPoints;

  /// Bumped each time an answer could not be sent, so the view can say so.
  final int problem;

  /// Scoring failed (e.g. offline); the quiz can be submitted again.
  final bool submitFailed;

  final QuizResult? result;
  final RewardSummary? rewards;

  bool get isFinished => result != null;
  Question get current => questions[index];
  bool get isLast => index == questions.length - 1;
  double get progress => questions.isEmpty ? 0 : (index + (revealed ? 1 : 0)) / questions.length;
  AnswerRecord? get lastAnswer => answers.length > index ? answers[index] : null;
  bool get hasStarted => answers.isNotEmpty || selected != null;

  /// Questions with an answer chosen (skipped and timed-out ones don't count).
  int get answeredCount {
    if (request.mode != QuizMode.exam) return answers.where((a) => !a.isSkipped).length;
    // The exam keeps the question on screen out of [answers] until the learner moves on.
    final others = answers.indexed.where((e) => e.$1 != index && !e.$2.isSkipped).length;
    return others + (selected != null ? 1 : 0);
  }

  /// The exam lets the learner return to an earlier question and change the
  /// answer until the quiz is submitted. The other modes lock each answer.
  bool get canGoBack {
    if (phase != QuizPhase.active || sending || shownIndex == 0) return false;
    // A duel is a race against a recorded opponent: no looking back.
    return request.mode != QuizMode.duel;
  }

  /// The question on screen: the one being looked at, or the current one.
  int get shownIndex => viewing ?? index;
  Question get shown => questions[shownIndex];
  bool get isReviewing => viewing != null;

  /// The answer on screen: the viewed question's, or the current one's once it is locked.
  AnswerRecord? get shownAnswer => isReviewing ? answers[viewing!] : (revealed ? lastAnswer : null);

  /// Whether the Next button is enabled.
  bool get canAdvance =>
      phase == QuizPhase.active && !sending && (request.mode.instantFeedback ? revealed : true);

  QuizState copyWith({
    QuizPhase? phase,
    QuizFailure? failure,
    List<Question>? questions,
    int? index,
    int? viewing,
    bool clearViewing = false,
    int? selected,
    bool clearSelected = false,
    bool? sending,
    bool? revealed,
    List<AnswerRecord>? answers,
    int? combo,
    int? secondsLeft,
    DuelOpponent? opponent,
    List<OpponentAnswer>? opponentAnswers,
    int? playerPoints,
    int? opponentPoints,
    int? problem,
    bool? submitFailed,
    QuizResult? result,
    RewardSummary? rewards,
  }) {
    return QuizState(
      request: request,
      phase: phase ?? this.phase,
      failure: failure ?? this.failure,
      questions: questions ?? this.questions,
      index: index ?? this.index,
      viewing: clearViewing ? null : (viewing ?? this.viewing),
      selected: clearSelected ? null : (selected ?? this.selected),
      sending: sending ?? this.sending,
      revealed: revealed ?? this.revealed,
      answers: answers ?? this.answers,
      combo: combo ?? this.combo,
      secondsLeft: secondsLeft ?? this.secondsLeft,
      opponent: opponent ?? this.opponent,
      opponentAnswers: opponentAnswers ?? this.opponentAnswers,
      playerPoints: playerPoints ?? this.playerPoints,
      opponentPoints: opponentPoints ?? this.opponentPoints,
      problem: problem ?? this.problem,
      submitFailed: submitFailed ?? this.submitFailed,
      result: result ?? this.result,
      rewards: rewards ?? this.rewards,
    );
  }
}

final quizControllerProvider =
    NotifierProvider.autoDispose.family<QuizController, QuizState, QuizRequest>(QuizController.new);

/// Drives one quiz through a server session: the server picks the questions,
/// judges each answer and scores the whole quiz. This class only keeps time,
/// shows what the server returns and hands the verified result to the
/// rewards (XP, stars, streak), which stay on the device.
class QuizController extends Notifier<QuizState> {
  QuizController(this.request);

  final QuizRequest request;
  Timer? _timer;
  DateTime _questionStart = DateTime.now();
  DateTime _quizStart = DateTime.now();
  String? _sessionId;

  @override
  QuizState build() {
    ref.onDispose(() => _timer?.cancel());
    Future.microtask(_start);
    return QuizState(request: request);
  }

  QuizApi get _api => ref.read(quizApiProvider);
  DateTime _now() => ref.read(clockProvider)();

  Future<void> _start() async {
    try {
      final catalog = await ref.read(quizCatalogProvider.future);
      final profile = ref.read(profileProvider);
      final plan = QuizBuilder.plan(
        request: request,
        reachedChapters: ref.read(journeyProvider).reachedChapters,
        persona: profile.persona,
      );
      final topicIds = catalog.topicIdsFor(plan.chapterIds);
      if (plan.chapterIds.isNotEmpty && topicIds.isEmpty) {
        throw const ApiException(422, 'no_questions_available', 'Nothing published here yet');
      }
      final started = await _api.start(plan, topicIds: topicIds, catalog: catalog);
      if (!ref.mounted) return;
      _sessionId = started.sessionId;
      // The server charged the energy; show its figure.
      unawaited(ref.read(progressSyncProvider.notifier).refresh());
      final questions = started.questions;

      // Duels: the server picked the opponent and sent their recorded run.
      final opponent = started.opponent;
      final opponentAnswers = started.opponentAnswers;

      _quizStart = _now();
      _questionStart = _quizStart;
      final seconds = request.mode == QuizMode.exam ? GameRules.examSeconds : request.mode.secondsPerQuestion;
      state = state.copyWith(
        phase: QuizPhase.active,
        questions: questions,
        secondsLeft: seconds,
        opponent: opponent,
        opponentAnswers: opponentAnswers,
      );
      if (seconds != null) _startTimer();
    } on ApiException catch (e) {
      if (!ref.mounted) return;
      final failure = switch (e) {
        ApiException(code: 'no_questions_available') => QuizFailure.empty,
        ApiException(code: 'not_enough_energy') => QuizFailure.noEnergy,
        ApiException(isNetwork: true) => QuizFailure.network,
        ApiException(status: 401) => QuizFailure.signedOut,
        _ => QuizFailure.other,
      };
      state = state.copyWith(phase: QuizPhase.failed, failure: failure);
    }
  }

  /// Leaves before the first answer: the server removes the quiz and gives the
  /// energy back. Without a session (start failed) nothing was charged.
  /// Returns false when the server could not be reached, so the energy was
  /// not given back.
  Future<bool> abandon() async {
    _timer?.cancel();
    // The phone's copy took the energy when the quiz opened; give it back now.
    ref.read(profileProvider.notifier).refundEnergy(energyCostOf(request, ref.read(journeyProvider).stars));
    final id = _sessionId;
    if (id == null) return true;
    var refunded = true;
    try {
      await _api.abandon(id);
    } on ApiException {
      // Offline: the server keeps the charge, and the next sync shows it.
      refunded = false;
    }
    _sessionId = null;
    if (ref.mounted) await ref.read(progressSyncProvider.notifier).refresh();
    return refunded;
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => _tick());
  }

  void _tick() {
    final s = state;
    if (s.phase != QuizPhase.active || s.secondsLeft == null || s.sending) return;
    if (s.request.mode != QuizMode.exam && s.revealed) return; // paused on feedback
    _countDown(1);
  }

  /// The app was in the background for [away]: the timer can't tick there,
  /// but the server's clock kept going, so take that time off now.
  void catchUp(Duration away) {
    final s = state;
    if (s.phase != QuizPhase.active || s.secondsLeft == null || s.sending) return;
    if (s.request.mode != QuizMode.exam && s.revealed) return;
    if (away.inSeconds > 0) _countDown(away.inSeconds);
  }

  void _countDown(int seconds) {
    final s = state;
    final left = s.secondsLeft! - seconds;
    if (left > 0) {
      state = s.copyWith(secondsLeft: left);
      return;
    }
    state = s.copyWith(secondsLeft: 0);
    if (s.request.mode == QuizMode.exam) {
      _finishExam();
    } else {
      _timeOut();
    }
  }

  /// Time ran out on a question: tell the server, which records it as
  /// unanswered and sends back the right answer to show now. Offline, the
  /// answer shows on the result screen instead.
  Future<void> _timeOut() async {
    final s = state;
    final elapsed = _elapsedMs;
    state = s.copyWith(sending: true, clearSelected: true);
    Verdict? verdict;
    try {
      verdict = await _api.answer(
        _sessionId!,
        position: s.index + 1,
        question: s.current,
        option: null,
        elapsedMs: elapsed,
      );
    } on ApiException {
      verdict = null;
    }
    if (!ref.mounted) return;
    _lockAnswer(null, verdict: verdict, elapsedMs: elapsed);
  }

  int get _elapsedMs => _now().difference(_questionStart).inMilliseconds;

  /// User taps an option.
  Future<void> select(int option) async {
    final s = state;
    if (s.phase != QuizPhase.active || s.revealed || s.sending || s.isReviewing) return;
    if (!s.request.mode.instantFeedback) {
      state = s.copyWith(selected: option);
      return;
    }
    final elapsed = _elapsedMs;
    state = s.copyWith(selected: option, sending: true);
    try {
      final verdict = await _api.answer(
        _sessionId!,
        position: s.index + 1,
        question: s.current,
        option: option,
        elapsedMs: elapsed,
      );
      if (!ref.mounted) return;
      _lockAnswer(option, verdict: verdict, elapsedMs: elapsed);
    } on ApiException {
      if (!ref.mounted) return;
      state = state.copyWith(sending: false, clearSelected: true, problem: state.problem + 1);
    }
  }

  void _lockAnswer(int? option, {required Verdict? verdict, required int elapsedMs}) {
    final s = state;
    final record = AnswerRecord(
      question: s.current,
      selectedIndex: option,
      elapsedMs: elapsedMs,
      correct: verdict?.correct ?? false,
      reveal: verdict?.reveal,
    );
    var player = s.playerPoints;
    var opp = s.opponentPoints;
    if (s.request.mode == QuizMode.duel) {
      player += XpCalculator.duelPoints(
        correct: record.isCorrect,
        elapsedMs: record.elapsedMs,
        limitSeconds: GameRules.duelSeconds,
      );
      final o = s.opponentAnswers[s.index];
      opp += XpCalculator.duelPoints(correct: o.correct, elapsedMs: o.elapsedMs, limitSeconds: GameRules.duelSeconds);
    }
    state = s.copyWith(
      clearViewing: true,
      selected: option,
      clearSelected: option == null,
      sending: false,
      revealed: true,
      answers: [...s.answers, record],
      combo: record.isCorrect ? s.combo + 1 : 0,
      playerPoints: player,
      opponentPoints: opp,
    );
  }

  // Exam answers are saved as the learner moves on; submit waits for them.
  // Each save resolves to whether it reached the server.
  final _saves = <int, Future<bool>>{};

  Future<bool> _saveExamAnswer(int index, int option) => _saves[index] = _api
      .answer(_sessionId!, position: index + 1, question: state.questions[index], option: option)
      .then((_) => true, onError: (Object _) => false);

  /// The exam's answers with the question on screen recorded: added when it
  /// is seen for the first time, replaced when the learner came back to it.
  /// The answer is sent to the server, which keeps the latest until submit.
  List<AnswerRecord> _examAnswersWithCurrent(QuizState s) {
    final record = AnswerRecord(question: s.current, selectedIndex: s.selected, elapsedMs: _elapsedMs, correct: false);
    if (s.selected != null) _saveExamAnswer(s.index, s.selected!);
    final answers = [...s.answers];
    if (s.index < answers.length) {
      answers[s.index] = record;
    } else {
      answers.add(record);
    }
    return answers;
  }

  /// Shows the exam question at [index], with the answer already given to it.
  void _showExamQuestion(QuizState s, int index, List<AnswerRecord> answers) {
    final chosen = index < answers.length ? answers[index].selectedIndex : null;
    _questionStart = _now();
    state = s.copyWith(index: index, answers: answers, selected: chosen, clearSelected: chosen == null);
  }

  /// Previous button. In the exam it goes back to a question you can still
  /// change; elsewhere it shows the earlier question with your answer and the
  /// right one, to read only. The clock keeps running.
  void previous() {
    final s = state;
    if (!s.canGoBack) return;
    if (s.request.mode == QuizMode.exam) {
      _showExamQuestion(s, s.index - 1, _examAnswersWithCurrent(s));
    } else {
      state = s.copyWith(viewing: s.shownIndex - 1);
    }
  }

  /// Next while looking at an earlier question: one step towards the current one.
  void viewNext() {
    final s = state;
    final viewing = s.viewing;
    if (viewing == null) return;
    state = viewing + 1 >= s.index ? s.copyWith(clearViewing: true) : s.copyWith(viewing: viewing + 1);
  }

  /// Next button.
  void next() {
    final s = state;
    if (s.isReviewing) return viewNext();
    if (!s.canAdvance) return;
    if (s.request.mode == QuizMode.exam) {
      final answers = _examAnswersWithCurrent(s);
      if (s.isLast) {
        state = s.copyWith(answers: answers);
        _finishExam();
      } else {
        _showExamQuestion(s, s.index + 1, answers);
      }
      return;
    }
    if (s.isLast) {
      _finish();
      return;
    }
    _questionStart = _now();
    state = s.copyWith(
      index: s.index + 1,
      clearSelected: true,
      revealed: false,
      secondsLeft: s.request.mode.secondsPerQuestion,
    );
  }

  void _finishExam() {
    final s = state;
    // Unanswered questions count as skipped.
    final answers = [
      ...s.answers,
      for (var i = s.answers.length; i < s.questions.length; i++)
        AnswerRecord(question: s.questions[i], selectedIndex: null, elapsedMs: 0, correct: false),
    ];
    state = s.copyWith(answers: answers);
    _finish();
  }

  /// Submits again after a failed attempt (e.g. back online).
  Future<void> retrySubmit() async {
    if (state.submitFailed) await _finish();
  }

  Future<void> _finish() async {
    _timer?.cancel();
    state = state.copyWith(phase: QuizPhase.submitting, submitFailed: false);
    final SubmittedQuiz submitted;
    try {
      // Re-send any exam answer that did not reach the server (answers can change until submit).
      for (final MapEntry(key: i, value: save) in [..._saves.entries]) {
        if (await save) continue;
        final option = state.answers[i].selectedIndex;
        if (option != null && !await _saveExamAnswer(i, option)) {
          throw const ApiException(0, 'network', 'Could not save an answer');
        }
      }
      submitted = await _api.submit(_sessionId!, state.questions);
    } on ApiException {
      if (!ref.mounted) return;
      state = state.copyWith(phase: QuizPhase.active, submitFailed: true);
      return;
    }
    if (!ref.mounted) return;

    // The server's verdicts are canonical; local records only add timing.
    final s = state;
    final answers = [
      for (final (i, a) in s.answers.indexed)
        a.withServerVerdict(correct: submitted.verdicts[i].correct, reveal: submitted.verdicts[i].reveal),
    ];
    // Progress after this quiz, so the screens show the server's numbers.
    final progress = await ref.read(progressSyncProvider.notifier).refresh();
    if (!ref.mounted) return;
    final result = QuizResult(
      request: s.request,
      answers: answers,
      durationMs: _now().difference(_quizStart).inMilliseconds,
      // The server marks exams (minus marks for wrong answers, except for citizens).
      examScore: s.request.mode == QuizMode.exam ? submitted.score : null,
      // The server's points decide the duel; the running score was the phone's estimate.
      duelPlayerPoints: s.request.mode == QuizMode.duel ? (submitted.duel?.playerPoints ?? s.playerPoints) : null,
      duelOpponentPoints: s.request.mode == QuizMode.duel ? (submitted.duel?.opponentPoints ?? s.opponentPoints) : null,
      opponent: s.opponent,
    );
    // New mistakes, or ones now answered right.
    ref.invalidate(reviewProvider);
    // The quiz may have joined this week's league, or moved the learner up in it.
    final league = await ref.read(progressSyncProvider.notifier).league();
    if (!ref.mounted) return;
    final rewards = QuizCompletionService(ref).complete(
      result,
      submitted.rewards,
      progress,
      league: league,
      duel: submitted.duel,
    );
    state = s.copyWith(phase: QuizPhase.finished, answers: answers, result: result, rewards: rewards);
  }
}
