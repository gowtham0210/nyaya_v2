import '../../../core/api/api_client.dart';
import '../domain/mock_exam_models.dart';
import 'mock_exam_api.dart';

/// DEBUG-ONLY DEMO DATA. Used only when the app is run in debug mode with
/// `--dart-define=MOCK_EXAMS_DEMO=true` (see [mockExamApiProvider]); a release
/// build never reaches this class. Everything here is invented sample content
/// held in memory: no server call is made and nothing is saved.
class DemoMockExamApi implements MockExamApi {
  static const label = 'DEMO';
  static const _total = 5;
  static const _key = {1: 'b', 2: 'c', 3: 'a', 4: 'd', 5: 'b'};
  static const _timedPaperId = 'demo-timed';

  String _paperId = 'demo-practice';
  String? _attemptId;
  AttemptMode _mode = AttemptMode.practice;
  DateTime _startedAt = DateTime.now();
  DateTime? _deadline;
  String _status = 'in_progress';
  final _answers = <int, ({List<String> selected, int seq})>{};
  final _finished = <AttemptSummary>[];

  bool get _open => _attemptId != null && _status == 'in_progress';

  void _expireIfDue() {
    if (_open && _deadline != null && !DateTime.now().isBefore(_deadline!)) _status = 'expired';
  }

  @override
  Future<bool> isAvailable(String slug) async => slug == MockExamSlugs.aibe;

  @override
  Future<PaperPage> papers(String slug, {String? cursor}) async {
    if (slug != MockExamSlugs.aibe) throw const ApiException(404, 'not_found', 'Exam not found');
    return const PaperPage([
      PaperSummary(
        id: 'demo-practice',
        code: 'demo-1',
        revision: 1,
        title: '[DEMO] Sample practice paper (not an official paper)',
        edition: null,
        year: null,
        setLabel: null,
        totalQuestions: _total,
        durationSeconds: null,
        configStatus: 'unverified',
      ),
      PaperSummary(
        id: _timedPaperId,
        code: 'demo-2',
        revision: 1,
        title: '[DEMO] Sample timed paper, 5 minutes (not an official format)',
        edition: null,
        year: null,
        setLabel: null,
        totalQuestions: _total,
        durationSeconds: 300,
        configStatus: 'official_confirmed',
      ),
    ], null);
  }

  @override
  Future<Attempt?> activeAttempt(String slug) async {
    _expireIfDue();
    return _open ? Attempt.fromJson(_attemptJson()) : null;
  }

  @override
  Future<Attempt> startAttempt(String slug, {required AttemptKind kind, String? paperId, required AttemptMode mode, bool practiceTimer = false}) async {
    _expireIfDue();
    if (_open) throw const ApiException(409, 'attempt_in_progress', 'You already have an unfinished attempt');
    _paperId = paperId ?? 'demo-practice';
    _attemptId = 'demo-attempt-${_finished.length + 1}';
    _mode = mode;
    _startedAt = DateTime.now();
    _deadline = mode == AttemptMode.timed || practiceTimer ? _startedAt.add(const Duration(minutes: 5)) : null;
    _status = 'in_progress';
    _answers.clear();
    return Attempt.fromJson(_attemptJson());
  }

  @override
  Future<Attempt> attempt(String id) async {
    if (id != _attemptId) throw const ApiException(404, 'not_found', 'Attempt not found');
    _expireIfDue();
    return Attempt.fromJson(_attemptJson());
  }

  @override
  Future<SaveOutcome> saveAnswers(String attemptId, List<PendingAnswer> batch) async {
    _expireIfDue();
    if (!_open) throw ApiException(409, _status == 'expired' ? 'attempt_expired' : 'attempt_submitted', 'closed');
    final out = <SavedAnswer>[];
    for (final a in batch) {
      final stored = _answers[a.position];
      if (a.seq > (stored?.seq ?? 0)) {
        _answers[a.position] = (selected: a.selected, seq: a.seq);
        out.add(SavedAnswer(a.position, true, null, a.selected, a.seq));
      } else {
        out.add(SavedAnswer(a.position, false, 'stale', stored?.selected ?? const [], stored?.seq ?? 0));
      }
    }
    return SaveOutcome(out, DateTime.now());
  }

  @override
  Future<Attempt> advanceSection(String attemptId) async => Attempt.fromJson(_attemptJson());

  @override
  Future<AttemptResult> submit(String attemptId) async {
    _expireIfDue();
    if (_open) {
      _status = 'submitted';
      _record();
    }
    return AttemptResult.fromJson(_resultJson());
  }

  @override
  Future<AttemptResult> result(String attemptId) async {
    _expireIfDue();
    if (_open) throw const ApiException(409, 'attempt_in_progress', 'not yet');
    return AttemptResult.fromJson(_resultJson());
  }

  @override
  Future<AttemptReview> review(String attemptId) async {
    _expireIfDue();
    if (_open) throw const ApiException(409, 'attempt_in_progress', 'not yet');
    return AttemptReview.fromJson({
      'attempt_id': _attemptId,
      'provisional': true,
      'provisional_reasons': ['DEMO data: sample questions, not an official paper'],
      'questions': [
        for (var p = 1; p <= _total; p++)
          {
            'position': p,
            'withdrawn': false,
            'stem': _stem(p),
            'options': _options(p),
            'selected_option_ids': _answers[p]?.selected,
            'accepted_option_ids': [_key[p]!],
            'outcome': _outcome(p),
            'marks': _outcome(p) == 'correct' ? 1 : (_outcome(p) == 'incorrect' ? -0.25 : 0),
            'explanation': '[DEMO] Sample explanation for question $p. Real explanations are reviewed before they are shown.',
          },
      ],
    });
  }

  @override
  Future<AttemptSummaryPage> history({String? exam, String? cursor}) async => AttemptSummaryPage(_finished.reversed.toList(), null);

  @override
  Future<List<ExamStats>> stats() async {
    final withMarks = _finished.where((a) => a.percentage != null).toList();
    if (withMarks.isEmpty) return const [];
    final pcts = [for (final a in withMarks) a.percentage!];
    return [
      ExamStats(
        exam: MockExamSlugs.aibe,
        attempts: _finished.length,
        withMarks: withMarks.length,
        averagePercentage: pcts.reduce((a, b) => a + b) / pcts.length,
        bestPercentage: pcts.reduce((a, b) => a > b ? a : b),
      ),
    ];
  }

  // ------------------------------------------------------------ demo content

  String _stem(int p) => '[DEMO] Sample question $p. This is invented practice text, not from any exam paper.';

  List<Map<String, String>> _options(int p) => [
        for (final o in ['a', 'b', 'c', 'd']) {'id': o, 'text': 'Sample option ${o.toUpperCase()} for question $p'},
      ];

  String _outcome(int p) {
    final s = _answers[p]?.selected ?? const <String>[];
    if (s.isEmpty) return 'unanswered';
    return s.first == _key[p] ? 'correct' : 'incorrect';
  }

  ({int correct, int incorrect, int unanswered, double marks}) _score() {
    var c = 0, i = 0, u = 0;
    for (var p = 1; p <= _total; p++) {
      switch (_outcome(p)) {
        case 'correct':
          c++;
        case 'incorrect':
          i++;
        default:
          u++;
      }
    }
    return (correct: c, incorrect: i, unanswered: u, marks: c - 0.25 * i);
  }

  void _record() {
    final s = _score();
    _finished.add(AttemptSummary(
      id: _attemptId!,
      kind: AttemptKind.fixedPaper,
      mode: _mode,
      status: AttemptStatus.parse(_status),
      exam: MockExamSlugs.aibe,
      paperTitle: _paperId == _timedPaperId ? '[DEMO] Sample timed paper' : '[DEMO] Sample practice paper',
      startedAt: _startedAt,
      marksObtained: s.marks,
      maxMarks: _total.toDouble(),
      percentage: s.marks / _total * 100,
      provisional: true,
    ));
  }

  Map<String, dynamic> _attemptJson() {
    final now = DateTime.now();
    final timed = _paperId == _timedPaperId;
    return {
      'id': _attemptId,
      'kind': 'fixed_paper',
      'mode': _mode.api,
      'status': _status,
      'exam': MockExamSlugs.aibe,
      'paper': {
        'id': _paperId,
        'code': timed ? 'demo-2' : 'demo-1',
        'title': timed ? '[DEMO] Sample timed paper' : '[DEMO] Sample practice paper',
        'revision': 1,
      },
      'language': 'en',
      'started_at': _startedAt.toUtc().toIso8601String(),
      'deadline_at': _deadline?.toUtc().toIso8601String(),
      'server_now': now.toUtc().toIso8601String(),
      'remaining_seconds': _deadline?.difference(now).inSeconds,
      'section_navigation': 'free',
      'current_section_position': null,
      'sections': <Object>[],
      'total_questions': _total,
      'answered_count': _answers.values.where((a) => a.selected.isNotEmpty).length,
      'submitted_at': _open ? null : now.toUtc().toIso8601String(),
      'result_available': !_open,
      'questions': [
        for (var p = 1; p <= _total; p++)
          {
            'position': p,
            'section_code': null,
            'original_ref': 'DEMO-$p',
            'withdrawn': false,
            'question_version_id': 'demo-v$p',
            'stem': _stem(p),
            'options': _options(p),
            'selected_option_ids': _answers[p]?.selected,
            'answer_seq': _answers[p]?.seq ?? 0,
          },
      ],
    };
  }

  Map<String, dynamic> _resultJson() {
    final s = _score();
    return {
      'attempt_id': _attemptId,
      'status': _status,
      'finalised_by': _status == 'expired' ? 'expiry' : 'learner',
      'submitted_at': DateTime.now().toUtc().toIso8601String(),
      'result': {
        'marks_available': true,
        'rules_verified': false,
        'provisional': true,
        'provisional_reasons': ['DEMO data: sample questions, not an official paper'],
        'withdrawn_policy': 'unscored',
        'overall': {
          'total_positions': _total,
          'scorable_positions': _total,
          'correct': s.correct,
          'incorrect': s.incorrect,
          'unanswered': s.unanswered,
          'withdrawn': 0,
          'marks_obtained': s.marks,
          'max_marks': _total.toDouble(),
          'percentage': s.marks / _total * 100,
        },
        'sections': <Object>[],
        'pass': {'available': false, 'reason': 'DEMO data: no pass criteria', 'general': null, 'reserved': null},
        'positions': <Object>[],
      },
    };
  }
}
