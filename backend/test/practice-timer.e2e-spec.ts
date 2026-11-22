import { eq } from 'drizzle-orm';
import { newId } from '../src/core/ids.js';
import {
  examAttempts,
  exams,
  questions,
  questionVersions,
} from '../src/db/schema.js';
import { startApp, type TestApp } from './helpers.js';

type Session = Awaited<ReturnType<TestApp['signInAs']>>;

/** The paper practice timer: a clock for practising, never the official timed mode. */
describe('paper practice timer', () => {
  let t: TestApp;
  let admin: Session, publisher: Session, editor: Session, learner: Session;
  let aibeId: string;

  const as = (s: Session) => ({
    get: (url: string) => t.http().get(url).auth(s.token, { type: 'bearer' }),
    post: (url: string, body: object = {}) =>
      t.http().post(url).auth(s.token, { type: 'bearer' }).send(body),
    patch: (url: string, body: object) =>
      t.http().patch(url).auth(s.token, { type: 'bearer' }).send(body),
    put: (url: string, body: object) =>
      t.http().put(url).auth(s.token, { type: 'bearer' }).send(body),
  });

  const question = async () => {
    const questionId = newId();
    const versionId = newId();
    await t.db.insert(questions).values({ id: questionId, examOnly: true });
    await t.db.insert(questionVersions).values({
      id: versionId,
      questionId,
      versionNo: 1,
      status: 'published',
      topicId: t.topicId,
      stem: `Stem ${versionId.slice(-8)}`,
      explanation: 'An explanation',
      options: [
        { id: 'a', text: 'First' },
        { id: 'b', text: 'Second' },
        { id: 'c', text: 'Third' },
      ],
      correctOptionIds: ['b'],
      validFrom: '2000-01-01',
    });
    await t.db
      .update(questions)
      .set({ liveVersionId: versionId })
      .where(eq(questions.id, questionId));
    return versionId;
  };

  /** An unverified paper (no duration, rules unconfirmed), published. */
  const paper = async (over: object = {}, publish = true) => {
    const p = (
      await as(admin)
        .post('/v1/admin/exam-papers', {
          exam_id: aibeId,
          code: `p-${newId().slice(-10)}`,
          title: 'Unverified paper',
          total_questions: 2,
          ...over,
        })
        .expect(201)
    ).body;
    const [a, b] = [await question(), await question()];
    await as(admin)
      .put(`/v1/admin/exam-papers/${p.id}/positions`, {
        positions: [
          { position: 1, question_version_id: a, original_ref: '1' },
          { position: 2, question_version_id: b, original_ref: '2' },
        ],
      })
      .expect(200);
    if (publish)
      await as(admin).post(`/v1/admin/exam-papers/${p.id}/publish`).expect(200);
    return p;
  };
  // Each learner may have one open attempt at a time, so every test uses a new one.
  const fresh = () => t.signInAs('learner');
  const start = (s: Session, paperId: string, body: object = {}) =>
    as(s).post('/v1/exams/aibe/attempts', {
      kind: 'fixed_paper',
      paper_id: paperId,
      ...body,
    });

  beforeAll(async () => {
    t = await startApp();
    [admin, publisher, editor, learner] = await Promise.all([
      t.signInAs('admin'),
      t.signInAs('publisher'),
      t.signInAs('content_editor'),
      t.signInAs('learner'),
    ]);
    aibeId = newId();
    await t.db.insert(exams).values({
      id: aibeId,
      slug: 'aibe',
      name: 'AIBE',
      shortName: 'AIBE',
      isActive: true,
    });
  });
  afterAll(() => t.close());

  describe('configuring it', () => {
    it('is set by an admin on a draft, validated, and copied by a revision', async () => {
      const p = (
        await as(admin)
          .post('/v1/admin/exam-papers', {
            exam_id: aibeId,
            code: `cfg-${newId().slice(-8)}`,
            title: 'Config paper',
            total_questions: 2,
          })
          .expect(201)
      ).body;
      expect(p.practice_timer_seconds).toBeNull();
      const url = `/v1/admin/exam-papers/${p.id}`;
      await as(admin).patch(url, { practice_timer_seconds: 59 }).expect(400);
      await as(admin).patch(url, { practice_timer_seconds: 86_401 }).expect(400);
      const set = await as(admin)
        .patch(url, { practice_timer_seconds: 10_800 })
        .expect(200);
      expect(set.body.practice_timer_seconds).toBe(10_800);
      // It touches nothing official.
      expect(set.body).toMatchObject({
        duration_seconds: null,
        config_status: 'unverified',
      });
      await as(admin).patch(url, { practice_timer_seconds: null }).expect(200);
      await as(admin).patch(url, { practice_timer_seconds: 10_800 }).expect(200);
      // Only an admin changes it.
      for (const s of [editor, publisher, learner])
        await as(s).patch(url, { practice_timer_seconds: 60 }).expect(403);
    });

    it('is frozen with a published paper, and a revision keeps it', async () => {
      const p = await paper({ practice_timer_seconds: 7200 });
      await as(admin)
        .patch(`/v1/admin/exam-papers/${p.id}`, { practice_timer_seconds: 60 })
        .expect(409);
      const rev = (
        await as(admin).post(`/v1/admin/exam-papers/${p.id}/revise`).expect(201)
      ).body;
      expect(rev).toMatchObject({
        revision: 2,
        status: 'draft',
        practice_timer_seconds: 7200,
      });
    });

    it('is shown to learners with the paper, beside the unchanged official fields', async () => {
      const p = await paper({ practice_timer_seconds: 10_800 });
      const list = await as(learner).get('/v1/exams/aibe/papers').expect(200);
      const mine = list.body.items.find((x: { id: string }) => x.id === p.id);
      expect(mine).toMatchObject({
        practice_timer_seconds: 10_800,
        duration_seconds: null,
        config_status: 'unverified',
      });
    });
  });

  describe('using it', () => {
    it('runs a server clock on an unverified paper, in practice mode', async () => {
      const p = await paper({ practice_timer_seconds: 10_800 });
      const me = await fresh();
      const before = Date.now();
      const res = await start(me, p.id, { practice_timer: true }).expect(201);
      expect(res.body.mode).toBe('practice');
      const left = res.body.remaining_seconds as number;
      expect(left).toBeGreaterThan(10_790);
      expect(left).toBeLessThanOrEqual(10_800);
      expect(Date.parse(res.body.deadline_at)).toBeGreaterThanOrEqual(
        before + 10_800 * 1000 - 1000,
      );
      const [row] = await t.db
        .select()
        .from(examAttempts)
        .where(eq(examAttempts.id, res.body.id));
      expect(row).toMatchObject({ mode: 'practice', durationSeconds: 10_800 });
      // It ends like any attempt with a deadline: late saves are refused.
      await t.db
        .update(examAttempts)
        .set({ deadlineAt: new Date(Date.now() - 5000) })
        .where(eq(examAttempts.id, res.body.id));
      const late = await as(me)
        .put(`/v1/me/exam-attempts/${res.body.id}/answers/1`, {
          selected_option_ids: ['b'],
          seq: 1,
        })
        .expect(409);
      expect(late.body.code).toBe('attempt_expired');
      const done = await as(me)
        .get(`/v1/me/exam-attempts/${res.body.id}`)
        .expect(200);
      expect(done.body.status).toBe('expired');
    });

    it('without the option a practice attempt has no clock, as before', async () => {
      const p = await paper({ practice_timer_seconds: 10_800 });
      const res = await start(await fresh(), p.id).expect(201);
      expect(res.body).toMatchObject({
        mode: 'practice',
        deadline_at: null,
        remaining_seconds: null,
      });
    });

    it('refuses it on a paper that has none', async () => {
      const p = await paper();
      const res = await start(await fresh(), p.id, { practice_timer: true }).expect(
        409,
      );
      expect(res.body.code).toBe('practice_timer_not_available');
    });
  });

  describe('the official timed mode is unchanged', () => {
    it('still refuses timed mode on an unverified paper, even with a practice timer', async () => {
      const p = await paper({
        practice_timer_seconds: 10_800,
        duration_seconds: 10_800,
      });
      const res = await start(await fresh(), p.id, { mode: 'timed' }).expect(409);
      expect(res.body.code).toBe('timed_mode_not_allowed');
      const noDuration = await paper({ practice_timer_seconds: 10_800 });
      const res2 = await start(await fresh(), noDuration.id, {
        mode: 'timed',
      }).expect(409);
      expect(res2.body.code).toBe('timed_mode_not_allowed');
    });

    it('does not let the practice timer be combined with the official timed mode, or used on a random mock', async () => {
      const p = await paper({ practice_timer_seconds: 10_800 });
      await start(await fresh(), p.id, { mode: 'timed', practice_timer: true }).expect(
        422,
      );
      await as(await fresh())
        .post('/v1/exams/aibe/attempts', {
          kind: 'random_mock',
          practice_timer: true,
        })
        .expect(422);
    });

    it('still runs the official clock from duration_seconds on a confirmed paper', async () => {
      const p = await paper({
        duration_seconds: 3600,
        practice_timer_seconds: 10_800,
        config_status: 'official_confirmed',
      });
      const res = await start(await fresh(), p.id, { mode: 'timed' }).expect(201);
      expect(res.body.mode).toBe('timed');
      expect(res.body.remaining_seconds).toBeLessThanOrEqual(3600);
      expect(res.body.remaining_seconds).toBeGreaterThan(3590);
    });
  });
});
