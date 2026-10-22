import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../profile/application/profile_controller.dart';
import '../domain/question.dart';

final questionRepositoryProvider = Provider<QuestionRepository>((ref) => AssetQuestionRepository());

/// Question bank for the current UI language.
final questionBankProvider = FutureProvider<QuestionBank>((ref) {
  final locale = ref.watch(localeProvider);
  return ref.watch(questionRepositoryProvider).load(locale.languageCode);
});

abstract interface class QuestionRepository {
  Future<QuestionBank> load(String languageCode);
}

/// Bundled JSON banks. English (`en.json`) is authoritative for answers,
/// chapters and difficulty; `<code>.json` overlays translated text by id and
/// falls back to English for anything missing — so a partial translation can
/// never break a quiz. A remote CMS implementation can replace this class.
class AssetQuestionRepository implements QuestionRepository {
  /// [load] reads a bundled text file; injectable for tests.
  AssetQuestionRepository({Future<String> Function(String path)? load}) : _load = load ?? rootBundle.loadString;

  final Future<String> Function(String path) _load;
  final _cache = <String, QuestionBank>{};

  @override
  Future<QuestionBank> load(String languageCode) async {
    final cached = _cache[languageCode];
    if (cached != null) return cached;

    final en = jsonDecode(await _load('assets/questions/en.json')) as Map<String, dynamic>;
    Map<String, dynamic>? tr;
    if (languageCode != 'en') {
      try {
        tr = jsonDecode(await _load('assets/questions/$languageCode.json'))
            as Map<String, dynamic>;
      } catch (_) {
        tr = null;
      }
    }

    final trById = <String, Map<String, dynamic>>{
      for (final q in (tr?['questions'] as List<dynamic>? ?? const []))
        (q as Map<String, dynamic>)['id'] as String: q,
    };
    final questions = [
      for (final q in en['questions'] as List<dynamic>)
        Question.fromJson(q as Map<String, dynamic>).localized(trById[q['id']]),
    ];

    final enCh = en['chapters'] as Map<String, dynamic>;
    final trCh = tr?['chapters'] as Map<String, dynamic>? ?? const {};
    final chapters = <String, ChapterText>{
      for (final e in enCh.entries)
        e.key: ChapterText(
          title: (trCh[e.key]?['title'] ?? e.value['title']) as String,
          subtitle: (trCh[e.key]?['subtitle'] ?? e.value['subtitle']) as String,
        ),
    };

    return _cache[languageCode] = QuestionBank(questions: questions, chapters: chapters);
  }
}
