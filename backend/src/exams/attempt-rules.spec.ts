import {
  answerSaveVerdict,
  computeResult,
  remainingSeconds,
  type AttemptRules,
  type ScoredPositionInput,
} from './attempt-rules.js';

const rules = (over: Partial<AttemptRules> = {}): AttemptRules => ({
  marksCorrect: 1,
  negativeMarks: 0.25,
  marksUnanswered: 0,
  withdrawnPolicy: 'unscored',
  withdrawnPolicyConfirmed: false,
  rulesVerified: true,
  passPercentGeneral: 50,
  passPercentReserved: 45,
  ...over,
});

const pos = (
  position: number,
  over: Partial<ScoredPositionInput> = {},
): ScoredPositionInput => ({
  position,
  sectionCode: null,
  sectionPosition: null,
  answerStatus: 'keyed',
  questionType: 'single_select',
  accepted: ['a'],
  marksCorrect: null,
  selected: null,
  ...over,
});

describe('computeResult', () => {
  it('counts correct, incorrect and unanswered, and applies negative marking', () => {
    const r = computeResult(rules(), [
      pos(1, { selected: ['a'] }),
      pos(2, { selected: ['b'] }),
      pos(3),
      pos(4, { selected: ['a'] }),
    ]);
    expect(r.overall).toMatchObject({
      total_positions: 4,
      scorable_positions: 4,
      correct: 2,
      incorrect: 1,
      unanswered: 1,
      marks_obtained: 1.75,
      max_marks: 4,
      percentage: 43.75,
    });
    expect(r.marks_available).toBe(true);
    expect(r.positions.map((p) => p.outcome)).toEqual([
      'correct',
      'incorrect',
      'unanswered',
      'correct',
    ]);
  });

  it('accepts any of several accepted answers', () => {
    const r = computeResult(rules(), [
      pos(1, {
        answerStatus: 'multi_accepted',
        accepted: ['a', 'c'],
        selected: ['c'],
      }),
      pos(2, {
        answerStatus: 'multi_accepted',
        accepted: ['a', 'c'],
        selected: ['b'],
      }),
    ]);
    expect(r.overall.correct).toBe(1);
    expect(r.overall.incorrect).toBe(1);
  });

  it('leaves a withdrawn question out of the marks and the maximum, and marks the result provisional', () => {
    const r = computeResult(rules(), [
      pos(1, { selected: ['a'] }),
      pos(2, { answerStatus: 'withdrawn', accepted: [], selected: ['b'] }),
    ]);
    expect(r.overall).toMatchObject({
      total_positions: 2,
      scorable_positions: 1,
      withdrawn: 1,
      marks_obtained: 1,
      max_marks: 1,
      percentage: 100,
    });
    expect(r.provisional).toBe(true);
    expect(r.provisional_reasons[0]).toMatch(/withdrawn/i);
    expect(r.withdrawn_policy).toBe('unscored');
    expect(r.positions[1].outcome).toBe('withdrawn_unscored');
  });

  it('is not provisional once the unscored rule is confirmed, and awards marks only under award_all', () => {
    const confirmed = computeResult(rules({ withdrawnPolicyConfirmed: true }), [
      pos(1, { answerStatus: 'withdrawn', accepted: [] }),
    ]);
    expect(confirmed.provisional).toBe(false);
    const awarded = computeResult(
      rules({ withdrawnPolicy: 'award_all', withdrawnPolicyConfirmed: true }),
      [
        pos(1, { selected: ['a'] }),
        pos(2, { answerStatus: 'withdrawn', accepted: [] }),
      ],
    );
    expect(awarded.overall).toMatchObject({
      marks_obtained: 2,
      max_marks: 2,
      withdrawn: 1,
    });
    expect(awarded.provisional).toBe(false);
  });

  it('uses each position’s own marks and builds a section breakdown', () => {
    const r = computeResult(rules({ negativeMarks: 0 }), [
      pos(1, {
        sectionCode: 's1',
        sectionPosition: 1,
        marksCorrect: 2,
        selected: ['a'],
      }),
      pos(2, { sectionCode: 's1', sectionPosition: 1, marksCorrect: 2 }),
      pos(3, {
        sectionCode: 's2',
        sectionPosition: 2,
        marksCorrect: 1,
        selected: ['a'],
      }),
    ]);
    expect(r.sections.map((s) => [s.code, s.position])).toEqual([
      ['s1', 1],
      ['s2', 2],
    ]);
    expect(r.sections[0]).toMatchObject({
      correct: 1,
      unanswered: 1,
      marks_obtained: 2,
      max_marks: 4,
    });
    expect(r.sections[1]).toMatchObject({
      correct: 1,
      marks_obtained: 1,
      max_marks: 1,
    });
    expect(r.overall).toMatchObject({ marks_obtained: 3, max_marks: 5 });
  });

  it('reports counts but no marks when the marking rules are not configured', () => {
    const r = computeResult(rules({ negativeMarks: null }), [
      pos(1, { selected: ['a'] }),
      pos(2, { selected: ['b'] }),
    ]);
    expect(r.marks_available).toBe(false);
    expect(r.overall).toMatchObject({
      correct: 1,
      incorrect: 1,
      marks_obtained: null,
      max_marks: null,
      percentage: null,
    });
    expect(r.positions.every((p) => p.marks === null)).toBe(true);
    expect(r.pass.available).toBe(false);
    expect(r.pass.reason).toMatch(/not configured/);
  });

  describe('pass criteria', () => {
    const answers = (right: number, total: number) =>
      Array.from({ length: total }, (_, i) =>
        pos(i + 1, { selected: i < right ? ['a'] : ['b'] }),
      );

    it('judges each category only when verified, complete and not provisional', () => {
      const r = computeResult(rules({ negativeMarks: 0 }), answers(48, 100));
      expect(r.pass).toEqual({
        available: true,
        reason: null,
        percentage: 48,
        general: { threshold: 50, met: false },
        reserved: { threshold: 45, met: true },
      });
    });

    it('makes no claim when the rules are unverified', () => {
      const r = computeResult(
        rules({ rulesVerified: false, negativeMarks: 0 }),
        answers(90, 100),
      );
      expect(r.pass).toMatchObject({
        available: false,
        general: null,
        reserved: null,
      });
      expect(r.pass.reason).toMatch(/verified/);
      expect(r.overall.percentage).toBe(90);
    });

    it('makes no claim without a threshold', () => {
      const r = computeResult(
        rules({
          passPercentGeneral: null,
          passPercentReserved: null,
          negativeMarks: 0,
        }),
        answers(90, 100),
      );
      expect(r.pass.available).toBe(false);
      expect(r.pass.reason).toMatch(/No pass criteria/);
    });

    it('makes no claim while the result is provisional', () => {
      const r = computeResult(rules({ negativeMarks: 0 }), [
        ...answers(9, 10),
        pos(11, { answerStatus: 'withdrawn', accepted: [] }),
      ]);
      expect(r.provisional).toBe(true);
      expect(r.pass.available).toBe(false);
      expect(r.pass.reason).toMatch(/provisional/);
    });

    it('can have only one category configured', () => {
      const r = computeResult(
        rules({ passPercentReserved: null, negativeMarks: 0 }),
        answers(60, 100),
      );
      expect(r.pass.general).toEqual({ threshold: 50, met: true });
      expect(r.pass.reserved).toBeNull();
    });
  });

  it('handles an attempt with nothing scorable', () => {
    const r = computeResult(rules({ withdrawnPolicyConfirmed: true }), [
      pos(1, { answerStatus: 'withdrawn', accepted: [] }),
    ]);
    expect(r.overall).toMatchObject({
      scorable_positions: 0,
      percentage: null,
    });
    expect(r.pass.available).toBe(false);
  });
});

describe('answerSaveVerdict', () => {
  const stored = { seq: 3, selected: ['a'] };
  it('applies a newer counter', () => {
    expect(answerSaveVerdict(stored, { seq: 4, selected: ['b'] })).toEqual({
      apply: true,
    });
    expect(
      answerSaveVerdict(
        { seq: 0, selected: null },
        { seq: 1, selected: ['a'] },
      ),
    ).toEqual({
      apply: true,
    });
  });
  it('ignores an older counter as stale', () => {
    expect(answerSaveVerdict(stored, { seq: 2, selected: ['b'] })).toEqual({
      apply: false,
      reason: 'stale',
    });
  });
  it('treats the same counter and answer as a duplicate, a different answer as a conflict', () => {
    expect(answerSaveVerdict(stored, { seq: 3, selected: ['a'] })).toEqual({
      apply: false,
      reason: 'duplicate',
    });
    expect(answerSaveVerdict(stored, { seq: 3, selected: ['b'] })).toEqual({
      apply: false,
      reason: 'conflict',
    });
    expect(
      answerSaveVerdict({ seq: 2, selected: null }, { seq: 2, selected: null })
        .apply,
    ).toBe(false);
  });
});

describe('remainingSeconds', () => {
  const now = new Date('2026-01-01T10:00:00Z');
  it('counts down, never goes below zero, and is null without a deadline', () => {
    expect(remainingSeconds(new Date('2026-01-01T10:00:30.2Z'), now)).toBe(31);
    expect(remainingSeconds(new Date('2026-01-01T09:00:00Z'), now)).toBe(0);
    expect(remainingSeconds(null, now)).toBeNull();
  });
});
