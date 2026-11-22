import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';
import '../../../core/storage/local_store.dart';
import '../../auth/application/auth_controller.dart';
import '../data/mock_exam_api.dart';
import '../data/mock_exam_cache.dart';
import '../domain/mock_exam_models.dart';
import 'server_clock.dart';

/// How eagerly answers are sent. Tests make it instant.
@immutable
class AutosaveTuning {
  const AutosaveTuning({
    this.debounce = const Duration(milliseconds: 400),
    this.retryDelays = const [
      Duration(seconds: 2),
      Duration(seconds: 4),
      Duration(seconds: 8),
      Duration(seconds: 16),
      Duration(seconds: 30),
    ],
    this.expiryRecheck = const Duration(seconds: 2),
    this.endedOfflineRetryDelays = const [
      Duration(seconds: 5),
      Duration(seconds: 15),
      Duration(seconds: 30),
      Duration(seconds: 60),
    ],
    this.maxBatch = 200,
  });

  final Duration debounce;
  final List<Duration> retryDelays;

  /// When the server still says "open" at the local deadline (a second or so
  /// of drift), how long to wait before asking again.
  final Duration expiryRecheck;

  /// Waits between attempts to reach the server after the deadline passed
  /// offline (the last one repeats). Gentler than answer retries: there is
  /// nothing to lose by waiting, only the result to fetch.
  final List<Duration> endedOfflineRetryDelays;

  /// The most answers sent in one request (the API's limit).
  final int maxBatch;
}

final autosaveTuningProvider = Provider<AutosaveTuning>((ref) => const AutosaveTuning());

enum AttemptPhase { loading, active, submitting, finished, failed }

/// [offline]: no connection. [serverIssue]: the server answered with a
/// temporary error (5xx, a timeout or rate limit). Either way the answers are
/// kept and sent again automatically.
enum SaveStatus { saved, saving, offline, serverIssue }

enum AttemptFailure { network, signedOut, notFound, other }

typedef AttemptKey = ({String slug, String id});

const _keep = Object();

@immutable
class AttemptState {
  const AttemptState({
    this.phase = AttemptPhase.loading,
    this.attempt,
    this.pending = const {},
    this.saveStatus = SaveStatus.saved,
    this.failure,
    this.notice,
    this.submitFailed = false,
    this.estimatedClock = false,
    this.endedOffline = false,
  });

  final AttemptPhase phase;
  final Attempt? attempt;

  /// Answers not yet confirmed by the server, by position.
  final Map<int, PendingAnswer> pending;
  final SaveStatus saveStatus;
  final AttemptFailure? failure;

  /// An error code to tell the learner about once (e.g. section_locked).
  final String? notice;

  /// The last submit could not reach the server; the answers are kept.
  final bool submitFailed;

  /// Opened offline: the time left is an estimate until the server is reached.
  final bool estimatedClock;

  /// The deadline has passed locally but the server could not be asked.
  final bool endedOffline;

  AttemptState copyWith({
    AttemptPhase? phase,
    Object? attempt = _keep,
    Map<int, PendingAnswer>? pending,
    SaveStatus? saveStatus,
    Object? failure = _keep,
    Object? notice = _keep,
    bool? submitFailed,
    bool? estimatedClock,
    bool? endedOffline,
  }) =>
      AttemptState(
        phase: phase ?? this.phase,
        attempt: identical(attempt, _keep) ? this.attempt : attempt as Attempt?,
        pending: pending ?? this.pending,
        saveStatus: saveStatus ?? this.saveStatus,
        failure: identical(failure, _keep) ? this.failure : failure as AttemptFailure?,
        notice: identical(notice, _keep) ? this.notice : notice as String?,
        submitFailed: submitFailed ?? this.submitFailed,
        estimatedClock: estimatedClock ?? this.estimatedClock,
        endedOffline: endedOffline ?? this.endedOffline,
      );
}

final attemptControllerProvider =
    NotifierProvider.autoDispose.family<AttemptController, AttemptState, AttemptKey>(AttemptController.new);

/// Runs one unfinished attempt: it keeps the server's deadline, sends the
/// learner's answers in the background and survives a closed app or a lost
/// connection. The server owns the deadline, the questions and the scoring;
/// this only mirrors them.
class AttemptController extends Notifier<AttemptState> {
  AttemptController(this.key);

  final AttemptKey key;

  ServerClock? _clock;
  Timer? _debounce;
  Timer? _retry;
  Timer? _recheck;
  Timer? _deadlineRetry;
  int _retries = 0;
  int _deadlineRetries = 0;
  bool _disposed = false;
  bool _settling = false;

  /// The server asked us to wait (Retry-After): nothing is sent until the
  /// retry timer fires, however many answers are chosen meanwhile.
  bool _holding = false;
  Future<void>? _inflight;

  MockExamApi get _api => ref.read(mockExamApiProvider);
  MockExamCache get _cache => ref.read(mockExamCacheProvider);
  AutosaveTuning get _tuning => ref.read(autosaveTuningProvider);
  String? get _userId => ref.read(authProvider)?.id;

  @override
  AttemptState build() {
    ref.onDispose(() {
      _disposed = true;
      _debounce?.cancel();
      _retry?.cancel();
      _recheck?.cancel();
      _deadlineRetry?.cancel();
    });
    Future.microtask(load);
    return const AttemptState();
  }

  void _set(AttemptState s) {
    if (!_disposed) state = s;
  }

  /// A failure that says nothing about the answers themselves: no connection,
  /// a server or gateway error, a timeout or rate limit. Keep what is unsent
  /// and try again later.
  static bool _temporary(ApiException e) => e.isNetwork || e.status >= 500 || e.status == 408 || e.status == 429;

  /// The server looked at the request and refused it: invalid, or not allowed now.
  static bool _refused(ApiException e) => e.status == 400 || e.status == 409 || e.status == 422;

  /// What the learner is told while answers wait: no connection, or a server problem.
  static SaveStatus _waitingFor(ApiException e) => e.isNetwork ? SaveStatus.offline : SaveStatus.serverIssue;

  static bool _isWaiting(SaveStatus s) => s == SaveStatus.offline || s == SaveStatus.serverIssue;

  /// Time left, or null for an attempt with no deadline.
  Duration? remaining() {
    final a = state.attempt;
    final clock = _clock;
    if (a == null || a.deadlineAt == null || clock == null) return null;
    return clock.remaining(a.deadlineAt!);
  }

  // ---------------------------------------------------------------- loading

  Future<void> load() async {
    final userId = _userId;
    if (userId == null) {
      _set(state.copyWith(phase: AttemptPhase.failed, failure: AttemptFailure.signedOut));
      return;
    }
    try {
      _adopt(await _api.attempt(key.id), userId);
    } on ApiException catch (e) {
      if (_temporary(e)) {
        if (state.attempt != null && _clock != null && state.phase != AttemptPhase.finished) {
          // Still running: keep the screen, the answers and the monotonic
          // clock exactly as they are. The next contact corrects the time.
          _set(state.copyWith(saveStatus: _waitingFor(e)));
          _scheduleRetry(after: e.retryAfter);
        } else if (!_loadFromCache(userId)) {
          // A genuine restart: only the cache (and a time estimate) is left.
          _set(state.copyWith(phase: AttemptPhase.failed, failure: AttemptFailure.network));
        }
      } else if (e.status == 401) {
        _set(state.copyWith(phase: AttemptPhase.failed, failure: AttemptFailure.signedOut));
      } else if (e.status == 404) {
        await _cache.remove(userId, key.slug);
        _set(state.copyWith(phase: AttemptPhase.failed, failure: AttemptFailure.notFound));
      } else {
        _set(state.copyWith(phase: AttemptPhase.failed, failure: AttemptFailure.other));
      }
    }
  }

  /// Takes the server's view of the attempt, keeping answers it has not seen yet.
  void _adopt(Attempt fresh, String userId) {
    final clock = _clock;
    if (clock == null) {
      _clock = ServerClock(fresh.serverNow, ref.read(elapsedSourceFactoryProvider));
    } else {
      clock.resync(fresh.serverNow);
    }
    _deadlineRetry?.cancel();
    _deadlineRetries = 0;
    if (!fresh.open) {
      _cache.remove(userId, key.slug);
      _set(AttemptState(phase: AttemptPhase.finished, attempt: fresh));
      return;
    }
    // Answers waiting to be sent survive a reload: in memory, or from the cache.
    final waiting = <int, PendingAnswer>{...state.pending};
    final cached = _cache.read(userId, key.slug);
    if (cached != null && cached.attempt.id == fresh.id) {
      for (final p in cached.pending) {
        final held = waiting[p.position];
        if (held == null || held.seq < p.seq) waiting[p.position] = p;
      }
    }
    final bySeq = {for (final q in fresh.questions) q.position: q};
    waiting.removeWhere((pos, p) => p.seq <= (bySeq[pos]?.answerSeq ?? 0));
    final questions = [
      for (final q in fresh.questions)
        waiting[q.position] == null ? q : q.withAnswer(waiting[q.position]!.selected, waiting[q.position]!.seq),
    ];
    _set(AttemptState(
      phase: AttemptPhase.active,
      attempt: fresh.copyWith(questions: questions),
      pending: waiting,
      saveStatus: waiting.isEmpty ? SaveStatus.saved : SaveStatus.saving,
    ));
    _persist();
    if (waiting.isNotEmpty) _flush();
  }

  bool _loadFromCache(String userId) {
    final cached = _cache.read(userId, key.slug);
    if (cached == null || cached.attempt.id != key.id || !cached.attempt.open) return false;
    // Without the server, the time since the last contact is the gap on the
    // device's clock (never negative). It is only an estimate.
    var gap = ref.read(clockProvider)().toUtc().difference(cached.deviceAt);
    if (gap.isNegative) gap = Duration.zero;
    _clock = ServerClock(cached.serverNow.add(gap), ref.read(elapsedSourceFactoryProvider));
    _set(AttemptState(
      phase: AttemptPhase.active,
      attempt: cached.attempt,
      pending: {for (final p in cached.pending) p.position: p},
      saveStatus: SaveStatus.offline,
      estimatedClock: true,
    ));
    _scheduleRetry();
    return true;
  }

  void _persist() {
    final userId = _userId, a = state.attempt;
    final clock = _clock;
    if (userId == null || a == null || clock == null || !a.open) return;
    _cache.write(
      userId,
      key.slug,
      CachedAttempt(
        attempt: a,
        pending: state.pending.values.toList(),
        serverNow: clock.now(),
        deviceAt: ref.read(clockProvider)().toUtc(),
      ),
    );
  }

  // ---------------------------------------------------------------- answering

  /// The section answers may be saved to, for a locked-order exam; null otherwise.
  String? _openSectionCode(Attempt a) {
    if (!a.lockedOrder) return null;
    for (final s in a.sections) {
      if (s.position == a.currentSectionPosition) return s.code;
    }
    return null;
  }

  bool canAnswer(AttemptQuestion q) {
    final a = state.attempt;
    if (a == null || state.phase != AttemptPhase.active || q.withdrawn) return false;
    final code = _openSectionCode(a);
    return code == null || q.sectionCode == code;
  }

  /// Chooses [optionId] for [position] (choosing it again clears the answer).
  void select(int position, String optionId) {
    final a = state.attempt;
    if (a == null) return;
    final i = a.questions.indexWhere((q) => q.position == position);
    if (i < 0 || !canAnswer(a.questions[i])) return;
    if (remaining() == Duration.zero) {
      if (!state.endedOffline) onDeadlineReached();
      return;
    }
    final q = a.questions[i];
    final next = q.selected.contains(optionId) ? <String>[] : [optionId];
    final seq = (state.pending[position]?.seq ?? q.answerSeq) + 1;
    final questions = [...a.questions]..[i] = q.withAnswer(next, seq);
    _set(state.copyWith(
      attempt: a.copyWith(questions: questions),
      pending: {...state.pending, position: PendingAnswer(position, next, seq)},
      saveStatus: _isWaiting(state.saveStatus) ? state.saveStatus : SaveStatus.saving,
      notice: null,
    ));
    _persist();
    _debounce?.cancel();
    _debounce = Timer(_tuning.debounce, _flush);
  }

  Future<void> _flush() {
    // Told to wait: leave everything queued; the retry timer sends it.
    if (_holding) return Future.value();
    return _inflight ??= _doFlush().whenComplete(() => _inflight = null);
  }

  Future<void> _doFlush() async {
    _retry?.cancel();
    while (state.pending.isNotEmpty && !_disposed && state.attempt != null) {
      // In position order, at most one request's worth at a time; the rest
      // stays queued (and is sent next) whatever happens to this batch.
      final all = state.pending.values.toList()..sort((a, b) => a.position.compareTo(b.position));
      final batch = all.take(_tuning.maxBatch).toList();
      if (state.saveStatus != SaveStatus.saving) _set(state.copyWith(saveStatus: SaveStatus.saving));
      try {
        final outcome = await _api.saveAnswers(key.id, batch);
        _retries = 0;
        _clock?.resync(outcome.serverNow);
        _reconcile(outcome.results);
        _set(state.copyWith(estimatedClock: false));
        _persist();
      } on ApiException catch (e) {
        if (_temporary(e)) {
          // Nothing was refused: everything stays queued and is retried,
          // after the server's Retry-After when it gave one.
          _set(state.copyWith(saveStatus: _waitingFor(e)));
          _persist();
          _scheduleRetry(after: e.retryAfter);
          return;
        }
        if (e.code == 'attempt_expired' || e.code == 'attempt_submitted' || e.status == 404) {
          // The attempt is over on the server (or is not this learner's): show how it ended.
          await load();
          return;
        }
        if (e.status == 401) {
          _set(state.copyWith(phase: AttemptPhase.failed, failure: AttemptFailure.signedOut));
          return;
        }
        if (!_refused(e)) {
          // An error we do not understand is not proof the answers are bad: keep them.
          _set(state.copyWith(saveStatus: _waitingFor(e)));
          _persist();
          _scheduleRetry(after: e.retryAfter);
          return;
        }
        // The server refused this batch (a locked section, an invalid answer).
        // Drop only the answers it saw; one chosen since (a higher counter), or
        // waiting in a later batch, stays queued.
        final sent = {for (final p in batch) p.position: p.seq};
        final kept = {...state.pending}..removeWhere((pos, p) => sent[pos] != null && p.seq <= sent[pos]!);
        _set(state.copyWith(pending: kept));
        _persist(); // or the cached copy would bring the refused answers back
        final code = e.code;
        await load();
        _set(state.copyWith(notice: code));
        if (state.phase != AttemptPhase.active) return;
        continue; // send whatever is still waiting
      }
    }
    if (!_disposed && state.pending.isEmpty && !_isWaiting(state.saveStatus)) {
      _set(state.copyWith(saveStatus: SaveStatus.saved));
    }
  }

  void _reconcile(List<SavedAnswer> results) {
    final a = state.attempt;
    if (a == null) return;
    final pending = {...state.pending};
    final questions = [...a.questions];
    for (final r in results) {
      final cur = pending[r.position];
      if (cur == null) continue;
      if (r.applied) {
        // The server holds what was sent; a newer local change stays queued.
        if (cur.seq <= r.seq) pending.remove(r.position);
      } else if (r.seq >= cur.seq) {
        // Stale, duplicate or conflicting: the server's answer stands.
        pending.remove(r.position);
        final i = questions.indexWhere((q) => q.position == r.position);
        if (i >= 0) questions[i] = questions[i].withAnswer(r.selected, r.seq);
      }
    }
    _set(state.copyWith(attempt: a.copyWith(questions: questions), pending: pending));
  }

  /// One retry timer at a time. With [after] (a valid Retry-After) it waits
  /// exactly that long and nothing is sent before; otherwise the usual backoff.
  void _scheduleRetry({Duration? after}) {
    _retry?.cancel();
    _holding = false;
    // A request that was still out when the screen closed must not leave a timer behind.
    if (_disposed) return;
    // After the deadline passed offline the gentler deadline retry does the
    // asking, so the two never poll side by side.
    if (state.endedOffline) return;
    final Duration delay;
    if (after != null) {
      delay = after;
      _holding = true;
    } else {
      final delays = _tuning.retryDelays;
      delay = delays[_retries.clamp(0, delays.length - 1)];
      _retries++;
    }
    _retry = Timer(delay, () async {
      _holding = false;
      if (_disposed || state.phase == AttemptPhase.finished) return;
      if (state.pending.isNotEmpty) {
        await _flush();
      } else {
        await load(); // nothing to send: just see whether the server is back
      }
    });
  }

  /// Back in the foreground: the timer kept running on the server, so ask it.
  Future<void> onResumed() async {
    if (state.phase == AttemptPhase.active) await load();
  }

  // ---------------------------------------------------------------- sections

  Future<void> advanceSection() async {
    final a = state.attempt;
    if (a == null || !a.lockedOrder || state.phase != AttemptPhase.active) return;
    await _flush();
    if (state.pending.isNotEmpty) return; // still offline: not now
    try {
      final fresh = await _api.advanceSection(key.id);
      final userId = _userId;
      if (userId != null) _adopt(fresh, userId);
    } on ApiException catch (e) {
      if (e.isNetwork) {
        _set(state.copyWith(saveStatus: _waitingFor(e), notice: e.isNetwork ? 'network' : null));
      } else if (e.code == 'attempt_expired' || e.code == 'attempt_submitted') {
        await load();
      } else {
        _set(state.copyWith(notice: e.code));
      }
    }
  }

  // ---------------------------------------------------------------- finishing

  Future<void> submit() async {
    if (state.phase != AttemptPhase.active) return;
    _debounce?.cancel();
    _set(state.copyWith(phase: AttemptPhase.submitting, submitFailed: false));
    await _flush();
    if (state.pending.isNotEmpty || state.phase == AttemptPhase.finished || state.phase == AttemptPhase.failed) {
      if (state.phase == AttemptPhase.submitting) {
        _set(state.copyWith(phase: AttemptPhase.active, submitFailed: true));
      }
      return;
    }
    try {
      await _api.submit(key.id);
      await _finish();
    } on ApiException catch (e) {
      if (e.code == 'attempt_expired' || e.code == 'attempt_submitted') {
        await _finish();
      } else {
        _set(state.copyWith(phase: AttemptPhase.active, submitFailed: true, notice: e.isNetwork ? null : e.code));
      }
    }
  }

  Future<void> _finish() async {
    final userId = _userId;
    if (userId != null) await _cache.remove(userId, key.slug);
    final a = state.attempt;
    _set(AttemptState(phase: AttemptPhase.finished, attempt: a));
  }

  void _scheduleDeadlineRetry() {
    _deadlineRetry?.cancel();
    if (_disposed) return;
    final delays = _tuning.endedOfflineRetryDelays;
    final delay = delays[_deadlineRetries.clamp(0, delays.length - 1)];
    _deadlineRetries++;
    _deadlineRetry = Timer(delay, () {
      if (_disposed || state.phase == AttemptPhase.finished) return;
      onDeadlineReached();
    });
  }

  /// The local clock reached the deadline. The server decides: it ends the
  /// attempt itself, so ask it, and never rely on this device's opinion.
  Future<void> onDeadlineReached() async {
    if (_settling || state.phase == AttemptPhase.finished) return;
    _settling = true;
    try {
      final userId = _userId;
      if (userId == null) return;
      final fresh = await _api.attempt(key.id);
      if (fresh.open) {
        // A moment of drift: the server has not ended it yet.
        _clock?.resync(fresh.serverNow);
        _recheck?.cancel();
        _recheck = Timer(_tuning.expiryRecheck, () {
          _settling = false;
          if (!_disposed) onDeadlineReached();
        });
        return;
      }
      _adopt(fresh, userId);
    } on ApiException catch (e) {
      if (_temporary(e)) {
        // The server is the only one who can end the attempt: keep it open
        // here (showing "time is up, reconnect"), and ask again later.
        _set(state.copyWith(endedOffline: true, saveStatus: _waitingFor(e)));
        _scheduleDeadlineRetry();
      } else {
        await load();
      }
    } finally {
      if (_recheck?.isActive != true) _settling = false;
    }
  }
}
