import 'package:flutter/foundation.dart';

/// The exams the app knows by slug. Which of them a learner sees depends only
/// on what the learner API answers for them; the app never turns one on.
abstract final class MockExamSlugs {
  static const aibe = 'aibe';
  static const clat = 'clat';
  static const ailet = 'ailet';
  static const all = [aibe, clat, ailet];
}

enum AttemptMode {
  practice,
  timed;

  String get api => name;
}

enum AttemptKind {
  fixedPaper('fixed_paper'),
  randomMock('random_mock');

  const AttemptKind(this.api);
  final String api;
}

enum AttemptStatus {
  inProgress,
  submitted,
  expired;

  static AttemptStatus parse(String s) => switch (s) {
        'submitted' => AttemptStatus.submitted,
        'expired' => AttemptStatus.expired,
        _ => AttemptStatus.inProgress,
      };
}

@immutable
class PaperSummary {
  const PaperSummary({
    required this.id,
    required this.code,
    required this.revision,
    required this.title,
    required this.edition,
    required this.year,
    required this.setLabel,
    required this.totalQuestions,
    required this.durationSeconds,
    required this.configStatus,
    this.practiceTimerSeconds,
  });

  final String id;
  final String code;
  final int revision;
  final String title;
  final String? edition;
  final int? year;
  final String? setLabel;
  final int totalQuestions;
  final int? durationSeconds;
  final String configStatus;

  /// An admin-set practice timer. It is not the official exam time: it only
  /// lets a learner practise against a clock, and never makes timed mode
  /// "official".
  final int? practiceTimerSeconds;

  bool get verified => configStatus == 'official_confirmed';

  /// Mirrors the server's rule (a known duration and officially confirmed
  /// rules). The server still decides when the attempt starts.
  bool get timedAvailable => durationSeconds != null && verified;

  factory PaperSummary.fromJson(Map<String, dynamic> j) => PaperSummary(
        id: j['id'] as String,
        code: j['code'] as String,
        revision: (j['revision'] as num).toInt(),
        title: j['title'] as String,
        edition: j['edition'] as String?,
        year: (j['year'] as num?)?.toInt(),
        setLabel: j['set_label'] as String?,
        totalQuestions: (j['total_questions'] as num).toInt(),
        durationSeconds: (j['duration_seconds'] as num?)?.toInt(),
        configStatus: j['config_status'] as String? ?? 'unverified',
        practiceTimerSeconds: (j['practice_timer_seconds'] as num?)?.toInt(),
      );
}

@immutable
class PaperPage {
  const PaperPage(this.items, this.nextCursor);
  final List<PaperSummary> items;
  final String? nextCursor;
}

@immutable
class ExamOption {
  const ExamOption(this.id, this.text);
  final String id;
  final String text;

  factory ExamOption.fromJson(Map<String, dynamic> j) =>
      ExamOption(j['id'] as String, j['text'] as String);
  Map<String, dynamic> toJson() => {'id': id, 'text': text};
}

/// One position of an attempt as the learner sees it: never a key.
@immutable
class AttemptQuestion {
  const AttemptQuestion({
    required this.position,
    required this.sectionCode,
    required this.originalRef,
    required this.withdrawn,
    required this.stem,
    required this.options,
    required this.selected,
    required this.answerSeq,
  });

  final int position;
  final String? sectionCode;
  final String? originalRef;

  /// A placeholder for a question the exam body withdrew; it cannot be answered.
  final bool withdrawn;
  final String? stem;
  final List<ExamOption> options;
  final List<String> selected;
  final int answerSeq;

  bool get answered => selected.isNotEmpty;

  AttemptQuestion withAnswer(List<String> selected, int seq) => AttemptQuestion(
        position: position,
        sectionCode: sectionCode,
        originalRef: originalRef,
        withdrawn: withdrawn,
        stem: stem,
        options: options,
        selected: selected,
        answerSeq: seq,
      );

  factory AttemptQuestion.fromJson(Map<String, dynamic> j) => AttemptQuestion(
        position: (j['position'] as num).toInt(),
        sectionCode: j['section_code'] as String?,
        originalRef: j['original_ref'] as String?,
        withdrawn: j['withdrawn'] as bool? ?? false,
        stem: j['stem'] as String?,
        options: [
          for (final o in (j['options'] as List? ?? const []).cast<Map<String, dynamic>>()) ExamOption.fromJson(o),
        ],
        selected: [for (final s in (j['selected_option_ids'] as List? ?? const [])) s as String],
        answerSeq: (j['answer_seq'] as num? ?? 0).toInt(),
      );

  Map<String, dynamic> toJson() => {
        'position': position,
        'section_code': sectionCode,
        'original_ref': originalRef,
        'withdrawn': withdrawn,
        'stem': stem,
        'options': withdrawn ? null : [for (final o in options) o.toJson()],
        'selected_option_ids': selected,
        'answer_seq': answerSeq,
      };
}

@immutable
class AttemptSection {
  const AttemptSection(this.code, this.position, this.questionCount);
  final String code;
  final int position;
  final int questionCount;

  factory AttemptSection.fromJson(Map<String, dynamic> j) => AttemptSection(
        j['code'] as String,
        (j['position'] as num).toInt(),
        (j['question_count'] as num).toInt(),
      );
  Map<String, dynamic> toJson() => {'code': code, 'position': position, 'question_count': questionCount};
}

@immutable
class Attempt {
  const Attempt({
    required this.id,
    required this.kind,
    required this.mode,
    required this.status,
    required this.exam,
    required this.paperTitle,
    required this.startedAt,
    required this.deadlineAt,
    required this.serverNow,
    required this.sectionNavigation,
    required this.currentSectionPosition,
    required this.sections,
    required this.questions,
    required this.submittedAt,
  });

  final String id;
  final AttemptKind kind;
  final AttemptMode mode;
  final AttemptStatus status;
  final String exam;
  final String? paperTitle;
  final DateTime startedAt;

  /// Set by the server for timed attempts; the app only displays it.
  final DateTime? deadlineAt;

  /// The server's clock when this was sent.
  final DateTime serverNow;
  final String sectionNavigation;
  final int? currentSectionPosition;
  final List<AttemptSection> sections;
  final List<AttemptQuestion> questions;
  final DateTime? submittedAt;

  bool get open => status == AttemptStatus.inProgress;

  /// A practice attempt that runs against a server clock (not official timing).
  bool get practiceTimed => mode == AttemptMode.practice && deadlineAt != null;
  bool get lockedOrder => sectionNavigation == 'locked_order';
  int get answeredCount => questions.where((q) => q.answered).length;

  Attempt copyWith({List<AttemptQuestion>? questions, int? currentSectionPosition}) => Attempt(
        id: id,
        kind: kind,
        mode: mode,
        status: status,
        exam: exam,
        paperTitle: paperTitle,
        startedAt: startedAt,
        deadlineAt: deadlineAt,
        serverNow: serverNow,
        sectionNavigation: sectionNavigation,
        currentSectionPosition: currentSectionPosition ?? this.currentSectionPosition,
        sections: sections,
        questions: questions ?? this.questions,
        submittedAt: submittedAt,
      );

  factory Attempt.fromJson(Map<String, dynamic> j) {
    final paper = j['paper'] as Map<String, dynamic>?;
    return Attempt(
      id: j['id'] as String,
      kind: j['kind'] == 'fixed_paper' ? AttemptKind.fixedPaper : AttemptKind.randomMock,
      mode: j['mode'] == 'timed' ? AttemptMode.timed : AttemptMode.practice,
      status: AttemptStatus.parse(j['status'] as String),
      exam: j['exam'] as String,
      paperTitle: paper?['title'] as String?,
      startedAt: DateTime.parse(j['started_at'] as String),
      deadlineAt: j['deadline_at'] == null ? null : DateTime.parse(j['deadline_at'] as String),
      serverNow: DateTime.parse(j['server_now'] as String),
      sectionNavigation: j['section_navigation'] as String? ?? 'free',
      currentSectionPosition: (j['current_section_position'] as num?)?.toInt(),
      sections: [
        for (final s in (j['sections'] as List? ?? const []).cast<Map<String, dynamic>>()) AttemptSection.fromJson(s),
      ],
      questions: [
        for (final q in (j['questions'] as List? ?? const []).cast<Map<String, dynamic>>()) AttemptQuestion.fromJson(q),
      ],
      submittedAt: j['submitted_at'] == null ? null : DateTime.parse(j['submitted_at'] as String),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'kind': kind.api,
        'mode': mode.api,
        'status': switch (status) {
          AttemptStatus.inProgress => 'in_progress',
          AttemptStatus.submitted => 'submitted',
          AttemptStatus.expired => 'expired',
        },
        'exam': exam,
        'paper': paperTitle == null ? null : {'title': paperTitle},
        'started_at': startedAt.toUtc().toIso8601String(),
        'deadline_at': deadlineAt?.toUtc().toIso8601String(),
        'server_now': serverNow.toUtc().toIso8601String(),
        'section_navigation': sectionNavigation,
        'current_section_position': currentSectionPosition,
        'sections': [for (final s in sections) s.toJson()],
        'questions': [for (final q in questions) q.toJson()],
        'submitted_at': submittedAt?.toUtc().toIso8601String(),
      };
}

/// An answer waiting to reach the server. [seq] only ever goes up.
@immutable
class PendingAnswer {
  const PendingAnswer(this.position, this.selected, this.seq);
  final int position;
  final List<String> selected;
  final int seq;

  Map<String, dynamic> toJson() => {'position': position, 'selected_option_ids': selected, 'seq': seq};
  factory PendingAnswer.fromJson(Map<String, dynamic> j) => PendingAnswer(
        (j['position'] as num).toInt(),
        [for (final s in (j['selected_option_ids'] as List)) s as String],
        (j['seq'] as num).toInt(),
      );
}

@immutable
class SavedAnswer {
  const SavedAnswer(this.position, this.applied, this.reason, this.selected, this.seq);
  final int position;
  final bool applied;
  final String? reason;
  final List<String> selected;
  final int seq;

  factory SavedAnswer.fromJson(Map<String, dynamic> j) => SavedAnswer(
        (j['position'] as num).toInt(),
        j['applied'] as bool,
        j['reason'] as String?,
        [for (final s in (j['selected_option_ids'] as List? ?? const [])) s as String],
        (j['seq'] as num).toInt(),
      );
}

@immutable
class SaveOutcome {
  const SaveOutcome(this.results, this.serverNow);
  final List<SavedAnswer> results;
  final DateTime serverNow;
}

@immutable
class Tally {
  const Tally({
    required this.code,
    required this.totalPositions,
    required this.scorablePositions,
    required this.correct,
    required this.incorrect,
    required this.unanswered,
    required this.withdrawn,
    required this.marksObtained,
    required this.maxMarks,
    required this.percentage,
  });

  final String? code;
  final int totalPositions;
  final int scorablePositions;
  final int correct;
  final int incorrect;
  final int unanswered;
  final int withdrawn;
  final double? marksObtained;
  final double? maxMarks;
  final double? percentage;

  factory Tally.fromJson(Map<String, dynamic> j) => Tally(
        code: j['code'] as String?,
        totalPositions: (j['total_positions'] as num? ?? 0).toInt(),
        scorablePositions: (j['scorable_positions'] as num? ?? 0).toInt(),
        correct: (j['correct'] as num? ?? 0).toInt(),
        incorrect: (j['incorrect'] as num? ?? 0).toInt(),
        unanswered: (j['unanswered'] as num? ?? 0).toInt(),
        withdrawn: (j['withdrawn'] as num? ?? 0).toInt(),
        marksObtained: (j['marks_obtained'] as num?)?.toDouble(),
        maxMarks: (j['max_marks'] as num?)?.toDouble(),
        percentage: (j['percentage'] as num?)?.toDouble(),
      );
}

@immutable
class PassThreshold {
  const PassThreshold(this.threshold, this.met);
  final double threshold;
  final bool met;
}

@immutable
class PassCheck {
  const PassCheck({required this.available, required this.reason, required this.general, required this.reserved});

  /// False means no pass or fail may be claimed.
  final bool available;
  final String? reason;
  final PassThreshold? general;
  final PassThreshold? reserved;

  factory PassCheck.fromJson(Map<String, dynamic>? j) {
    PassThreshold? t(Object? v) => v is Map<String, dynamic>
        ? PassThreshold((v['threshold'] as num).toDouble(), v['met'] as bool)
        : null;
    if (j == null) return const PassCheck(available: false, reason: null, general: null, reserved: null);
    return PassCheck(
      available: j['available'] as bool? ?? false,
      reason: j['reason'] as String?,
      general: t(j['general']),
      reserved: t(j['reserved']),
    );
  }
}

@immutable
class AttemptResult {
  const AttemptResult({
    required this.attemptId,
    required this.status,
    required this.submittedAt,
    required this.marksAvailable,
    required this.provisional,
    required this.provisionalReasons,
    required this.overall,
    required this.sections,
    required this.pass,
  });

  final String attemptId;
  final AttemptStatus status;
  final DateTime submittedAt;
  final bool marksAvailable;

  /// Scoring still depends on a rule that is not confirmed (e.g. withdrawn questions).
  final bool provisional;
  final List<String> provisionalReasons;
  final Tally overall;
  final List<Tally> sections;
  final PassCheck pass;

  factory AttemptResult.fromJson(Map<String, dynamic> j) {
    final r = j['result'] as Map<String, dynamic>;
    return AttemptResult(
      attemptId: j['attempt_id'] as String,
      status: AttemptStatus.parse(j['status'] as String),
      submittedAt: DateTime.parse(j['submitted_at'] as String),
      marksAvailable: r['marks_available'] as bool? ?? false,
      provisional: r['provisional'] as bool? ?? false,
      provisionalReasons: [for (final s in (r['provisional_reasons'] as List? ?? const [])) s as String],
      overall: Tally.fromJson(r['overall'] as Map<String, dynamic>),
      sections: [
        for (final s in (r['sections'] as List? ?? const []).cast<Map<String, dynamic>>()) Tally.fromJson(s),
      ],
      pass: PassCheck.fromJson(r['pass'] as Map<String, dynamic>?),
    );
  }
}

/// A finished attempt's question with the answers and explanation. Only ever
/// fetched after submission.
@immutable
class ReviewItem {
  const ReviewItem({
    required this.position,
    required this.sectionCode,
    required this.originalRef,
    required this.withdrawn,
    required this.stem,
    required this.options,
    required this.selected,
    required this.accepted,
    required this.outcome,
    required this.marks,
    required this.explanation,
  });

  final int position;
  final String? sectionCode;
  final String? originalRef;
  final bool withdrawn;
  final String? stem;
  final List<ExamOption> options;
  final List<String> selected;
  final List<String> accepted;
  final String outcome;
  final double? marks;
  final String? explanation;

  factory ReviewItem.fromJson(Map<String, dynamic> j) => ReviewItem(
        position: (j['position'] as num).toInt(),
        sectionCode: j['section_code'] as String?,
        originalRef: j['original_ref'] as String?,
        withdrawn: j['withdrawn'] as bool? ?? false,
        stem: j['stem'] as String?,
        options: [
          for (final o in (j['options'] as List? ?? const []).cast<Map<String, dynamic>>()) ExamOption.fromJson(o),
        ],
        selected: [for (final s in (j['selected_option_ids'] as List? ?? const [])) s as String],
        accepted: [for (final s in (j['accepted_option_ids'] as List? ?? const [])) s as String],
        outcome: j['outcome'] as String? ?? '',
        marks: (j['marks'] as num?)?.toDouble(),
        explanation: j['explanation'] as String?,
      );
}

@immutable
class AttemptReview {
  const AttemptReview({required this.provisional, required this.reasons, required this.items});
  final bool provisional;
  final List<String> reasons;
  final List<ReviewItem> items;

  factory AttemptReview.fromJson(Map<String, dynamic> j) => AttemptReview(
        provisional: j['provisional'] as bool? ?? false,
        reasons: [for (final s in (j['provisional_reasons'] as List? ?? const [])) s as String],
        items: [
          for (final q in (j['questions'] as List).cast<Map<String, dynamic>>()) ReviewItem.fromJson(q),
        ],
      );
}

@immutable
class AttemptSummary {
  const AttemptSummary({
    required this.id,
    required this.kind,
    required this.mode,
    required this.status,
    required this.exam,
    required this.paperTitle,
    required this.startedAt,
    required this.marksObtained,
    required this.maxMarks,
    required this.percentage,
    required this.provisional,
  });

  final String id;
  final AttemptKind kind;
  final AttemptMode mode;
  final AttemptStatus status;
  final String exam;
  final String? paperTitle;
  final DateTime startedAt;
  final double? marksObtained;
  final double? maxMarks;
  final double? percentage;
  final bool? provisional;

  factory AttemptSummary.fromJson(Map<String, dynamic> j) => AttemptSummary(
        id: j['id'] as String,
        kind: j['kind'] == 'fixed_paper' ? AttemptKind.fixedPaper : AttemptKind.randomMock,
        mode: j['mode'] == 'timed' ? AttemptMode.timed : AttemptMode.practice,
        status: AttemptStatus.parse(j['status'] as String),
        exam: j['exam'] as String,
        paperTitle: j['paper_title'] as String?,
        startedAt: DateTime.parse(j['started_at'] as String),
        marksObtained: (j['marks_obtained'] as num?)?.toDouble(),
        maxMarks: (j['max_marks'] as num?)?.toDouble(),
        percentage: (j['percentage'] as num?)?.toDouble(),
        provisional: j['provisional'] as bool?,
      );
}

@immutable
class AttemptSummaryPage {
  const AttemptSummaryPage(this.items, this.nextCursor);
  final List<AttemptSummary> items;
  final String? nextCursor;
}

@immutable
class ExamStats {
  const ExamStats({
    required this.exam,
    required this.attempts,
    required this.withMarks,
    required this.averagePercentage,
    required this.bestPercentage,
  });

  final String exam;
  final int attempts;
  final int withMarks;
  final double? averagePercentage;
  final double? bestPercentage;

  factory ExamStats.fromJson(Map<String, dynamic> j) => ExamStats(
        exam: j['exam'] as String,
        attempts: (j['attempts'] as num).toInt(),
        withMarks: (j['with_marks'] as num).toInt(),
        averagePercentage: (j['average_percentage'] as num?)?.toDouble(),
        bestPercentage: (j['best_percentage'] as num?)?.toDouble(),
      );
}
