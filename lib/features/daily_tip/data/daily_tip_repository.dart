import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';
import '../../profile/application/profile_controller.dart';

/// A legal tip from the content portal: reviewed by a legal reviewer and
/// published for one day. Nothing here is bundled in the app.
@immutable
class DailyTip {
  const DailyTip({
    required this.id,
    required this.title,
    required this.summary,
    required this.explanation,
    required this.legalReference,
    required this.sourceUrl,
    required this.publishDate,
    required this.lastVerified,
  });

  final String id;
  final String title;

  /// Shown on the Home card.
  final String summary;
  final String explanation;

  /// The Act and section the tip rests on.
  final String legalReference;

  /// The official source (the API only sends https links).
  final String sourceUrl;
  final DateTime publishDate;
  final DateTime lastVerified;

  /// Reads the API's shape; null when it is not one we know.
  static DailyTip? fromJson(Map<String, dynamic> j) {
    final publish = DateTime.tryParse(j['publish_date'] as String? ?? '');
    final verified = DateTime.tryParse(j['last_verified_on'] as String? ?? '');
    if (publish == null || verified == null) return null;
    return DailyTip(
      id: j['id'] as String,
      title: j['title'] as String,
      summary: j['summary'] as String,
      explanation: j['explanation'] as String,
      legalReference: j['legal_reference'] as String,
      sourceUrl: j['source_url'] as String,
      publishDate: publish,
      lastVerified: verified,
    );
  }
}

abstract interface class DailyTipRepository {
  /// Today's tip in [language]; null when none is published for today.
  Future<DailyTip?> today(String language);

  /// One published tip; throws an [ApiException] with status 404 when it is
  /// not (or no longer) available.
  Future<DailyTip> byId(String id);
}

final dailyTipRepositoryProvider = Provider<DailyTipRepository>(
  (ref) => HttpDailyTipRepository(ref.watch(apiClientProvider)),
);

/// Today's tip, in the learner's language when the editors wrote one and in
/// English otherwise. Null means nothing is published for today. Refresh with
/// `ref.invalidate(dailyTipProvider)`.
///
/// Home renews it at 00:00 India time and when the app comes back after the
/// day has changed (see `DailyTipRenewal`).
///
/// No automatic retries: a failure shows the card's own "Try again", instead
/// of Riverpod re-asking in the background while the card spins.
final dailyTipProvider = FutureProvider<DailyTip?>((ref) async {
  final repo = ref.watch(dailyTipRepositoryProvider);
  final language = ref.watch(profileProvider.select((p) => p.language.code));
  final tip = await repo.today(language);
  if (tip != null || language == 'en') return tip;
  return repo.today('en');
}, retry: (_, _) => null);

/// One tip by id, for the detail screen opened from a link.
final dailyTipByIdProvider = FutureProvider.family<DailyTip, String>(
  (ref, id) => ref.watch(dailyTipRepositoryProvider).byId(id),
  // A withdrawn tip is a 404 for good; show it at once, not after retries.
  retry: (_, _) => null,
);

/// The Nyaya API's published tips. No sign-in is needed to read them.
class HttpDailyTipRepository implements DailyTipRepository {
  HttpDailyTipRepository(this._client);

  final ApiClient _client;

  @override
  Future<DailyTip?> today(String language) async {
    final j = await _client.get('/v1/daily-tips/today', query: {'language': language}, auth: false)
        as Map<String, dynamic>;
    final tip = j['tip'];
    return tip == null ? null : DailyTip.fromJson(tip as Map<String, dynamic>);
  }

  @override
  Future<DailyTip> byId(String id) async {
    final j = await _client.get('/v1/daily-tips/${Uri.encodeComponent(id)}', auth: false) as Map<String, dynamic>;
    final tip = DailyTip.fromJson(j);
    if (tip == null) throw const ApiException(0, 'unreadable', 'The tip could not be read');
    return tip;
  }
}
