import { and, eq } from 'drizzle-orm';
import { newId } from '../src/core/ids.js';
import {
  auditLog,
  contentReports,
  questions,
  questionVersions,
} from '../src/db/schema.js';
import { startApp, type TestApp } from './helpers.js';

type Session = Awaited<ReturnType<TestApp['signInAs']>>;

describe('reporting questions', () => {
  let t: TestApp;
  let versionId: string;
  let questionId: string;
  let unseenVersion: string;

  const as = (s: Session) => ({
    get: (url: string) => t.http().get(url).auth(s.token, { type: 'bearer' }),
    post: (url: string, body: object = {}) =>
      t.http().post(url).auth(s.token, { type: 'bearer' }).send(body),
    patch: (url: string, body: object) =>
      t.http().patch(url).auth(s.token, { type: 'bearer' }).send(body),
  });
  /** A learner who has been shown the question (one duel). */
  const shown = async () => {
    const s = await t.signInAs('learner');
    await as(s)
      .post('/v1/quiz-sessions', {
        mode: 'duel',
        topic_id: t.topicId,
        question_count: 1,
      })
      .expect(201);
    return s;
  };
  const report = (s: Session, body: object = {}) =>
    as(s).post('/v1/content-reports', {
      question_version_id: versionId,
      reason: 'wrong_answer',
      ...body,
    });

  beforeAll(async () => {
    t = await startApp();
    const add = async (live: boolean) => {
      const qid = newId();
      const vid = newId();
      await t.db.insert(questions).values({ id: qid });
      await t.db.insert(questionVersions).values({
        id: vid,
        questionId: qid,
        versionNo: 1,
        status: live ? 'published' : 'draft',
        topicId: t.topicId,
        language: 'en',
        difficulty: 1,
        stem: live ? 'Is a Zero FIR allowed?' : 'Draft only',
        options: [
          { id: 'a', text: 'Yes' },
          { id: 'b', text: 'No' },
        ],
        correctOptionIds: ['a'],
        explanation: 'Section 173 BNSS.',
        validFrom: '2000-01-01',
      });
      if (live)
        await t.db
          .update(questions)
          .set({ liveVersionId: vid })
          .where(eq(questions.id, qid));
      return { qid, vid };
    };
    ({ qid: questionId, vid: versionId } = await add(true));
    unseenVersion = (await add(false)).vid;
  });
  afterAll(() => t.close());

  it('takes a report about a question you were shown, once while it is open', async () => {
    const s = await shown();
    const res = await report(s, {
      comment: '  The answer changed in 2024.  ',
    }).expect(201);
    expect(res.body.id).toBeDefined();
    const again = await report(s).expect(409);
    expect(again.body.code).toBe('already_reported');
    const [row] = await t.db
      .select()
      .from(contentReports)
      .where(eq(contentReports.id, res.body.id));
    expect(row).toMatchObject({
      comment: 'The answer changed in 2024.',
      outcome: null,
    });
    // A report never changes the question.
    const [q] = await t.db
      .select({ live: questions.liveVersionId, retired: questions.retiredAt })
      .from(questions)
      .where(eq(questions.id, questionId));
    expect(q).toEqual({ live: versionId, retired: null });
  });

  it('refuses versions you were never shown, bad reasons and long comments', async () => {
    const s = await shown();
    await report(s, { question_version_id: unseenVersion }).expect(404);
    await report(s, { reason: 'boring' }).expect(400);
    await report(s, { comment: 'x'.repeat(501) }).expect(400);
  });

  it('caps reports at 20 a day', async () => {
    const s = await shown();
    for (let i = 0; i < 20; i++)
      await t.db.insert(contentReports).values({
        id: newId(),
        userId: s.id,
        questionVersionId: versionId,
        reason: 'typo',
        outcome: 'no_change',
        resolvedBy: s.id,
        resolvedAt: new Date(),
      });
    const res = await report(s).expect(429);
    expect(res.body.code).toBe('report_limit');
  });

  it('gives staff a queue, urgent first, and closes reports with an audit trail', async () => {
    const [learner, other] = [await shown(), await shown()];
    await report(learner, { reason: 'typo' }).expect(201);
    await report(other, { reason: 'outdated_law' }).expect(201);
    const editor = await t.signInAs('content_editor');
    await as(learner).get('/v1/admin/content-reports').expect(403);

    const queue = (
      await as(editor)
        .get(`/v1/admin/content-reports?question_id=${questionId}`)
        .expect(200)
    ).body.items;
    expect(queue[0]).toMatchObject({
      urgent: true,
      question_id: questionId,
      stem: 'Is a Zero FIR allowed?',
      version_no: 1,
      outcome: null,
    });
    expect(queue.at(-1).urgent).toBe(false);
    expect(JSON.stringify(queue)).not.toContain('@');

    const target = queue.find((r: { reason: string }) => r.reason === 'typo');
    const closed = (
      await as(editor)
        .patch(`/v1/admin/content-reports/${target.id}`, {
          outcome: 'no_change',
          note: 'Checked: the wording is right.',
        })
        .expect(200)
    ).body;
    expect(closed).toMatchObject({
      outcome: 'no_change',
      resolution_note: 'Checked: the wording is right.',
    });
    expect(closed.resolved_by).toBeTruthy();
    await as(editor)
      .patch(`/v1/admin/content-reports/${target.id}`, {
        outcome: 'fixed',
        note: 'Again',
      })
      .expect(409);
    await as(editor)
      .patch(`/v1/admin/content-reports/${target.id}`, {
        outcome: 'fixed',
        note: ' ',
      })
      .expect(400);
    const audit = await t.db
      .select({ action: auditLog.action })
      .from(auditLog)
      .where(
        and(
          eq(auditLog.entityType, 'content_report'),
          eq(auditLog.entityId, target.id),
        ),
      );
    expect(audit.map((a) => a.action)).toEqual(['report.resolved']);

    // Closed reports leave the open queue and the learner can report again.
    const open = (await as(editor).get('/v1/admin/content-reports').expect(200))
      .body.items;
    expect(open.some((r: { id: string }) => r.id === target.id)).toBe(false);
    await report(learner, { reason: 'typo' }).expect(201);
  });
});
