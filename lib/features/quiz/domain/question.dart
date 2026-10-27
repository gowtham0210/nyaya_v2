import 'package:flutter/foundation.dart';

/// A question as the learner sees it. The answer key stays on the server;
/// see [Reveal] for what comes back once an answer is final.
@immutable
class Question {
  const Question({
    required this.id,
    required this.chapterId,
    required this.difficulty,
    required this.text,
    required this.options,
    required this.optionIds,
  });

  /// The server's question_version_id.
  final String id;
  final String chapterId;
  final int difficulty;
  final String text;

  /// Option texts in the order to show them.
  final List<String> options;

  /// Server option ids, parallel to [options].
  final List<String> optionIds;
}

/// What the server discloses about a question after it is answered
/// (practice modes) or the quiz is submitted (exam).
@immutable
class Reveal {
  const Reveal({required this.correctIndex, required this.explanation, required this.reference});

  /// Index into [Question.options]; null if the server named an unknown option.
  final int? correctIndex;
  final String explanation;

  /// Provision or source, e.g. "Article 394, Constitution of India".
  final String reference;
}
