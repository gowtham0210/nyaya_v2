import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';

/// A question the learner already answered, with its answer. When the
/// question is retired or no longer in force, [available] is false and only
/// the text they saw is left.
@immutable
class ReviewQuestion {
  const ReviewQuestion({
    required this.questionId,
    required this.available,
    this.updatedSince = false,
    required this.stem,
    required this.options,
    required this.correctOptionIds,
    required this.explanation,
    required this.reference,
    this.sourceUrl,
  });

  final String questionId;
  final bool available;

  /// Revised after the learner answered it; this is the version they answered.
  final bool updatedSince;
  final String stem;

  /// (id, text) in the question's own order.
  final List<({String id, String text})> options;
  final List<String> correctOptionIds;
  final String? explanation;
  final String? reference;
  final String? sourceUrl;

  List<String> get correctTexts => [
        for (final o in options)
          if (correctOptionIds.contains(o.id)) o.text,
      ];

  factory ReviewQuestion.fromJson(Map<String, dynamic> j) => ReviewQuestion(
        questionId: j['question_id'] as String,
        available: j['available'] as bool,
        updatedSince: j['updated_since'] as bool? ?? false,
        stem: j['stem'] as String,
        options: [
          for (final o in (j['options'] as List).cast<Map<String, dynamic>>())
            (id: o['id'] as String, text: o['text'] as String),
        ],
        correctOptionIds: (j['correct_option_ids'] as List).cast<String>(),
        explanation: j['explanation'] as String?,
        reference: (j['provision_reference'] as String?) ?? (j['source_title'] as String?),
        sourceUrl: j['source_url'] as String?,
      );
}

@immutable
class Mistake {
  const Mistake({required this.question, required this.wrongCount, required this.lastWrongAt, required this.saved});

  final ReviewQuestion question;
  final int wrongCount;
  final DateTime lastWrongAt;
  final bool saved;

  factory Mistake.fromJson(Map<String, dynamic> j) => Mistake(
        question: ReviewQuestion.fromJson(j['question'] as Map<String, dynamic>),
        wrongCount: j['wrong_count'] as int,
        lastWrongAt: DateTime.parse(j['last_wrong_at'] as String),
        saved: j['saved'] as bool,
      );
}

@immutable
class SavedQuestion {
  const SavedQuestion({required this.question, required this.savedAt});

  final ReviewQuestion question;
  final DateTime savedAt;

  factory SavedQuestion.fromJson(Map<String, dynamic> j) => SavedQuestion(
        question: ReviewQuestion.fromJson(j['question'] as Map<String, dynamic>),
        savedAt: DateTime.parse(j['saved_at'] as String),
      );
}

/// Why a learner reports a question (the API's report reasons).
enum ReportReason {
  wrongAnswer('wrong_answer'),
  unclear('unclear'),
  outdatedLaw('outdated_law'),
  typo('typo'),
  other('other');

  const ReportReason(this.apiName);
  final String apiName;
}

final reviewApiProvider = Provider<ReviewApi>((ref) => HttpReviewApi(ref.watch(apiClientProvider)));

/// Saved questions, mistakes and question reports on the Nyaya API.
abstract interface class ReviewApi {
  Future<List<Mistake>> mistakes();
  Future<List<SavedQuestion>> saved();
  Future<void> save(String questionId);
  Future<void> unsave(String questionId);

  /// Reports a problem with the version the learner was shown.
  Future<void> report({required String questionVersionId, required ReportReason reason, String? comment});
}

class HttpReviewApi implements ReviewApi {
  HttpReviewApi(this._client);

  final ApiClient _client;

  @override
  Future<List<Mistake>> mistakes() async {
    final j = await _client.get('/v1/me/mistakes') as Map<String, dynamic>;
    return [for (final m in (j['items'] as List).cast<Map<String, dynamic>>()) Mistake.fromJson(m)];
  }

  @override
  Future<List<SavedQuestion>> saved() async {
    final j = await _client.get('/v1/me/bookmarks') as Map<String, dynamic>;
    return [for (final m in (j['items'] as List).cast<Map<String, dynamic>>()) SavedQuestion.fromJson(m)];
  }

  @override
  Future<void> save(String questionId) => _client.post('/v1/me/bookmarks', body: {'question_id': questionId});

  @override
  Future<void> unsave(String questionId) => _client.delete('/v1/me/bookmarks/$questionId');

  @override
  Future<void> report({required String questionVersionId, required ReportReason reason, String? comment}) =>
      _client.post('/v1/content-reports', body: {
        'question_version_id': questionVersionId,
        'reason': reason.apiName,
        if (comment != null && comment.trim().isNotEmpty) 'comment': comment.trim(),
      });
}
