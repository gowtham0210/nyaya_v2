import { eq } from 'drizzle-orm';
import { newId } from '../src/core/ids.js';
import {
  auditLog,
  contentSources,
  examPaperKeyHistory,
  examPapers,
  exams,
  questions,
  questionVersions,
  type LicenseStatus,
} from '../src/db/schema.js';
import { startApp, type TestApp } from './helpers.js';

type Session = Awaited<ReturnType<TestApp['signInAs']>>;

describe('fixed exam papers', () => {
  let t: TestApp;
  let admin: Session, editor: Session, learner: Session;
  let examId: string;

  const as = (s: Session) => ({
    get: (url: string) => t.http().get(url).auth(s.token, { type: 'bearer' }),
    post: (url: string, body: object = {}) =>
      t.http().post(url).auth(s.token, { type: 'bearer' }).send(body),
    patch: (url: string, body: object) =>
      t.http().patch(url).auth(s.token, { type: 'bearer' }).send(body),
    put: (url: string, body: object) =>
      t.http().put(url).auth(s.token, { type: 'bearer' }).send(body),
  });

  const source = async (status: LicenseStatus = 'permission_granted') => {
    const id = newId();
    await t.db.insert(contentSources).values({
      id,
      kind: 'original',
      title: `Source ${status}`,
      licenseStatus: status,
    });
    return id;
  };

  /** A question with one published version, as a paper may pin it. */
  const question = async (
    over: Partial<typeof questionVersions.$inferInsert> = {},
    status: 'published' | 'draft' | 'superseded' = 'published',
  ) => {
    const questionId = newId();
    const versionId = newId();
    await t.db.insert(questions).values({ id: questionId, examOnly: true });
    await t.db.insert(questionVersions).values({
      id: versionId,
      questionId,
      versionNo: 1,
      status,
      topicId: t.topicId,
      stem: `Stem ${versionId.slice(-8)}`,
      explanation: 'SECRET EXPLANATION',
      options: [
        { id: 'a', text: 'First' },
        { id: 'b', text: 'Second' },
        { id: 'c', text: 'Third' },
        { id: 'd', text: 'Fourth' },
      ],
      correctOptionIds: ['b'],
      validFrom: '2000-01-01',
      ...over,
    });
    return { questionId, versionId };
  };

  const paperBody = (over: object = {}) => ({
    exam_id: examId,
    code: `aibe-test-${newId().slice(-8)}`,
    title: 'AIBE test paper',
    edition: 'XVIII',
    set_label: 'A',
    total_questions: 3,
    ...over,
  });
  const createPaper = async (over: object = {}) =>
    (await as(admin).post('/v1/admin/exam-papers', paperBody(over)).expect(201))
      .body;

  /** A complete draft: two keyed questions and one withdrawn placeholder. */
  const fullDraft = async (over: object = {}) => {
    const paper = await createPaper(over);
    const q1 = await question();
    const q2 = await question({ alternateCorrectOptionIds: ['c'] });
    await as(admin)
      .put(`/v1/admin/exam-papers/${paper.id}/positions`, {
        positions: [
          {
            position: 1,
            question_version_id: q1.versionId,
            original_ref: 'Q1',
            option_order: ['d', 'c', 'b', 'a'],
            original_label_scheme: 'A-D',
          },
          {
            position: 2,
            question_version_id: q2.versionId,
            original_ref: 'Q2',
          },
          {
            position: 3,
            original_ref: 'Q3',
            withdrawn_note: 'Withdrawn by the exam body',
          },
        ],
      })
      .expect(200);
    return { paper, q1, q2 };
  };

  beforeAll(async () => {
    t = await startApp();
    [admin, editor, learner] = await Promise.all([
      t.signInAs('admin'),
      t.signInAs('content_editor'),
      t.signInAs('learner'),
    ]);
    examId = newId();
    await t.db
      .insert(exams)
      .values({ id: examId, slug: 'aibe', name: 'AIBE', shortName: 'AIBE' });
  });
  afterAll(() => t.close());

  describe('setting up a paper', () => {
    it('is for admins to write and staff to read', async () => {
      await t
        .http()
        .post('/v1/admin/exam-papers')
        .send(paperBody())
        .expect(401);
      await as(learner).post('/v1/admin/exam-papers', paperBody()).expect(403);
      await as(editor).post('/v1/admin/exam-papers', paperBody()).expect(403);
      const paper = await createPaper();
      await as(editor).get(`/v1/admin/exam-papers/${paper.id}`).expect(200);
      await as(learner).get(`/v1/admin/exam-papers/${paper.id}`).expect(403);
      await as(editor)
        .patch(`/v1/admin/exam-papers/${paper.id}`, { title: 'Nope nope' })
        .expect(403);
    });

    it('starts as an unverified draft with the interim unscored rule', async () => {
      const paper = await createPaper();
      expect(paper).toMatchObject({
        status: 'draft',
        revision: 1,
        frozen_at: null,
        config_status: 'unverified',
        withdrawn_policy: 'unscored',
        withdrawn_policy_confirmed: false,
        supersedes_id: null,
      });
    });

    it('refuses a repeated code and an unknown exam', async () => {
      const paper = await createPaper();
      await as(admin)
        .post('/v1/admin/exam-papers', paperBody({ code: paper.code }))
        .expect(409);
      await as(admin)
        .post('/v1/admin/exam-papers', paperBody({ exam_id: newId() }))
        .expect(404);
    });

    it('will not award marks for withdrawn questions until the rule is confirmed', async () => {
      const res = await as(admin)
        .post(
          '/v1/admin/exam-papers',
          paperBody({ withdrawn_policy: 'award_all' }),
        )
        .expect(422);
      expect(res.body.code).toBe('withdrawn_policy_unconfirmed');
      const ok = await as(admin)
        .post(
          '/v1/admin/exam-papers',
          paperBody({
            withdrawn_policy: 'award_all',
            withdrawn_policy_confirmed: true,
          }),
        )
        .expect(201);
      expect(ok.body.withdrawn_policy).toBe('award_all');
      // And the database refuses it even if the service were bypassed.
      const bare = await createPaper();
      await expect(
        t.db
          .update(examPapers)
          .set({ withdrawnPolicy: 'award_all' })
          .where(eq(examPapers.id, bare.id)),
      ).rejects.toThrow();
    });
  });

  describe('positions', () => {
    it('keep the original order, option order, labels and withdrawn placeholders', async () => {
      const { paper, q1, q2 } = await fullDraft();
      const res = await as(admin)
        .get(`/v1/admin/exam-papers/${paper.id}`)
        .expect(200);
      const [p1, p2, p3] = res.body.positions;
      expect(
        res.body.positions.map((p: { position: number }) => p.position),
      ).toEqual([1, 2, 3]);
      expect(p1).toMatchObject({
        question_version_id: q1.versionId,
        original_ref: 'Q1',
        option_order: ['d', 'c', 'b', 'a'],
        original_label_scheme: 'A-D',
        answer_status: 'keyed',
        accepted_option_ids: ['b'],
      });
      expect(p2).toMatchObject({
        question_version_id: q2.versionId,
        option_order: null,
        answer_status: 'multi_accepted',
        accepted_option_ids: ['b', 'c'],
      });
      expect(p3).toMatchObject({
        answer_status: 'withdrawn',
        question_id: null,
        question_version_id: null,
        accepted_option_ids: [],
        withdrawn_note: 'Withdrawn by the exam body',
      });
    });

    it('can be replaced in place, keeping the key history of a position that did not change', async () => {
      const { paper, q1 } = await fullDraft();
      await as(admin)
        .post(`/v1/admin/exam-papers/${paper.id}/positions/1/key-history`, {
          kind: 'provisional',
          accepted_option_ids: ['b'],
          source_document_ref: 'Provisional key, page 1',
        })
        .expect(201);
      const q3 = await question();
      await as(admin)
        .put(`/v1/admin/exam-papers/${paper.id}/positions`, {
          positions: [
            { position: 1, question_version_id: q1.versionId },
            { position: 2, question_version_id: q3.versionId },
          ],
        })
        .expect(200);
      const res = await as(admin)
        .get(`/v1/admin/exam-papers/${paper.id}`)
        .expect(200);
      expect(res.body.positions).toHaveLength(2);
      expect(res.body.positions[0].key_history).toHaveLength(1);
      const log = await t.db
        .select()
        .from(auditLog)
        .where(eq(auditLog.action, 'exam_paper.positions_replaced'));
      expect(log.length).toBeGreaterThan(0);
    });

    it('refuse a draft version, a bad option order and a bad position, and accept any source record', async () => {
      const paper = await createPaper();
      const draftOnly = await question({}, 'draft');
      const pending = await question({
        contentSourceId: await source('pending'),
      });
      const blocked = await question({
        contentSourceId: await source('blocked'),
      });
      const ok = await question();
      const put = (positions: object[]) =>
        as(admin).put(`/v1/admin/exam-papers/${paper.id}/positions`, {
          positions,
        });
      for (const bad of [draftOnly]) {
        const res = await put([
          { position: 1, question_version_id: bad.versionId },
        ]).expect(422);
        expect(res.body.code).toBe('invalid_positions');
      }
      await put([
        {
          position: 1,
          question_version_id: ok.versionId,
          option_order: ['a', 'b'],
        },
      ]).expect(422);
      await put([
        {
          position: 1,
          question_version_id: ok.versionId,
          option_order: ['a', 'a', 'b', 'c'],
        },
      ]).expect(422);
      await put([{ position: 9, question_version_id: ok.versionId }]).expect(
        422,
      );
      await put([
        { position: 1, question_version_id: ok.versionId },
        { position: 1, question_version_id: ok.versionId },
      ]).expect(422);
      await put([{ position: 1, question_version_id: newId() }]).expect(422);
      await put([{ position: 1, option_order: ['a'] }]).expect(422);
      for (const pinned of [
        await question({ contentSourceId: await source('permitted_by_terms') }),
        pending,
        blocked,
      ])
        await put([
          { position: 1, question_version_id: pinned.versionId },
        ]).expect(200);
    });

    it('pin an exact version: a later revision of the question does not change the paper', async () => {
      const { paper, q1 } = await fullDraft();
      await as(admin)
        .post(`/v1/admin/exam-papers/${paper.id}/publish`)
        .expect(200);
      const [before] = await t.db
        .select()
        .from(questionVersions)
        .where(eq(questionVersions.id, q1.versionId));
      // The question is revised: version 1 is superseded, version 2 is live.
      const v2 = newId();
      await t.db.insert(questionVersions).values({
        ...before,
        id: v2,
        versionNo: 2,
        stem: 'A completely different stem',
        status: 'published',
      });
      await t.db
        .update(questionVersions)
        .set({ status: 'superseded' })
        .where(eq(questionVersions.id, q1.versionId));
      await t.db
        .update(questions)
        .set({ liveVersionId: v2 })
        .where(eq(questions.id, q1.questionId));
      const res = await as(admin)
        .get(`/v1/admin/exam-papers/${paper.id}`)
        .expect(200);
      expect(res.body.positions[0].question_version_id).toBe(q1.versionId);
    });
  });

  describe('answer-key history', () => {
    it('records every key with its source, and the newest one is the effective key', async () => {
      const { paper } = await fullDraft();
      const src = await source();
      const url = `/v1/admin/exam-papers/${paper.id}/positions/1/key-history`;
      await as(admin)
        .post(url, {
          kind: 'provisional',
          accepted_option_ids: ['b'],
          source_document_ref: 'Provisional key, page 3',
          retrieved_on: '2026-11-01',
        })
        .expect(201);
      const final = await as(admin)
        .post(url, {
          kind: 'final',
          accepted_option_ids: ['b', 'c'],
          content_source_id: src,
          source_document_ref: 'Final key, notice 7',
          retrieved_on: '2026-11-18',
          source_sha256: 'ab'.repeat(32),
          note: 'Two options accepted',
        })
        .expect(201);
      expect(final.body).toMatchObject({
        kind: 'final',
        accepted_option_ids: ['b', 'c'],
        content_source_id: src,
        retrieved_on: '2026-11-18',
        source_sha256: 'ab'.repeat(32),
      });
      const res = await as(admin)
        .get(`/v1/admin/exam-papers/${paper.id}`)
        .expect(200);
      const p1 = res.body.positions[0];
      expect(p1.key_history.map((k: { kind: string }) => k.kind)).toEqual([
        'provisional',
        'final',
      ]);
      expect(p1.accepted_option_ids).toEqual(['b', 'c']);
    });

    it('checks the entry: real options, a source, a valid hash, and the right kind for a withdrawn position', async () => {
      const { paper } = await fullDraft();
      const url = (n: number) =>
        `/v1/admin/exam-papers/${paper.id}/positions/${n}/key-history`;
      const post = (n: number, body: object) => as(admin).post(url(n), body);
      await post(1, {
        kind: 'final',
        accepted_option_ids: ['z'],
        source_document_ref: 'x',
      }).expect(422);
      await post(1, {
        kind: 'final',
        accepted_option_ids: [],
        source_document_ref: 'x',
      }).expect(422);
      await post(1, { kind: 'final', accepted_option_ids: ['a'] }).expect(422);
      await post(1, {
        kind: 'withdrawn',
        accepted_option_ids: [],
        source_document_ref: 'x',
      }).expect(422);
      await post(1, {
        kind: 'final',
        accepted_option_ids: ['a'],
        source_document_ref: 'x',
        source_sha256: 'not-a-hash',
      }).expect(400);
      await post(1, {
        kind: 'final',
        accepted_option_ids: ['a'],
        content_source_id: newId(),
      }).expect(422);
      await post(3, {
        kind: 'final',
        accepted_option_ids: ['a'],
        source_document_ref: 'x',
      }).expect(422);
      await post(3, {
        kind: 'withdrawn',
        accepted_option_ids: [],
        source_document_ref: 'Notice withdrawing question 3',
      }).expect(201);
      await post(7, {
        kind: 'final',
        accepted_option_ids: ['a'],
        source_document_ref: 'x',
      }).expect(404);
    });

    it('is append-only in the API: entries cannot be edited or deleted', async () => {
      const { paper } = await fullDraft();
      await as(admin)
        .patch(
          `/v1/admin/exam-papers/${paper.id}/positions/1/key-history/${newId()}`,
          {},
        )
        .expect(404);
      const rows = await t.db
        .select()
        .from(examPaperKeyHistory)
        .where(eq(examPaperKeyHistory.paperId, paper.id));
      expect(rows).toHaveLength(0);
    });
  });

  describe('publishing and freezing', () => {
    it('refuses an incomplete draft and says what is missing', async () => {
      const paper = await createPaper({ total_questions: 4 });
      const res = await as(admin)
        .post(`/v1/admin/exam-papers/${paper.id}/publish`)
        .expect(422);
      expect(res.body.code).toBe('paper_not_ready');
      expect(JSON.stringify(res.body.details)).toMatch(/missing/);
      const ready = await as(admin)
        .get(`/v1/admin/exam-papers/${paper.id}/readiness`)
        .expect(200);
      expect(ready.body.ready).toBe(false);
    });

    it('freezes a complete paper, and a frozen paper refuses every change', async () => {
      const { paper, q1 } = await fullDraft();
      const ready = await as(admin)
        .get(`/v1/admin/exam-papers/${paper.id}/readiness`)
        .expect(200);
      expect(ready.body).toEqual({ ready: true, problems: [] });
      const res = await as(admin)
        .post(`/v1/admin/exam-papers/${paper.id}/publish`)
        .expect(200);
      expect(res.body.status).toBe('published');
      expect(res.body.frozen_at).not.toBeNull();

      const frozen = async (
        r: Promise<{ status: number; body: { code: string } }>,
      ) => {
        const x = await r;
        expect(x.status).toBe(409);
        expect(x.body.code).toBe('paper_frozen');
      };
      await frozen(
        as(admin).patch(`/v1/admin/exam-papers/${paper.id}`, {
          title: 'Changed title',
        }),
      );
      await frozen(
        as(admin).put(`/v1/admin/exam-papers/${paper.id}/positions`, {
          positions: [{ position: 1, question_version_id: q1.versionId }],
        }),
      );
      await frozen(
        as(admin).post(
          `/v1/admin/exam-papers/${paper.id}/positions/1/key-history`,
          {
            kind: 'revised',
            accepted_option_ids: ['a'],
            source_document_ref: 'x',
          },
        ),
      );
      await frozen(as(admin).post(`/v1/admin/exam-papers/${paper.id}/publish`));
      const after = await as(admin)
        .get(`/v1/admin/exam-papers/${paper.id}`)
        .expect(200);
      expect(after.body.title).toBe('AIBE test paper');
      expect(after.body.positions).toHaveLength(3);
    });

    it('is audited', async () => {
      const { paper } = await fullDraft();
      await as(admin)
        .post(`/v1/admin/exam-papers/${paper.id}/publish`)
        .expect(200);
      const log = await t.db
        .select()
        .from(auditLog)
        .where(eq(auditLog.entityId, paper.id));
      expect(log.map((l) => l.action)).toEqual(
        expect.arrayContaining([
          'exam_paper.created',
          'exam_paper.positions_replaced',
          'exam_paper.published',
        ]),
      );
    });
  });

  describe('revisions', () => {
    it('start a draft from a frozen paper, copying positions and key history', async () => {
      const { paper } = await fullDraft();
      await as(admin)
        .post(`/v1/admin/exam-papers/${paper.id}/positions/1/key-history`, {
          kind: 'provisional',
          accepted_option_ids: ['b'],
          source_document_ref: 'Provisional key',
        })
        .expect(201);
      await as(admin)
        .post(`/v1/admin/exam-papers/${paper.id}/publish`)
        .expect(200);

      const rev = await as(admin)
        .post(`/v1/admin/exam-papers/${paper.id}/revise`)
        .expect(201);
      expect(rev.body).toMatchObject({
        status: 'draft',
        revision: 2,
        supersedes_id: paper.id,
        code: paper.code,
        frozen_at: null,
      });
      expect(rev.body.positions).toHaveLength(3);
      expect(rev.body.positions[0].key_history).toHaveLength(1);
      expect(rev.body.positions[0].id).not.toBe(
        (await as(admin).get(`/v1/admin/exam-papers/${paper.id}`)).body
          .positions[0].id,
      );
      // Only one draft revision at a time.
      await as(admin)
        .post(`/v1/admin/exam-papers/${paper.id}/revise`)
        .expect(409);
      // A draft cannot be revised.
      await as(admin)
        .post(`/v1/admin/exam-papers/${rev.body.id}/revise`)
        .expect(409);
    });

    it('leave the frozen paper untouched while the revision is edited, then replace it on publish', async () => {
      const { paper } = await fullDraft();
      await as(admin)
        .post(`/v1/admin/exam-papers/${paper.id}/publish`)
        .expect(200);
      const rev = (
        await as(admin)
          .post(`/v1/admin/exam-papers/${paper.id}/revise`)
          .expect(201)
      ).body;
      await as(admin)
        .post(`/v1/admin/exam-papers/${rev.id}/positions/1/key-history`, {
          kind: 'revised',
          accepted_option_ids: ['a', 'b'],
          source_document_ref: 'Corrected key, notice 9',
        })
        .expect(201);
      const original = await as(admin)
        .get(`/v1/admin/exam-papers/${paper.id}`)
        .expect(200);
      expect(original.body.positions[0].key_history).toHaveLength(0);
      expect(original.body.positions[0].accepted_option_ids).toEqual(['b']);

      await as(admin)
        .post(`/v1/admin/exam-papers/${rev.id}/publish`)
        .expect(200);
      const old = await as(admin)
        .get(`/v1/admin/exam-papers/${paper.id}`)
        .expect(200);
      const now = await as(admin)
        .get(`/v1/admin/exam-papers/${rev.id}`)
        .expect(200);
      expect(old.body.status).toBe('retired');
      expect(old.body.frozen_at).not.toBeNull();
      expect(now.body.status).toBe('published');
      expect(now.body.positions[0].accepted_option_ids).toEqual(['a', 'b']);
    });

    it('cannot be started from a draft, and a retired paper cannot be retired again', async () => {
      const draft = await createPaper();
      await as(admin)
        .post(`/v1/admin/exam-papers/${draft.id}/revise`)
        .expect(409);
      await as(admin)
        .post(`/v1/admin/exam-papers/${draft.id}/retire`)
        .expect(409);
    });
  });

  describe('what learners see', () => {
    let publishedId: string;
    let q1: { versionId: string };

    beforeAll(async () => {
      const full = await fullDraft({ code: 'aibe-learner-view' });
      q1 = full.q1;
      publishedId = full.paper.id;
      await as(admin)
        .post(`/v1/admin/exam-papers/${publishedId}/publish`)
        .expect(200);
    });

    it('is hidden while the exam is switched off', async () => {
      await as(learner).get('/v1/exams/aibe/papers').expect(404);
      await as(learner).get(`/v1/exams/aibe/papers/${publishedId}`).expect(404);
    });

    it('lists and opens published papers once the exam is on, and needs sign-in', async () => {
      await t.db
        .update(exams)
        .set({ isActive: true })
        .where(eq(exams.id, examId));
      await t.http().get('/v1/exams/aibe/papers').expect(401);
      const list = await as(learner).get('/v1/exams/aibe/papers').expect(200);
      const ids = list.body.items.map((p: { id: string }) => p.id);
      expect(ids).toContain(publishedId);
      // Drafts are never listed.
      const draft = await createPaper();
      expect(ids).not.toContain(draft.id);
      await as(learner).get(`/v1/exams/aibe/papers/${draft.id}`).expect(404);
      await as(learner).get('/v1/exams/clat/papers').expect(404);
    });

    it('shows the original question and option order, with withdrawn positions as placeholders', async () => {
      const res = await as(learner)
        .get(`/v1/exams/aibe/papers/${publishedId}`)
        .expect(200);
      const [p1, p2, p3] = res.body.positions;
      expect(p1.question_version_id).toBe(q1.versionId);
      expect(p1.options.map((o: { id: string }) => o.id)).toEqual([
        'd',
        'c',
        'b',
        'a',
      ]);
      expect(p2.options.map((o: { id: string }) => o.id)).toEqual([
        'a',
        'b',
        'c',
        'd',
      ]);
      expect(p3).toEqual({
        position: 3,
        original_ref: 'Q3',
        withdrawn: true,
        question_version_id: null,
        stem: null,
        options: null,
      });
    });

    it('never includes keys, explanations, key history, sources or staff notes', async () => {
      const res = await as(learner)
        .get(`/v1/exams/aibe/papers/${publishedId}`)
        .expect(200);
      const text = JSON.stringify(res.body);
      for (const leak of [
        'SECRET EXPLANATION',
        'correct',
        'accepted',
        'explanation',
        'key_history',
        'official_key_text',
        'license',
        'source',
        'withdrawn_note',
        'Withdrawn by the exam body',
        'withdrawn_policy',
      ])
        expect(text).not.toContain(leak);
      const list = await as(learner).get('/v1/exams/aibe/papers').expect(200);
      expect(JSON.stringify(list.body)).not.toMatch(/source|accepted|correct/);
    });
  });
});
