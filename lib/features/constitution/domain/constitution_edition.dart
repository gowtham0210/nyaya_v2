import 'package:flutter/foundation.dart';

/// One edition of the Constitution of India as India Code publishes it, read
/// from `GET /v1/constitution`. The API is the source of truth: nothing here
/// is added, guessed or translated. The app never holds the PDF itself, only
/// its official address.
@immutable
class ConstitutionEdition {
  const ConstitutionEdition({
    required this.id,
    this.languageCode,
    required this.languageName,
    this.nativeName,
    this.script,
    required this.title,
    this.authorityNote,
    required this.downloadUri,
    this.sourcePageUri,
    required this.sizeBytes,
    this.modified,
    required this.large,
    required this.scanned,
  });

  /// Stable id (`ta`, `mni-Mtei`, `original`).
  final String id;

  /// BCP 47 style code; null for the original copy, which is not a language.
  final String? languageCode;

  /// The language in English, as the API names it.
  final String languageName;
  final String? nativeName;
  final String? script;
  final String title;

  /// Reviewed wording about the edition's legal standing. The app shows
  /// nothing about authority unless the API provides this.
  final String? authorityNote;

  /// The official India Code address of the PDF (https only).
  final Uri downloadUri;

  /// The item's page on India Code, for when the PDF will not open.
  final Uri? sourcePageUri;

  /// As India Code reports it; approximate.
  final int sizeBytes;
  final DateTime? modified;

  /// A big download: warn before opening.
  final bool large;

  /// Scanned pages with no text layer: not searchable, may not be read aloud.
  final bool scanned;

  /// Reads one edition; null when it is not one this build can use safely (a
  /// missing field, or a link that is not https).
  static ConstitutionEdition? fromJson(Map<String, dynamic> j) {
    final download = _https(j['download_url']);
    final file = j['file'];
    final flags = j['flags'];
    final id = j['id'];
    final name = j['language_name'];
    final title = j['title'];
    if (download == null ||
        file is! Map<String, dynamic> ||
        id is! String ||
        id.isEmpty ||
        name is! String ||
        name.isEmpty ||
        title is! String ||
        title.isEmpty) {
      return null;
    }
    final size = file['size_bytes'];
    if (size is! num) return null;
    String? text(Object? v) => v is String && v.trim().isNotEmpty ? v : null;
    return ConstitutionEdition(
      id: id,
      languageCode: text(j['language_code']),
      languageName: name,
      nativeName: text(j['native_name']),
      script: text(j['script']),
      title: title,
      authorityNote: text(j['authority_note']),
      downloadUri: download,
      sourcePageUri: _https(j['source_page_url']),
      sizeBytes: size.toInt(),
      modified: DateTime.tryParse(file['source_modified_at'] as String? ?? ''),
      large: flags is Map<String, dynamic> && flags['large'] == true,
      scanned: flags is Map<String, dynamic> && flags['scanned'] == true,
    );
  }
}

/// The list the screen shows: the editions, the original copy apart from them,
/// and where it all came from.
@immutable
class ConstitutionLibrary {
  const ConstitutionLibrary({
    required this.sourceName,
    this.collectionUri,
    this.fetchedAt,
    required this.stale,
    this.fromCache = false,
    this.original,
    required this.editions,
  });

  final String sourceName;
  final Uri? collectionUri;

  /// When the API last read India Code; null if it never did.
  final DateTime? fetchedAt;

  /// The API could not reach India Code, so the details may be out of date.
  final bool stale;

  /// This copy is the one kept on the phone, because the API was unreachable.
  final bool fromCache;
  final ConstitutionEdition? original;
  final List<ConstitutionEdition> editions;

  bool get isEmpty => original == null && editions.isEmpty;

  /// Whether to warn that the details may be old.
  bool get maybeOutOfDate => stale || fromCache;

  ConstitutionLibrary asCached() => ConstitutionLibrary(
    sourceName: sourceName,
    collectionUri: collectionUri,
    fetchedAt: fetchedAt,
    stale: stale,
    fromCache: true,
    original: original,
    editions: editions,
  );

  /// The edition in [languageCode], or the English one when there is none
  /// ([fellBack] is then true). Null when neither is listed.
  ({ConstitutionEdition? edition, bool fellBack}) forLanguage(String languageCode) {
    ConstitutionEdition? by(String code) => editions.where((e) => e.languageCode == code).firstOrNull;
    final exact = by(languageCode);
    if (exact != null) return (edition: exact, fellBack: false);
    return (edition: by('en'), fellBack: true);
  }

  /// Reads the API's body (and the copy kept on the phone). Editions this
  /// build cannot use are left out; a body with no list at all is an error.
  static ConstitutionLibrary fromJson(Map<String, dynamic> j) {
    final list = j['editions'];
    if (list is! List) throw const FormatException('editions is not a list');
    final source = j['source'];
    final src = source is Map<String, dynamic> ? source : const <String, dynamic>{};
    final original = j['original'];
    return ConstitutionLibrary(
      sourceName: src['name'] is String ? src['name'] as String : 'India Code',
      collectionUri: _https(src['collection_url']),
      fetchedAt: DateTime.tryParse(src['fetched_at'] as String? ?? ''),
      stale: src['stale'] == true,
      original: original is Map<String, dynamic> ? ConstitutionEdition.fromJson(original) : null,
      editions: [for (final e in list.whereType<Map<String, dynamic>>()) ?ConstitutionEdition.fromJson(e)],
    );
  }
}

/// An https address with a host, or null. Anything else is never opened.
Uri? _https(Object? value) {
  if (value is! String) return null;
  final uri = Uri.tryParse(value);
  return uri != null && uri.isScheme('https') && uri.host.isNotEmpty ? uri : null;
}

/// "3.4 MB", "512 KB": rounded, for a size India Code gives only roughly.
String formatFileSize(int bytes) {
  if (bytes < 1000000) return '${(bytes / 1000).round().clamp(1, 999)} KB';
  final mb = bytes / 1000000;
  return mb < 100 ? '${mb.toStringAsFixed(1)} MB' : '${mb.round()} MB';
}
