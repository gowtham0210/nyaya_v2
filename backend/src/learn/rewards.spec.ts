import { describe, expect, it } from 'vitest';
import {
  questionXp,
  sessionXp,
  stars,
  type AnsweredQuestion,
} from './rewards.js';
import { milestoneFor, streakOn } from './streak.js';

// Cases copied from the app's test/gamification_test.dart, so both agree.
const slow = (correct: boolean): AnsweredQuestion => ({
  correct,
  difficulty: 1,
  elapsedMs: 30_000,
});
const xp = (before: number) =>
  questionXp({
    difficulty: 1,
    elapsedMs: 30_000,
    referenceSeconds: 30,
    comboBefore: before,
  });
const session = (
  answers: boolean[],
  opts: Partial<Parameters<typeof sessionXp>[0]> = {},
) =>
  sessionXp({
    mode: 'case_path',
    questions: answers.map(slow),
    streak: 0,
    isReplayOfMastered: false,
    ...opts,
  }).total;

describe('XP', () => {
  it('pays 10 for a slow correct easy answer and 15 for an instant one', () => {
    expect(xp(0)).toBe(10);
    expect(
      questionXp({
        difficulty: 1,
        elapsedMs: 0,
        referenceSeconds: 30,
        comboBefore: 0,
      }),
    ).toBe(15);
  });

  it('adds a combo bonus from the 3rd correct in a row, up to +6', () => {
    expect([1, 2, 3, 4, 10].map(xp)).toEqual([10, 12, 14, 16, 16]);
  });

  it('multiplies by difficulty', () => {
    expect(
      questionXp({
        difficulty: 3,
        elapsedMs: 30_000,
        referenceSeconds: 30,
        comboBefore: 0,
      }),
    ).toBe(15);
  });

  it('adds completion and perfect bonuses, then the streak multiplier', () => {
    expect(session([true, true, true])).toBe(52);
    expect(session([true, true, true], { streak: 7 })).toBe(
      Math.round(52 * 1.2),
    );
  });

  it('is never negative', () => {
    expect(session([false, false])).toBe(10);
  });

  it('pays half for replaying a mastered level and 1.25x for the docket', () => {
    expect(session([true], { isReplayOfMastered: true })).toBe(15);
    expect(session([true], { mode: 'daily_docket' })).toBe(
      Math.round(30 * 1.25),
    );
  });

  it('gives duels XP for correct answers only, with no win bonus', () => {
    expect(session([true, false], { mode: 'duel' })).toBe(20);
  });
});

describe('stars', () => {
  it('uses the 50/80/100 % thresholds', () => {
    expect([stars(1, 3), stars(2, 4), stars(4, 5), stars(2, 2)]).toEqual([
      0, 1, 2, 3,
    ]);
  });
});

describe('streak', () => {
  it('counts days in a row and restarts after a missed day without freezes', () => {
    expect(streakOn(['2026-10-01', '2026-10-02'], '2026-10-02').streak).toBe(2);
    expect(streakOn(['2026-10-01', '2026-10-02'], '2026-10-03').streak).toBe(2);
    expect(streakOn(['2026-10-01', '2026-10-02'], '2026-10-04').streak).toBe(0);
    const restarted = streakOn(
      ['2026-10-01', '2026-10-02', '2026-10-05'],
      '2026-10-05',
    );
    expect(restarted).toMatchObject({ streak: 1, longest: 2 });
  });

  it('earns a freeze at 7 days that covers one missed day', () => {
    const week = Array.from({ length: 7 }, (_, i) => `2026-10-0${i + 1}`);
    expect(streakOn(week, '2026-10-07')).toMatchObject({
      streak: 7,
      freezes: 1,
    });
    const afterGap = streakOn([...week, '2026-10-09'], '2026-10-09');
    expect(afterGap).toMatchObject({
      streak: 8,
      freezes: 0,
      frozenDays: ['2026-10-08'],
    });
    // Two missed days need two freezes.
    expect(streakOn([...week, '2026-10-10'], '2026-10-10').streak).toBe(1);
  });

  it('names milestones', () => {
    expect([2, 3, 7, 8].map(milestoneFor)).toEqual([null, 3, 7, null]);
  });
});
