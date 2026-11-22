import { count, eq } from 'drizzle-orm';
import { newId } from '../src/core/ids.js';
import {
  auditLog,
  coinLedger,
  examAttemptQuestions,
  examAttempts,
  examQuestionTags,
  exams,
  questions,
  questionVersions,
  quizSessions,
  subjects,
  topics,
} from '../src/db/schema.js';
import { AttemptsService } from '../src/exams/attempts.service.js';
import { startApp, type TestApp } from './helpers.js';

type Session = Awaited<ReturnType<TestApp['signInAs']>>;

const OFFICIAL = {
  config_status: 'official_confirmed',
  config_source: 'Test fixture: stands in for an official notice',
  config_checked_on: '2026-11-18',
};

describe('formal exam attempts', () => {
  let t: TestApp;
  let admin: Session, bob: Session;
  let aibeId: string;
  let topicA: string, topicB: string;
  let before: { quiz: number; coins: number };

  const as = (s: Session) => ({
    get: (url: string) => t.http().get(url).auth(s.token, { type: 'bearer' }),
    post: (url: string, body: object = {}) =>
      t.http().post(url).auth(s.token, { type: 'bearer' }).send(body),
    put: (url: string, body: object) =>
      t.http().put(url).auth(s.token, { type: 'bearer' }).send(body),
  });
  const learner = () => t.signInAs('learner');

  let n = 0;
  const question = async (
    topicId = topicA,
    over: Partial<typeof questionVersions.$inferInsert> = {},
  ) => {
    const questionId = newId();
    const versionId = newId();
    n++;
    await t.db.insert(questions).values({ id: questionId, examOnly: true });
    await t.db.insert(questionVersions).values({
      id: versionId,
      questionId,
      versionNo: 1,
      status: 'published',
      topicId,
      stem: `Stem number ${n} ${versionId.slice(-6)}`,
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
    await t.db
      .update(questions)
      .set({ liveVersionId: versionId })
      .where(eq(questions.id, questionId));
    return { questionId, versionId };
  };
  const tag = (questionId: string, examId: string) =>
    t.db.insert(examQuestionTags).values({ questionId, examId });

  /** A published paper: p1 (b), p2 (b or c), p3 (b), p4 withdrawn. */
  const makePaper = async (over: object = {}) => {
    const paper = (
      await as(admin)
        .post('/v1/admin/exam-papers', {
          exam_id: aibeId,
          code: `p-${newId().slice(-10)}`,
          title: 'Fixture paper',
          total_questions: 4,
          duration_seconds: 3600,
          marks_correct: 1,
          negative_marks: 0.25,
          marks_unanswered: 0,
          config_status: 'official_confirmed',
          ...over,
        })
        .expect(201)
    ).body;
    const q1 = await question();
    const q2 = await question(topicA, { alternateCorrectOptionIds: ['c'] });
    const q3 = await question();
    await as(admin)
      .put(`/v1/admin/exam-papers/${paper.id}/positions`, {
        positions: [
          {
            position: 1,
            question_version_id: q1.versionId,
            original_ref: 'Q1',
            option_order: ['d', 'c', 'b', 'a'],
          },
          {
            position: 2,
            question_version_id: q2.versionId,
            original_ref: 'Q2',
          },
          {
            position: 3,
            question_version_id: q3.versionId,
            original_ref: 'Q3',
          },
          { position: 4, original_ref: 'Q4' },
        ],
      })
      .expect(200);
    await as(admin)
      .post(`/v1/admin/exam-papers/${paper.id}/publish`)
      .expect(200);
    return { paper, q1, q2, q3 };
  };

  const startFixed = (s: Session, paperId: string, mode?: string) =>
    as(s).post('/v1/exams/aibe/attempts', {
      kind: 'fixed_paper',
      paper_id: paperId,
      ...(mode ? { mode } : {}),
    });
  const save = (
    s: Session,
    id: string,
    position: number,
    selected: string[],
    seq: number,
  ) =>
    as(s).put(`/v1/me/exam-attempts/${id}/answers/${position}`, {
      selected_option_ids: selected,
      seq,
    });
  const rows = (id: string) =>
    t.db
      .select()
      .from(examAttemptQuestions)
      .where(eq(examAttemptQuestions.attemptId, id));
  const expire = (id: string) =>
    t.db
      .update(examAttempts)
      .set({ deadlineAt: new Date(Date.now() - 5000) })
      .where(eq(examAttempts.id, id));
  const auditCount = async (id: string, action: string) =>
    (
      await t.db.select().from(auditLog).where(eq(auditLog.entityId, id))
    ).filter((l) => l.action === action).length;

  beforeAll(async () => {
    t = await startApp();
    [admin, bob] = await Promise.all([
      t.signInAs('admin'),
      t.signInAs('learner'),
    ]);
    aibeId = newId();
    await t.db
      .insert(exams)
      .values({
        id: aibeId,
        slug: 'aibe',
        name: 'AIBE',
        shortName: 'AIBE',
        isActive: true,
      });
    topicA = t.topicId;
    topicB = newId();
    const subjectId = newId();
    await t.db
      .insert(subjects)
      .values({ id: subjectId, slug: 'procedure', name: 'Procedure' });
    await t.db
      .insert(topics)
      .values({ id: topicB, subjectId, slug: 'cpc', name: 'CPC' });
    before = {
      quiz: (await t.db.select({ n: count() }).from(quizSessions))[0].n,
      coins: (await t.db.select({ n: count() }).from(coinLedger))[0].n,
    };
  });
  afterAll(() => t.close());

  describe('starting a fixed-paper attempt', () => {
    it('freezes the paper revision, order, option order and withdrawn placeholder, without any key', async () => {
      const { paper, q1 } = await makePaper();
      const alice = await learner();
      const res = await startFixed(alice, paper.id).expect(201);
      const a = res.body;
      expect(a).toMatchObject({
        kind: 'fixed_paper',
        mode: 'practice',
        status: 'in_progress',
        exam: 'aibe',
        deadline_at: null,
        remaining_seconds: null,
        total_questions: 4,
        answered_count: 0,
        paper: { id: paper.id, revision: 1 },
        result_available: false,
      });
      const [p1, p2, , p4] = a.questions;
      expect(p1.question_version_id).toBe(q1.versionId);
      expect(p1.options.map((o: { id: string }) => o.id)).toEqual([
        'd',
        'c',
        'b',
        'a',
      ]);
      expect(p1.original_ref).toBe('Q1');
      expect(p2.options.map((o: { id: string }) => o.id)).toEqual([
        'a',
        'b',
        'c',
        'd',
      ]);
      expect(p4).toMatchObject({
        withdrawn: true,
        stem: null,
        options: null,
        question_version_id: null,
      });
      const text = JSON.stringify(res.body);
      for (const leak of ['SECRET', 'explanation', 'accepted', 'correct'])
        expect(text).not.toContain(leak);
      // The frozen key is stored, but only on the server.
      const stored = await rows(a.id);
      expect(stored[0].acceptedOptionIds).toEqual(['b']);
      expect(stored[1].acceptedOptionIds).toEqual(['b', 'c']);
      expect(stored[3].answerStatus).toBe('withdrawn');
    });

    it('needs a published paper of an active exam, and a paper_id', async () => {
      const alice = await learner();
      await as(alice)
        .post('/v1/exams/aibe/attempts', { kind: 'fixed_paper' })
        .expect(422);
      await startFixed(alice, newId()).expect(404);
      const draft = (
        await as(admin)
          .post('/v1/admin/exam-papers', {
            exam_id: aibeId,
            code: `d-${newId().slice(-10)}`,
            title: 'Draft paper',
            total_questions: 1,
          })
          .expect(201)
      ).body;
      await startFixed(alice, draft.id).expect(404);
      await t.db
        .insert(exams)
        .values({ id: newId(), slug: 'clat', name: 'CLAT', shortName: 'CLAT' });
      await as(alice)
        .post('/v1/exams/clat/attempts', { kind: 'random_mock' })
        .expect(404);
      await t
        .http()
        .post('/v1/exams/aibe/attempts')
        .send({ kind: 'fixed_paper' })
        .expect(401);
    });

    it('allows one unfinished attempt per exam, even when two start requests race', async () => {
      const { paper } = await makePaper();
      const alice = await learner();
      const results = await Promise.all([
        startFixed(alice, paper.id),
        startFixed(alice, paper.id),
      ]);
      expect(results.map((r) => r.status).sort()).toEqual([201, 409]);
      const loser = results.find((r) => r.status === 409)!;
      expect(loser.body.code).toBe('attempt_in_progress');
      const mine = await t.db
        .select()
        .from(examAttempts)
        .where(eq(examAttempts.userId, alice.id));
      expect(mine).toHaveLength(1);
      await startFixed(alice, paper.id).expect(409);
    });
  });

  describe('the timer', () => {
    it('is practice by default (no deadline) and timed only when the paper rules are confirmed', async () => {
      const unverified = await makePaper({ config_status: 'unverified' });
      const noDuration = await makePaper({ duration_seconds: undefined });
      const alice = await learner();
      const a = await startFixed(alice, unverified.paper.id, 'timed').expect(
        409,
      );
      expect(a.body.code).toBe('timed_mode_not_allowed');
      const b = await startFixed(alice, noDuration.paper.id, 'timed').expect(
        409,
      );
      expect(b.body.code).toBe('timed_mode_not_allowed');
      await startFixed(alice, unverified.paper.id, 'practice').expect(201);
    });

    it('sets the deadline on the server from the paper’s duration and ignores any client value', async () => {
      const { paper } = await makePaper();
      const alice = await learner();
      const sneaky = await as(alice)
        .post('/v1/exams/aibe/attempts', {
          kind: 'fixed_paper',
          paper_id: paper.id,
          mode: 'timed',
          deadline_at: '2099-01-01T00:00:00Z',
          duration_seconds: 999999,
        })
        .expect(400);
      expect(sneaky.body.code).toBe('validation_failed');
      const res = await startFixed(alice, paper.id, 'timed').expect(201);
      const started = Date.parse(res.body.started_at);
      expect(Date.parse(res.body.deadline_at) - started).toBe(3600 * 1000);
      expect(res.body.remaining_seconds).toBeGreaterThan(3590);
      expect(res.body.remaining_seconds).toBeLessThanOrEqual(3600);
      expect(typeof res.body.server_now).toBe('string');
      // No endpoint takes a deadline: it cannot be moved afterwards either.
      await as(alice)
        .put(`/v1/me/exam-attempts/${res.body.id}/answers/1`, {
          selected_option_ids: ['b'],
          seq: 1,
          deadline_at: '2099-01-01T00:00:00Z',
        })
        .expect(400);
    });

    it('does not pause while the app is closed: the deadline stays fixed across fetches', async () => {
      const { paper } = await makePaper();
      const alice = await learner();
      const first = (await startFixed(alice, paper.id, 'timed').expect(201))
        .body;
      const again = (
        await as(alice).get(`/v1/me/exam-attempts/${first.id}`).expect(200)
      ).body;
      const active = (
        await as(alice).get('/v1/exams/aibe/attempts/active').expect(200)
      ).body;
      expect(again.deadline_at).toBe(first.deadline_at);
      expect(active.deadline_at).toBe(first.deadline_at);
      expect(active.id).toBe(first.id);
    });

    it('refuses answers after the deadline and finishes the attempt, keeping what was saved', async () => {
      const { paper } = await makePaper();
      const alice = await learner();
      const a = (await startFixed(alice, paper.id, 'timed').expect(201)).body;
      await save(alice, a.id, 1, ['b'], 1).expect(200);
      await expire(a.id);
      const late = await save(alice, a.id, 2, ['b'], 1).expect(409);
      expect(late.body.code).toBe('attempt_expired');
      const [row] = await t.db
        .select()
        .from(examAttempts)
        .where(eq(examAttempts.id, a.id));
      expect(row).toMatchObject({ status: 'expired', finalisedBy: 'expiry' });
      expect(row.submittedAt!.getTime()).toBe(row.deadlineAt!.getTime());
      const stored = await rows(a.id);
      expect(stored[0].selectedOptionIds).toEqual(['b']);
      expect(stored[1].selectedOptionIds).toBeNull();
      const result = await as(alice)
        .get(`/v1/me/exam-attempts/${a.id}/result`)
        .expect(200);
      expect(result.body.status).toBe('expired');
      expect(result.body.result.overall).toMatchObject({
        correct: 1,
        unanswered: 2,
      });
      expect(await auditCount(a.id, 'exam_attempt.expired')).toBe(1);
      // Resuming an expired attempt is not possible, and a new one can be started.
      await as(alice).get('/v1/exams/aibe/attempts/active').expect(404);
      await startFixed(alice, paper.id).expect(201);
    });

    it('treats a late submit as an expiry, with the same result however often it is repeated', async () => {
      const { paper } = await makePaper();
      const alice = await learner();
      const a = (await startFixed(alice, paper.id, 'timed').expect(201)).body;
      await save(alice, a.id, 1, ['b'], 1).expect(200);
      await expire(a.id);
      const first = await as(alice)
        .post(`/v1/me/exam-attempts/${a.id}/submit`)
        .expect(200);
      expect(first.body.status).toBe('expired');
      const second = await as(alice)
        .post(`/v1/me/exam-attempts/${a.id}/submit`)
        .expect(200);
      expect(second.body).toEqual(first.body);
    });

    it('finishes overdue attempts in a sweep, once even when sweeps overlap', async () => {
      const { paper } = await makePaper();
      const users = await Promise.all([learner(), learner(), learner()]);
      const ids: string[] = [];
      for (const u of users) {
        const a = (await startFixed(u, paper.id, 'timed').expect(201)).body;
        await expire(a.id);
        ids.push(a.id);
      }
      const svc = t.app.get(AttemptsService);
      const counts = await Promise.all([
        svc.sweepExpired(),
        svc.sweepExpired(),
      ]);
      expect(counts[0] + counts[1]).toBe(3);
      for (const id of ids) {
        const [row] = await t.db
          .select()
          .from(examAttempts)
          .where(eq(examAttempts.id, id));
        expect(row).toMatchObject({ status: 'expired', finalisedBy: 'sweep' });
        expect(await auditCount(id, 'exam_attempt.expired')).toBe(1);
      }
      expect(await svc.sweepExpired()).toBe(0);
    });

    it('lets only an admin run the sweep through the API, and audits it', async () => {
      const alice = await learner();
      await as(alice).post('/v1/admin/exam-attempts/sweep').expect(403);
      await t.http().post('/v1/admin/exam-attempts/sweep').expect(401);
      const res = await as(admin)
        .post('/v1/admin/exam-attempts/sweep')
        .expect(200);
      expect(typeof res.body.finalised).toBe('number');
      const log = await t.db
        .select()
        .from(auditLog)
        .where(eq(auditLog.action, 'exam_attempt.sweep_run'));
      expect(log.length).toBeGreaterThan(0);
    });

    it('does not expire a practice attempt', async () => {
      const { paper } = await makePaper();
      const alice = await learner();
      const a = (await startFixed(alice, paper.id).expect(201)).body;
      // Even a sweep far in the future leaves a practice attempt (no deadline) alone.
      await t.app
        .get(AttemptsService)
        .sweepExpired(new Date(Date.now() + 1e10));
      const [row] = await t.db
        .select()
        .from(examAttempts)
        .where(eq(examAttempts.id, a.id));
      expect(row.status).toBe('in_progress');
      await save(alice, a.id, 1, ['b'], 1).expect(200);
    });
  });

  describe('autosave and resume', () => {
    it('saves single answers and batches, keeping the selection and unanswered questions', async () => {
      const { paper } = await makePaper();
      const alice = await learner();
      const a = (await startFixed(alice, paper.id).expect(201)).body;
      const one = await save(alice, a.id, 1, ['a'], 1).expect(200);
      expect(one.body.results).toEqual([
        {
          position: 1,
          applied: true,
          reason: null,
          selected_option_ids: ['a'],
          seq: 1,
        },
      ]);
      const batch = await as(alice)
        .put(`/v1/me/exam-attempts/${a.id}/answers`, {
          answers: [
            { position: 2, selected_option_ids: ['c'], seq: 1 },
            { position: 3, selected_option_ids: ['d'], seq: 4 },
          ],
        })
        .expect(200);
      expect(
        batch.body.results.every((r: { applied: boolean }) => r.applied),
      ).toBe(true);
      expect(JSON.stringify(batch.body)).not.toMatch(/correct|accepted|SECRET/);
      const resumed = (
        await as(alice).get('/v1/exams/aibe/attempts/active').expect(200)
      ).body;
      expect(resumed.id).toBe(a.id);
      expect(resumed.answered_count).toBe(3);
      expect(
        resumed.questions.map(
          (q: { selected_option_ids: string[] | null }) =>
            q.selected_option_ids,
        ),
      ).toEqual([['a'], ['c'], ['d'], null]);
      expect(resumed.questions[2].answer_seq).toBe(4);
      // An answer can be cleared.
      await save(alice, a.id, 1, [], 2).expect(200);
      expect(
        (await as(alice).get(`/v1/me/exam-attempts/${a.id}`)).body
          .answered_count,
      ).toBe(2);
    });

    it('never lets an older request overwrite a newer answer', async () => {
      const { paper } = await makePaper();
      const alice = await learner();
      const a = (await startFixed(alice, paper.id).expect(201)).body;
      await save(alice, a.id, 1, ['b'], 5).expect(200);
      const stale = await save(alice, a.id, 1, ['a'], 3).expect(200);
      expect(stale.body.results[0]).toEqual({
        position: 1,
        applied: false,
        reason: 'stale',
        selected_option_ids: ['b'],
        seq: 5,
      });
      const dup = await save(alice, a.id, 1, ['b'], 5).expect(200);
      expect(dup.body.results[0]).toMatchObject({
        applied: false,
        reason: 'duplicate',
      });
      const conflict = await save(alice, a.id, 1, ['c'], 5).expect(200);
      expect(conflict.body.results[0]).toMatchObject({
        applied: false,
        reason: 'conflict',
        selected_option_ids: ['b'],
      });
      expect((await rows(a.id))[0].selectedOptionIds).toEqual(['b']);
    });

    it('keeps the answer with the highest counter when saves arrive together', async () => {
      const { paper } = await makePaper();
      const alice = await learner();
      const a = (await startFixed(alice, paper.id).expect(201)).body;
      const picks: [string, number][] = [
        ['a', 2],
        ['b', 9],
        ['c', 4],
        ['d', 7],
        ['a', 1],
        ['c', 8],
      ];
      await Promise.all(
        picks.map(([o, seq]) => save(alice, a.id, 1, [o], seq)),
      );
      const [q] = await rows(a.id);
      expect(q.answerSeq).toBe(9);
      expect(q.selectedOptionIds).toEqual(['b']);
    });

    it('checks a request whole: one bad answer applies none', async () => {
      const { paper } = await makePaper();
      const alice = await learner();
      const a = (await startFixed(alice, paper.id).expect(201)).body;
      const bad = async (answers: object[], status = 422) =>
        as(alice)
          .put(`/v1/me/exam-attempts/${a.id}/answers`, { answers })
          .expect(status);
      await bad([
        { position: 1, selected_option_ids: ['b'], seq: 1 },
        { position: 2, selected_option_ids: ['zz'], seq: 1 },
      ]);
      await bad([{ position: 9, selected_option_ids: ['a'], seq: 1 }]);
      await bad([{ position: 4, selected_option_ids: ['a'], seq: 1 }]); // withdrawn
      await bad([{ position: 1, selected_option_ids: ['a', 'b'], seq: 1 }]); // single select
      await bad([{ position: 1, selected_option_ids: ['a', 'a'], seq: 1 }]);
      await bad([
        { position: 1, selected_option_ids: ['a'], seq: 1 },
        { position: 1, selected_option_ids: ['b'], seq: 2 },
      ]);
      await bad([{ position: 1, selected_option_ids: ['a'], seq: 0 }], 400);
      await bad([], 400);
      expect(
        (await rows(a.id)).every((r) => r.selectedOptionIds === null),
      ).toBe(true);
    });
  });

  describe('submitting and results', () => {
    it('scores the attempt with the paper’s rules and marks the result provisional', async () => {
      const { paper } = await makePaper();
      const alice = await learner();
      const a = (await startFixed(alice, paper.id).expect(201)).body;
      await save(alice, a.id, 1, ['b'], 1).expect(200); // correct
      await save(alice, a.id, 2, ['c'], 1).expect(200); // accepted alternate
      await save(alice, a.id, 3, ['a'], 1).expect(200); // wrong
      const res = await as(alice)
        .post(`/v1/me/exam-attempts/${a.id}/submit`)
        .expect(200);
      expect(res.body).toMatchObject({
        status: 'submitted',
        finalised_by: 'learner',
      });
      const r = res.body.result;
      expect(r.overall).toEqual({
        total_positions: 4,
        scorable_positions: 3,
        correct: 2,
        incorrect: 1,
        unanswered: 0,
        withdrawn: 1,
        marks_obtained: 1.75,
        max_marks: 3,
        percentage: 58.33,
      });
      expect(r).toMatchObject({
        marks_available: true,
        provisional: true,
        withdrawn_policy: 'unscored',
        rules_verified: true,
      });
      expect(r.provisional_reasons[0]).toMatch(/withdrawn/i);
      expect(r.positions.map((p: { outcome: string }) => p.outcome)).toEqual([
        'correct',
        'correct',
        'incorrect',
        'withdrawn_unscored',
      ]);
      // No pass criteria: the score is shown without any pass or fail claim.
      expect(r.pass).toMatchObject({
        available: false,
        general: null,
        reserved: null,
      });
      expect(JSON.stringify(res.body)).not.toMatch(/passed|failed/);
    });

    it('shows counts but no marks when the paper has no marking rules configured', async () => {
      const { paper } = await makePaper({
        marks_correct: undefined,
        negative_marks: undefined,
        marks_unanswered: undefined,
      });
      const alice = await learner();
      const a = (await startFixed(alice, paper.id).expect(201)).body;
      await save(alice, a.id, 1, ['b'], 1).expect(200);
      const res = await as(alice)
        .post(`/v1/me/exam-attempts/${a.id}/submit`)
        .expect(200);
      expect(res.body.result.marks_available).toBe(false);
      expect(res.body.result.overall).toMatchObject({
        correct: 1,
        marks_obtained: null,
        max_marks: null,
        percentage: null,
      });
      expect(res.body.result.pass.available).toBe(false);
    });

    it('does not judge a pass from a paper whose rules are unverified, even with a blueprint threshold', async () => {
      const bp = (
        await as(admin)
          .post('/v1/admin/exam-blueprints', {
            exam_id: aibeId,
            code: `unv-${newId().slice(-8)}`,
            duration_seconds: 600,
            total_questions: 1,
            marks_correct: 1,
            pass_percent_general: 40,
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
      const { paper } = await makePaper({
        config_status: 'unverified',
        blueprint_id: bp.id,
      });
      const alice = await learner();
      const a = (await startFixed(alice, paper.id).expect(201)).body;
      const res = await as(alice)
        .post(`/v1/me/exam-attempts/${a.id}/submit`)
        .expect(200);
      expect(res.body.result.rules_verified).toBe(false);
      expect(res.body.result.pass.available).toBe(false);
    });

    it('is idempotent: repeating or racing the submit gives one result and one audit entry', async () => {
      const { paper } = await makePaper();
      const alice = await learner();
      const a = (await startFixed(alice, paper.id).expect(201)).body;
      await save(alice, a.id, 1, ['b'], 1).expect(200);
      const results = await Promise.all([
        as(alice).post(`/v1/me/exam-attempts/${a.id}/submit`),
        as(alice).post(`/v1/me/exam-attempts/${a.id}/submit`),
        as(alice).post(`/v1/me/exam-attempts/${a.id}/submit`),
      ]);
      expect(results.map((r) => r.status)).toEqual([200, 200, 200]);
      expect(results[1].body).toEqual(results[0].body);
      expect(results[2].body).toEqual(results[0].body);
      const later = await as(alice)
        .post(`/v1/me/exam-attempts/${a.id}/submit`)
        .expect(200);
      expect(later.body).toEqual(results[0].body);
      expect(await auditCount(a.id, 'exam_attempt.submitted')).toBe(1);
      expect(
        await t.db
          .select()
          .from(examAttempts)
          .where(eq(examAttempts.userId, alice.id)),
      ).toHaveLength(1);
    });

    it('refuses answers after submission, and a save racing a submit never changes the result', async () => {
      const { paper } = await makePaper();
      const alice = await learner();
      const a = (await startFixed(alice, paper.id).expect(201)).body;
      await save(alice, a.id, 1, ['b'], 1).expect(200);
      const [, sub] = await Promise.all([
        save(alice, a.id, 2, ['b'], 1),
        as(alice).post(`/v1/me/exam-attempts/${a.id}/submit`),
      ]);
      expect(sub.status).toBe(200);
      const late = await save(alice, a.id, 3, ['b'], 1).expect(409);
      expect(late.body.code).toBe('attempt_submitted');
      const final = await as(alice)
        .get(`/v1/me/exam-attempts/${a.id}/result`)
        .expect(200);
      const stored = await rows(a.id);
      const answered = stored.filter((r) => r.selectedOptionIds?.length).length;
      expect(
        final.body.result.overall.correct + final.body.result.overall.incorrect,
      ).toBe(answered);
      expect(stored[2].selectedOptionIds).toBeNull();
    });

    it('releases keys and explanations only after the attempt is finished', async () => {
      const { paper } = await makePaper();
      const alice = await learner();
      const a = (await startFixed(alice, paper.id).expect(201)).body;
      await save(alice, a.id, 1, ['a'], 1).expect(200);
      expect(
        (await as(alice).get(`/v1/me/exam-attempts/${a.id}/review`).expect(409))
          .body.code,
      ).toBe('attempt_in_progress');
      await as(alice).get(`/v1/me/exam-attempts/${a.id}/result`).expect(409);
      const during = (
        await as(alice).get(`/v1/me/exam-attempts/${a.id}`).expect(200)
      ).body;
      expect(JSON.stringify(during)).not.toMatch(/SECRET|accepted|explanation/);

      await as(alice).post(`/v1/me/exam-attempts/${a.id}/submit`).expect(200);
      const review = (
        await as(alice).get(`/v1/me/exam-attempts/${a.id}/review`).expect(200)
      ).body;
      const [r1, r2, , r4] = review.questions;
      expect(r1).toMatchObject({
        selected_option_ids: ['a'],
        accepted_option_ids: ['b'],
        outcome: 'incorrect',
        explanation: 'SECRET EXPLANATION',
      });
      expect(r1.options.map((o: { id: string }) => o.id)).toEqual([
        'd',
        'c',
        'b',
        'a',
      ]);
      expect(r2.accepted_option_ids).toEqual(['b', 'c']);
      expect(r4).toMatchObject({
        withdrawn: true,
        stem: null,
        explanation: null,
        outcome: 'withdrawn_unscored',
      });
      expect(review.provisional).toBe(true);
    });
  });

  describe('immutable snapshots', () => {
    it('are unaffected by a later revision of the paper or its key', async () => {
      const { paper, q1 } = await makePaper();
      const alice = await learner();
      const a = (await startFixed(alice, paper.id).expect(201)).body;
      await save(alice, a.id, 1, ['b'], 1).expect(200);

      // The paper is corrected: a new revision pins another question and a new key.
      const rev = (
        await as(admin)
          .post(`/v1/admin/exam-papers/${paper.id}/revise`)
          .expect(201)
      ).body;
      const other = await question();
      await as(admin)
        .put(`/v1/admin/exam-papers/${rev.id}/positions`, {
          positions: rev.positions.map(
            (p: { position: number; question_version_id: string | null }) =>
              p.position === 1
                ? { position: 1, question_version_id: other.versionId }
                : p.question_version_id
                  ? {
                      position: p.position,
                      question_version_id: p.question_version_id,
                    }
                  : { position: p.position },
          ),
        })
        .expect(200);
      await as(admin)
        .post(`/v1/admin/exam-papers/${rev.id}/publish`)
        .expect(200);
      // Even the question's own text changes in the bank.
      await t.db
        .update(questions)
        .set({ retiredAt: new Date() })
        .where(eq(questions.id, q1.questionId));

      const again = (
        await as(alice).get(`/v1/me/exam-attempts/${a.id}`).expect(200)
      ).body;
      expect(again.paper).toMatchObject({ id: paper.id, revision: 1 });
      expect(again.questions[0].question_version_id).toBe(q1.versionId);
      const res = await as(alice)
        .post(`/v1/me/exam-attempts/${a.id}/submit`)
        .expect(200);
      expect(res.body.result.positions[0].outcome).toBe('correct');
      // The retired revision can no longer be started; the new one can.
      const bob2 = await learner();
      await startFixed(bob2, paper.id).expect(404);
      const fresh = await startFixed(bob2, rev.id).expect(201);
      expect(fresh.body.paper.revision).toBe(2);
    });
  });

  describe('who can see an attempt', () => {
    it('is the learner alone: everyone else gets not found, anonymous gets unauthorised', async () => {
      const { paper } = await makePaper();
      const alice = await learner();
      const a = (await startFixed(alice, paper.id).expect(201)).body;
      const urls = [
        ['get', `/v1/me/exam-attempts/${a.id}`],
        ['get', `/v1/me/exam-attempts/${a.id}/result`],
        ['get', `/v1/me/exam-attempts/${a.id}/review`],
        ['post', `/v1/me/exam-attempts/${a.id}/submit`],
        ['post', `/v1/me/exam-attempts/${a.id}/advance-section`],
      ] as const;
      for (const [method, url] of urls) {
        await (method === 'get' ? as(bob).get(url) : as(bob).post(url)).expect(
          404,
        );
        await t.http()[method](url).expect(401);
      }
      await save(bob, a.id, 1, ['b'], 1).expect(404);
      await as(admin).get(`/v1/me/exam-attempts/${a.id}`).expect(404);
      await as(bob).get('/v1/exams/aibe/attempts/active').expect(404);
      expect((await rows(a.id))[0].selectedOptionIds).toBeNull();
      const theirs = await as(bob).get('/v1/me/exam-attempts').expect(200);
      expect(theirs.body.items.map((i: { id: string }) => i.id)).not.toContain(
        a.id,
      );
    });
  });

  describe('random mock attempts', () => {
    let mockExam: string;
    let blueprintId: string;

    const blueprint = async (
      examId: string,
      over: object = {},
      sectionsOver?: object[],
    ) => {
      const bp = (
        await as(admin)
          .post('/v1/admin/exam-blueprints', {
            exam_id: examId,
            code: `bp-${newId().slice(-8)}`,
            duration_seconds: 7200,
            total_questions: 6,
            marks_correct: 2,
            negative_marks: 0.5,
            marks_unanswered: 0,
            pass_percent_general: 40,
            pass_percent_reserved: 35,
            ...OFFICIAL,
            ...over,
          })
          .expect(201)
      ).body;
      await as(admin)
        .put(`/v1/admin/exam-blueprints/${bp.id}/sections`, {
          sections: sectionsOver ?? [
            {
              code: 's1',
              name: 'One',
              position: 1,
              question_count: 4,
              topics: [{ topic_id: topicA }],
            },
            {
              code: 's2',
              name: 'Two',
              position: 2,
              question_count: 2,
              marks_correct: 3,
              topics: [{ topic_id: topicB }],
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
    const newExam = async (slug: string) => {
      const id = newId();
      await t.db
        .insert(exams)
        .values({ id, slug, name: slug, shortName: slug, isActive: true });
      return id;
    };
    const fill = async (examId: string, a: number, b: number) => {
      for (let i = 0; i < a; i++)
        await tag((await question(topicA)).questionId, examId);
      for (let i = 0; i < b; i++)
        await tag((await question(topicB)).questionId, examId);
    };
    const startMock = (s: Session, slug: string, mode?: string) =>
      as(s).post(`/v1/exams/${slug}/attempts`, {
        kind: 'random_mock',
        ...(mode ? { mode } : {}),
      });

    beforeAll(async () => {
      mockExam = await newExam('rmock');
      await fill(mockExam, 10, 6);
      blueprintId = await blueprint(mockExam);
    });

    it('uses the Stage 3 engine and freezes the questions, seed and option order', async () => {
      const alice = await learner();
      const res = await startMock(alice, 'rmock').expect(201);
      const a = res.body;
      expect(a).toMatchObject({
        kind: 'random_mock',
        total_questions: 6,
        paper: null,
      });
      expect(a.sections).toEqual([
        { code: 's1', position: 1, question_count: 4 },
        { code: 's2', position: 2, question_count: 2 },
      ]);
      expect(
        a.questions.map((q: { section_code: string }) => q.section_code),
      ).toEqual(['s1', 's1', 's1', 's1', 's2', 's2']);
      expect(JSON.stringify(a)).not.toMatch(/SECRET|accepted|correct/);
      const [row] = await t.db
        .select()
        .from(examAttempts)
        .where(eq(examAttempts.id, a.id));
      expect(row).toMatchObject({ blueprintId, algorithmVersion: 1 });
      expect(row.seed).toEqual(expect.any(String));
      const stored = await rows(a.id);
      expect(
        stored.every(
          (q) =>
            q.optionOrder!.length === 4 && q.acceptedOptionIds.length === 1,
        ),
      ).toBe(true);
      expect(stored.slice(4).every((q) => Number(q.marksCorrect) === 3)).toBe(
        true,
      );

      // Resuming returns the same questions in the same order, not a new mock.
      const resumed = (
        await as(alice).get('/v1/exams/rmock/attempts/active').expect(200)
      ).body;
      expect(resumed.questions).toEqual(a.questions);
      const fetched = (
        await as(alice).get(`/v1/me/exam-attempts/${a.id}`).expect(200)
      ).body;
      expect(
        fetched.questions.map(
          (q: { question_version_id: string }) => q.question_version_id,
        ),
      ).toEqual(
        a.questions.map(
          (q: { question_version_id: string }) => q.question_version_id,
        ),
      );
    });

    it('scores sections and overall with section marks, and judges the pass from verified rules', async () => {
      const alice = await learner();
      const a = (await startMock(alice, 'rmock').expect(201)).body;
      const stored = await rows(a.id);
      const key = (i: number) => stored[i].acceptedOptionIds[0];
      const wrong = (i: number) => (key(i) === 'a' ? 'b' : 'a');
      // s1 (2 marks, -0.5): 3 right, 1 wrong. s2 (3 marks): 1 right, 1 blank.
      const answers = [
        [1, key(0)],
        [2, key(1)],
        [3, key(2)],
        [4, wrong(3)],
        [5, key(4)],
      ] as const;
      await as(alice)
        .put(`/v1/me/exam-attempts/${a.id}/answers`, {
          answers: answers.map(([position, o]) => ({
            position,
            selected_option_ids: [o],
            seq: 1,
          })),
        })
        .expect(200);
      const res = await as(alice)
        .post(`/v1/me/exam-attempts/${a.id}/submit`)
        .expect(200);
      const r = res.body.result;
      expect(r.sections.map((s: { code: string }) => s.code)).toEqual([
        's1',
        's2',
      ]);
      expect(r.sections[0]).toMatchObject({
        correct: 3,
        incorrect: 1,
        marks_obtained: 5.5,
        max_marks: 8,
      });
      expect(r.sections[1]).toMatchObject({
        correct: 1,
        unanswered: 1,
        marks_obtained: 3,
        max_marks: 6,
      });
      expect(r.overall).toMatchObject({
        marks_obtained: 8.5,
        max_marks: 14,
        percentage: 60.71,
      });
      expect(r).toMatchObject({ provisional: false, rules_verified: true });
      expect(r.pass).toEqual({
        available: true,
        reason: null,
        percentage: 60.71,
        general: { threshold: 40, met: true },
        reserved: { threshold: 35, met: true },
      });
    });

    it('prefers questions from earlier finished attempts that are new to the learner', async () => {
      const alice = await learner();
      const ids = async () =>
        await rows((await startMock(alice, 'rmock').expect(201)).body.id);
      const first = await ids();
      const firstId = first[0].attemptId;
      await as(alice)
        .post(`/v1/me/exam-attempts/${firstId}/submit`)
        .expect(200);
      const second = await ids();
      const seen = new Set(first.map((q) => q.questionId));
      expect(second.filter((q) => seen.has(q.questionId))).toHaveLength(0);
    });

    it('is timed only with an officially confirmed blueprint, with a server deadline from it', async () => {
      const alice = await learner();
      const res = await startMock(alice, 'rmock', 'timed').expect(201);
      expect(
        Date.parse(res.body.deadline_at) - Date.parse(res.body.started_at),
      ).toBe(7200 * 1000);
      const unverified = await newExam('rmock-unv');
      await fill(unverified, 4, 2);
      await blueprint(unverified, {
        config_status: 'unverified',
        config_source: undefined,
        config_checked_on: undefined,
      });
      const other = await learner();
      const refused = await startMock(other, 'rmock-unv', 'timed').expect(409);
      expect(refused.body.code).toBe('timed_mode_not_allowed');
      const practice = await startMock(other, 'rmock-unv').expect(201);
      // Unverified rules: marks are shown but no pass is judged.
      const done = await as(other)
        .post(`/v1/me/exam-attempts/${practice.body.id}/submit`)
        .expect(200);
      expect(done.body.result).toMatchObject({ rules_verified: false });
      expect(done.body.result.pass.available).toBe(false);
    });

    it('is refused clearly when there is no current blueprint or the pool is too small', async () => {
      const bare = await newExam('rmock-bare');
      const alice = await learner();
      expect((await startMock(alice, 'rmock-bare').expect(409)).body.code).toBe(
        'no_current_blueprint',
      );
      const tiny = await newExam('rmock-tiny');
      await fill(tiny, 1, 0);
      await blueprint(tiny);
      const res = await startMock(alice, 'rmock-tiny').expect(422);
      expect(res.body.code).toBe('mock_pool_insufficient');
      expect(
        await t.db
          .select()
          .from(examAttempts)
          .where(eq(examAttempts.examId, tiny)),
      ).toHaveLength(0);
      void bare;
    });

    it('respects locked-order sections, and lets sections move freely otherwise', async () => {
      const locked = await newExam('rmock-locked');
      await fill(locked, 4, 2);
      await blueprint(locked, { section_navigation: 'locked_order' });
      const alice = await learner();
      const a = (await startMock(alice, 'rmock-locked').expect(201)).body;
      expect(a).toMatchObject({
        section_navigation: 'locked_order',
        current_section_position: 1,
      });
      const s2 = await save(alice, a.id, 5, ['a'], 1).expect(409);
      expect(s2.body.code).toBe('section_locked');
      await save(alice, a.id, 1, ['a'], 1).expect(200);
      const next = (
        await as(alice)
          .post(`/v1/me/exam-attempts/${a.id}/advance-section`)
          .expect(200)
      ).body;
      expect(next.current_section_position).toBe(2);
      await save(alice, a.id, 5, ['a'], 1).expect(200);
      expect((await save(alice, a.id, 1, ['b'], 2).expect(409)).body.code).toBe(
        'section_locked',
      );
      expect(
        (
          await as(alice)
            .post(`/v1/me/exam-attempts/${a.id}/advance-section`)
            .expect(409)
        ).body.code,
      ).toBe('last_section');

      const free = await learner();
      const f = (await startMock(free, 'rmock').expect(201)).body;
      expect(f.section_navigation).toBe('free');
      await save(free, f.id, 5, ['a'], 1).expect(200);
      expect(
        (
          await as(free)
            .post(`/v1/me/exam-attempts/${f.id}/advance-section`)
            .expect(409)
        ).body.code,
      ).toBe('not_locked_order');
    });
  });

  describe('history and statistics', () => {
    it('lists the learner’s attempts newest first with scores, filters and pages', async () => {
      const { paper } = await makePaper();
      const alice = await learner();
      const ids: string[] = [];
      for (let i = 0; i < 3; i++) {
        const a = (await startFixed(alice, paper.id).expect(201)).body;
        await save(alice, a.id, 1, [i === 1 ? 'a' : 'b'], 1).expect(200);
        await as(alice).post(`/v1/me/exam-attempts/${a.id}/submit`).expect(200);
        ids.push(a.id);
      }
      const open = (await startFixed(alice, paper.id).expect(201)).body;
      const list = (await as(alice).get('/v1/me/exam-attempts').expect(200))
        .body;
      expect(list.items.map((i: { id: string }) => i.id)).toEqual([
        open.id,
        ...ids.reverse(),
      ]);
      expect(list.items[0]).toMatchObject({
        status: 'in_progress',
        marks_obtained: null,
        paper_title: 'Fixture paper',
      });
      expect(list.items[1]).toMatchObject({
        status: 'submitted',
        exam: 'aibe',
        provisional: true,
      });
      const page = (
        await as(alice).get('/v1/me/exam-attempts?limit=2').expect(200)
      ).body;
      expect(page.items).toHaveLength(2);
      const rest = (
        await as(alice)
          .get(`/v1/me/exam-attempts?limit=2&cursor=${page.next_cursor}`)
          .expect(200)
      ).body;
      expect(rest.items).toHaveLength(2);
      expect(rest.next_cursor).toBeNull();
      const done = (
        await as(alice)
          .get('/v1/me/exam-attempts?status=submitted&exam=aibe')
          .expect(200)
      ).body;
      expect(done.items).toHaveLength(3);
      expect(
        (await as(alice).get('/v1/me/exam-attempts?exam=clat').expect(200)).body
          .items,
      ).toHaveLength(0);
    });

    it('summarises finished attempts per exam, and an overdue one counts as finished', async () => {
      const { paper } = await makePaper();
      const alice = await learner();
      const a1 = (await startFixed(alice, paper.id, 'timed').expect(201)).body;
      await save(alice, a1.id, 1, ['b'], 1).expect(200);
      await expire(a1.id);
      const stats = (
        await as(alice).get('/v1/me/exam-attempts/stats').expect(200)
      ).body;
      expect(stats.exams).toHaveLength(1);
      expect(stats.exams[0]).toMatchObject({
        exam: 'aibe',
        attempts: 1,
        with_marks: 1,
        best_percentage: 33.33,
        average_percentage: 33.33,
      });
      const none = await learner();
      expect(
        (await as(none).get('/v1/me/exam-attempts/stats').expect(200)).body,
      ).toEqual({ exams: [] });
    });
  });

  it('leaves the learning games and their rewards untouched', async () => {
    const quiz = (await t.db.select({ n: count() }).from(quizSessions))[0].n;
    const coins = (await t.db.select({ n: count() }).from(coinLedger))[0].n;
    expect({ quiz, coins }).toEqual(before);
  });
});
