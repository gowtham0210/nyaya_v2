import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:nyaya/features/journey/domain/journey.dart';
import 'package:nyaya/features/profile/domain/user_profile.dart';
import 'package:nyaya/features/quiz/domain/question.dart';
import 'package:nyaya/features/quiz/domain/quiz_builder.dart';
import 'package:nyaya/features/quiz/domain/quiz_models.dart';

Map<String, dynamic> _load(String code) =>
    jsonDecode(File('assets/questions/$code.json').readAsStringSync()) as Map<String, dynamic>;

void main() {
  final en = _load('en');
  final questions = [for (final q in en['questions'] as List) Question.fromJson(q as Map<String, dynamic>)];
  final bank = QuestionBank(
    questions: questions,
    chapters: {
      for (final e in (en['chapters'] as Map<String, dynamic>).entries)
        e.key: ChapterText(title: e.value['title'] as String, subtitle: e.value['subtitle'] as String),
    },
  );

  group('English question bank', () {
    test('every journey level has questions', () {
      for (final n in JourneyCatalog.nodes.where((n) => n.kind == NodeKind.level)) {
        expect(bank.forLevel(n.chapter.id, n.level), isNotEmpty, reason: n.id);
      }
    });

    test('questions are well-formed and ids unique', () {
      final ids = <String>{};
      for (final q in questions) {
        expect(ids.add(q.id), isTrue, reason: 'duplicate ${q.id}');
        expect(q.options.length, 4, reason: q.id);
        expect(q.answerIndex, inInclusiveRange(0, 3), reason: q.id);
        expect(q.options.toSet().length, 4, reason: 'duplicate option in ${q.id}');
        expect(q.text.trim(), isNotEmpty);
        expect(q.explanation.trim(), isNotEmpty);
      }
    });

    test('every chapter id in the catalog has a title', () {
      for (final c in JourneyCatalog.chapters) {
        expect(bank.chapters[c.id]?.title, isNotEmpty, reason: c.id);
      }
    });
  });

  for (final code in ['hi', 'ta', 'te', 'kn', 'ml']) {
    test('$code translation mirrors English ids and option counts', () {
      final t = _load(code);
      final tq = t['questions'] as List;
      expect(tq.length, questions.length);
      for (var i = 0; i < tq.length; i++) {
        final m = tq[i] as Map<String, dynamic>;
        expect(m['id'], questions[i].id);
        expect((m['options'] as List).length, 4, reason: '${m['id']}');
        expect(m.containsKey('answer'), isFalse, reason: 'answers must come from English');
      }
      // Overlay keeps the English answer key.
      final localized = questions.first.localized(tq.first as Map<String, dynamic>);
      expect(localized.answerIndex, questions.first.answerIndex);
      expect(localized.text, isNot(questions.first.text));
    });
  }

  group('QuizBuilder', () {
    test('Daily Docket is the same set for everyone on a day', () {
      List<String> build(int seed) => QuizBuilder.build(
            request: const QuizRequest(QuizMode.dailyDocket),
            bank: bank,
            reachedChapters: const {'constitution'},
            persona: Persona.aspirant,
            dayKey: '2026-10-22',
            random: Random(seed),
          ).map((q) => q.id).toList();
      expect(build(1), build(2));
      expect(build(1).length, 5);
    });

    test('citizen exam pool avoids the hardest questions', () {
      final qs = QuizBuilder.build(
        request: const QuizRequest(QuizMode.exam),
        bank: bank,
        reachedChapters: const {},
        persona: Persona.citizen,
        dayKey: '2026-10-22',
      );
      expect(qs.length, 20);
      expect(qs.every((q) => q.difficulty <= 2), isTrue);
    });

    test('Case Path uses exactly the level questions', () {
      final qs = QuizBuilder.build(
        request: const QuizRequest(QuizMode.casePath, levelId: 'criminal_2'),
        bank: bank,
        reachedChapters: const {},
        persona: Persona.citizen,
        dayKey: '2026-10-22',
      );
      expect(qs.every((q) => q.chapterId == 'criminal' && q.level == 2), isTrue);
      expect(qs.length, bank.forLevel('criminal', 2).length);
    });
  });
}
