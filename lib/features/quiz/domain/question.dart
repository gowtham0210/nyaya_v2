import 'package:flutter/foundation.dart';

@immutable
class Question {
  const Question({
    required this.id,
    required this.chapterId,
    required this.level,
    required this.difficulty,
    required this.text,
    required this.options,
    required this.answerIndex,
    required this.explanation,
    required this.reference,
  });

  final String id;
  final String chapterId;
  final int level;
  final int difficulty;
  final String text;
  final List<String> options;
  final int answerIndex;
  final String explanation;
  final String reference;

  factory Question.fromJson(Map<String, dynamic> j) => Question(
        id: j['id'] as String,
        chapterId: j['chapter'] as String,
        level: j['level'] as int,
        difficulty: j['difficulty'] as int,
        text: j['question'] as String,
        options: (j['options'] as List<dynamic>).cast<String>(),
        answerIndex: j['answer'] as int,
        explanation: j['explanation'] as String? ?? '',
        reference: j['reference'] as String? ?? '',
      );

  /// Overlays translated text while keeping the authoritative English answer
  /// key, chapter and difficulty.
  Question localized(Map<String, dynamic>? t) {
    if (t == null) return this;
    final opts = (t['options'] as List<dynamic>?)?.cast<String>();
    return Question(
      id: id,
      chapterId: chapterId,
      level: level,
      difficulty: difficulty,
      text: t['question'] as String? ?? text,
      options: opts != null && opts.length == options.length ? opts : options,
      answerIndex: answerIndex,
      explanation: t['explanation'] as String? ?? explanation,
      reference: t['reference'] as String? ?? reference,
    );
  }
}

@immutable
class ChapterText {
  const ChapterText({required this.title, required this.subtitle});

  final String title;
  final String subtitle;
}

/// All questions + chapter names for one language.
class QuestionBank {
  QuestionBank({required this.questions, required this.chapters})
      : _byChapterLevel = _index(questions);

  final List<Question> questions;
  final Map<String, ChapterText> chapters;
  final Map<String, List<Question>> _byChapterLevel;

  static Map<String, List<Question>> _index(List<Question> qs) {
    final map = <String, List<Question>>{};
    for (final q in qs) {
      map.putIfAbsent('${q.chapterId}_${q.level}', () => []).add(q);
    }
    return map;
  }

  List<Question> forLevel(String chapterId, int level) =>
      _byChapterLevel['${chapterId}_$level'] ?? const [];

  List<Question> forChapters(Set<String> chapterIds) =>
      questions.where((q) => chapterIds.contains(q.chapterId)).toList();

  Question? byId(String id) {
    for (final q in questions) {
      if (q.id == id) return q;
    }
    return null;
  }
}
