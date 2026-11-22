import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:nyaya/core/api/api_client.dart';
import 'package:nyaya/core/api/token_store.dart';
import 'package:nyaya/features/mock_exams/data/mock_exam_api.dart';
import 'package:nyaya/features/mock_exams/domain/mock_exam_models.dart';

/// How a Retry-After header becomes a wait: usable values are kept (within
/// limits); anything else is ignored so the usual backoff applies.
void main() {
  final now = DateTime.utc(2026, 11, 20, 10);

  group('parseRetryAfter', () {
    test('reads whole seconds', () {
      expect(parseRetryAfter('5'), const Duration(seconds: 5));
      expect(parseRetryAfter(' 30 '), const Duration(seconds: 30));
      expect(parseRetryAfter('120'), const Duration(seconds: 120));
    });

    test('holds a wait within the shortest and longest allowed', () {
      expect(parseRetryAfter('0'), retryAfterMin);
      expect(parseRetryAfter('3600'), retryAfterMax);
      expect(parseRetryAfter('999999999'), retryAfterMax);
    });

    test('reads an HTTP date in the future', () {
      expect(parseRetryAfter('Fri, 20 Nov 2026 10:00:45 GMT', now: now), const Duration(seconds: 45));
      expect(parseRetryAfter('Fri, 20 Nov 2026 10:30:00 GMT', now: now), retryAfterMax);
    });

    test('ignores a missing, empty or unusable header', () {
      for (final bad in [null, '', '   ', '-5', '1.5', '5s', 'soon', 'NaN', '１２', '0x10', '1e3']) {
        expect(parseRetryAfter(bad, now: now), isNull, reason: 'header: $bad');
      }
    });

    test('ignores a date that has already passed', () {
      expect(parseRetryAfter('Fri, 20 Nov 2026 09:59:00 GMT', now: now), isNull);
      expect(parseRetryAfter('Fri, 20 Nov 2026 10:00:00 GMT', now: now), isNull);
      expect(parseRetryAfter('Fri, 99 Zzz 2026 99:99:99 GMT', now: now), isNull);
    });
  });

  group('the API client', () {
    Future<ApiException> failure(int status, {String? header, String body = '{"code":"x","message":"y"}'}) async {
      final client = ApiClient(
        baseUrl: 'http://test',
        client: MockClient((_) async => http.Response(body, status, headers: {'retry-after': ?header})),
        tokens: MemoryTokenStore(),
      );
      try {
        await client.get('/v1/anything');
      } on ApiException catch (e) {
        return e;
      }
      throw StateError('expected an error');
    }

    test('carries a valid Retry-After on a 429 and on 5xx errors', () async {
      expect((await failure(429, header: '7')).retryAfter, const Duration(seconds: 7));
      expect((await failure(503, header: '12')).retryAfter, const Duration(seconds: 12));
      expect((await failure(500, header: '2')).retryAfter, const Duration(seconds: 2));
    });

    test('has none when the header is missing or invalid', () async {
      expect((await failure(429)).retryAfter, isNull);
      expect((await failure(429, header: 'abc')).retryAfter, isNull);
      expect((await failure(429, header: '-1')).retryAfter, isNull);
      expect((await failure(503, header: '')).retryAfter, isNull);
    });

    test('ignores the header on errors where waiting means nothing', () async {
      expect((await failure(422, header: '5')).retryAfter, isNull);
      expect((await failure(409, header: '5')).retryAfter, isNull);
    });

    test('still reads the error body and status as before', () async {
      final e = await failure(429, header: '4', body: '{"code":"rate_limited","message":"slow down"}');
      expect(e.status, 429);
      expect(e.code, 'rate_limited');
      expect(e.message, 'slow down');
      expect(e.isNetwork, isFalse);
    });

    test('reaches the mock exam API’s caller, so autosave can use it', () async {
      final api = HttpMockExamApi(ApiClient(
        baseUrl: 'http://test',
        client: MockClient((_) async => http.Response('{"code":"rate_limited","message":"x"}', 429, headers: {'retry-after': '9'})),
        tokens: MemoryTokenStore(),
      ));
      await expectLater(
        api.saveAnswers('attempt-1', const [PendingAnswer(1, ['a'], 1)]),
        throwsA(isA<ApiException>().having((e) => e.retryAfter, 'retryAfter', const Duration(seconds: 9))),
      );
    });
  });
}
