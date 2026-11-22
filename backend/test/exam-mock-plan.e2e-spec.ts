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
  type LicenseStatus,
} from '../src/db/schema.js';
import { startApp, type TestApp } from './helpers.js';

type Session = Awaited<ReturnType<TestApp['signInAs']>>;

interface Fixture {
  topicId: string;
  tagged?: boolean;
  status?: 'published' | 'draft';
  lawRegime?: LawRegime;
  license?: LicenseStatus;
  conceptKey?: string;
  lockOptionOrder?: boolean;
  examOnly?: boolean;
}

describe('randomised mock plans', () => {
  let t: TestApp;
  let admin: Session, editor: Session, learner: Session;
  let topicA: string, topicB: string;

  const as = (s: Session) => ({
    get: (url: string) => t.http().get(url).auth(s.token, { type: 'bearer' }),
    post: (url: string, body: object = {}) =>
      t.http().post(url).auth(s.token, { type: 'bearer' }).send(body),
    put: (url: string, body: object) =>
      t.http().put(url).auth(s.token, { type: 'bearer' }).send(body),
  });

  const newExam = async (slug: string) => {
    const id = newId();
    await t.db
      .insert(exams)
      .values({
        id,
        slug,
        name: slug.toUpperCase(),
        shortName: slug.toUpperCase(),
      });
    return id;
  };

  /** A published, tagged question for [examId]. */
  const add = async (examId: string, f: Fixture) => {
    const questionId = newId();
    const versionId = newId();
    const status = f.status ?? 'published';
    await t.db
      .insert(questions)
      .values({ id: questionId, examOnly: f.examOnly ?? true });
    let sourceId: string | null = null;
    if (f.license) {
      sourceId = newId();
      await t.db.insert(contentSources).values({
        id: sourceId,
        kind: 'third_party',
        title: `Source ${f.license}`,
        licenseStatus: f.license,
      });
    }
    await t.db.insert(questionVersions).values({
      id: versionId,
      questionId,
      versionNo: 1,
      status,
      topicId: f.topicId,
      stem: `SECRET STEM ${versionId.slice(-8)}`,
      explanation: 'SECRET EXPLANATION',
      options: [
        { id: 'a', text: 'One' },
        { id: 'b', text: 'Two' },
        { id: 'c', text: 'Three' },
        { id: 'd', text: 'Four' },
      ],
      correctOptionIds: ['a'],
      validFrom: '2000-01-01',
      lawRegime: f.lawRegime ?? 'neutral',
      contentSourceId: sourceId,
      conceptKey: f.conceptKey ?? null,
      lockOptionOrder: f.lockOptionOrder ?? false,
    });
    if (status === 'published')
      await t.db
        .update(questions)
        .set({ liveVersionId: versionId })
        .where(eq(questions.id, questionId));
    if (f.tagged ?? true)
      await t.db.insert(examQuestionTags).values({ questionId, examId });
    return { questionId, versionId };
  };

  const addMany = (examId: string, n: number, f: Fixture) =>
    Promise.all(Array.from({ length: n }, () => add(examId, f)));

  /** Publishes a blueprint of two sections and makes it the exam's current one. */
  const currentBlueprint = async (
    examId: string,
    over: object = {},
    sections?: object[],
  ) => {
    const bp = (
      await as(admin)
        .post('/v1/admin/exam-blueprints', {
          exam_id: examId,
          code: `bp-${newId().slice(-8)}`,
          duration_seconds: 7200,
          total_questions: 10,
          marks_correct: 1,
          ...over,
        })
        .expect(201)
    ).body;
    await as(admin)
      .put(`/v1/admin/exam-blueprints/${bp.id}/sections`, {
        sections: sections ?? [
          {
            code: 's1',
            name: 'Section one',
            position: 1,
            question_count: 6,
            topics: [
              { topic_id: topicA, min_count: 2, max_count: 6, weight: 1 },
            ],
          },
          {
            code: 's2',
            name: 'Section two',
            position: 2,
            question_count: 4,
            topics: [
              { topic_id: topicB, min_count: 1, max_count: 4, weight: 1 },
            ],
          },
        ],
      })
      .expect(200);
    await as(admin)
      .post(`/v1/admin/exam-blueprints/${bp.id}/publish`)
      .expect(200);
    await as(admin)
      .post(`/v1/admin/exam-blueprints/${bp.id}/make-current`)
      .expect(200);
    return bp.id as string;
  };

  const plan = (examId: string, body: object = {}) =>
    as(admin).post(`/v1/admin/exams/${examId}/mock-plans`, body);
  const questionIds = (body: {
    sections: { questions: { question_id: string }[] }[];
  }) => body.sections.flatMap((s) => s.questions.map((q) => q.question_id));

  beforeAll(async () => {
    t = await startApp();
    [admin, editor, learner] = await Promise.all([
      t.signInAs('admin'),
      t.signInAs('content_editor'),
      t.signInAs('learner'),
    ]);
    topicA = t.topicId;
    topicB = newId();
    const subjectId = newId();
    await t.db
      .insert(subjects)
      .values({ id: subjectId, slug: 'procedure', name: 'Procedure' });
    await t.db
      .insert(topics)
      .values({ id: topicB, subjectId, slug: 'cpc', name: 'CPC' });
  });
  afterAll(() => t.close());

  it('is refused clearly when the exam has no current blueprint', async () => {
    const examId = await newExam('noblueprint');
    await addMany(examId, 12, { topicId: topicA });
    const res = await plan(examId).expect(409);
    expect(res.body.code).toBe('no_current_blueprint');
    const ready = await as(admin)
      .get(`/v1/admin/exams/${examId}/mock-readiness`)
      .expect(409);
    expect(ready.body.code).toBe('no_current_blueprint');
    // A published blueprint that is not designated current does not count.
    const bp = (
      await as(admin)
        .post('/v1/admin/exam-blueprints', {
          exam_id: examId,
          code: 'spare',
          duration_seconds: 600,
          total_questions: 1,
          marks_correct: 1,
        })
        .expect(201)
    ).body;
    await as(admin)
      .put(`/v1/admin/exam-blueprints/${bp.id}/sections`, {
        sections: [
          {
            code: 's',
            name: 'S',
            position: 1,
            question_count: 1,
            topics: [{ topic_id: topicA }],
          },
        ],
      })
      .expect(200);
    await as(admin)
      .post(`/v1/admin/exam-blueprints/${bp.id}/publish`)
      .expect(200);
    await plan(examId).expect(409);
  });

  it('is for staff only', async () => {
    const examId = await newExam('staffonly');
    await t
      .http()
      .post(`/v1/admin/exams/${examId}/mock-plans`)
      .send({})
      .expect(401);
    await as(learner)
      .post(`/v1/admin/exams/${examId}/mock-plans`, {})
      .expect(403);
    await as(learner)
      .get(`/v1/admin/exams/${examId}/mock-readiness`)
      .expect(403);
  });

  describe('from the current blueprint', () => {
    let examId: string;
    let blueprintId: string;

    beforeAll(async () => {
      examId = await newExam('quota');
      await addMany(examId, 12, { topicId: topicA });
      await addMany(examId, 8, { topicId: topicB });
      blueprintId = await currentBlueprint(examId);
    });

    it('fills every section and keeps the topic quotas', async () => {
      const res = await plan(examId).expect(200);
      expect(res.body.blueprint_id).toBe(blueprintId);
      expect(res.body.total_questions).toBe(10);
      const [s1, s2] = res.body.sections;
      expect(s1.questions).toHaveLength(6);
      expect(s2.questions).toHaveLength(4);
      expect(s1.topic_counts).toEqual([{ topic_id: topicA, count: 6 }]);
      expect(
        s1.questions.every((q: { topic_id: string }) => q.topic_id === topicA),
      ).toBe(true);
      expect(
        s2.questions.every((q: { topic_id: string }) => q.topic_id === topicB),
      ).toBe(true);
      expect(new Set(questionIds(res.body)).size).toBe(10);
    });

    it('returns ids and option orders only, never text, keys or explanations', async () => {
      const res = await plan(examId).expect(200);
      const text = JSON.stringify(res.body);
      for (const leak of [
        'SECRET',
        'stem',
        'explanation',
        'correct',
        'accepted',
      ])
        expect(text).not.toContain(leak);
      const q = res.body.sections[0].questions[0];
      expect(Object.keys(q).sort()).toEqual([
        'option_order',
        'option_order_locked',
        'question_id',
        'topic_id',
        'version_id',
      ]);
      expect([...q.option_order].sort()).toEqual(['a', 'b', 'c', 'd']);
    });

    it('can be reproduced from its seed, and differs for another seed', async () => {
      const first = await plan(examId).expect(200);
      expect(typeof first.body.seed).toBe('string');
      const again = await plan(examId, { seed: first.body.seed }).expect(200);
      expect(again.body).toEqual(first.body);
      const other = await plan(examId, { seed: 'a-different-seed' }).expect(
        200,
      );
      expect(questionIds(other.body)).not.toEqual(questionIds(first.body));
    });

    it('prefers questions the learner has not seen', async () => {
      const first = await plan(examId, { seed: 'unseen-1' }).expect(200);
      const seen = questionIds(first.body);
      const next = await plan(examId, {
        seed: 'unseen-2',
        seen_question_ids: seen,
      }).expect(200);
      // 20 questions in the pool, 10 per mock: a fully unseen mock exists.
      expect(next.body.seen_used).toBe(0);
      expect(questionIds(next.body).some((id) => seen.includes(id))).toBe(
        false,
      );
    });

    it('reports readiness with per-topic pool sizes', async () => {
      const res = await as(admin)
        .get(`/v1/admin/exams/${examId}/mock-readiness`)
        .expect(200);
      expect(res.body).toMatchObject({
        ready: true,
        blueprint_id: blueprintId,
        pool_size: 20,
        shortfalls: [],
      });
      expect(res.body.sections[0].topics[0]).toMatchObject({
        topic_id: topicA,
        eligible: 12,
        distinct_concepts: 12,
      });
      await as(editor)
        .get(`/v1/admin/exams/${examId}/mock-readiness`)
        .expect(200);
    });
  });

  describe('eligibility of what it draws', () => {
    it('only draws published, tagged questions of this exam, whatever a historical licence record says', async () => {
      const examId = await newExam('pool');
      const other = await newExam('pool-other');
      const good = await addMany(examId, 5, { topicId: topicA });
      const cleared = await add(examId, {
        topicId: topicA,
        license: 'permission_granted',
      });
      const terms = await add(examId, {
        topicId: topicA,
        license: 'permitted_by_terms',
      });
      const pending = await add(examId, {
        topicId: topicA,
        license: 'pending',
      });
      const blocked = await add(examId, {
        topicId: topicA,
        license: 'blocked',
      });
      const draft = await add(examId, { topicId: topicA, status: 'draft' });
      const untagged = await add(examId, { topicId: topicA, tagged: false });
      const otherExam = await add(other, { topicId: topicA });
      await currentBlueprint(examId, { total_questions: 4 }, [
        {
          code: 's',
          name: 'S',
          position: 1,
          question_count: 4,
          topics: [{ topic_id: topicA }],
        },
      ]);
      const allowed = new Set(
        [...good, cleared, terms, pending, blocked].map((q) => q.questionId),
      );
      const forbidden = [draft, untagged, otherExam].map((q) => q.questionId);
      for (let i = 0; i < 12; i++) {
        const res = await plan(examId, { seed: `pool-seed-${i}` }).expect(200);
        for (const id of questionIds(res.body)) {
          expect(allowed.has(id)).toBe(true);
          expect(forbidden).not.toContain(id);
        }
      }
      const ready = await as(admin)
        .get(`/v1/admin/exams/${examId}/mock-readiness`)
        .expect(200);
      expect(ready.body.pool_size).toBe(9);
    });

    it('leaves out questions only about the old codes by default, even under prefer_new', async () => {
      for (const filter of ['any', 'exclude_old', 'prefer_new'] as const) {
        const examId = await newExam(`old-${filter}`);
        const modern = await addMany(examId, 6, {
          topicId: topicA,
          lawRegime: 'new_codes',
        });
        const both = await add(examId, { topicId: topicA, lawRegime: 'both' });
        const old = await addMany(examId, 6, {
          topicId: topicA,
          lawRegime: 'old_codes',
        });
        await currentBlueprint(
          examId,
          { law_regime_filter: filter, total_questions: 5 },
          [
            {
              code: 's',
              name: 'S',
              position: 1,
              question_count: 5,
              topics: [{ topic_id: topicA }],
            },
          ],
        );
        const oldIds = old.map((o) => o.questionId);
        const okIds = [...modern, both].map((m) => m.questionId);
        for (let i = 0; i < 8; i++) {
          const res = await plan(examId, { seed: `old-seed-${i}` }).expect(200);
          for (const id of questionIds(res.body)) {
            expect(oldIds).not.toContain(id);
            expect(okIds).toContain(id);
          }
        }
      }
    });

    it('includes old-code questions only when the blueprint says include_all', async () => {
      const examId = await newExam('old-include-all');
      await addMany(examId, 2, { topicId: topicA, lawRegime: 'new_codes' });
      const old = await addMany(examId, 8, {
        topicId: topicA,
        lawRegime: 'old_codes',
      });
      await currentBlueprint(
        examId,
        { law_regime_filter: 'include_all', total_questions: 6 },
        [
          {
            code: 's',
            name: 'S',
            position: 1,
            question_count: 6,
            topics: [{ topic_id: topicA }],
          },
        ],
      );
      const res = await plan(examId).expect(200);
      const oldIds = old.map((o) => o.questionId);
      expect(
        questionIds(res.body).filter((id) => oldIds.includes(id)).length,
      ).toBeGreaterThanOrEqual(4);
    });

    it('does not use withdrawn or retired questions', async () => {
      const examId = await newExam('retired');
      const live = await addMany(examId, 4, { topicId: topicA });
      const gone = await add(examId, { topicId: topicA });
      await t.db
        .update(questions)
        .set({ retiredAt: new Date() })
        .where(eq(questions.id, gone.questionId));
      await currentBlueprint(examId, { total_questions: 4 }, [
        {
          code: 's',
          name: 'S',
          position: 1,
          question_count: 4,
          topics: [{ topic_id: topicA }],
        },
      ]);
      const res = await plan(examId).expect(200);
      expect(new Set(questionIds(res.body))).toEqual(
        new Set(live.map((q) => q.questionId)),
      );
    });

    it('does not use ordinary (not exam-only) questions that nobody tagged for the exam', async () => {
      const examId = await newExam('ordinary');
      await addMany(examId, 3, { topicId: topicA });
      await addMany(examId, 6, {
        topicId: topicA,
        tagged: false,
        examOnly: false,
      });
      await currentBlueprint(examId, { total_questions: 5 }, [
        {
          code: 's',
          name: 'S',
          position: 1,
          question_count: 5,
          topics: [{ topic_id: topicA }],
        },
      ]);
      const res = await plan(examId).expect(422);
      expect(res.body.code).toBe('mock_pool_insufficient');
    });
  });

  describe('duplicate concepts and option order', () => {
    it('uses at most one question for a concept', async () => {
      const examId = await newExam('concepts');
      await addMany(examId, 6, { topicId: topicA, conceptKey: 'article-14' });
      await addMany(examId, 6, { topicId: topicA, conceptKey: 'article-21' });
      await addMany(examId, 6, { topicId: topicA });
      const ids = await t.db
        .select({
          q: questionVersions.questionId,
          c: questionVersions.conceptKey,
        })
        .from(questionVersions);
      await currentBlueprint(examId, { total_questions: 8 }, [
        {
          code: 's',
          name: 'S',
          position: 1,
          question_count: 8,
          topics: [{ topic_id: topicA }],
        },
      ]);
      for (let i = 0; i < 10; i++) {
        const res = await plan(examId, { seed: `concept-${i}` }).expect(200);
        const concepts = questionIds(res.body)
          .map((id) => ids.find((x) => x.q === id)!.c)
          .filter((c): c is string => !!c);
        expect(new Set(concepts).size).toBe(concepts.length);
      }
    });

    it('fails clearly instead of returning a short mock when concepts leave too few', async () => {
      const examId = await newExam('concepts-short');
      await addMany(examId, 9, {
        topicId: topicA,
        conceptKey: 'only-one-concept',
      });
      await currentBlueprint(examId, { total_questions: 3 }, [
        {
          code: 's',
          name: 'S',
          position: 1,
          question_count: 3,
          topics: [{ topic_id: topicA }],
        },
      ]);
      const res = await plan(examId).expect(422);
      expect(res.body.code).toBe('mock_pool_insufficient');
      expect(res.body.details.length).toBeGreaterThan(0);
      expect(res.body.sections).toBeUndefined();
    });

    it('keeps the stored option order where a version locks it', async () => {
      const examId = await newExam('locked');
      await addMany(examId, 5, { topicId: topicA, lockOptionOrder: true });
      await currentBlueprint(examId, { total_questions: 5 }, [
        {
          code: 's',
          name: 'S',
          position: 1,
          question_count: 5,
          topics: [{ topic_id: topicA }],
        },
      ]);
      const res = await plan(examId).expect(200);
      for (const q of res.body.sections[0].questions) {
        expect(q.option_order).toEqual(['a', 'b', 'c', 'd']);
        expect(q.option_order_locked).toBe(true);
      }
    });
  });

  describe('when the pool cannot satisfy the blueprint', () => {
    it('names the section and topic that fell short, and returns no plan', async () => {
      const examId = await newExam('short');
      await addMany(examId, 3, { topicId: topicA });
      await currentBlueprint(examId);
      const res = await plan(examId).expect(422);
      expect(res.body.code).toBe('mock_pool_insufficient');
      expect(res.body.details.map((d: { field: string }) => d.field)).toEqual(
        expect.arrayContaining([expect.stringContaining('s1')]),
      );
      expect(res.body.sections).toBeUndefined();
      const ready = await as(admin)
        .get(`/v1/admin/exams/${examId}/mock-readiness`)
        .expect(200);
      expect(ready.body.ready).toBe(false);
      expect(ready.body.shortfalls.length).toBeGreaterThan(0);
    });

    it('fails on a completely empty pool', async () => {
      const examId = await newExam('empty');
      await currentBlueprint(examId);
      const res = await plan(examId).expect(422);
      expect(res.body.code).toBe('mock_pool_insufficient');
    });
  });

  it('does not change anything: no blueprint is published or made current by planning', async () => {
    const examId = await newExam('readonly');
    await addMany(examId, 12, { topicId: topicA });
    await addMany(examId, 8, { topicId: topicB });
    await currentBlueprint(examId);
    const before = await t.db.select().from(examBlueprints);
    await plan(examId).expect(200);
    expect(await t.db.select().from(examBlueprints)).toEqual(before);
  });
});
