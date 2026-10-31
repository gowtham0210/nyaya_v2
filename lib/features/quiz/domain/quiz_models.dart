import 'package:flutter/foundation.dart';

import '../../../core/config/game_rules.dart';
import 'question.dart';

/// The four quiz modes (see docs/DESIGN.md §Quiz modes), plus mistake practice.
enum QuizMode {
  /// Level-map campaign. No hard timer; instant feedback.
  casePath,

  /// Same 5 questions for everyone today. 30 s each. Always free.
  dailyDocket,

  /// 1v1 vs a rated opponent. 7 questions, 15 s each, speed-weighted points.
  duel,

  /// Exam simulator. 20 questions / 20 min, +1 / −0.25, review at the end.
  exam,

  /// Up to 10 of your own wrong answers. Free, untimed, instant feedback;
  /// a question answered right leaves your mistakes list.
  mistakeReview;

  int get energyCost => switch (this) {
        QuizMode.casePath => GameRules.casePathEnergyCost,
        QuizMode.dailyDocket => GameRules.dailyDocketEnergyCost,
        QuizMode.duel => GameRules.duelEnergyCost,
        QuizMode.exam => GameRules.examEnergyCost,
        QuizMode.mistakeReview => 0,
      };

  /// Seconds allowed per question; null = untimed per question.
  int? get secondsPerQuestion => switch (this) {
        QuizMode.casePath => null,
        QuizMode.dailyDocket => GameRules.dailyDocketSeconds,
        QuizMode.duel => GameRules.duelSeconds,
        QuizMode.exam => null,
        QuizMode.mistakeReview => null,
      };

  /// Reference time used for the XP speed bonus.
  int get speedReferenceSeconds => switch (this) {
        QuizMode.casePath => 30,
        QuizMode.dailyDocket => GameRules.dailyDocketSeconds,
        QuizMode.duel => GameRules.duelSeconds,
        QuizMode.exam => 60,
        QuizMode.mistakeReview => 30,
      };

  /// Whether the right answer is revealed right after each pick.
  bool get instantFeedback => this != QuizMode.exam;

  /// The mode's name on the Nyaya API.
  String get apiName => switch (this) {
        QuizMode.casePath => 'case_path',
        QuizMode.dailyDocket => 'daily_docket',
        QuizMode.duel => 'duel',
        QuizMode.exam => 'exam',
        QuizMode.mistakeReview => 'mistake_review',
      };
}

/// What the user asked to play. Value-equal so it can key a provider family.
@immutable
class QuizRequest {
  const QuizRequest(this.mode, {this.levelId});

  final QuizMode mode;

  /// For [QuizMode.casePath]: the journey node id, e.g. `constitution_2`.
  final String? levelId;

  @override
  bool operator ==(Object other) =>
      other is QuizRequest && other.mode == mode && other.levelId == levelId;

  @override
  int get hashCode => Object.hash(mode, levelId);
}

@immutable
class AnswerRecord {
  const AnswerRecord({
    required this.question,
    required this.selectedIndex,
    required this.elapsedMs,
    required this.correct,
    this.reveal,
  });

  final Question question;

  /// Null when time ran out or the question was skipped.
  final int? selectedIndex;
  final int elapsedMs;

  /// As judged by the server.
  final bool correct;

  /// Correct option and explanation, once the server has disclosed them.
  final Reveal? reveal;

  bool get isCorrect => correct;
  bool get isSkipped => selectedIndex == null;

  AnswerRecord withServerVerdict({required bool correct, required Reveal reveal}) => AnswerRecord(
        question: question,
        selectedIndex: selectedIndex,
        elapsedMs: elapsedMs,
        correct: correct,
        reveal: reveal,
      );
}

/// Who a duel races: another learner's recorded run ("Asha K."), or a
/// practice player when none fitted. Picked by the server.
@immutable
class DuelOpponent {
  const DuelOpponent({required this.name, required this.rating, required this.practice});

  final String name;
  final int rating;
  final bool practice;

  /// Avatar colour, the same for the same name.
  int get avatarSeed => name.hashCode & 0xFFFFF;
}

/// One of the opponent's recorded answers: right or not, and how long it took.
@immutable
class OpponentAnswer {
  const OpponentAnswer({required this.correct, required this.elapsedMs});

  final bool correct;
  final int elapsedMs;
}

/// How a duel ended, as the server settled it.
@immutable
class DuelOutcome {
  const DuelOutcome({
    required this.playerPoints,
    required this.opponentPoints,
    required this.ratingBefore,
    required this.ratingAfter,
  });

  final int playerPoints;
  final int opponentPoints;
  final int ratingBefore;
  final int ratingAfter;
}

@immutable
class QuizResult {
  const QuizResult({
    required this.request,
    required this.answers,
    required this.durationMs,
    this.examScore,
    this.duelPlayerPoints,
    this.duelOpponentPoints,
    this.opponent,
  });

  final QuizRequest request;
  final List<AnswerRecord> answers;
  final int durationMs;
  final double? examScore;
  final int? duelPlayerPoints;
  final int? duelOpponentPoints;
  final DuelOpponent? opponent;

  int get total => answers.length;
  int get correct => answers.where((a) => a.isCorrect).length;
  int get wrong => answers.where((a) => !a.isCorrect && !a.isSkipped).length;
  int get skipped => answers.where((a) => a.isSkipped).length;
  double get accuracy => total == 0 ? 0 : correct / total;
  bool get isPerfect => total > 0 && correct == total;

  int get stars {
    if (accuracy >= 1) return 3;
    if (accuracy >= GameRules.twoStarAccuracy) return 2;
    if (accuracy >= GameRules.oneStarAccuracy) return 1;
    return 0;
  }

  bool get passed => stars > 0;

  bool? get duelWon => duelPlayerPoints == null
      ? null
      : duelPlayerPoints! > (duelOpponentPoints ?? 0);
  bool get duelDraw => duelPlayerPoints != null && duelPlayerPoints == duelOpponentPoints;
}
