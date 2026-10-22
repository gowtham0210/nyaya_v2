import 'package:flutter_test/flutter_test.dart';
import 'package:nyaya/core/config/game_rules.dart';
import 'package:nyaya/core/utils/day.dart';
import 'package:nyaya/features/gamification/domain/daily_policy.dart';
import 'package:nyaya/features/gamification/domain/league.dart';
import 'package:nyaya/features/gamification/domain/xp_calculator.dart';
import 'package:nyaya/features/profile/domain/user_profile.dart';
import 'package:nyaya/features/quiz/domain/question.dart';
import 'package:nyaya/features/quiz/domain/quiz_models.dart';

Question _q(int difficulty, {int answer = 0}) => Question(
      id: 'q$difficulty',
      chapterId: 'constitution',
      level: difficulty,
      difficulty: difficulty,
      text: 'Q',
      options: const ['a', 'b', 'c', 'd'],
      answerIndex: answer,
      explanation: '',
      reference: '',
    );

QuizResult _result(List<bool> correct, {QuizMode mode = QuizMode.casePath, int ms = 30000}) => QuizResult(
      request: QuizRequest(mode, levelId: 'constitution_1'),
      durationMs: 0,
      answers: [
        for (final c in correct) AnswerRecord(question: _q(1), selectedIndex: c ? 0 : 1, elapsedMs: ms),
      ],
    );

void main() {
  group('XpCalculator', () {
    test('slow correct easy answer is worth the base 10', () {
      expect(
        XpCalculator.questionXp(difficulty: 1, elapsedMs: 30000, referenceSeconds: 30, comboBefore: 0),
        10,
      );
    });

    test('instant answer earns the full speed bonus', () {
      expect(XpCalculator.questionXp(difficulty: 1, elapsedMs: 0, referenceSeconds: 30, comboBefore: 0), 15);
    });

    test('combo bonus starts at the 3rd consecutive correct and caps at +6', () {
      double xp(int before) =>
          XpCalculator.questionXp(difficulty: 1, elapsedMs: 30000, referenceSeconds: 30, comboBefore: before);
      expect(xp(1), 10);
      expect(xp(2), 12);
      expect(xp(3), 14);
      expect(xp(4), 16);
      expect(xp(10), 16);
    });

    test('difficulty multiplies question XP', () {
      expect(XpCalculator.questionXp(difficulty: 3, elapsedMs: 30000, referenceSeconds: 30, comboBefore: 0), 15);
    });

    test('session XP adds completion/perfect bonuses and streak multiplier', () {
      final perfect = XpCalculator.session(result: _result([true, true, true]), streak: 0);
      // 10 + 10 + 12 (combo) + 10 completion + 10 perfect
      expect(perfect.total, 52);
      final withStreak = XpCalculator.session(result: _result([true, true, true]), streak: 7);
      expect(withStreak.total, (52 * 1.2).round());
    });

    test('XP is never negative even with all wrong answers', () {
      final r = XpCalculator.session(result: _result([false, false]), streak: 0);
      expect(r.total, GameRules.xpCompletionBonus);
    });

    test('replaying a mastered level pays half', () {
      final r = XpCalculator.session(result: _result([true]), streak: 0, isReplayOfMastered: true);
      expect(r.total, ((10 + 10 + 10) * 0.5).round());
    });

    test('duel points are 500–1000 for correct, 0 for wrong', () {
      expect(XpCalculator.duelPoints(correct: true, elapsedMs: 0, limitSeconds: 15), 1000);
      expect(XpCalculator.duelPoints(correct: true, elapsedMs: 15000, limitSeconds: 15), 500);
      expect(XpCalculator.duelPoints(correct: false, elapsedMs: 0, limitSeconds: 15), 0);
    });
  });

  group('QuizResult stars', () {
    test('thresholds 50/80/100%', () {
      expect(_result([true, false, false]).stars, 0);
      expect(_result([true, true, false, false]).stars, 1);
      expect(_result([true, true, true, true, false]).stars, 2);
      expect(_result([true, true]).stars, 3);
    });
  });

  group('DailyPolicy', () {
    final monday = DateTime(2026, 10, 19, 9);

    test('new day resets energy and daily counters', () {
      const p = UserProfile(energy: 0, energyDay: '2026-10-18', quizzesToday: 3, aiMessagesToday: 5);
      final r = DailyPolicy.rollover(p, monday);
      expect(r.energy, GameRules.freeDailyEnergy);
      expect(r.energyDay, '2026-10-19');
      expect(r.quizzesToday, 0);
      expect(r.aiMessagesToday, 0);
    });

    test('same day does not refill energy', () {
      final p = UserProfile(energy: 1, energyDay: Day.key(monday), weekId: Day.weekKey(monday));
      expect(DailyPolicy.rollover(p, monday).energy, 1);
    });

    test('missing a day breaks the streak without freezes', () {
      const p = UserProfile(streak: 9, lastActiveDay: '2026-10-17');
      expect(DailyPolicy.rollover(p, monday).streak, 0);
    });

    test('a freeze protects one missed day', () {
      const p = UserProfile(streak: 9, lastActiveDay: '2026-10-17', streakFreezes: 1);
      final r = DailyPolicy.rollover(p, monday);
      expect(r.streak, 9);
      expect(r.streakFreezes, 0);
      expect(r.frozenDays, contains('2026-10-18'));
      final (after, _, extended) = DailyPolicy.onQuizCompleted(r, monday);
      expect(extended, isTrue);
      expect(after.streak, 10);
    });

    test('first quiz of the day extends streak once and hits milestones', () {
      const p = UserProfile(streak: 2, lastActiveDay: '2026-10-18', coins: 0);
      final (a, milestone, extended) = DailyPolicy.onQuizCompleted(p, monday);
      expect(extended, isTrue);
      expect(a.streak, 3);
      expect(milestone, 3);
      expect(a.coins, GameRules.streakMilestones[3]);
      final (b, _, again) = DailyPolicy.onQuizCompleted(a, monday);
      expect(again, isFalse);
      expect(b.streak, 3);
    });

    test('week close records an outcome and resets weekly XP', () {
      final lastWeek = Day.weekKey(monday.subtract(const Duration(days: 7)));
      final p = UserProfile(weekId: lastWeek, weeklyXp: 100000, leagueTier: 1, name: 'Test');
      final r = DailyPolicy.rollover(p, monday);
      expect(r.weekId, Day.weekKey(monday));
      expect(r.weeklyXp, 0);
      expect(r.pendingLeagueOutcome?.rank, 1);
      expect(r.leagueTier, 2);
    });
  });

  group('Leagues', () {
    test('promotion and demotion zones', () {
      expect(Leagues.nextTier(1, 1), 2);
      expect(Leagues.nextTier(1, 30), 1, reason: 'no demotion in entry tiers');
      expect(Leagues.nextTier(5, 7), 6);
      expect(Leagues.nextTier(5, 8), 5);
      expect(Leagues.nextTier(5, 26), 4);
      expect(Leagues.nextTier(8, 1), 8, reason: 'top tier cannot promote');
    });

    test('simulated cohort is deterministic and contains the user', () {
      List<LeagueEntry> make() =>
          LeagueSimulator.cohort(weekId: '2026-W43', tier: 3, userXp: 120, userName: 'Me', progress: 0.5);
      final a = make();
      final b = make();
      expect(a.length, Leagues.cohortSize);
      expect(a.map((e) => e.xp).toList(), b.map((e) => e.xp).toList());
      expect(a.where((e) => e.isUser).length, 1);
    });

    test('Elo moves toward the result', () {
      expect(Elo.update(rating: 1000, opponent: 1000, score: 1, k: 32), 1016);
      expect(Elo.update(rating: 1000, opponent: 1000, score: 0, k: 32), 984);
    });
  });

  group('Day', () {
    test('week key uses ISO weeks', () {
      expect(Day.weekKey(DateTime(2026, 10, 22)), '2026-W43');
      expect(Day.weekKey(DateTime(2027, 1, 1)), '2026-W53');
    });

    test('days between handles month boundaries', () {
      expect(Day.between('2026-10-31', '2026-11-02'), 2);
    });
  });
}
