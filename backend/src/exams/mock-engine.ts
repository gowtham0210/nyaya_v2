import { createHash } from 'node:crypto';

/*
 * The randomised-mock generator, free of the database so it can be tested
 * and replayed. Given the same sections, candidates, seed and seen-set it
 * always returns the same plan. Anything that cannot be satisfied is an
 * error naming the section and topic; a plan is never returned short.
 */

/** Bump when the algorithm changes in a way that alters the plan for a seed. */
export const MOCK_ALGORITHM_VERSION = 1;

export interface MockCandidate {
  questionId: string;
  versionId: string;
  topicId: string;
  /** Questions testing the same concept share a key; only one is used per mock. */
  conceptKey: string | null;
  lockOptionOrder: boolean;
  optionIds: string[];
}

export interface TopicQuota {
  topicId: string;
  min: number;
  max: number | null;
  weight: number;
}

export interface SectionSpec {
  code: string;
  position: number;
  questionCount: number;
  topics: TopicQuota[];
}

export interface PlannedQuestion {
  question_id: string;
  version_id: string;
  topic_id: string;
  /** Option ids in the order to show; the version's own order when it is locked. */
  option_order: string[];
  option_order_locked: boolean;
}

export interface PlannedSection {
  code: string;
  position: number;
  question_count: number;
  topic_counts: { topic_id: string; count: number }[];
  questions: PlannedQuestion[];
}

export interface MockPlan {
  algorithm_version: number;
  seed: string;
  sections: PlannedSection[];
  total_questions: number;
  /** How many chosen questions the caller had already seen. */
  seen_used: number;
}

export interface MockShortfall {
  section: string;
  topic_id: string | null;
  reason: string;
}

export class MockPlanError extends Error {
  constructor(
    readonly code: 'mock_pool_insufficient' | 'mock_blueprint_invalid',
    message: string,
    readonly shortfalls: MockShortfall[],
  ) {
    super(message);
  }
}

/** A repeatable stream of numbers in [0, 1), from SHA-256 of the seed and a counter. */
export function seededRandom(seed: string): () => number {
  let counter = 0;
  return () => {
    const h = createHash('sha256').update(`${seed}:${counter++}`).digest();
    return h.readUIntBE(0, 6) / 2 ** 48;
  };
}

/** Fisher–Yates over a copy. */
export function shuffled<T>(items: readonly T[], rnd: () => number): T[] {
  const a = [...items];
  for (let i = a.length - 1; i > 0; i--) {
    const j = Math.floor(rnd() * (i + 1));
    [a[i], a[j]] = [a[j], a[i]];
  }
  return a;
}

/**
 * Splits [count] questions across topics: each gets at least its minimum,
 * none more than its maximum or what is available, and the rest is shared by
 * weight (largest remainder, ties broken by the seeded stream). Returns the
 * shortfalls instead when no split exists.
 */
export function allocateQuotas(
  section: Pick<SectionSpec, 'code' | 'questionCount'>,
  topics: (TopicQuota & { available: number })[],
  rnd: () => number,
): { counts: Map<string, number> } | { shortfalls: MockShortfall[] } {
  const shortfalls: MockShortfall[] = [];
  const hi = new Map<string, number>();
  const counts = new Map<string, number>();
  for (const t of topics) {
    const cap = Math.min(t.max ?? Infinity, t.available);
    hi.set(t.topicId, cap);
    if (t.min > t.available) {
      shortfalls.push({
        section: section.code,
        topic_id: t.topicId,
        reason: `needs at least ${t.min} questions but only ${t.available} are usable`,
      });
    }
    counts.set(t.topicId, t.min);
  }
  if (shortfalls.length) return { shortfalls };

  const minTotal = [...counts.values()].reduce((a, b) => a + b, 0);
  if (minTotal > section.questionCount) {
    return {
      shortfalls: [
        {
          section: section.code,
          topic_id: null,
          reason: `topic minimums add up to ${minTotal}, more than the ${section.questionCount} questions in the section`,
        },
      ],
    };
  }
  const capTotal = [...hi.values()].reduce((a, b) => a + b, 0);
  if (capTotal < section.questionCount) {
    return {
      shortfalls: [
        {
          section: section.code,
          topic_id: null,
          reason: `only ${capTotal} usable questions fit the topic limits, but the section needs ${section.questionCount}`,
        },
      ],
    };
  }

  let remaining = section.questionCount - minTotal;
  while (remaining > 0) {
    const open = topics.filter(
      (t) => counts.get(t.topicId)! < hi.get(t.topicId)!,
    );
    const totalWeight = open.reduce((a, t) => a + t.weight, 0);
    const shares = shuffled(open, rnd).map((t) => {
      const exact = (remaining * t.weight) / totalWeight;
      const room = hi.get(t.topicId)! - counts.get(t.topicId)!;
      return { t, whole: Math.min(Math.floor(exact), room), frac: exact % 1 };
    });
    let given = 0;
    for (const s of shares) {
      counts.set(s.t.topicId, counts.get(s.t.topicId)! + s.whole);
      given += s.whole;
    }
    remaining -= given;
    // Hand out what the rounding left, largest remainder first.
    shares.sort((a, b) => b.frac - a.frac);
    for (const s of shares) {
      if (remaining === 0) break;
      if (counts.get(s.t.topicId)! < hi.get(s.t.topicId)!) {
        counts.set(s.t.topicId, counts.get(s.t.topicId)! + 1);
        remaining--;
      }
    }
  }
  return { counts };
}

export interface BuildInput {
  sections: SectionSpec[];
  candidates: MockCandidate[];
  seed: string;
  /** Question ids the learner has met before; used only when needed. */
  seen?: ReadonlySet<string>;
}

/** Builds a plan, or throws MockPlanError naming every shortfall. */
export function buildMockPlan(input: BuildInput): MockPlan {
  const seen = input.seen ?? new Set<string>();
  const problems: MockShortfall[] = input.sections.length
    ? input.sections.flatMap(blueprintProblems)
    : [
        {
          section: '-',
          topic_id: null,
          reason: 'the blueprint has no sections',
        },
      ];
  if (problems.length) {
    throw new MockPlanError(
      'mock_blueprint_invalid',
      'The blueprint cannot produce a mock',
      problems,
    );
  }

  // A topic's usable ceiling can fall when another topic takes a concept first;
  // such topics are capped at what they really delivered and the plan is rebuilt.
  const caps = new Map<string, number>();
  for (let attempt = 0; attempt <= input.sections.length * 8; attempt++) {
    const result = attemptPlan(input, seen, caps);
    if ('plan' in result) return result.plan;
    if (result.capped.length === 0) {
      throw new MockPlanError(
        'mock_pool_insufficient',
        'There are not enough eligible questions to build this mock',
        result.shortfalls,
      );
    }
    for (const c of result.capped) caps.set(c.key, c.count);
  }
  throw new MockPlanError(
    'mock_pool_insufficient',
    'There are not enough eligible questions to build this mock',
    [],
  );
}

function blueprintProblems(s: SectionSpec): MockShortfall[] {
  const out: MockShortfall[] = [];
  if (s.topics.length === 0)
    out.push({
      section: s.code,
      topic_id: null,
      reason: 'the section has no topics to draw from',
    });
  return out;
}

type Attempt =
  | { plan: MockPlan }
  | { capped: { key: string; count: number }[]; shortfalls: MockShortfall[] };

function attemptPlan(
  input: BuildInput,
  seen: ReadonlySet<string>,
  caps: Map<string, number>,
): Attempt {
  const rnd = seededRandom(input.seed);
  const usedQuestions = new Set<string>();
  const usedConcepts = new Set<string>();
  const sections: PlannedSection[] = [];
  const shortfalls: MockShortfall[] = [];
  const capped: { key: string; count: number }[] = [];
  let seenUsed = 0;

  for (const section of [...input.sections].sort(
    (a, b) => a.position - b.position,
  )) {
    // Rank each topic's candidates once: unseen before seen, random within each.
    const ranked = new Map<string, MockCandidate[]>();
    for (const t of section.topics) {
      const mine = input.candidates.filter(
        (c) => c.topicId === t.topicId && !usedQuestions.has(c.questionId),
      );
      const unseen = shuffled(
        mine.filter((c) => !seen.has(c.questionId)),
        rnd,
      );
      const old = shuffled(
        mine.filter((c) => seen.has(c.questionId)),
        rnd,
      );
      ranked.set(t.topicId, [...unseen, ...old]);
    }
    const topics = section.topics.map((t) => {
      const list = ranked.get(t.topicId)!;
      const concepts = new Set<string>();
      let distinct = 0;
      for (const c of list) {
        if (c.conceptKey === null) distinct++;
        else if (
          !usedConcepts.has(c.conceptKey) &&
          !concepts.has(c.conceptKey)
        ) {
          concepts.add(c.conceptKey);
          distinct++;
        }
      }
      const key = `${section.code}:${t.topicId}`;
      return {
        ...t,
        available: Math.min(distinct, caps.get(key) ?? Infinity),
      };
    });

    const alloc = allocateQuotas(section, topics, rnd);
    if ('shortfalls' in alloc) {
      shortfalls.push(...alloc.shortfalls);
      continue;
    }

    const picked: PlannedQuestion[] = [];
    const topicCounts: { topic_id: string; count: number }[] = [];
    for (const t of section.topics) {
      const want = alloc.counts.get(t.topicId) ?? 0;
      let got = 0;
      for (const c of ranked.get(t.topicId)!) {
        if (got === want) break;
        if (c.conceptKey !== null && usedConcepts.has(c.conceptKey)) continue;
        if (usedQuestions.has(c.questionId)) continue;
        usedQuestions.add(c.questionId);
        if (c.conceptKey !== null) usedConcepts.add(c.conceptKey);
        if (seen.has(c.questionId)) seenUsed++;
        got++;
        picked.push({
          question_id: c.questionId,
          version_id: c.versionId,
          topic_id: c.topicId,
          option_order: c.lockOptionOrder
            ? [...c.optionIds]
            : shuffled(c.optionIds, rnd),
          option_order_locked: c.lockOptionOrder,
        });
      }
      if (got < want) {
        capped.push({ key: `${section.code}:${t.topicId}`, count: got });
        shortfalls.push({
          section: section.code,
          topic_id: t.topicId,
          reason: `needs ${want} questions but only ${got} remain after removing duplicate concepts`,
        });
      }
      topicCounts.push({ topic_id: t.topicId, count: got });
    }
    sections.push({
      code: section.code,
      position: section.position,
      question_count: section.questionCount,
      topic_counts: topicCounts,
      questions: shuffled(picked, rnd),
    });
  }

  if (shortfalls.length) return { capped, shortfalls };
  return {
    plan: {
      algorithm_version: MOCK_ALGORITHM_VERSION,
      seed: input.seed,
      sections,
      total_questions: sections.reduce((a, s) => a + s.questions.length, 0),
      seen_used: seenUsed,
    },
  };
}
