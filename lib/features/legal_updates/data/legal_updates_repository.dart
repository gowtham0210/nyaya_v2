import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';
import '../../../core/storage/local_store.dart';

enum UpdateCategory {
  supremeCourt('supreme_court'),
  highCourts('high_courts'),
  legislation('legislation'),
  explainer('explainer');

  const UpdateCategory(this.apiName);
  final String apiName;

  static UpdateCategory? fromApi(String? name) => values.where((c) => c.apiName == name).firstOrNull;
}

@immutable
class LegalUpdate {
  const LegalUpdate({
    required this.id,
    required this.category,
    required this.title,
    required this.summary,
    required this.keyPoints,
    required this.whyItMatters,
    required this.source,
    this.sourceUrl,
    required this.date,
    required this.readMinutes,
  });

  final String id;
  final UpdateCategory category;
  final String title;
  final String summary;
  final List<String> keyPoints;
  final String whyItMatters;
  final String source;

  /// The judgment, gazette or official page, when the editors gave one.
  final String? sourceUrl;
  final DateTime date;
  final int readMinutes;

  /// Card thumbnail; until it exists the card shows its category's painting.
  /// Prompts are in docs/UPDATES_ART.md.
  String get image => 'assets/images/update_${id.replaceAll('-', '_')}.webp';

  /// Reads the API's (and the cache's) shape; null when it is not one we know.
  static LegalUpdate? fromJson(Map<String, dynamic> j) {
    final category = UpdateCategory.fromApi(j['category'] as String?);
    final date = DateTime.tryParse(j['date'] as String? ?? '');
    if (category == null || date == null) return null;
    return LegalUpdate(
      id: j['id'] as String,
      category: category,
      title: j['title'] as String,
      summary: j['summary'] as String,
      keyPoints: (j['key_points'] as List).cast<String>(),
      whyItMatters: j['why_it_matters'] as String,
      source: j['source'] as String,
      sourceUrl: j['source_url'] as String?,
      date: date,
      readMinutes: j['read_minutes'] as int,
    );
  }
}

final legalUpdatesRepositoryProvider = Provider<LegalUpdatesRepository>(
  (ref) => HttpLegalUpdatesRepository(ref.watch(apiClientProvider), ref.watch(localStoreProvider)),
);

final legalUpdatesProvider = FutureProvider<List<LegalUpdate>>(
  (ref) => ref.watch(legalUpdatesRepositoryProvider).fetch(),
);

final savedUpdatesProvider = NotifierProvider<SavedUpdatesController, Set<String>>(SavedUpdatesController.new);

/// Ids of updates the user bookmarked, kept on the device.
class SavedUpdatesController extends Notifier<Set<String>> {
  static const _key = 'saved_updates_v1';

  LocalStore get _store => ref.read(localStoreProvider);

  @override
  Set<String> build() => (_store.readJsonList(_key) ?? const []).cast<String>().toSet();

  void toggle(String id) {
    state = state.contains(id) ? ({...state}..remove(id)) : {...state, id};
    _store.writeJson(_key, state.toList());
  }
}

abstract interface class LegalUpdatesRepository {
  Future<List<LegalUpdate>> fetch();
}

/// Published news from the Nyaya API (written and reviewed in the content
/// portal). The last list is kept on the phone, so the tab still works
/// offline; with no copy yet, the error reaches the screen's retry state.
class HttpLegalUpdatesRepository implements LegalUpdatesRepository {
  HttpLegalUpdatesRepository(this._client, this._store);

  static const _cacheKey = 'legal_updates_cache_v1';

  final ApiClient _client;
  final LocalStore _store;

  @override
  Future<List<LegalUpdate>> fetch() async {
    try {
      final j = await _client.get('/v1/news', auth: false) as Map<String, dynamic>;
      final items = (j['items'] as List).cast<Map<String, dynamic>>();
      await _store.writeJson(_cacheKey, items);
      return _parse(items);
    } on ApiException {
      final cached = _store.readJsonList(_cacheKey);
      if (cached == null) rethrow;
      return _parse(cached.cast<Map<String, dynamic>>());
    }
  }

  /// Newest first; articles of a kind this build does not know are skipped.
  static List<LegalUpdate> _parse(List<Map<String, dynamic>> items) =>
      [for (final j in items) ?LegalUpdate.fromJson(j)]..sort((a, b) => b.date.compareTo(a.date));
}
