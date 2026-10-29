import 'dart:async';
import 'dart:math';

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

@immutable
class OpponentAnswer {
  const OpponentAnswer({required this.correct, required this.elapsedMs});
  final bool correct;
  final int elapsedMs;
}

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

  /// Whether the Next button is enabled.
  bool get canAdvance =>
      phase == QuizPhase.active && !sending && (request.mode.instantFeedback ? revealed : true);

  QuizState copyWith({
    QuizPhase? phase,
    QuizFailure? failure,
    List<Question>? questions,
    int? index,
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

      DuelOpponent? opponent;
      var opponentAnswers = const <OpponentAnswer>[];
      if (request.mode == QuizMode.duel) {
        final rng = Random();
        opponent = QuizBuilder.opponent(profile.duelRating, rng);
        opponentAnswers = [
          for (final q in questions)
            () {
              final (c, ms) = QuizBuilder.opponentAnswer(opponent!, q, rng);
              return OpponentAnswer(correct: c, elapsedMs: ms);
            }(),
        ];
      }

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
  Future<void> abandon() async {
    _timer?.cancel();
    // The phone's copy took the energy when the quiz opened; give it back now.
    ref.read(profileProvider.notifier).refundEnergy(request.mode.energyCost);
    final id = _sessionId;
    if (id == null) return;
    try {
      await _api.abandon(id);
    } on ApiException {
      // Offline: the server keeps the charge until the next sync shows it.
    }
    _sessionId = null;
    await ref.read(progressSyncProvider.notifier).refresh();
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => _tick());
  }

  void _tick() {
    final s = state;
    if (s.phase != QuizPhase.active || s.secondsLeft == null || s.sending) return;
    if (s.request.mode != QuizMode.exam && s.revealed) return; // paused on feedback
    final left = s.secondsLeft! - 1;
    if (left > 0) {
      state = s.copyWith(secondsLeft: left);
      return;
    }
    state = s.copyWith(secondsLeft: 0);
    if (s.request.mode == QuizMode.exam) {
      _finishExam();
    } else {
      // Time ran out: nothing is sent, so the answer stays secret until the result.
      _lockAnswer(null, verdict: null, elapsedMs: _elapsedMs);
    }
  }

  int get _elapsedMs => _now().difference(_questionStart).inMilliseconds;

  /// User taps an option.
  Future<void> select(int option) async {
    final s = state;
    if (s.phase != QuizPhase.active || s.revealed || s.sending) return;
    if (!s.request.mode.instantFeedback) {
      state = s.copyWith(selected: option);
      return;
    }
    final elapsed = _elapsedMs;
    state = s.copyWith(selected: option, sending: true);
    try {
      final verdict = await _api.answer(_sessionId!, position: s.index + 1, question: s.current, option: option);
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

  /// Next button.
  void next() {
    final s = state;
    if (!s.canAdvance) return;
    if (s.request.mode == QuizMode.exam) {
      final record = AnswerRecord(question: s.current, selectedIndex: s.selected, elapsedMs: _elapsedMs, correct: false);
      if (s.selected != null) _saveExamAnswer(s.index, s.selected!);
      final answers = [...s.answers, record];
      if (s.isLast) {
        state = s.copyWith(answers: answers);
        _finishExam();
      } else {
        _questionStart = _now();
        state = s.copyWith(index: s.index + 1, answers: answers, clearSelected: true);
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
      duelPlayerPoints: s.request.mode == QuizMode.duel ? s.playerPoints : null,
      duelOpponentPoints: s.request.mode == QuizMode.duel ? s.opponentPoints : null,
      opponent: s.opponent,
    );
    // New mistakes, or ones now answered right.
    ref.invalidate(reviewProvider);
    // The quiz may have joined this week's league, or moved the learner up in it.
    final league = await ref.read(progressSyncProvider.notifier).league();
    if (!ref.mounted) return;
    final rewards = QuizCompletionService(ref).complete(result, submitted.rewards, progress, league: league);
    state = s.copyWith(phase: QuizPhase.finished, answers: answers, result: result, rewards: rewards);
  }
}
