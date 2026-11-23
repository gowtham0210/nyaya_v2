import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';
import '../../../core/storage/local_store.dart';
import '../domain/constitution_edition.dart';

abstract interface class ConstitutionRepository {
  Future<ConstitutionLibrary> fetch();
}

final constitutionRepositoryProvider = Provider<ConstitutionRepository>(
  (ref) => HttpConstitutionRepository(ref.watch(apiClientProvider), ref.watch(localStoreProvider)),
);

/// The editions list. Opened afresh each time the screen opens; with no
/// automatic retries, so a failure shows the screen's own "Try again".
final constitutionProvider = FutureProvider.autoDispose<ConstitutionLibrary>(
  (ref) => ref.watch(constitutionRepositoryProvider).fetch(),
  retry: (_, _) => null,
);

/// The Nyaya API's `GET /v1/constitution`: the editions' details and their
/// official India Code links. Only this small list is kept on the phone (so
/// the screen still opens offline); the PDFs themselves are never downloaded,
/// stored or proxied.
class HttpConstitutionRepository implements ConstitutionRepository {
  HttpConstitutionRepository(this._client, this._store);

  static const _cacheKey = 'constitution_library_v1';

  final ApiClient _client;
  final LocalStore _store;

  static const _unreadable = ApiException(0, 'unreadable', 'The Constitution list could not be read');

  @override
  Future<ConstitutionLibrary> fetch() async {
    try {
      final j = await _client.get('/v1/constitution', auth: false);
      if (j is! Map<String, dynamic>) throw _unreadable;
      final library = ConstitutionLibrary.fromJson(j);
      await _store.writeJson(_cacheKey, j);
      return library;
    } on FormatException {
      throw _unreadable;
    } on ApiException {
      // Unreachable or refused: the last list seen, if there is one.
      final cached = _store.readJson(_cacheKey);
      if (cached == null) rethrow;
      try {
        return ConstitutionLibrary.fromJson(cached).asCached();
      } on FormatException {
        throw _unreadable;
      }
    }
  }
}
