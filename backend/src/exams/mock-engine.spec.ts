import {
  allocateQuotas,
  buildMockPlan,
  MockPlanError,
  seededRandom,
  type MockCandidate,
  type SectionSpec,
} from './mock-engine.js';

let n = 0;
const cand = (
  topicId: string,
  over: Partial<MockCandidate> = {},
): MockCandidate => {
  n++;
  return {
    questionId: `q${n}`,
    versionId: `v${n}`,
    topicId,
    conceptKey: null,
    lockOptionOrder: false,
    optionIds: ['a', 'b', 'c', 'd'],
    ...over,
  };
};
const many = (
  topicId: string,
  count: number,
  over: Partial<MockCandidate> = {},
) => Array.from({ length: count }, () => cand(topicId, over));

const section = (
  topics: SectionSpec['topics'],
  questionCount: number,
  code = 's1',
  position = 1,
): SectionSpec => ({ code, position, questionCount, topics });
const quota = (
  topicId: string,
  min = 0,
  max: number | null = null,
  weight = 1,
) => ({
  topicId,
  min,
  max,
  weight,
});
const countBy = (items: { topic_id: string }[], topicId: string) =>
  items.filter((i) => i.topic_id === topicId).length;

describe('seededRandom', () => {
  it('repeats for the same seed and differs for another', () => {
    const a = seededRandom('seed-1');
    const b = seededRandom('seed-1');
    const c = seededRandom('seed-2');
    const xs = Array.from({ length: 5 }, a);
    expect(Array.from({ length: 5 }, b)).toEqual(xs);
    expect(Array.from({ length: 5 }, c)).not.toEqual(xs);
    expect(xs.every((x) => x >= 0 && x < 1)).toBe(true);
  });
});

describe('allocateQuotas', () => {
  const rnd = () => seededRandom('q');
  it('honours minimums, maximums and the total', () => {
    const r = allocateQuotas(
      { code: 's', questionCount: 10 },
      [
        { ...quota('a', 3, 4), available: 20 },
        { ...quota('b', 0, null), available: 20 },
        { ...quota('c', 2, 2), available: 20 },
      ],
      rnd(),
    );
    if (!('counts' in r)) throw new Error('expected an allocation');
    const c = r.counts;
    expect([...c.values()].reduce((x, y) => x + y, 0)).toBe(10);
    expect(c.get('a')!).toBeGreaterThanOrEqual(3);
    expect(c.get('a')!).toBeLessThanOrEqual(4);
    expect(c.get('c')).toBe(2);
  });

  it('shares the rest by weight', () => {
    const r = allocateQuotas(
      { code: 's', questionCount: 12 },
      [
        { ...quota('a', 0, null, 3), available: 50 },
        { ...quota('b', 0, null, 1), available: 50 },
      ],
      rnd(),
    );
    if (!('counts' in r)) throw new Error('expected an allocation');
    expect(r.counts.get('a')).toBe(9);
    expect(r.counts.get('b')).toBe(3);
  });

  it('moves the surplus when a topic runs out of questions', () => {
    const r = allocateQuotas(
      { code: 's', questionCount: 10 },
      [
        { ...quota('a', 0, null, 1), available: 2 },
        { ...quota('b', 0, null, 1), available: 50 },
      ],
      rnd(),
    );
    if (!('counts' in r)) throw new Error('expected an allocation');
    expect(r.counts.get('a')).toBe(2);
    expect(r.counts.get('b')).toBe(8);
  });

  it('reports a topic that cannot reach its minimum', () => {
    const r = allocateQuotas(
      { code: 's', questionCount: 5 },
      [{ ...quota('a', 4), available: 1 }],
      rnd(),
    );
    expect(r).toEqual({
      shortfalls: [expect.objectContaining({ section: 's', topic_id: 'a' })],
    });
  });

  it('reports minimums that exceed the section, and limits that cannot fill it', () => {
    expect(
      allocateQuotas(
        { code: 's', questionCount: 3 },
        [
          { ...quota('a', 2), available: 9 },
          { ...quota('b', 2), available: 9 },
        ],
        rnd(),
      ),
    ).toHaveProperty('shortfalls');
    expect(
      allocateQuotas(
        { code: 's', questionCount: 10 },
        [{ ...quota('a', 0, 3), available: 9 }],
        rnd(),
      ),
    ).toHaveProperty('shortfalls');
  });
});

describe('buildMockPlan', () => {
  it('fills each section and keeps topic minimums and maximums', () => {
    const candidates = [...many('a', 30), ...many('b', 30), ...many('c', 30)];
    const plan = buildMockPlan({
      sections: [
        section([quota('a', 4, 6), quota('b', 3, 5), quota('c', 0, 2)], 12),
      ],
      candidates,
      seed: 'seed-x',
    });
    const [s] = plan.sections;
    expect(s.questions).toHaveLength(12);
    expect(plan.total_questions).toBe(12);
    expect(countBy(s.questions, 'a')).toBeGreaterThanOrEqual(4);
    expect(countBy(s.questions, 'a')).toBeLessThanOrEqual(6);
    expect(countBy(s.questions, 'b')).toBeGreaterThanOrEqual(3);
    expect(countBy(s.questions, 'b')).toBeLessThanOrEqual(5);
    expect(countBy(s.questions, 'c')).toBeLessThanOrEqual(2);
    expect(s.topic_counts.reduce((x, y) => x + y.count, 0)).toBe(12);
  });

  it('never repeats a question across sections', () => {
    const candidates = many('a', 20);
    const plan = buildMockPlan({
      sections: [
        section([quota('a')], 8, 's1', 1),
        section([quota('a')], 8, 's2', 2),
      ],
      candidates,
      seed: 'seed-y',
    });
    const ids = plan.sections.flatMap((s) =>
      s.questions.map((q) => q.question_id),
    );
    expect(new Set(ids).size).toBe(16);
  });

  it('uses at most one question per concept, even across topics and sections', () => {
    const candidates = [
      ...many('a', 6, { conceptKey: 'art-14' }),
      ...many('b', 6, { conceptKey: 'art-21' }),
      ...many('a', 10),
      ...many('b', 10),
    ];
    for (const seed of ['d1', 'd2', 'd3', 'd4']) {
      const plan = buildMockPlan({
        sections: [section([quota('a'), quota('b')], 10)],
        candidates,
        seed,
      });
      const byId = new Map(candidates.map((c) => [c.questionId, c]));
      const concepts = plan.sections[0].questions
        .map((q) => byId.get(q.question_id)!.conceptKey)
        .filter(Boolean);
      expect(new Set(concepts).size).toBe(concepts.length);
    }
  });

  it('fails when duplicate concepts leave too few questions, instead of returning a short mock', () => {
    const candidates = many('a', 10, { conceptKey: 'same-concept' });
    let error: unknown;
    try {
      buildMockPlan({
        sections: [section([quota('a')], 5)],
        candidates,
        seed: 's',
      });
    } catch (e) {
      error = e;
    }
    expect(error).toBeInstanceOf(MockPlanError);
    expect((error as MockPlanError).code).toBe('mock_pool_insufficient');
    expect((error as MockPlanError).shortfalls.length).toBeGreaterThan(0);
  });

  it('is reproducible for a seed, and varies with another', () => {
    const candidates = many('a', 60);
    const spec = [section([quota('a')], 20)];
    const run = (seed: string) =>
      buildMockPlan({ sections: spec, candidates, seed });
    expect(run('same')).toEqual(run('same'));
    expect(
      run('same').sections[0].questions.map((q) => q.question_id),
    ).not.toEqual(run('other').sections[0].questions.map((q) => q.question_id));
  });

  it('prefers questions the learner has not seen, and falls back to seen ones only when it must', () => {
    const fresh = many('a', 10);
    const old = many('a', 10);
    const seen = new Set(old.map((o) => o.questionId));
    const enough = buildMockPlan({
      sections: [section([quota('a')], 10)],
      candidates: [...old, ...fresh],
      seed: 'u',
      seen,
    });
    expect(enough.seen_used).toBe(0);
    const fresh10 = new Set(fresh.map((f) => f.questionId));
    expect(
      enough.sections[0].questions.every((q) => fresh10.has(q.question_id)),
    ).toBe(true);

    const short = buildMockPlan({
      sections: [section([quota('a')], 15)],
      candidates: [...old, ...fresh],
      seed: 'u',
      seen,
    });
    expect(short.sections[0].questions).toHaveLength(15);
    expect(short.seen_used).toBe(5);
  });

  it('shuffles options unless the version locks their order', () => {
    const free = many('a', 40, { optionIds: ['a', 'b', 'c', 'd', 'e', 'f'] });
    const plan = buildMockPlan({
      sections: [section([quota('a')], 40)],
      candidates: free,
      seed: 'o',
    });
    const orders = plan.sections[0].questions.map((q) =>
      q.option_order.join(''),
    );
    expect(orders.every((o) => [...o].sort().join('') === 'abcdef')).toBe(true);
    expect(orders.some((o) => o !== 'abcdef')).toBe(true);

    const locked = many('a', 10, { lockOptionOrder: true });
    const plan2 = buildMockPlan({
      sections: [section([quota('a')], 10)],
      candidates: locked,
      seed: 'o',
    });
    expect(
      plan2.sections[0].questions.every(
        (q) => q.option_order.join('') === 'abcd' && q.option_order_locked,
      ),
    ).toBe(true);
  });

  it('refuses an empty pool, an empty blueprint, and a section without topics', () => {
    expect(() =>
      buildMockPlan({
        sections: [section([quota('a')], 5)],
        candidates: [],
        seed: 's',
      }),
    ).toThrow(MockPlanError);
    expect(() =>
      buildMockPlan({ sections: [], candidates: many('a', 3), seed: 's' }),
    ).toThrow(MockPlanError);
    expect(() =>
      buildMockPlan({
        sections: [section([], 5)],
        candidates: many('a', 9),
        seed: 's',
      }),
    ).toThrow(MockPlanError);
  });

  it('names the section and topic that fell short', () => {
    try {
      buildMockPlan({
        sections: [
          section([quota('a')], 3, 's1', 1),
          section([quota('b', 5)], 5, 's2', 2),
        ],
        candidates: [...many('a', 5), ...many('b', 2)],
        seed: 's',
      });
      throw new Error('should have thrown');
    } catch (e) {
      expect(e).toBeInstanceOf(MockPlanError);
      expect((e as MockPlanError).shortfalls).toEqual([
        expect.objectContaining({ section: 's2', topic_id: 'b' }),
      ]);
    }
  });
});
