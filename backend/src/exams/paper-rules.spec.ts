import {
  acceptedOptions,
  answerStatusFor,
  isPermutation,
  publishProblems,
  scorePosition,
  type PaperDraftState,
  type ScoringPolicy,
} from './paper-rules.js';

const policy = (over: Partial<ScoringPolicy> = {}): ScoringPolicy => ({
  marksCorrect: 1,
  negativeMarks: 0,
  marksUnanswered: 0,
  withdrawnPolicy: 'unscored',
  ...over,
});

describe('acceptedOptions', () => {
  const base = {
    answerStatus: 'keyed' as const,
    versionCorrect: ['a'],
    versionAlternates: [],
    latestKey: null,
  };
  it("uses the version's own key without history", () => {
    expect(acceptedOptions(base)).toEqual(['a']);
  });
  it('accepts alternates as well as the correct option', () => {
    expect(
      acceptedOptions({
        ...base,
        answerStatus: 'multi_accepted',
        versionAlternates: ['c'],
      }),
    ).toEqual(['a', 'c']);
  });
  it('lets the newest key-history entry override the version', () => {
    expect(
      acceptedOptions({
        ...base,
        latestKey: { kind: 'revised', acceptedOptionIds: ['b', 'd'] },
      }),
    ).toEqual(['b', 'd']);
  });
  it('accepts nothing for a withdrawn position', () => {
    expect(
      acceptedOptions({
        answerStatus: 'withdrawn',
        versionCorrect: [],
        versionAlternates: [],
        latestKey: { kind: 'withdrawn', acceptedOptionIds: [] },
      }),
    ).toEqual([]);
  });
});

describe('answerStatusFor', () => {
  it('derives withdrawn, keyed and multi_accepted', () => {
    expect(answerStatusFor(null, [], [])).toBe('withdrawn');
    expect(answerStatusFor('v', ['a'], [])).toBe('keyed');
    expect(answerStatusFor('v', ['a'], ['b'])).toBe('multi_accepted');
  });
});

describe('isPermutation', () => {
  it('needs every option exactly once', () => {
    expect(isPermutation(['b', 'a', 'c'], ['a', 'b', 'c'])).toBe(true);
    expect(isPermutation(['a', 'a', 'c'], ['a', 'b', 'c'])).toBe(false);
    expect(isPermutation(['a', 'b'], ['a', 'b', 'c'])).toBe(false);
    expect(isPermutation(['a', 'b', 'x'], ['a', 'b', 'c'])).toBe(false);
  });
});

describe('scorePosition', () => {
  const keyed = {
    answerStatus: 'keyed' as const,
    questionType: 'single_select',
    accepted: ['a'],
  };
  const multi = {
    ...keyed,
    answerStatus: 'multi_accepted' as const,
    accepted: ['a', 'c'],
  };

  it('scores correct, incorrect and unanswered', () => {
    const p = policy({ negativeMarks: 0.25 });
    expect(scorePosition(p, keyed, ['a'])).toEqual({
      outcome: 'correct',
      marks: 1,
      counted: true,
    });
    expect(scorePosition(p, keyed, ['b'])).toEqual({
      outcome: 'incorrect',
      marks: -0.25,
      counted: true,
    });
    expect(scorePosition(p, keyed, null)).toEqual({
      outcome: 'unanswered',
      marks: 0,
      counted: true,
    });
    expect(scorePosition(p, keyed, [])).toMatchObject({
      outcome: 'unanswered',
    });
  });

  it('counts any accepted option as correct', () => {
    expect(scorePosition(policy(), multi, ['a']).outcome).toBe('correct');
    expect(scorePosition(policy(), multi, ['c']).outcome).toBe('correct');
    expect(scorePosition(policy(), multi, ['b']).outcome).toBe('incorrect');
    expect(scorePosition(policy(), multi, ['a', 'c']).outcome).toBe(
      'incorrect',
    );
  });

  it('leaves a withdrawn position out under the interim unscored policy', () => {
    const w = {
      answerStatus: 'withdrawn' as const,
      questionType: 'single_select',
      accepted: [],
    };
    expect(scorePosition(policy(), w, ['a'])).toEqual({
      outcome: 'withdrawn_unscored',
      marks: 0,
      counted: false,
    });
    expect(scorePosition(policy(), w, null).counted).toBe(false);
  });

  it('awards full marks for a withdrawn position only under award_all', () => {
    const w = {
      answerStatus: 'withdrawn' as const,
      questionType: 'single_select',
      accepted: [],
    };
    expect(
      scorePosition(policy({ withdrawnPolicy: 'award_all' }), w, null),
    ).toEqual({
      outcome: 'withdrawn_awarded',
      marks: 1,
      counted: true,
    });
  });
});

describe('publishProblems', () => {
  const ready = (over: Partial<PaperDraftState> = {}): PaperDraftState => ({
    totalQuestions: 3,
    positions: [1, 2, 3].map((position) => ({
      position,
      answerStatus: 'keyed' as const,
      versionProblem: null,
    })),
    withdrawnPolicy: 'unscored',
    withdrawnPolicyConfirmed: false,
    marksCorrect: 1,
    hasWithdrawn: false,
    ...over,
  });

  it('accepts a complete paper', () => {
    expect(publishProblems(ready())).toEqual([]);
  });
  it('names missing positions', () => {
    const p = publishProblems(
      ready({
        positions: [
          { position: 1, answerStatus: 'keyed', versionProblem: null },
        ],
      }),
    );
    expect(p.map((x) => x.reason).join(' ')).toMatch(
      /Positions 2, 3 are missing/,
    );
  });
  it('reports a position whose version is not usable', () => {
    const p = publishProblems(
      ready({
        positions: [
          {
            position: 1,
            answerStatus: 'keyed',
            versionProblem: 'The pinned version is draft',
          },
          { position: 2, answerStatus: 'keyed', versionProblem: null },
          { position: 3, answerStatus: 'keyed', versionProblem: null },
        ],
      }),
    );
    expect(p).toEqual([
      { field: 'positions[1]', reason: 'The pinned version is draft' },
    ]);
  });
  it('lets withdrawn positions through under unscored, but not award_all unconfirmed', () => {
    expect(publishProblems(ready({ hasWithdrawn: true }))).toEqual([]);
    expect(
      publishProblems(
        ready({
          withdrawnPolicy: 'award_all',
          withdrawnPolicyConfirmed: false,
        }),
      ),
    ).toHaveLength(1);
  });
});
