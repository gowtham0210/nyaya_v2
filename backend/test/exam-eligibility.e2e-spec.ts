import { eq } from 'drizzle-orm';
import { newId } from '../src/core/ids.js';
import {
  contentSources,
  examBlueprints,
  examQuestionTags,
  exams,
  questions,
  questionVersions,
  subjects,
  topics,
  type LawRegime,
  type LawRegimeFilter,
  type LicenseStatus,
} from '../src/db/schema.js';
import { examEligible, examPool } from '../src/exams/exam-eligibility.js';
import { ExamEligibilityService } from '../src/exams/exam-eligibility.service.js';
import { startApp, type TestApp } from './helpers.js';

type Session = Awaited<ReturnType<TestApp['signInAs']>>;

interface Fixture {
  tagged?: boolean;
  examOnly?: boolean;
  status?: 'published' | 'draft';
  retired?: boolean;
  language?: string;
  validFrom?: string | null;
  validTo?: string | null;
  topicId?: string;
  lawRegime?: LawRegime;
  license?: LicenseStatus | 'none';
  tagExam?: string;
}

describe('which questions a randomised mock may draw from', () => {
  let t: TestApp;
  let service: ExamEligibilityService;
  let examId: string;
  let otherExamId: string;
  let inactiveTopicId: string;
  let analyst: Session, learner: Session;
  const all: string[] = [];

  const options = (lawRegimeFilter: LawRegimeFilter = 'any') => ({
    language: 'en',
    now: new Date(),
    lawRegimeFilter,
  });

  const addSource = async (status: LicenseStatus) => {
    const id = newId();
    await t.db.insert(contentSources).values({
      id,
      kind: 'third_party',
      title: `Source ${status}`,
      licenseStatus: status,
    });
    return id;
  };

  const add = async (f: Fixture = {}) => {
    const questionId = newId();
    const versionId = newId();
    const status = f.status ?? 'published';
    await t.db.insert(questions).values({
      id: questionId,
      examOnly: f.examOnly ?? false,
      retiredAt: f.retired ? new Date() : null,
    });
    await t.db.insert(questionVersions).values({
      id: versionId,
      questionId,
      versionNo: 1,
      status: f.retired ? 'retired' : status,
      topicId: f.topicId ?? t.topicId,
      language: f.language ?? 'en',
      stem: `Question ${versionId.slice(-6)}`,
      options: [
        { id: 'a', text: 'Right' },
        { id: 'b', text: 'Wrong' },
      ],
      correctOptionIds: ['a'],
      validFrom: f.validFrom === undefined ? '2000-01-01' : f.validFrom,
      validTo: f.validTo ?? null,
      lawRegime: f.lawRegime ?? 'neutral',
      contentSourceId:
        f.license && f.license !== 'none' ? await addSource(f.license) : null,
    });
    if (status === 'published' && !f.retired)
      await t.db
        .update(questions)
        .set({ liveVersionId: versionId })
        .where(eq(questions.id, questionId));
    if (f.tagged ?? true)
      await t.db
        .insert(examQuestionTags)
        .values({ questionId, examId: f.tagExam ?? examId });
    all.push(questionId);
    return questionId;
  };

  const explain = (questionId: string, filter?: LawRegimeFilter) =>
    service.explain(examId, questionId, options(filter));
  const codes = async (questionId: string, filter?: LawRegimeFilter) =>
    (await explain(questionId, filter)).reasons.map((r) => r.code);

  beforeAll(async () => {
    t = await startApp();
    service = t.app.get(ExamEligibilityService);
    examId = newId();
    otherExamId = newId();
    await t.db.insert(exams).values([
      { id: examId, slug: 'aibe', name: 'AIBE', shortName: 'AIBE' },
      { id: otherExamId, slug: 'clat', name: 'CLAT', shortName: 'CLAT' },
    ]);
    const subjectId = newId();
    inactiveTopicId = newId();
    await t.db
      .insert(subjects)
      .values({ id: subjectId, slug: 'idle', name: 'Idle', isActive: true });
    await t.db.insert(topics).values({
      id: inactiveTopicId,
      subjectId,
      slug: 'idle-topic',
      name: 'Idle topic',
      isActive: false,
    });
    [analyst, learner] = await Promise.all([
      t.signInAs('analyst'),
      t.signInAs('learner'),
    ]);
  });
  afterAll(() => t.close());

  it('draws a tagged ordinary question, and refuses an untagged one', async () => {
    const tagged = await add();
    const untagged = await add({ tagged: false });
    expect(await explain(tagged)).toMatchObject({
      eligible: true,
      examOnly: false,
      reasons: [],
    });
    expect(await codes(untagged)).toEqual(['no_exam_tag']);
  });

  it('draws a tagged exam-only question, and refuses an untagged one', async () => {
    const tagged = await add({ examOnly: true });
    const untagged = await add({ examOnly: true, tagged: false });
    expect(await explain(tagged)).toMatchObject({
      eligible: true,
      examOnly: true,
    });
    expect(await codes(untagged)).toEqual(['no_exam_tag']);
  });

  it('does not count a tag for a different exam', async () => {
    const q = await add({ tagExam: otherExamId });
    expect(await codes(q)).toEqual(['no_exam_tag']);
    expect((await service.explain(otherExamId, q, options())).eligible).toBe(
      true,
    );
  });

  it('explains every reason a question is left out', async () => {
    expect(await codes(await add({ status: 'draft' }))).toEqual([
      'not_published',
    ]);
    expect(await codes(await add({ retired: true }))).toEqual([
      'retired',
      'not_published',
    ]);
    expect(await codes(await add({ language: 'hi' }))).toEqual([
      'language_mismatch',
    ]);
    expect(await codes(await add({ validFrom: '2999-01-01' }))).toEqual([
      'not_yet_valid',
    ]);
    expect(await codes(await add({ validFrom: null }))).toEqual([
      'not_yet_valid',
    ]);
    expect(await codes(await add({ topicId: inactiveTopicId }))).toEqual([
      'topic_inactive',
    ]);
    // Several at once are all reported.
    expect(await codes(await add({ tagged: false, language: 'hi' }))).toEqual([
      'no_exam_tag',
      'language_mismatch',
    ]);
    expect(await codes(newId())).toEqual(['question_not_found']);
  });

  it('keeps a question that has stopped being in force: an exam may still test it', async () => {
    const expired = await add({ validTo: '2001-01-01' });
    expect((await explain(expired)).eligible).toBe(true);
  });

  it('draws content whatever a historical licence record says', async () => {
    for (const license of [
      'none',
      'permission_granted',
      'permitted_by_terms',
      'pending',
      'blocked',
    ] as const)
      expect((await explain(await add({ license }))).eligible).toBe(true);
  });

  it('is not affected when a historical licence record changes later', async () => {
    const q = await add({ license: 'permission_granted' });
    expect((await explain(q)).eligible).toBe(true);
    await t.db.update(contentSources).set({ licenseStatus: 'blocked' });
    expect((await explain(q)).eligible).toBe(true);
    expect(await codes(q)).toEqual([]);
    await t.db
      .update(contentSources)
      .set({ licenseStatus: 'permission_granted' });
  });

  describe('law regime rule', () => {
    const everyRule = [
      'any',
      'exclude_old',
      'prefer_new',
      'include_all',
    ] as const;

    it('lets new-code, mixed and neutral questions through under every rule', async () => {
      for (const lawRegime of ['new_codes', 'both', 'neutral'] as const) {
        const q = await add({ lawRegime });
        for (const filter of everyRule)
          expect((await explain(q, filter)).eligible).toBe(true);
      }
    });

    it('leaves old-code-only questions out of a random mock by default', async () => {
      const q = await add({ lawRegime: 'old_codes' });
      // The default rule, with nothing chosen.
      expect(await codes(q)).toEqual(['law_regime_excluded']);
      expect(await codes(q, 'any')).toEqual(['law_regime_excluded']);
      expect(await codes(q, 'exclude_old')).toEqual(['law_regime_excluded']);
    });

    it('does not read prefer_new as permission to include them', async () => {
      const q = await add({ lawRegime: 'old_codes' });
      expect(await codes(q, 'prefer_new')).toEqual(['law_regime_excluded']);
    });

    it('includes them only under the explicit include_all rule', async () => {
      const q = await add({ lawRegime: 'old_codes' });
      expect((await explain(q, 'include_all')).eligible).toBe(true);
    });
  });

  it('builds a pool that agrees with the explanation for every question', async () => {
    for (const filter of [
      'any',
      'exclude_old',
      'prefer_new',
      'include_all',
    ] as const) {
      const rows = (await examPool(t.db, { id: questions.id }).where(
        examEligible(examId, options(filter)),
      )) as unknown as { id: string }[];
      const pool = new Set(rows.map((r) => r.id));
      const expected = new Set<string>();
      for (const id of all)
        if ((await explain(id, filter)).eligible) expected.add(id);
      expect([...pool].sort()).toEqual([...expected].sort());
      expect(await service.poolSize(examId, options(filter))).toBe(
        expected.size,
      );
    }
  });

  it('never lets an untagged question into the pool', async () => {
    const before = await service.poolSize(examId, options());
    await add({ tagged: false });
    await add({ tagged: false, examOnly: true });
    expect(await service.poolSize(examId, options())).toBe(before);
    await add();
    expect(await service.poolSize(examId, options())).toBe(before + 1);
  });

  describe('the staff endpoint', () => {
    const url = (qid: string, query = '') =>
      `/v1/admin/exams/${examId}/questions/${qid}/eligibility${query}`;

    it('is for staff, not learners', async () => {
      const q = await add();
      await t.http().get(url(q)).expect(401);
      await t
        .http()
        .get(url(q))
        .auth(learner.token, { type: 'bearer' })
        .expect(403);
      const res = await t
        .http()
        .get(url(q))
        .auth(analyst.token, { type: 'bearer' })
        .expect(200);
      expect(res.body).toEqual({
        eligible: true,
        exam_only: false,
        law_regime: 'neutral',
        law_regime_filter: 'any',
        blueprint_id: null,
        reasons: [],
      });
    });

    it("applies a blueprint's law-regime rule, and only a blueprint of this exam", async () => {
      const q = await add({ lawRegime: 'old_codes' });
      const bp = (
        code: string,
        exam: string,
        lawRegimeFilter: LawRegimeFilter,
        published = false,
      ) => {
        const id = newId();
        return t.db
          .insert(examBlueprints)
          .values({
            id,
            examId: exam,
            code,
            durationSeconds: 600,
            totalQuestions: 10,
            marksCorrect: '1',
            lawRegimeFilter,
            status: published ? 'published' : 'draft',
          })
          .then(() => id);
      };
      const exclude = await bp('exclude', examId, 'exclude_old');
      const prefer = await bp('prefer', examId, 'prefer_new');
      const include = await bp('include', examId, 'include_all', true);
      const foreign = await bp('foreign', otherExamId, 'include_all');
      const get = (query: string) =>
        t.http().get(url(q, query)).auth(analyst.token, { type: 'bearer' });

      // No blueprint named and none current: the default rule leaves it out.
      expect((await get('').expect(200)).body).toMatchObject({
        eligible: false,
        law_regime_filter: 'any',
        blueprint_id: null,
        reasons: [{ code: 'law_regime_excluded' }],
      });
      for (const id of [exclude, prefer])
        expect(
          (await get(`?blueprint_id=${id}`).expect(200)).body.reasons[0].code,
        ).toBe('law_regime_excluded');
      expect(
        (await get(`?blueprint_id=${include}`).expect(200)).body,
      ).toMatchObject({
        eligible: true,
        law_regime_filter: 'include_all',
        blueprint_id: include,
      });
      await get(`?blueprint_id=${foreign}`).expect(404);

      // With a current blueprint, it is the one used when none is named.
      await t.db
        .update(examBlueprints)
        .set({ isCurrent: true })
        .where(eq(examBlueprints.id, include));
      expect((await get('').expect(200)).body).toMatchObject({
        eligible: true,
        law_regime_filter: 'include_all',
        blueprint_id: include,
      });
      await t.db
        .update(examBlueprints)
        .set({ isCurrent: false })
        .where(eq(examBlueprints.id, include));
      await t
        .http()
        .get(`/v1/admin/exams/${newId()}/questions/${q}/eligibility`)
        .auth(analyst.token, { type: 'bearer' })
        .expect(404);
    });
  });
});
