import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:nyaya/core/api/api_client.dart';
import 'package:nyaya/core/storage/local_store.dart';
import 'package:nyaya/features/legal_updates/data/legal_updates_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/fake_backend.dart';

Map<String, dynamic> article(String id, String date, {String category = 'supreme_court'}) => {
      'id': id,
      'category': category,
      'title': 'Title $id',
      'summary': 'Summary',
      'key_points': ['One', 'Two'],
      'why_it_matters': 'Why',
      'source': 'Supreme Court of India',
      'source_url': null,
      'date': date,
      'read_minutes': 2,
    };

void main() {
  late LocalStore store;
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    store = LocalStore(await SharedPreferences.getInstance());
  });

  HttpLegalUpdatesRepository repoWith(Future<http.Response> Function(http.Request) handler) =>
      HttpLegalUpdatesRepository(
        ApiClient(baseUrl: 'https://api.test', client: MockClient(handler), tokens: signedInTokens()),
        store,
      );

  test('reads published news from the API, newest first, without a token', () async {
    final repo = repoWith((req) async {
      expect(req.url.toString(), 'https://api.test/v1/news');
      expect(req.headers['authorization'], isNull);
      return http.Response(
        jsonEncode({
          'items': [
            article('old', '2024-01-02'),
            article('new', '2025-04-08', category: 'legislation'),
            article('future-kind', '2025-05-01', category: 'tribunals'),
          ],
        }),
        200,
      );
    });
    final items = await repo.fetch();
    // A category this build does not know is skipped.
    expect(items.map((u) => u.id), ['new', 'old']);
    expect(items.first.category, UpdateCategory.legislation);
    expect(items.first.keyPoints, ['One', 'Two']);
    expect(items.first.date, DateTime(2025, 4, 8));
  });

  test('shows the last list when offline', () async {
    await repoWith((_) async => http.Response(jsonEncode({'items': [article('a', '2025-01-01')]}), 200)).fetch();
    final offline = repoWith((_) => throw http.ClientException('offline'));
    expect((await offline.fetch()).map((u) => u.id), ['a']);
  });

  test('fails when offline with nothing kept yet', () async {
    final offline = repoWith((_) => throw http.ClientException('offline'));
    await expectLater(offline.fetch(), throwsA(isA<ApiException>()));
  });
}
