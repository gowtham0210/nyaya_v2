import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nyaya/core/api/api_client.dart';
import 'package:nyaya/core/api/token_store.dart';
import 'package:nyaya/core/storage/local_store.dart';
import 'package:nyaya/features/mock_exams/application/attempt_controller.dart';
import 'package:nyaya/features/mock_exams/application/server_clock.dart';
import 'package:nyaya/features/mock_exams/data/mock_exam_api.dart';
import 'package:nyaya/features/mock_exams/data/mock_exam_cache.dart';
import 'package:nyaya/features/mock_exams/domain/mock_exam_models.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/fake_mock_exam_api.dart';

/// A monotonic clock the test moves by hand.
class Mono {
  Duration t = Duration.zero;
  ElapsedSource Function() get factory => () {
        final start = t;
        return () => t - start;
      };
}

const _key = (slug: 'aibe', id: 'attempt-1');

/// The controller that runs an unfinished attempt: the server's deadline,
/// autosave with counters, resume, offline use and submission.
void main() {
  late FakeMockExamApi api;
  late SharedPreferences prefs;
  late Mono mono;
  late DateTime wall;

  setUp(() async {
    api = FakeMockExamApi()..begin();
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    mono = Mono();
    wall = DateTime.utc(2026, 11, 20, 10);
  });

  ProviderContainer container({String userId = 'user-1'}) {
    final tokens = MemoryTokenStore(StoredSession(
      accessToken: 'access',
      refreshToken: 'refresh',
      user: {'id': userId, 'email': '$userId@test.local', 'display_name': 'Ravi', 'roles': ['learner']},
    ));
    final c = ProviderContainer(overrides: [
      sharedPreferencesProvider.overrideWithValue(prefs),
      tokenStoreProvider.overrideWithValue(tokens),
      mockExamApiProvider.overrideWithValue(api),
      elapsedSourceFactoryProvider.overrideWithValue(mono.factory),
      clockProvider.overrideWithValue(() => wall),
      autosaveTuningProvider.overrideWithValue(const AutosaveTuning(
        debounce: Duration(milliseconds: 5),
        retryDelays: [Duration(milliseconds: 20)],
        expiryRecheck: Duration(milliseconds: 20),
        endedOfflineRetryDelays: [Duration(milliseconds: 30), Duration(milliseconds: 60)],
      )),
    ]);
    addTearDown(c.dispose);
    return c;
  }

  /// Keeps the (auto-dispose) controller alive and returns reads of it.
  ({AttemptState Function() state, AttemptController ctrl}) open(ProviderContainer c) {
    final sub = c.listen(attemptControllerProvider(_key), (_, _) {});
    addTearDown(sub.close);
    return (state: () => c.read(attemptControllerProvider(_key)), ctrl: c.read(attemptControllerProvider(_key).notifier));
  }

  Future<void> until(bool Function() ok, {String? why}) async {
    for (var i = 0; i < 400; i++) {
      if (ok()) return;
      await Future<void>.delayed(const Duration(milliseconds: 5));
    }
    fail('Timed out waiting: ${why ?? 'condition'}');
  }

  Future<void> loaded(({AttemptState Function() state, AttemptController ctrl}) h) =>
      until(() => h.state().phase != AttemptPhase.loading, why: 'the attempt to load');

  group('loading', () {
    test('takes the questions, answers and deadline from the server', () async {
      api.begin(mode: AttemptMode.timed, limit: const Duration(minutes: 90));
      api.forceAnswer(1, ['b'], 3);
      final h = open(container());
      await loaded(h);
      final a = h.state().attempt!;
      expect(h.state().phase, AttemptPhase.active);
      expect(a.questions, hasLength(4));
      expect(a.questions.first.selected, ['b']);
      expect(a.questions.first.answerSeq, 3);
      expect(a.questions[3].withdrawn, isTrue);
      expect(h.ctrl.remaining(), const Duration(minutes: 90));
    });

    test('reports a missing attempt, and a lost connection with nothing cached', () async {
      final missing = open(container());
      api.id = 'another';
      await loaded(missing);
      expect(missing.state().failure, AttemptFailure.notFound);

      api.id = 'attempt-1';
      api.offline = true;
      final c2 = container(userId: 'someone-else');
      final h = open(c2);
      await loaded(h);
      expect(h.state().failure, AttemptFailure.network);
    });

    test('finishes at once when the server says the attempt is over', () async {
      api.status = 'submitted';
      final h = open(container());
      await loaded(h);
      expect(h.state().phase, AttemptPhase.finished);
    });
  });

  group('the timer', () {
    test('runs on the server deadline and a monotonic clock, not the phone clock', () async {
      api.begin(mode: AttemptMode.timed, limit: const Duration(minutes: 60));
      final h = open(container());
      await loaded(h);
      expect(h.ctrl.remaining(), const Duration(minutes: 60));
      mono.t += const Duration(minutes: 10);
      expect(h.ctrl.remaining(), const Duration(minutes: 50));
      // The phone's clock is wound forward ten hours: nothing changes.
      wall = wall.add(const Duration(hours: 10));
      expect(h.ctrl.remaining(), const Duration(minutes: 50));
      // Each contact with the server takes its time as the new base.
      api.now = api.now.add(const Duration(minutes: 12));
      mono.t += const Duration(minutes: 2);
      await h.ctrl.onResumed();
      expect(h.ctrl.remaining(), const Duration(minutes: 48));
    });

    test('has no timer for a practice attempt', () async {
      final h = open(container());
      await loaded(h);
      expect(h.ctrl.remaining(), isNull);
    });

    test('asks the server when the deadline passes, and shows how it ended', () async {
      api.begin(mode: AttemptMode.timed, limit: const Duration(minutes: 5));
      final h = open(container());
      await loaded(h);
      h.ctrl.select(1, 'b');
      await until(() => h.state().pending.isEmpty, why: 'the save');
      api.now = api.now.add(const Duration(minutes: 6));
      mono.t += const Duration(minutes: 6);
      expect(h.ctrl.remaining(), Duration.zero);
      await h.ctrl.onDeadlineReached();
      expect(h.state().phase, AttemptPhase.finished);
      expect(api.status, 'expired');
    });

    test('waits and asks again when the server has not ended it yet (a moment of drift)', () async {
      api.begin(mode: AttemptMode.timed, limit: const Duration(minutes: 5));
      final h = open(container());
      await loaded(h);
      mono.t += const Duration(minutes: 5, seconds: 1); // the device is a second ahead
      expect(h.ctrl.remaining(), Duration.zero);
      await h.ctrl.onDeadlineReached();
      expect(h.state().phase, AttemptPhase.active);
      api.now = api.now.add(const Duration(minutes: 5, seconds: 2));
      await until(() => h.state().phase == AttemptPhase.finished, why: 'the follow-up check');
    });

    test('does not send an answer chosen after the deadline', () async {
      api.begin(mode: AttemptMode.timed, limit: const Duration(minutes: 5));
      final h = open(container());
      await loaded(h);
      mono.t += const Duration(minutes: 6);
      api.now = api.now.add(const Duration(minutes: 6));
      h.ctrl.select(1, 'b');
      await until(() => h.state().phase == AttemptPhase.finished, why: 'the attempt to end');
      expect(api.saveBatches, isEmpty);
      expect(api.answers, isEmpty);
    });

    test('says so when the deadline passes with no way to ask the server', () async {
      api.begin(mode: AttemptMode.timed, limit: const Duration(minutes: 5));
      final h = open(container());
      await loaded(h);
      api.offline = true;
      mono.t += const Duration(minutes: 6);
      await h.ctrl.onDeadlineReached();
      expect(h.state().endedOffline, isTrue);
      expect(h.state().phase, AttemptPhase.active);
    });
  });

  group('autosave', () {
    test('sends a chosen answer and clears it from the queue', () async {
      final h = open(container());
      await loaded(h);
      h.ctrl.select(1, 'b');
      expect(h.state().pending, hasLength(1));
      expect(h.state().attempt!.questions.first.selected, ['b']);
      await until(() => h.state().pending.isEmpty && h.state().saveStatus == SaveStatus.saved, why: 'the save');
      expect(api.answers[1]!.selected, ['b']);
      expect(api.answers[1]!.seq, 1);
    });

    test('sends several quick changes together, with rising counters', () async {
      final h = open(container());
      await loaded(h);
      h.ctrl.select(1, 'a');
      h.ctrl.select(2, 'c');
      h.ctrl.select(1, 'b');
      await until(() => h.state().pending.isEmpty, why: 'the save');
      expect(api.saveBatches, hasLength(1));
      expect(api.answers[1]!.selected, ['b']);
      expect(api.answers[1]!.seq, 2);
      expect(api.answers[2]!.selected, ['c']);
    });

    test('choosing the same option again clears the answer', () async {
      final h = open(container());
      await loaded(h);
      h.ctrl.select(1, 'a');
      await until(() => h.state().pending.isEmpty);
      h.ctrl.select(1, 'a');
      await until(() => h.state().pending.isEmpty);
      expect(api.answers[1]!.selected, isEmpty);
      expect(api.answers[1]!.seq, 2);
      expect(h.state().attempt!.answeredCount, 0);
    });

    test('a late reply never overwrites a newer choice', () async {
      final h = open(container());
      await loaded(h);
      api.holdSaves = Completer<void>();
      h.ctrl.select(1, 'a');
      await until(() => api.saveBatches.isNotEmpty, why: 'the first save to start');
      h.ctrl.select(1, 'd'); // changed while the first request is still out
      api.releaseSaves();
      await until(() => h.state().pending.isEmpty && h.state().saveStatus == SaveStatus.saved, why: 'both saves');
      expect(h.state().attempt!.questions.first.selected, ['d']);
      expect(api.answers[1]!.selected, ['d']);
      expect(api.answers[1]!.seq, 2);
    });

    test('takes the server’s answer when it holds a newer one (another device)', () async {
      final h = open(container());
      await loaded(h);
      api.forceAnswer(2, ['d'], 9);
      h.ctrl.select(2, 'a'); // counter 1 locally: stale on the server
      await until(() => h.state().pending.isEmpty, why: 'the save');
      expect(h.state().attempt!.questions[1].selected, ['d']);
      expect(h.state().attempt!.questions[1].answerSeq, 9);
      expect(api.answers[2]!.selected, ['d']);
    });

    test('never answers a withdrawn question', () async {
      final h = open(container());
      await loaded(h);
      expect(h.ctrl.canAnswer(h.state().attempt!.questions[3]), isFalse);
      h.ctrl.select(4, 'a');
      expect(h.state().pending, isEmpty);
      expect(api.saveBatches, isEmpty);
    });

    test('takes the server’s state when it refuses an answer, and says why', () async {
      final h = open(container());
      await loaded(h);
      api.failNextSave = const ApiException(409, 'section_locked', 'closed');
      h.ctrl.select(1, 'a');
      await until(() => h.state().notice == 'section_locked', why: 'the refusal');
      expect(h.state().pending, isEmpty);
      expect(h.state().attempt!.questions.first.selected, anyOf(isNull, isEmpty));
    });

    test('shows how the attempt ended when a save finds it already over', () async {
      api.begin(mode: AttemptMode.timed, limit: const Duration(minutes: 5));
      final h = open(container());
      await loaded(h);
      api.now = api.now.add(const Duration(minutes: 6)); // the server ended it; the device does not know
      h.ctrl.select(1, 'a');
      await until(() => h.state().phase == AttemptPhase.finished, why: 'the attempt to end');
      expect(api.status, 'expired');
    });
  });

  group('offline use and resume', () {
    test('keeps answers while offline and sends them when the connection returns', () async {
      final h = open(container());
      await loaded(h);
      api.offline = true;
      h.ctrl.select(1, 'b');
      await until(() => h.state().saveStatus == SaveStatus.offline, why: 'going offline');
      expect(h.state().pending, hasLength(1));
      expect(h.state().attempt!.questions.first.selected, ['b']);
      api.offline = false;
      await until(() => h.state().pending.isEmpty && h.state().saveStatus == SaveStatus.saved, why: 'the retry');
      expect(api.answers[1]!.selected, ['b']);
    });

    test('reopens from the cached state after a restart with no connection, and syncs later', () async {
      final first = container();
      final h1 = open(first);
      await loaded(h1);
      api.offline = true;
      h1.ctrl.select(2, 'c');
      await until(() => h1.state().saveStatus == SaveStatus.offline);
      first.dispose();

      // A new run of the app, still offline.
      final h2 = open(container());
      await loaded(h2);
      expect(h2.state().phase, AttemptPhase.active);
      expect(h2.state().estimatedClock, isTrue);
      expect(h2.state().attempt!.questions[1].selected, ['c']);
      expect(h2.state().pending, hasLength(1));
      api.offline = false;
      await until(() => h2.state().pending.isEmpty && !h2.state().estimatedClock, why: 'syncing');
      expect(api.answers[2]!.selected, ['c']);
    });

    test('estimates the time left from the last contact when reopened offline', () async {
      api.begin(mode: AttemptMode.timed, limit: const Duration(minutes: 60));
      final first = container();
      final h1 = open(first);
      await loaded(h1);
      api.offline = true;
      h1.ctrl.select(1, 'a');
      await until(() => h1.state().saveStatus == SaveStatus.offline);
      first.dispose();
      wall = wall.add(const Duration(minutes: 20)); // time passes on the device
      final h2 = open(container());
      await loaded(h2);
      expect(h2.ctrl.remaining(), const Duration(minutes: 40));
      expect(h2.state().estimatedClock, isTrue);
    });

    test('keeps unsent answers when the server state is reloaded', () async {
      final h = open(container());
      await loaded(h);
      api.offline = true;
      h.ctrl.select(1, 'a');
      await until(() => h.state().saveStatus == SaveStatus.offline);
      api.offline = false;
      await h.ctrl.onResumed();
      await until(() => h.state().pending.isEmpty, why: 'the answer to be sent');
      expect(api.answers[1]!.selected, ['a']);
      expect(h.state().attempt!.questions.first.selected, ['a']);
    });
  });

  group('the cache', () {
    test('holds only what the learner already saw: no answer key or explanation', () async {
      final h = open(container());
      await loaded(h);
      h.ctrl.select(1, 'b');
      await until(() => h.state().pending.isEmpty);
      final raw = prefs.getString(MockExamCache.key)!;
      for (final secret in [FakeMockExamApi.secret, 'accepted', 'explanation', 'correct']) {
        expect(raw, isNot(contains(secret)));
      }
      expect(jsonDecode(raw)['user_id'], 'user-1');
    });

    test('is read by its own learner only, and wiped on sign-out or account change', () async {
      final cache = MockExamCache(LocalStore(prefs));
      final h = open(container());
      await loaded(h);
      h.ctrl.select(1, 'b');
      await until(() => h.state().pending.isEmpty);
      expect(cache.read('user-1', 'aibe'), isNotNull);
      expect(cache.read('user-2', 'aibe'), isNull);

      // A different account cannot reopen it offline.
      api.offline = true;
      final other = open(container(userId: 'user-2'));
      await loaded(other);
      expect(other.state().failure, AttemptFailure.network);

      await cache.clearAll();
      expect(cache.read('user-1', 'aibe'), isNull);
      expect(prefs.getString(MockExamCache.key), isNull);
    });

    test('writing for another learner replaces the first learner’s entries', () async {
      final cache = MockExamCache(LocalStore(prefs));
      final h = open(container());
      await loaded(h);
      h.ctrl.select(1, 'b');
      await until(() => h.state().pending.isEmpty);
      final entry = cache.read('user-1', 'aibe')!;
      await cache.write('user-2', 'aibe', entry);
      expect(cache.read('user-1', 'aibe'), isNull);
      expect(cache.read('user-2', 'aibe'), isNotNull);
    });
  });

  group('submitting', () {
    test('sends waiting answers first, then submits, and drops the cache', () async {
      final h = open(container());
      await loaded(h);
      h.ctrl.select(1, 'b');
      await h.ctrl.submit();
      expect(api.answers[1]!.selected, ['b']);
      expect(api.submitCalls, 1);
      expect(h.state().phase, AttemptPhase.finished);
      expect(prefs.getString(MockExamCache.key) ?? '', isNot(contains('"attempt"')));
    });

    test('a double tap submits once', () async {
      final h = open(container());
      await loaded(h);
      await Future.wait([h.ctrl.submit(), h.ctrl.submit()]);
      expect(api.submitCalls, 1);
    });

    test('keeps the attempt and the answers when the submit cannot reach the server', () async {
      final h = open(container());
      await loaded(h);
      h.ctrl.select(1, 'b');
      await until(() => h.state().pending.isEmpty);
      api.offline = true;
      await h.ctrl.submit();
      expect(h.state().phase, AttemptPhase.active);
      expect(h.state().submitFailed, isTrue);
      expect(h.state().attempt!.questions.first.selected, ['b']);
      api.offline = false;
      await h.ctrl.submit();
      expect(h.state().phase, AttemptPhase.finished);
    });

    test('does not submit while answers are still waiting offline', () async {
      final h = open(container());
      await loaded(h);
      api.offline = true;
      h.ctrl.select(1, 'b');
      await until(() => h.state().saveStatus == SaveStatus.offline);
      await h.ctrl.submit();
      expect(api.submitCalls, 0);
      expect(h.state().phase, AttemptPhase.active);
      expect(h.state().submitFailed, isTrue);
    });

    test('shows the result when the time ran out before the learner submitted', () async {
      api.begin(mode: AttemptMode.timed, limit: const Duration(minutes: 5));
      final h = open(container());
      await loaded(h);
      api.now = api.now.add(const Duration(minutes: 6));
      await h.ctrl.submit();
      expect(h.state().phase, AttemptPhase.finished);
    });
  });

  group('temporary failures keep every answer', () {
    for (final status in [500, 502, 503, 408, 429]) {
      test('HTTP $status: the answer stays queued, on screen and in the cache, and is sent on the retry', () async {
        final h = open(container());
        await loaded(h);
        api.failNextSave = ApiException(status, 'unavailable', 'try again later');
        h.ctrl.select(1, 'b');
        await until(() => h.state().saveStatus == SaveStatus.serverIssue, why: 'the failure');
        expect(h.state().pending, hasLength(1));
        expect(h.state().notice, isNull, reason: 'nothing was refused, so nothing is reported');
        expect(h.state().attempt!.questions.first.selected, ['b']);
        final cached = MockExamCache(LocalStore(prefs)).read('user-1', 'aibe')!;
        expect(cached.pending, hasLength(1));
        await until(() => h.state().pending.isEmpty && h.state().saveStatus == SaveStatus.saved, why: 'the retry');
        expect(api.answers[1]!.selected, ['b']);
      });
    }

    test('an answer chosen while the failing request was out survives it', () async {
      final h = open(container());
      await loaded(h);
      api.holdSaves = Completer<void>();
      h.ctrl.select(1, 'a');
      await until(() => api.saveBatches.isNotEmpty, why: 'the first request');
      h.ctrl.select(1, 'd');
      api.failNextSave = const ApiException(503, 'unavailable', 'try again later');
      api.releaseSaves();
      await until(() => h.state().pending.isEmpty && h.state().saveStatus == SaveStatus.saved, why: 'the retry');
      expect(api.answers[1]!.selected, ['d']);
      expect(api.answers[1]!.seq, 2);
    });

    test('repeated failures keep everything, and the same retry mechanism delivers it', () async {
      final h = open(container());
      await loaded(h);
      api.saveFailureQueue.addAll([
        const ApiException(502, 'bad_gateway', 'x'),
        const ApiException(429, 'too_many', 'x'),
        const ApiException(503, 'unavailable', 'x'),
      ]);
      h.ctrl.select(1, 'a');
      h.ctrl.select(2, 'c');
      await until(() => h.state().pending.isEmpty && h.state().saveStatus == SaveStatus.saved, why: 'the retries');
      expect(api.saveBatches.length, 4);
      expect(api.answers[1]!.selected, ['a']);
      expect(api.answers[2]!.selected, ['c']);
    });

    test('a server error while reloading leaves a running attempt exactly as it was', () async {
      final h = open(container());
      await loaded(h);
      h.ctrl.select(1, 'b');
      await until(() => h.state().pending.isEmpty);
      api.attemptFailure = const ApiException(503, 'unavailable', 'x');
      await h.ctrl.onResumed();
      expect(h.state().phase, AttemptPhase.active);
      expect(h.state().attempt!.questions.first.selected, ['b']);
      expect(h.state().saveStatus, SaveStatus.serverIssue);
      api.attemptFailure = null;
      await until(() => h.state().saveStatus == SaveStatus.saved, why: 'the retry to reach the server');
    });

    test('a sign-out (401) ends the attempt screen instead of retrying forever', () async {
      final h = open(container());
      await loaded(h);
      api.failNextSave = const ApiException(401, 'unauthorized', 'x');
      h.ctrl.select(1, 'b');
      await until(() => h.state().phase == AttemptPhase.failed, why: 'the sign-out');
      expect(h.state().failure, AttemptFailure.signedOut);
    });
  });

  group('what the learner is told while answers wait', () {
    test('a server error is a server issue, a lost connection is offline, and both recover to saved', () async {
      final h = open(container());
      await loaded(h);
      api.failNextSave = const ApiException(503, 'unavailable', 'x');
      h.ctrl.select(1, 'a');
      await until(() => h.state().saveStatus == SaveStatus.serverIssue, why: 'the server issue');
      await until(() => h.state().saveStatus == SaveStatus.saved, why: 'the retry');

      api.offline = true;
      h.ctrl.select(2, 'b');
      await until(() => h.state().saveStatus == SaveStatus.offline, why: 'going offline');
      api.offline = false;
      await until(() => h.state().saveStatus == SaveStatus.saved, why: 'coming back');
    });

    for (final status in [500, 502, 503, 429, 408]) {
      test('HTTP $status shows a server issue, not offline', () async {
        final h = open(container());
        await loaded(h);
        api.failNextSave = ApiException(status, 'unavailable', 'x');
        h.ctrl.select(1, 'a');
        await until(() => h.state().saveStatus != SaveStatus.saving, why: 'the failure');
        expect(h.state().saveStatus, SaveStatus.serverIssue);
        await until(() => h.state().saveStatus == SaveStatus.saved);
      });
    }

    test('a new answer chosen during a server issue keeps the server-issue message', () async {
      final h = open(container());
      await loaded(h);
      api.failNextSave = const ApiException(503, 'unavailable', 'x', retryAfter: Duration(milliseconds: 120));
      h.ctrl.select(1, 'a');
      await until(() => h.state().saveStatus == SaveStatus.serverIssue);
      h.ctrl.select(2, 'b');
      expect(h.state().saveStatus, SaveStatus.serverIssue);
      await until(() => h.state().saveStatus == SaveStatus.saved);
    });
  });

  group('Retry-After', () {
    test('a valid header is waited out before anything is sent again, and nothing is lost', () async {
      final h = open(container());
      await loaded(h);
      // The usual retry is 20 ms here; the server asks for 200 ms.
      api.failNextSave = const ApiException(429, 'rate_limited', 'slow down', retryAfter: Duration(milliseconds: 200));
      h.ctrl.select(1, 'a');
      await until(() => h.state().saveStatus == SaveStatus.serverIssue, why: 'the 429');
      expect(api.saveBatches, hasLength(1));

      // More answers while waiting are queued, not sent.
      h.ctrl.select(2, 'c');
      h.ctrl.select(1, 'd');
      await Future<void>.delayed(const Duration(milliseconds: 100));
      expect(api.saveBatches, hasLength(1), reason: 'the server said to wait');
      expect(h.state().pending, hasLength(2));

      await until(() => h.state().pending.isEmpty && h.state().saveStatus == SaveStatus.saved, why: 'the delayed retry');
      // One retry carried both answers: no duplicate timers, no second attempt.
      expect(api.saveBatches, hasLength(2));
      expect(api.saveBatches.last.map((a) => a.position), [1, 2]);
      expect(api.answers[1]!.selected, ['d']);
      expect(api.answers[1]!.seq, 2);
      expect(api.answers[2]!.selected, ['c']);
    });

    test('also honoured on a 503', () async {
      final h = open(container());
      await loaded(h);
      api.failNextSave = const ApiException(503, 'unavailable', 'x', retryAfter: Duration(milliseconds: 150));
      h.ctrl.select(1, 'a');
      await until(() => h.state().saveStatus == SaveStatus.serverIssue);
      await Future<void>.delayed(const Duration(milliseconds: 70));
      expect(api.saveBatches, hasLength(1));
      await until(() => h.state().saveStatus == SaveStatus.saved);
      expect(api.saveBatches, hasLength(2));
    });

    test('without a header the usual backoff applies (20 ms here)', () async {
      final h = open(container());
      await loaded(h);
      api.failNextSave = const ApiException(429, 'rate_limited', 'slow down');
      h.ctrl.select(1, 'a');
      await until(() => h.state().saveStatus == SaveStatus.serverIssue);
      await until(() => h.state().saveStatus == SaveStatus.saved, why: 'the backoff retry');
      expect(api.saveBatches, hasLength(2));
      expect(api.answers[1]!.selected, ['a']);
    });

    test('an unusable header is ignored, so the usual backoff applies', () async {
      final unusable = await _exceptionFor(429, retryAfter: 'later, please');
      expect(unusable.retryAfter, isNull);
      final h = open(container());
      await loaded(h);
      api.failNextSave = unusable;
      h.ctrl.select(1, 'a');
      await until(() => h.state().saveStatus == SaveStatus.serverIssue);
      await until(() => h.state().saveStatus == SaveStatus.saved, why: 'the backoff retry');
      expect(api.saveBatches, hasLength(2));
    });

    test('a failure while waiting out the header schedules a fresh wait, never two timers', () async {
      final h = open(container());
      await loaded(h);
      api.failNextSave = const ApiException(429, 'rate_limited', 'x', retryAfter: Duration(milliseconds: 80));
      h.ctrl.select(1, 'a');
      await until(() => h.state().saveStatus == SaveStatus.serverIssue);
      // The retry hits another 429 with a different wait.
      api.saveFailureQueue.add(const ApiException(429, 'rate_limited', 'x', retryAfter: Duration(milliseconds: 80)));
      await until(() => api.saveBatches.length == 2, why: 'the first retry');
      await until(() => h.state().saveStatus == SaveStatus.saved, why: 'the second retry');
      expect(api.saveBatches, hasLength(3));
      expect(api.answers[1]!.selected, ['a']);
    });

    test('a submit while the server says wait does not send, and keeps the answers', () async {
      final h = open(container());
      await loaded(h);
      api.failNextSave = const ApiException(429, 'rate_limited', 'x', retryAfter: Duration(milliseconds: 200));
      h.ctrl.select(1, 'b');
      await until(() => h.state().saveStatus == SaveStatus.serverIssue);
      await h.ctrl.submit();
      expect(api.submitCalls, 0);
      expect(h.state().phase, AttemptPhase.active);
      expect(h.state().submitFailed, isTrue);
      expect(h.state().attempt!.questions.first.selected, ['b']);
      await until(() => h.state().saveStatus == SaveStatus.saved);
      await h.ctrl.submit();
      expect(api.submitCalls, 1);
    });
  });

  group('permanent refusals drop only what the server saw', () {
    for (final status in [400, 422]) {
      test('HTTP $status: the refused answer goes, a newer choice stays and is sent', () async {
        final h = open(container());
        await loaded(h);
        api.holdSaves = Completer<void>();
        h.ctrl.select(1, 'a');
        await until(() => api.saveBatches.isNotEmpty, why: 'the first request');
        h.ctrl.select(1, 'd'); // newer than what the server is about to refuse
        api.failNextSave = ApiException(status, 'refused', 'no');
        api.releaseSaves();
        await until(() => h.state().pending.isEmpty && h.state().saveStatus == SaveStatus.saved, why: 'the newer answer');
        expect(api.answers[1]!.selected, ['d']);
        expect(api.answers[1]!.seq, 2);
        expect(h.state().notice, 'refused');
      });
    }

    test('an answer the server refuses is dropped, and not retried', () async {
      final h = open(container());
      await loaded(h);
      api.failNextSave = const ApiException(422, 'invalid_answer', 'no');
      h.ctrl.select(1, 'a');
      await until(() => h.state().notice == 'invalid_answer', why: 'the refusal');
      expect(h.state().pending, isEmpty);
      await Future<void>.delayed(const Duration(milliseconds: 60));
      expect(api.saveBatches, hasLength(1), reason: 'a refused answer is not sent again');
    });
  });

  group('large backlogs', () {
    const positions = 450;

    /// 449 answers (position 4 is withdrawn) all chosen before the first request goes out.
    Future<({AttemptState Function() state, AttemptController ctrl})> answerEverything() async {
      api.total = positions;
      api.begin();
      final h = open(container());
      await loaded(h);
      for (var p = 1; p <= positions; p++) {
        if (p != 4) h.ctrl.select(p, 'a');
      }
      return h;
    }

    test('sends at most 200 answers per request, in position order, with their counters', () async {
      final h = await answerEverything();
      await until(() => h.state().pending.isEmpty && h.state().saveStatus == SaveStatus.saved, why: 'every batch');
      expect(api.saveBatches.map((b) => b.length), [200, 200, 49]);
      for (final batch in api.saveBatches) {
        final order = batch.map((a) => a.position).toList();
        expect(order, [...order]..sort());
        expect(batch.every((a) => a.seq == 1), isTrue);
      }
      expect(api.answers.length, 449);
      expect(api.answers.values.every((a) => a.selected.join() == 'a' && a.seq == 1), isTrue);
    });

    test('a temporary failure on a later batch loses nothing', () async {
      api.saveFailureQueue.addAll([null, const ApiException(503, 'unavailable', 'x')]);
      final h = await answerEverything();
      await until(() => h.state().saveStatus == SaveStatus.serverIssue, why: 'the failing batch');
      expect(h.state().pending, hasLength(249), reason: 'the first batch went through; the rest is still queued');
      await until(() => h.state().pending.isEmpty && h.state().saveStatus == SaveStatus.saved, why: 'the retry');
      expect(api.answers.length, 449);
    });

    test('a refused batch does not stop the batches after it', () async {
      api.saveFailureQueue.addAll([null, const ApiException(422, 'invalid_answer', 'no')]);
      final h = await answerEverything();
      await until(() => h.state().pending.isEmpty && h.state().saveStatus == SaveStatus.saved, why: 'every batch');
      expect(h.state().notice, 'invalid_answer');
      // The second request (positions 202 to 401) was refused; the first and third arrived.
      expect(api.answers.containsKey(1), isTrue);
      expect(api.answers.containsKey(201), isTrue);
      expect(api.answers.containsKey(300), isFalse);
      expect(api.answers.containsKey(450), isTrue);
      expect(api.answers.length, 249);
    });
  });

  group('the deadline passing while offline', () {
    test('keeps the attempt open, and the server finishes it once it can be reached', () async {
      api.begin(mode: AttemptMode.timed, limit: const Duration(minutes: 5));
      final h = open(container());
      await loaded(h);
      h.ctrl.select(1, 'b');
      await until(() => h.state().pending.isEmpty);
      api.offline = true;
      mono.t += const Duration(minutes: 6);
      await h.ctrl.onDeadlineReached();
      expect(h.state().endedOffline, isTrue);
      expect(h.state().phase, AttemptPhase.active, reason: 'only the server may end an attempt');
      expect(h.state().attempt!.questions.first.selected, ['b']);

      api.now = api.now.add(const Duration(minutes: 6));
      api.offline = false;
      await until(() => h.state().phase == AttemptPhase.finished, why: 'the server to end it');
      expect(api.status, 'expired');
    });

    test('asks again gently, and a tap on an answer does not ask at all', () async {
      api.begin(mode: AttemptMode.timed, limit: const Duration(minutes: 5));
      final h = open(container());
      await loaded(h);
      api.offline = true;
      mono.t += const Duration(minutes: 6);
      await h.ctrl.onDeadlineReached();
      final afterFirst = api.attemptFetches;
      for (var i = 0; i < 6; i++) {
        h.ctrl.select(1, 'a');
      }
      expect(api.attemptFetches, afterFirst, reason: 'answers are not accepted, and do not trigger requests');
      expect(api.saveBatches, isEmpty);
      await Future<void>.delayed(const Duration(milliseconds: 200));
      // Delays of 30 ms then 60 ms (repeating): a handful of requests, not a stream.
      expect(api.attemptFetches - afterFirst, lessThanOrEqualTo(4));
      expect(api.attemptFetches - afterFirst, greaterThanOrEqualTo(1));
    });

    test('a server error at the deadline is handled the same way', () async {
      api.begin(mode: AttemptMode.timed, limit: const Duration(minutes: 5));
      final h = open(container());
      await loaded(h);
      api.attemptFailure = const ApiException(503, 'unavailable', 'x');
      mono.t += const Duration(minutes: 6);
      await h.ctrl.onDeadlineReached();
      expect(h.state().endedOffline, isTrue);
      expect(h.state().phase, AttemptPhase.active);
      api.attemptFailure = null;
      api.now = api.now.add(const Duration(minutes: 6));
      await until(() => h.state().phase == AttemptPhase.finished, why: 'the server to end it');
    });

    test('coming back to the app asks the server straight away', () async {
      api.begin(mode: AttemptMode.timed, limit: const Duration(minutes: 5));
      final h = open(container());
      await loaded(h);
      api.offline = true;
      mono.t += const Duration(minutes: 6);
      await h.ctrl.onDeadlineReached();
      api.offline = false;
      api.now = api.now.add(const Duration(minutes: 6));
      await h.ctrl.onResumed();
      expect(h.state().phase, AttemptPhase.finished);
    });
  });

  group('keeping the monotonic clock', () {
    test('a reload while the app is running and offline does not swap in a wall-clock estimate', () async {
      api.begin(mode: AttemptMode.timed, limit: const Duration(minutes: 60));
      final h = open(container());
      await loaded(h);
      mono.t += const Duration(minutes: 10);
      wall = wall.add(const Duration(hours: 5)); // a wall-clock estimate would be wildly off
      api.offline = true;
      await h.ctrl.onResumed();
      expect(h.state().phase, AttemptPhase.active);
      expect(h.state().estimatedClock, isFalse, reason: 'the stopwatch is still running, so this is not an estimate');
      expect(h.state().saveStatus, SaveStatus.offline);
      expect(h.ctrl.remaining(), const Duration(minutes: 50));
      mono.t += const Duration(minutes: 5);
      expect(h.ctrl.remaining(), const Duration(minutes: 45));
    });

    test('the next successful response corrects the time from the server', () async {
      api.begin(mode: AttemptMode.timed, limit: const Duration(minutes: 60));
      final h = open(container());
      await loaded(h);
      mono.t += const Duration(minutes: 15);
      api.offline = true;
      await h.ctrl.onResumed();
      expect(h.ctrl.remaining(), const Duration(minutes: 45));
      api.offline = false;
      api.now = api.now.add(const Duration(minutes: 20)); // the server says 20 minutes have really passed
      await h.ctrl.onResumed();
      expect(h.ctrl.remaining(), const Duration(minutes: 40));
      expect(h.state().estimatedClock, isFalse);
    });

    test('only a real restart falls back to the estimate', () async {
      api.begin(mode: AttemptMode.timed, limit: const Duration(minutes: 60));
      final first = container();
      final h1 = open(first);
      await loaded(h1);
      api.offline = true;
      h1.ctrl.select(1, 'a');
      await until(() => h1.state().saveStatus == SaveStatus.offline);
      first.dispose();
      wall = wall.add(const Duration(minutes: 20));
      final h2 = open(container());
      await loaded(h2);
      expect(h2.state().estimatedClock, isTrue);
      expect(h2.ctrl.remaining(), const Duration(minutes: 40));
      api.offline = false;
      api.now = api.now.add(const Duration(minutes: 25));
      await until(() => !h2.state().estimatedClock, why: 'the server to correct the time');
      expect(h2.ctrl.remaining(), const Duration(minutes: 35));
    });
  });

  group('locked-order sections', () {
    test('answers only in the open section; advancing sends waiting answers first', () async {
      api.begin(locked: true, sections: 2);
      final h = open(container());
      await loaded(h);
      final qs = h.state().attempt!.questions;
      expect(h.ctrl.canAnswer(qs[0]), isTrue);
      expect(h.ctrl.canAnswer(qs[2]), isFalse);
      h.ctrl.select(3, 'a'); // section 2: ignored
      expect(h.state().pending, isEmpty);
      h.ctrl.select(1, 'b');
      await h.ctrl.advanceSection();
      expect(api.answers[1]!.selected, ['b']);
      expect(h.state().attempt!.currentSectionPosition, 2);
      final next = h.state().attempt!.questions;
      expect(h.ctrl.canAnswer(next[0]), isFalse);
      expect(h.ctrl.canAnswer(next[2]), isTrue);
    });
  });
}

/// The exception the real API client raises for a [status] answer carrying this Retry-After.
Future<ApiException> _exceptionFor(int status, {String? retryAfter}) async {
  final client = ApiClient(
    baseUrl: 'http://test',
    client: MockClient((_) async => http.Response(
          '{"code":"rate_limited","message":"slow down"}',
          status,
          headers: {'retry-after': ?retryAfter},
        )),
    tokens: MemoryTokenStore(),
  );
  try {
    await client.get('/v1/anything');
  } on ApiException catch (e) {
    return e;
  }
  throw StateError('expected an error');
}
