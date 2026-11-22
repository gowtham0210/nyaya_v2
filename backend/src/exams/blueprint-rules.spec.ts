import {
  configEvidenceProblems,
  sectionProblems,
  structureProblems,
  timedModeVerdict,
  type SectionDraft,
} from './blueprint-rules.js';

const topic = (
  topicId: string,
  minCount = 0,
  maxCount: number | null = null,
) => ({
  topicId,
  minCount,
  maxCount,
});
const section = (over: Partial<SectionDraft> = {}): SectionDraft => ({
  code: 'cpc',
  position: 1,
  questionCount: 10,
  durationSeconds: null,
  topics: [topic('t1')],
  ...over,
});
const bp = { totalQuestions: 10, durationSeconds: 10_800 };

describe('timedModeVerdict', () => {
  it('allows only a published, official-confirmed blueprint', () => {
    expect(
      timedModeVerdict({
        status: 'published',
        configStatus: 'official_confirmed',
      }),
    ).toEqual({ allowed: true });
  });

  it('refuses a draft or retired blueprint, even if official-confirmed', () => {
    for (const status of ['draft', 'retired'] as const)
      expect(
        timedModeVerdict({ status, configStatus: 'official_confirmed' }),
      ).toMatchObject({ allowed: false, code: 'blueprint_not_published' });
  });

  it('refuses an inferred or unverified blueprint, even if published', () => {
    for (const configStatus of ['inferred', 'unverified'] as const)
      expect(
        timedModeVerdict({ status: 'published', configStatus }),
      ).toMatchObject({
        allowed: false,
        code: 'config_not_official_confirmed',
      });
  });
});

describe('configEvidenceProblems', () => {
  it('asks nothing of an inferred or unverified blueprint', () => {
    for (const configStatus of ['inferred', 'unverified'] as const)
      expect(
        configEvidenceProblems({
          configStatus,
          configSource: null,
          configCheckedOn: null,
        }),
      ).toEqual([]);
  });

  it('wants the document and the date for an official-confirmed one', () => {
    const problems = configEvidenceProblems({
      configStatus: 'official_confirmed',
      configSource: '  ',
      configCheckedOn: null,
    });
    expect(problems.map((p) => p.field)).toEqual([
      'config_source',
      'config_checked_on',
    ]);
    expect(
      configEvidenceProblems({
        configStatus: 'official_confirmed',
        configSource: 'BCI booklet',
        configCheckedOn: '2026-11-18',
      }),
    ).toEqual([]);
  });
});

describe('structureProblems', () => {
  it('flags repeated codes, positions and topics', () => {
    const problems = structureProblems([
      section({ topics: [topic('t1'), topic('t1')] }),
      section(),
    ]);
    expect(problems.map((p) => p.reason)).toEqual([
      'Section codes must be different from each other',
      'Section positions must be different from each other',
      'A topic appears twice in the section',
    ]);
  });
});

describe('sectionProblems', () => {
  it('accepts sections that add up with satisfiable quotas', () => {
    expect(sectionProblems(bp, [section()])).toEqual([]);
    expect(
      sectionProblems(bp, [
        section({
          code: 'a',
          questionCount: 6,
          topics: [topic('t1', 2, 5), topic('t2', 1, 4)],
        }),
        section({
          code: 'b',
          position: 2,
          questionCount: 4,
          topics: [topic('t3')],
        }),
      ]),
    ).toEqual([]);
  });

  it('needs at least one section', () => {
    expect(sectionProblems(bp, [])[0].reason).toMatch(/at least one section/);
  });

  it('needs the sections to add up to the question count', () => {
    const problems = sectionProblems(bp, [section({ questionCount: 9 })]);
    expect(problems[0].reason).toMatch(
      /add up to 9 questions but the blueprint has 10/,
    );
  });

  it('needs minimums that fit and maximums that cover the section', () => {
    expect(
      sectionProblems(bp, [
        section({ topics: [topic('t1', 6), topic('t2', 5)] }),
      ])[0].reason,
    ).toMatch(/minimums add up to 11/);
    expect(
      sectionProblems(bp, [
        section({ topics: [topic('t1', 0, 3), topic('t2', 0, 4)] }),
      ])[0].reason,
    ).toMatch(/maximums add up to 7/);
    // An open-ended topic can always make up the difference.
    expect(
      sectionProblems(bp, [
        section({ topics: [topic('t1', 0, 3), topic('t2')] }),
      ]),
    ).toEqual([]);
  });

  it('needs topics, and a section timer within the exam', () => {
    expect(sectionProblems(bp, [section({ topics: [] })])[0].reason).toMatch(
      /no topics/,
    );
    expect(
      sectionProblems(bp, [section({ durationSeconds: 20_000 })])[0].reason,
    ).toMatch(/longer than the whole exam/);
  });
});
