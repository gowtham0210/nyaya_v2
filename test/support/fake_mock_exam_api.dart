import 'dart:async';

import 'package:nyaya/core/api/api_client.dart';
import 'package:nyaya/features/mock_exams/application/server_clock.dart';
import 'package:nyaya/features/mock_exams/data/mock_exam_api.dart';
import 'package:nyaya/features/mock_exams/domain/mock_exam_models.dart';

/// A stand-in for the mock exam API that behaves like the server: it owns the
/// questions, the answer key and the deadline; applies answers by counter;
/// ends a timed attempt at its deadline; and sends no key before submission.
///
/// Time is the test's own: move [now] to move the server's clock.
class FakeMockExamApi implements MockExamApi {
  FakeMockExamApi({DateTime? start}) : now = start ?? DateTime.utc(2026, 11, 20, 10);

  /// The server's clock.
  DateTime now;

  /// Exams the learner API shows (an inactive one answers 404).
  final available = <String>{MockExamSlugs.aibe};
  var paperList = <PaperSummary>[];

  /// Makes every call fail as if there were no connection.
  bool offline = false;

  /// Holds save responses until [releaseSaves] (to test late replies).
  Completer<void>? holdSaves;

  // What the tests look at.
  var startCalls = 0;
  var submitCalls = 0;
  var availabilityCalls = 0;
  final saveBatches = <List<PendingAnswer>>[];

  // The one attempt.
  String id = 'attempt-1';
  String slug = MockExamSlugs.aibe;
  AttemptMode mode = AttemptMode.practice;
  DateTime? deadline;
  String status = 'in_progress';
  String? finalisedBy;
  bool lockedOrder = false;
  bool hasAttempt = false;
  int currentSection = 1;
  bool provisional = true;
  PassCheck? passOverride;
  Map<String, dynamic>? passJson;

  /// Withdrawn at position 4; the rest are single-select with options a-d.
  final withdrawn = {4};
  final sectionOf = <int, int>{};
  final answers = <int, ({List<String> selected, int seq})>{};

  /// The answer key. Never leaves this class before submission.
  final key = {1: 'b', 2: 'c', 3: 'a'};
  static const secret = 'SECRET EXPLANATION';

  /// An error to raise on the next save, then clear.
  ApiException? failNextSave;

  /// One entry per save request, in order: an error to raise, or null to let
  /// that request through. Used up as requests arrive.
  final saveFailureQueue = <ApiException?>[];

  /// While set, fetching the attempt fails with it (a server error, say).
  ApiException? attemptFailure;
  var attemptFetches = 0;

  int total = 4;
  bool get open => status == 'in_progress';

  /// Creates an attempt with questions 1..[total] (and section numbers if [sections] is set).
  void begin({AttemptMode mode = AttemptMode.practice, Duration? limit, bool locked = false, int sections = 0}) {
    hasAttempt = true;
    this.mode = mode;
    deadline = mode == AttemptMode.timed ? now.add(limit ?? const Duration(hours: 1)) : null;
    status = 'in_progress';
    finalisedBy = null;
    lockedOrder = locked;
    currentSection = 1;
    answers.clear();
    sectionOf.clear();
    if (sections > 0) {
      for (var p = 1; p <= total; p++) {
        sectionOf[p] = p <= total ~/ 2 ? 1 : 2;
      }
    }
  }

  void releaseSaves() {
    holdSaves?.complete();
    holdSaves = null;
  }

  /// Another device answered: the server holds this at [seq].
  void forceAnswer(int position, List<String> selected, int seq) => answers[position] = (selected: selected, seq: seq);

  void _guard() {
    if (offline) throw const ApiException(0, 'network', 'Could not reach the server');
  }

  void _expireIfDue() {
    if (open && deadline != null && !now.isBefore(deadline!)) {
      status = 'expired';
      finalisedBy = 'expiry';
    }
  }

  Map<String, dynamic> _attemptJson() {
    return {
      'id': id,
      'kind': 'fixed_paper',
      'mode': mode.api,
      'status': status,
      'exam': slug,
      'paper': {'id': 'paper-1', 'code': 'p1', 'title': 'Fixture paper', 'revision': 1},
      'language': 'en',
      'started_at': now.toIso8601String(),
      'deadline_at': deadline?.toIso8601String(),
      'server_now': now.toIso8601String(),
      'remaining_seconds': deadline?.difference(now).inSeconds,
      'section_navigation': lockedOrder ? 'locked_order' : 'free',
      'current_section_position': lockedOrder ? currentSection : null,
      'sections': sectionOf.isEmpty
          ? <Object>[]
          : [
              for (final s in {...sectionOf.values})
                {'code': 's$s', 'position': s, 'question_count': sectionOf.values.where((v) => v == s).length},
            ],
      'total_questions': total,
      'answered_count': answers.values.where((a) => a.selected.isNotEmpty).length,
      'submitted_at': open ? null : now.toIso8601String(),
      'result_available': !open,
      'questions': [
        for (var p = 1; p <= total; p++)
          {
            'position': p,
            'section_code': sectionOf[p] == null ? null : 's${sectionOf[p]}',
            'original_ref': 'Q$p',
            'withdrawn': withdrawn.contains(p),
            'question_version_id': withdrawn.contains(p) ? null : 'v$p',
            'stem': withdrawn.contains(p) ? null : 'Question text $p',
            'options': withdrawn.contains(p)
                ? null
                : [
                    for (final o in ['a', 'b', 'c', 'd']) {'id': o, 'text': 'Option $o of $p'},
                  ],
            'selected_option_ids': answers[p]?.selected,
            'answer_seq': answers[p]?.seq ?? 0,
          },
      ],
    };
  }

  // ---------------------------------------------------------------- the API

  @override
  Future<bool> isAvailable(String slug) async {
    availabilityCalls++;
    _guard();
    return available.contains(slug);
  }

  @override
  Future<PaperPage> papers(String slug, {String? cursor}) async {
    _guard();
    if (!available.contains(slug)) throw const ApiException(404, 'not_found', 'Exam not found');
    return PaperPage(paperList, null);
  }

  @override
  Future<Attempt?> activeAttempt(String slug) async {
    _guard();
    _expireIfDue();
    return hasAttempt && open && slug == this.slug ? Attempt.fromJson(_attemptJson()) : null;
  }

  @override
  Future<Attempt> startAttempt(String slug, {required AttemptKind kind, String? paperId, required AttemptMode mode, bool practiceTimer = false}) async {
    startCalls++;
    _guard();
    if (!available.contains(slug)) throw const ApiException(404, 'not_found', 'Exam not found');
    _expireIfDue();
    if (hasAttempt && open) {
      throw const ApiException(409, 'attempt_in_progress', 'You already have an unfinished attempt');
    }
    begin(mode: mode, limit: practiceTimer ? const Duration(hours: 3) : null);
    if (practiceTimer) deadline = now.add(const Duration(hours: 3));
    this.slug = slug;
    return Attempt.fromJson(_attemptJson());
  }

  @override
  Future<Attempt> attempt(String id) async {
    attemptFetches++;
    _guard();
    if (attemptFailure != null) throw attemptFailure!;
    if (id != this.id) throw const ApiException(404, 'not_found', 'Attempt not found');
    _expireIfDue();
    return Attempt.fromJson(_attemptJson());
  }

  @override
  Future<SaveOutcome> saveAnswers(String attemptId, List<PendingAnswer> batch) async {
    _guard();
    saveBatches.add(batch);
    final hold = holdSaves;
    if (hold != null) await hold.future;
    _guard();
    final err = failNextSave;
    if (err != null) {
      failNextSave = null;
      throw err;
    }
    if (saveFailureQueue.isNotEmpty) {
      final next = saveFailureQueue.removeAt(0);
      if (next != null) throw next;
    }
    _expireIfDue();
    if (!open) {
      throw ApiException(409, status == 'expired' ? 'attempt_expired' : 'attempt_submitted', 'closed');
    }
    final out = <SavedAnswer>[];
    for (final a in batch) {
      final stored = answers[a.position];
      final storedSeq = stored?.seq ?? 0;
      if (a.seq > storedSeq) {
        answers[a.position] = (selected: a.selected, seq: a.seq);
        out.add(SavedAnswer(a.position, true, null, a.selected, a.seq));
      } else {
        final same = (stored?.selected ?? const <String>[]).join() == a.selected.join();
        out.add(SavedAnswer(
          a.position,
          false,
          a.seq < storedSeq ? 'stale' : (same ? 'duplicate' : 'conflict'),
          stored?.selected ?? const [],
          storedSeq,
        ));
      }
    }
    return SaveOutcome(out, now);
  }

  @override
  Future<Attempt> advanceSection(String attemptId) async {
    _guard();
    if (!lockedOrder) throw const ApiException(409, 'not_locked_order', 'free');
    currentSection++;
    return Attempt.fromJson(_attemptJson());
  }

  Map<String, dynamic> _resultJson() {
    var correct = 0, incorrect = 0, unanswered = 0;
    for (var p = 1; p <= total; p++) {
      if (withdrawn.contains(p)) continue;
      final s = answers[p]?.selected ?? const <String>[];
      if (s.isEmpty) {
        unanswered++;
      } else if (s.first == key[p]) {
        correct++;
      } else {
        incorrect++;
      }
    }
    final scorable = total - withdrawn.length;
    final marks = correct - 0.25 * incorrect;
    return {
      'attempt_id': id,
      'status': status,
      'finalised_by': finalisedBy ?? 'learner',
      'submitted_at': now.toIso8601String(),
      'result': {
        'marks_available': true,
        'rules_verified': true,
        'provisional': provisional,
        'provisional_reasons': provisional ? ['Withdrawn questions are left out of the marks until the rule is confirmed'] : <String>[],
        'withdrawn_policy': 'unscored',
        'overall': {
          'total_positions': total,
          'scorable_positions': scorable,
          'correct': correct,
          'incorrect': incorrect,
          'unanswered': unanswered,
          'withdrawn': withdrawn.length,
          'marks_obtained': marks,
          'max_marks': scorable.toDouble(),
          'percentage': scorable == 0 ? null : marks / scorable * 100,
        },
        'sections': <Object>[],
        'pass': passJson ?? {'available': false, 'reason': 'No pass criteria are configured for this exam', 'general': null, 'reserved': null},
        'positions': <Object>[],
      },
    };
  }

  @override
  Future<AttemptResult> submit(String attemptId) async {
    submitCalls++;
    _guard();
    _expireIfDue();
    if (open) {
      status = 'submitted';
      finalisedBy = 'learner';
    }
    return AttemptResult.fromJson(_resultJson());
  }

  @override
  Future<AttemptResult> result(String attemptId) async {
    _guard();
    _expireIfDue();
    if (open) throw const ApiException(409, 'attempt_in_progress', 'not yet');
    return AttemptResult.fromJson(_resultJson());
  }

  @override
  Future<AttemptReview> review(String attemptId) async {
    _guard();
    _expireIfDue();
    if (open) throw const ApiException(409, 'attempt_in_progress', 'not yet');
    return AttemptReview.fromJson({
      'attempt_id': id,
      'provisional': provisional,
      'provisional_reasons': <String>[],
      'questions': [
        for (var p = 1; p <= total; p++)
          {
            'position': p,
            'withdrawn': withdrawn.contains(p),
            'stem': withdrawn.contains(p) ? null : 'Question text $p',
            'options': withdrawn.contains(p)
                ? null
                : [
                    for (final o in ['a', 'b', 'c', 'd']) {'id': o, 'text': 'Option $o of $p'},
                  ],
            'selected_option_ids': answers[p]?.selected,
            'accepted_option_ids': withdrawn.contains(p) ? <String>[] : [key[p]!],
            'outcome': withdrawn.contains(p) ? 'withdrawn_unscored' : 'correct',
            'marks': 1,
            'explanation': withdrawn.contains(p) ? null : secret,
          },
      ],
    });
  }

  @override
  Future<AttemptSummaryPage> history({String? exam, String? cursor}) async {
    _guard();
    return AttemptSummaryPage([
      AttemptSummary(
        id: id,
        kind: AttemptKind.fixedPaper,
        mode: mode,
        status: AttemptStatus.parse(status),
        exam: slug,
        paperTitle: 'Fixture paper',
        startedAt: now,
        marksObtained: open ? null : 2.75,
        maxMarks: open ? null : 3,
        percentage: open ? null : 91.67,
        provisional: open ? null : provisional,
      ),
    ], null);
  }

  @override
  Future<List<ExamStats>> stats() async {
    _guard();
    return const [ExamStats(exam: MockExamSlugs.aibe, attempts: 2, withMarks: 2, averagePercentage: 70, bestPercentage: 91.67)];
  }
}

/// A monotonic clock a widget test moves by hand (the real stopwatch does not
/// follow the test's fake time).
class ManualMonotonic {
  Duration t = Duration.zero;

  ElapsedSource Function() get factory => () {
        final start = t;
        return () => t - start;
      };
}

PaperSummary samplePaper({
  String id = 'paper-1',
  String title = 'Fixture paper',
  int? durationSeconds,
  int? practiceTimerSeconds,
  String configStatus = 'unverified',
}) =>
    PaperSummary(
      id: id,
      code: 'fixture',
      revision: 1,
      title: title,
      edition: 'XVIII',
      year: 2023,
      setLabel: 'A',
      totalQuestions: 4,
      durationSeconds: durationSeconds,
      configStatus: configStatus,
      practiceTimerSeconds: practiceTimerSeconds,
    );
