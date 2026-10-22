import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/game_rules.dart';
import '../../../core/storage/local_store.dart';
import '../../../core/utils/day.dart';
import '../../gamification/domain/reward_summary.dart';
import '../../gamification/domain/xp_calculator.dart';
import '../../journey/application/journey_controller.dart';
import '../../profile/application/profile_controller.dart';
import '../../profile/domain/user_profile.dart';
import '../data/question_repository.dart';
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

@immutable
class QuizState {
  const QuizState({
    required this.request,
    required this.questions,
    this.index = 0,
    this.selected,
    this.revealed = false,
    this.answers = const [],
    this.combo = 0,
    this.secondsLeft,
    this.opponent,
    this.opponentAnswers = const [],
    this.playerPoints = 0,
    this.opponentPoints = 0,
    this.result,
    this.rewards,
  });

  final QuizRequest request;
  final List<Question> questions;
  final int index;
  final int? selected;

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

  final QuizResult? result;
  final RewardSummary? rewards;

  bool get isFinished => result != null;
  Question get current => questions[index];
  bool get isLast => index == questions.length - 1;
  double get progress => questions.isEmpty ? 0 : (index + (revealed ? 1 : 0)) / questions.length;
  AnswerRecord? get lastAnswer => answers.length > index ? answers[index] : null;
  bool get hasStarted => answers.isNotEmpty || selected != null;

  /// Whether the Next button is enabled.
  bool get canAdvance => request.mode.instantFeedback ? revealed : true;

  QuizState copyWith({
    int? index,
    int? selected,
    bool clearSelected = false,
    bool? revealed,
    List<AnswerRecord>? answers,
    int? combo,
    int? secondsLeft,
    int? playerPoints,
    int? opponentPoints,
    QuizResult? result,
    RewardSummary? rewards,
  }) {
    return QuizState(
      request: request,
      questions: questions,
      index: index ?? this.index,
      selected: clearSelected ? null : (selected ?? this.selected),
      revealed: revealed ?? this.revealed,
      answers: answers ?? this.answers,
      combo: combo ?? this.combo,
      secondsLeft: secondsLeft ?? this.secondsLeft,
      opponent: opponent,
      opponentAnswers: opponentAnswers,
      playerPoints: playerPoints ?? this.playerPoints,
      opponentPoints: opponentPoints ?? this.opponentPoints,
      result: result ?? this.result,
      rewards: rewards ?? this.rewards,
    );
  }
}

final quizControllerProvider =
    NotifierProvider.autoDispose.family<QuizController, QuizState, QuizRequest>(QuizController.new);

/// Drives one quiz session. Requires [questionBankProvider] to be loaded
/// before first read (the quiz screen guarantees this).
class QuizController extends Notifier<QuizState> {
  QuizController(this.request);

  final QuizRequest request;
  Timer? _timer;
  late DateTime _questionStart;
  late DateTime _quizStart;

  @override
  QuizState build() {
    ref.onDispose(() => _timer?.cancel());
    final bank = ref.read(questionBankProvider).requireValue;
    final profile = ref.read(profileProvider);
    final journey = ref.read(journeyProvider);
    final now = ref.read(clockProvider)();
    final rng = Random();

    final questions = QuizBuilder.build(
      request: request,
      bank: bank,
      reachedChapters: journey.reachedChapters,
      persona: profile.persona,
      dayKey: Day.key(now),
      random: rng,
    );

    DuelOpponent? opponent;
    var opponentAnswers = const <OpponentAnswer>[];
    if (request.mode == QuizMode.duel) {
      opponent = QuizBuilder.opponent(profile.duelRating, rng);
      opponentAnswers = [
        for (final q in questions)
          () {
            final (c, ms) = QuizBuilder.opponentAnswer(opponent!, q, rng);
            return OpponentAnswer(correct: c, elapsedMs: ms);
          }(),
      ];
    }

    _quizStart = now;
    _questionStart = now;
    final seconds = request.mode == QuizMode.exam
        ? GameRules.examSeconds
        : request.mode.secondsPerQuestion;
    if (seconds != null && questions.isNotEmpty) _startTimer();

    return QuizState(
      request: request,
      questions: questions,
      secondsLeft: seconds,
      opponent: opponent,
      opponentAnswers: opponentAnswers,
    );
  }

  DateTime _now() => ref.read(clockProvider)();

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => _tick());
  }

  void _tick() {
    final s = state;
    if (s.isFinished || s.secondsLeft == null) return;
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
      _lockAnswer(null);
    }
  }

  int get _elapsedMs => _now().difference(_questionStart).inMilliseconds;

  /// User taps an option.
  void select(int option) {
    final s = state;
    if (s.isFinished || s.revealed) return;
    if (s.request.mode.instantFeedback) {
      _lockAnswer(option);
    } else {
      state = s.copyWith(selected: option);
    }
  }

  void _lockAnswer(int? option) {
    final s = state;
    final record = AnswerRecord(question: s.current, selectedIndex: option, elapsedMs: _elapsedMs);
    var player = s.playerPoints;
    var opp = s.opponentPoints;
    if (s.request.mode == QuizMode.duel) {
      player += XpCalculator.duelPoints(
        correct: record.isCorrect,
        elapsedMs: record.elapsedMs,
        limitSeconds: GameRules.duelSeconds,
      );
      final o = s.opponentAnswers[s.index];
      opp += XpCalculator.duelPoints(
        correct: o.correct,
        elapsedMs: o.elapsedMs,
        limitSeconds: GameRules.duelSeconds,
      );
    }
    state = s.copyWith(
      selected: option,
      clearSelected: option == null,
      revealed: true,
      answers: [...s.answers, record],
      combo: record.isCorrect ? s.combo + 1 : 0,
      playerPoints: player,
      opponentPoints: opp,
    );
  }

  /// Next button.
  void next() {
    final s = state;
    if (s.isFinished) return;
    if (s.request.mode == QuizMode.exam) {
      final record = AnswerRecord(question: s.current, selectedIndex: s.selected, elapsedMs: _elapsedMs);
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
    if (!s.revealed) return;
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
        AnswerRecord(question: s.questions[i], selectedIndex: null, elapsedMs: 0),
    ];
    state = s.copyWith(answers: answers);
    _finish();
  }

  void _finish() {
    _timer?.cancel();
    final s = state;
    double? examScore;
    if (s.request.mode == QuizMode.exam) {
      final negative = ref.read(profileProvider).persona == Persona.citizen
          ? 0.0
          : GameRules.examNegativeMarks;
      examScore = s.answers.fold<double>(0, (sum, a) {
        if (a.isSkipped) return sum;
        return sum + (a.isCorrect ? GameRules.examCorrectMarks : -negative);
      });
    }
    final result = QuizResult(
      request: s.request,
      answers: s.answers,
      durationMs: _now().difference(_quizStart).inMilliseconds,
      examScore: examScore,
      duelPlayerPoints: s.request.mode == QuizMode.duel ? s.playerPoints : null,
      duelOpponentPoints: s.request.mode == QuizMode.duel ? s.opponentPoints : null,
      opponent: s.opponent,
    );
    final rewards = QuizCompletionService(ref).complete(result);
    state = s.copyWith(result: result, rewards: rewards);
  }
}
