import { and, eq } from 'drizzle-orm';
import { newId } from '../src/core/ids.js';
import { auditLog, exams } from '../src/db/schema.js';
import { startApp, type TestApp } from './helpers.js';

type Session = Awaited<ReturnType<TestApp['signInAs']>>;

const content = {
  stem: 'When did the Constitution of India come into force?',
  options: [
    { id: 'a', text: '26 January 1950' },
    { id: 'b', text: '15 August 1947' },
    { id: 'c', text: '26 November 1949' },
  ],
  correct_option_ids: ['a'],
  explanation:
    'It was adopted on 26 November 1949 and came into force on 26 January 1950.',
  source_title: 'Constitution of India',
  source_url: 'https://legislative.gov.in/constitution-of-india/',
  provision_reference: 'Article 394',
  valid_from: '1950-01-26',
};

/** The CMS workflow: who may do what, who may not, and what an admin may do. */
describe('CMS roles and approvals', () => {
  let t: TestApp;
  let admin: Session,
    editor: Session,
    reviewer: Session,
    publisher: Session,
    both: Session,
    editorReviewer: Session,
    learner: Session;
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
  const q = (id: string, action = '') =>
    `/v1/editor/questions/${id}${action && '/' + action}`;
  const create = async (s: Session, body: object = {}) =>
    (
      await as(s)
        .post('/v1/editor/questions', { topic_id: t.topicId, ...body })
        .expect(201)
    ).body;
  const audit = async (questionId: string, action: string) =>
    t.db
      .select()
      .from(auditLog)
      .where(
        and(eq(auditLog.entityId, questionId), eq(auditLog.action, action)),
      );

  beforeAll(async () => {
    t = await startApp();
    [admin, editor, reviewer, publisher, learner] = await Promise.all([
      t.signInAs('admin'),
      t.signInAs('content_editor'),
      t.signInAs('legal_reviewer'),
      t.signInAs('publisher'),
      t.signInAs(),
    ]);
    // One person holding both the reviewer and the publisher roles.
    both = await t.signInAs('legal_reviewer', 'publisher');
    editorReviewer = await t.signInAs('content_editor', 'legal_reviewer');
    examId = newId();
    await t.db
      .insert(exams)
      .values({ id: examId, slug: 'aibe', name: 'AIBE', shortName: 'AIBE' });
  });
  afterAll(() => t.close());

  describe('admin', () => {
    it('creates, edits, reviews, approves and publishes their own question, all audited', async () => {
      const d = await create(admin, { stem: 'Draft' });
      expect(d.latest.created_by).toBe(admin.id);
      await as(admin).patch(q(d.id), content).expect(200);
      await as(admin).post(q(d.id, 'submit')).expect(200);
      // An admin may approve and publish what they wrote.
      await as(admin).post(q(d.id, 'approve'), { note: 'Checked' }).expect(200);
      const live = (await as(admin).post(q(d.id, 'publish')).expect(200)).body;
      expect(live.latest.status).toBe('published');
      expect(live.latest.reviewer_id).toBe(admin.id);

      // Every step is in the audit log with the admin's id, the question and a time.
      for (const action of [
        'question.created',
        'question.updated',
        'question.submitted',
        'question.approved',
        'question.published',
      ]) {
        const rows = await audit(d.id, action);
        expect(rows.length).toBeGreaterThan(0);
        expect(rows[0]).toMatchObject({ actorId: admin.id, entityId: d.id });
        expect(rows[0].createdAt).toBeInstanceOf(Date);
      }
      const approved = (await audit(d.id, 'question.approved'))[0];
      expect(approved.data).toMatchObject({
        actor_role: 'admin',
        admin_override: 'approved own work',
      });
      const published = (await audit(d.id, 'question.published'))[0];
      expect(published.data).toMatchObject({
        actor_role: 'admin',
        admin_override: expect.stringContaining('same admin'),
      });
    });

    it('edits and publishes another user’s question', async () => {
      const d = await create(editor);
      await as(admin).patch(q(d.id), content).expect(200);
      await as(editor).post(q(d.id, 'submit')).expect(200);
      await as(reviewer).post(q(d.id, 'approve')).expect(200);
      const live = (await as(admin).post(q(d.id, 'publish')).expect(200)).body;
      expect(live.latest.status).toBe('published');
      // No override is recorded when nothing was overridden.
      const rows = await audit(d.id, 'question.published');
      expect(rows[0].data).not.toHaveProperty('admin_override');
      expect(rows[0].data).toMatchObject({ actor_role: 'admin' });
    });

    it('can still not publish what has not been approved', async () => {
      const d = await create(admin, content);
      await as(admin).post(q(d.id, 'submit')).expect(200);
      const res = await as(admin).post(q(d.id, 'publish')).expect(409);
      expect(res.body.code).toBe('invalid_transition');
    });

    it('sets exam tags at any stage, audited', async () => {
      const d = await create(admin, content);
      await as(admin).post(q(d.id, 'submit')).expect(200);
      await as(admin).post(q(d.id, 'approve')).expect(200);
      await as(admin).post(q(d.id, 'publish')).expect(200);
      await as(admin)
        .put(q(d.id, 'exam-tags'), { exam_ids: [examId] })
        .expect(200);
      const rows = await t.db
        .select()
        .from(auditLog)
        .where(eq(auditLog.entityId, d.id));
      expect(
        rows.some((r) => r.action.includes('tag') && r.actorId === admin.id),
      ).toBe(true);
    });
  });

  describe('editor, reviewer and publisher', () => {
    it('an editor submits; a different reviewer approves; a different publisher publishes', async () => {
      const d = await create(editor, content);
      const submitted = await as(editor).post(q(d.id, 'submit')).expect(200);
      expect(submitted.body.latest.status).toBe('in_review');
      await as(reviewer).post(q(d.id, 'approve')).expect(200);
      const live = (await as(publisher).post(q(d.id, 'publish')).expect(200))
        .body;
      expect(live.latest.status).toBe('published');
    });

    it('a reviewer cannot approve content they wrote or edited', async () => {
      const own = await create(editorReviewer, content);
      await as(editorReviewer).post(q(own.id, 'submit')).expect(200);
      const res = await as(editorReviewer).post(q(own.id, 'approve')).expect(403);
      expect(res.body.message).toMatch(/cannot approve/);
    });

    it('a publisher cannot publish unapproved content, or approve anything', async () => {
      const d = await create(editor, content);
      // Draft: not publishable.
      await as(publisher).post(q(d.id, 'publish')).expect(409);
      await as(editor).post(q(d.id, 'submit')).expect(200);
      // In review: still not publishable, and a publisher cannot approve.
      await as(publisher).post(q(d.id, 'publish')).expect(409);
      await as(publisher).post(q(d.id, 'approve')).expect(403);
      await as(publisher)
        .post(q(d.id, 'request-changes'), { reason: 'Not mine to say' })
        .expect(403);
    });

    it('the reviewer and the publisher of a version must be different users', async () => {
      const d = await create(editor, content);
      await as(editor).post(q(d.id, 'submit')).expect(200);
      await as(both).post(q(d.id, 'approve')).expect(200);
      const res = await as(both).post(q(d.id, 'publish')).expect(403);
      expect(res.body.message).toMatch(/cannot also publish/);
      // The version stays approved; another publisher can publish it.
      const live = (await as(publisher).post(q(d.id, 'publish')).expect(200))
        .body;
      expect(live.latest.status).toBe('published');
    });

    it('bulk publish applies the same reviewer and publisher rule', async () => {
      const d = await create(editor, content);
      await as(editor).post(q(d.id, 'submit')).expect(200);
      await as(both).post(q(d.id, 'approve')).expect(200);
      const res = await as(both)
        .post('/v1/editor/questions/bulk', {
          action: 'publish',
          question_ids: [d.id],
        })
        .expect(200);
      expect(res.body.results[0]).toMatchObject({ ok: false });
    });
  });

  describe('exam tags cannot be used to skip review', () => {
    it('an editor tags only an unpublished draft', async () => {
      const d = await create(editor, content);
      await as(editor)
        .put(q(d.id, 'exam-tags'), { exam_ids: [examId] })
        .expect(200);
      await as(editor).post(q(d.id, 'submit')).expect(200);
      // In review: frozen.
      const res = await as(editor)
        .put(q(d.id, 'exam-tags'), { exam_ids: [] })
        .expect(403);
      expect(res.body.message).toMatch(/ask an admin/);
      await as(reviewer).post(q(d.id, 'approve')).expect(200);
      await as(publisher).post(q(d.id, 'publish')).expect(200);
      // Published: frozen.
      await as(editor)
        .put(q(d.id, 'exam-tags'), { exam_ids: [] })
        .expect(403);
    });

    it('a publisher or reviewer cannot change tags at all', async () => {
      const d = await create(editor, content);
      await as(publisher)
        .put(q(d.id, 'exam-tags'), { exam_ids: [examId] })
        .expect(403);
      await as(reviewer)
        .put(q(d.id, 'exam-tags'), { exam_ids: [examId] })
        .expect(403);
      await as(learner)
        .put(q(d.id, 'exam-tags'), { exam_ids: [examId] })
        .expect(403);
    });
  });

  describe('exam configuration', () => {
    const paper = (over: object = {}) => ({
      exam_id: examId,
      code: `aibe-${newId().slice(-8)}`,
      title: 'AIBE paper',
      edition: 'XVIII',
      set_label: 'A',
      total_questions: 3,
      ...over,
    });
    const blueprint = (over: object = {}) => ({
      exam_id: examId,
      code: `bp-${newId().slice(-8)}`,
      duration_seconds: 10_800,
      total_questions: 10,
      marks_correct: 1,
      ...over,
    });

    it('blocks everyone but an admin from creating or changing papers, blueprints, content sources and activation', async () => {
      for (const s of [editor, reviewer, publisher, learner]) {
        await as(s).post('/v1/admin/exam-papers', paper()).expect(403);
        await as(s).post('/v1/admin/exam-blueprints', blueprint()).expect(403);
        await as(s).patch(`/v1/admin/exams/${examId}`, { is_active: true }).expect(403);
      }
      const source = { kind: 'third_party', title: 'A source' };
      for (const s of [editor, reviewer, publisher])
        await as(s).post('/v1/admin/content-sources', source).expect(403);

      // The admin can, with the change audited.
      const made = await as(admin)
        .post('/v1/admin/content-sources', source)
        .expect(201);
      const rows = await t.db
        .select()
        .from(auditLog)
        .where(eq(auditLog.entityId, made.body.id));
      expect(rows.some((r) => r.actorId === admin.id)).toBe(true);
    });

    it('lets an admin manage papers and blueprints directly', async () => {
      const p = (await as(admin).post('/v1/admin/exam-papers', paper()).expect(201))
        .body;
      const bp = (
        await as(admin).post('/v1/admin/exam-blueprints', blueprint()).expect(201)
      ).body;
      await as(admin).patch(`/v1/admin/exam-papers/${p.id}`, { title: 'AIBE XVIII' }).expect(200);
      // An incomplete draft is refused by the readiness rules, not by roles.
      await as(admin).post(`/v1/admin/exam-papers/${p.id}/publish`).expect(422);
      await as(admin).post(`/v1/admin/exam-blueprints/${bp.id}/publish`).expect(422);
    });

    it('lets a publisher publish a prepared paper or blueprint, but not create or change them', async () => {
      const p = (await as(admin).post('/v1/admin/exam-papers', paper()).expect(201))
        .body;
      const bp = (
        await as(admin).post('/v1/admin/exam-blueprints', blueprint()).expect(201)
      ).body;
      // Past the role check: the incomplete draft is refused on its content.
      await as(publisher).post(`/v1/admin/exam-papers/${p.id}/publish`).expect(422);
      await as(publisher).post(`/v1/admin/exam-blueprints/${bp.id}/publish`).expect(422);
      // Editing and the rest stay admin-only.
      await as(publisher).patch(`/v1/admin/exam-papers/${p.id}`, { title: 'Nope nope' }).expect(403);
      await as(publisher).post(`/v1/admin/exam-blueprints/${bp.id}/retire`, { reason: 'x' }).expect(403);
      // An editor cannot publish either.
      await as(editor).post(`/v1/admin/exam-papers/${p.id}/publish`).expect(403);
      await as(editor).post(`/v1/admin/exam-blueprints/${bp.id}/publish`).expect(403);
    });
  });
});
