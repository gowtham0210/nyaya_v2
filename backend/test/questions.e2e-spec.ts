import { eq } from 'drizzle-orm';
import { auditLog, topics } from '../src/db/schema.js';
import { startApp, type TestApp } from './helpers.js';

type Session = Awaited<ReturnType<TestApp['signInAs']>>;

const completeContent = {
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

describe('question lifecycle', () => {
  let t: TestApp;
  let editor: Session, reviewer: Session, publisher: Session, analyst: Session;

  const as = (s: Session) => ({
    get: (url: string) => t.http().get(url).auth(s.token, { type: 'bearer' }),
    post: (url: string, body: object = {}) =>
      t.http().post(url).auth(s.token, { type: 'bearer' }).send(body),
    patch: (url: string, body: object) =>
      t.http().patch(url).auth(s.token, { type: 'bearer' }).send(body),
  });
  const q = (id: string, action = '') =>
    `/v1/editor/questions/${id}${action && '/' + action}`;

  const createDraft = async (body: object = {}) =>
    (
      await as(editor)
        .post('/v1/editor/questions', { topic_id: t.topicId, ...body })
        .expect(201)
    ).body;

  beforeAll(async () => {
    t = await startApp();
    [editor, reviewer, publisher, analyst] = await Promise.all([
      t.signInAs('content_editor'),
      t.signInAs('legal_reviewer'),
      t.signInAs('publisher'),
      t.signInAs('analyst'),
    ]);
  });
  afterAll(() => t.close());

  it('takes a question from draft to published, with review and audit', async () => {
    const draft = await createDraft({ stem: 'Unfinished' });
    expect(draft.latest).toMatchObject({
      version_no: 1,
      status: 'draft',
      created_by: editor.id,
    });

    // Incomplete drafts cannot go to review; the response lists what is missing.
    const missing = await as(editor).post(q(draft.id, 'submit')).expect(422);
    expect(missing.body.code).toBe('content_incomplete');
    expect(missing.body.details.map((d: { field: string }) => d.field)).toEqual(
      expect.arrayContaining([
        'options',
        'explanation',
        'source_title',
        'valid_from',
      ]),
    );

    await as(editor).patch(q(draft.id), completeContent).expect(200);
    const inReview = await as(editor).post(q(draft.id, 'submit')).expect(200);
    expect(inReview.body.latest.status).toBe('in_review');

    // Content is frozen while in review.
    expect(
      (await as(editor).patch(q(draft.id), { stem: 'Changed' }).expect(409))
        .body.code,
    ).toBe('invalid_transition');

    await as(reviewer)
      .post(q(draft.id, 'request-changes'), {
        reason: 'Cite the official text',
      })
      .expect(200);
    await as(editor)
      .patch(q(draft.id), { citation: 'Constitution of India, Art. 394' })
      .expect(200);
    await as(editor).post(q(draft.id, 'submit')).expect(200);

    const approved = await as(reviewer)
      .post(q(draft.id, 'approve'), { note: 'Checked against the source' })
      .expect(200);
    expect(approved.body.latest).toMatchObject({
      status: 'approved',
      reviewer_id: reviewer.id,
    });
    expect(approved.body.latest.verified_at).toBeTruthy();
    expect(
      approved.body.reviews.map((r: { decision: string }) => r.decision),
    ).toEqual(['changes_requested', 'approved']);

    const published = await as(publisher)
      .post(q(draft.id, 'publish'))
      .expect(200);
    expect(published.body.latest).toMatchObject({
      status: 'published',
      published_by: publisher.id,
    });
    expect(published.body.live_version_id).toBe(published.body.latest.id);

    // A published version is immutable.
    await as(editor).patch(q(draft.id), { stem: 'Sneaky edit' }).expect(409);

    const actions = (
      await t.db.select().from(auditLog).where(eq(auditLog.entityId, draft.id))
    ).map((a) => a.action);
    expect(actions).toEqual([
      'question.created',
      'question.updated',
      'question.submitted',
      'question.changes_requested',
      'question.updated',
      'question.submitted',
      'question.approved',
      'question.published',
    ]);
  });

  /** Creates and publishes a question; returns its detail. */
  const publishNew = async () => {
    const d = await createDraft(completeContent);
    await as(editor).post(q(d.id, 'submit')).expect(200);
    await as(reviewer).post(q(d.id, 'approve')).expect(200);
    return (await as(publisher).post(q(d.id, 'publish')).expect(200)).body;
  };

  it('keeps the old version live during a revision, then supersedes it', async () => {
    const v1 = await publishNew();
    const revising = await as(editor)
      .post(q(v1.id, 'revise'), { change_note: 'Clarify wording' })
      .expect(200);
    expect(revising.body.latest).toMatchObject({
      version_no: 2,
      status: 'draft',
      change_note: 'Clarify wording',
    });
    expect(revising.body.latest.reviewer_id).toBeNull();
    expect(revising.body.live_version_id).toBe(v1.latest.id);

    await as(editor)
      .patch(q(v1.id), {
        stem: 'On which date did the Constitution of India come into force?',
      })
      .expect(200);
    await as(editor).post(q(v1.id, 'submit')).expect(200);
    await as(reviewer).post(q(v1.id, 'approve')).expect(200);
    const v2 = (await as(publisher).post(q(v1.id, 'publish')).expect(200)).body;

    expect(v2.live_version_id).toBe(v2.latest.id);
    expect(v2.versions.map((v: { status: string }) => v.status)).toEqual([
      'superseded',
      'published',
    ]);
  });

  it('retires the live version and allows a corrected version later', async () => {
    const live = await publishNew();
    const retired = (
      await as(publisher)
        .post(q(live.id, 'retire'), { reason: 'Law amended' })
        .expect(200)
    ).body;
    expect(retired.live_version_id).toBeNull();
    expect(retired.retired_at).toBeTruthy();
    expect(retired.latest.status).toBe('retired');

    await as(publisher)
      .post(q(live.id, 'retire'), { reason: 'Again' })
      .expect(409);
    const fixed = await as(editor)
      .post(q(live.id, 'revise'), { change_note: 'Updated for amendment' })
      .expect(200);
    expect(fixed.body.latest).toMatchObject({ version_no: 2, status: 'draft' });
  });

  it('enforces roles on every step', async () => {
    const d = await createDraft(completeContent);
    await as(reviewer)
      .post('/v1/editor/questions', { topic_id: t.topicId })
      .expect(403);
    await as(analyst).patch(q(d.id), { stem: 'x' }).expect(403);
    await as(editor).post(q(d.id, 'submit')).expect(200);
    await as(editor).post(q(d.id, 'approve')).expect(403);
    await as(reviewer).post(q(d.id, 'approve')).expect(200);
    const res = await as(editor).post(q(d.id, 'publish')).expect(403);
    expect(res.body.code).toBe('forbidden');
    await as(analyst).get(q(d.id)).expect(200);
  });

  it('does not let a reviewer approve their own work', async () => {
    const both = await t.signInAs('content_editor', 'legal_reviewer');
    const d = (
      await as(both)
        .post('/v1/editor/questions', {
          topic_id: t.topicId,
          ...completeContent,
        })
        .expect(201)
    ).body;
    await as(both).post(q(d.id, 'submit')).expect(200);
    const res = await as(both).post(q(d.id, 'approve')).expect(403);
    expect(res.body.message).toMatch(/cannot approve/);
  });

  it('does not let a reviewer approve a version they edited earlier', async () => {
    const both = await t.signInAs('content_editor', 'legal_reviewer');
    const d = await createDraft(completeContent);
    await as(both)
      .patch(q(d.id), { explanation: 'Edited by the reviewer.' })
      .expect(200);
    await as(editor)
      .patch(q(d.id), { explanation: completeContent.explanation })
      .expect(200);
    await as(editor).post(q(d.id, 'submit')).expect(200);
    const res = await as(both).post(q(d.id, 'approve')).expect(403);
    expect(res.body.message).toMatch(/cannot approve/);
    await as(reviewer).post(q(d.id, 'approve')).expect(200);
  });

  it('will not publish into an inactive topic', async () => {
    const d = await createDraft(completeContent);
    await as(editor).post(q(d.id, 'submit')).expect(200);
    await as(reviewer).post(q(d.id, 'approve')).expect(200);
    await t.db
      .update(topics)
      .set({ isActive: false })
      .where(eq(topics.id, t.topicId));
    try {
      const res = await as(publisher).post(q(d.id, 'publish')).expect(422);
      expect(res.body.details).toEqual([
        { field: 'topic_id', reason: 'The topic is inactive' },
      ]);
    } finally {
      await t.db
        .update(topics)
        .set({ isActive: true })
        .where(eq(topics.id, t.topicId));
    }
  });

  it('validates input and ids', async () => {
    await as(editor)
      .post('/v1/editor/questions', {
        topic_id: '00000000-0000-7000-8000-000000000000',
      })
      .expect(422);
    const bad = await as(editor)
      .post('/v1/editor/questions', {
        topic_id: t.topicId,
        difficulty: 9,
        stem: null,
      })
      .expect(400);
    expect(bad.body.code).toBe('validation_failed');
    await as(editor).get('/v1/editor/questions/not-a-uuid').expect(400);
    await as(editor)
      .get('/v1/editor/questions/00000000-0000-7000-8000-000000000000')
      .expect(404);
  });

  it('lists the newest first, filters by status and pages with a cursor', async () => {
    for (let i = 0; i < 3; i++)
      await createDraft({ stem: `Paging question ${i} 100% sure_` });
    const page1 = (
      await as(analyst)
        .get('/v1/editor/questions?status=draft&limit=2')
        .expect(200)
    ).body;
    expect(page1.items).toHaveLength(2);
    expect(
      page1.items.every(
        (i: { latest: { status: string } }) => i.latest.status === 'draft',
      ),
    ).toBe(true);
    expect(page1.next_cursor).toBeTruthy();

    const page2 = (
      await as(analyst)
        .get(
          `/v1/editor/questions?status=draft&limit=2&cursor=${page1.next_cursor}`,
        )
        .expect(200)
    ).body;
    const ids = [...page1.items, ...page2.items].map(
      (i: { id: string }) => i.id,
    );
    expect(new Set(ids).size).toBe(ids.length);

    // Search treats % and _ literally.
    const found = (
      await as(analyst)
        .get(`/v1/editor/questions?q=${encodeURIComponent('100% sure_')}`)
        .expect(200)
    ).body;
    expect(found.items).toHaveLength(3);
    expect(found.items[0].latest.stem).toBe('Paging question 2 100% sure_');

    await as(analyst).get('/v1/editor/questions?cursor=garbage').expect(400);
  });

  describe('bulk steps', () => {
    const bulk = (s: Session, body: object) =>
      as(s).post('/v1/editor/questions/bulk', body);

    it('runs each question on its own and reports each result in order', async () => {
      const ready = await createDraft(completeContent);
      const ready2 = await createDraft(completeContent);
      const unfinished = await createDraft({ stem: 'No options yet' });
      const missing = '00000000-0000-7000-8000-000000000000';

      const submitted = await bulk(editor, {
        action: 'submit',
        question_ids: [ready.id, unfinished.id, missing, ready2.id],
      }).expect(200);
      expect(submitted.body).toMatchObject({ succeeded: 2, failed: 2 });
      expect(submitted.body.results).toMatchObject([
        { question_id: ready.id, ok: true, status: 'in_review' },
        {
          question_id: unfinished.id,
          ok: false,
          error: { code: 'content_incomplete' },
        },
        { question_id: missing, ok: false, error: { code: 'not_found' } },
        { question_id: ready2.id, ok: true, status: 'in_review' },
      ]);
      expect(submitted.body.results[1].error.details.length).toBeGreaterThan(0);

      const approved = await bulk(reviewer, {
        action: 'approve',
        question_ids: [ready.id, ready2.id],
        note: 'Sources checked',
      }).expect(200);
      expect(approved.body).toMatchObject({ succeeded: 2, failed: 0 });
      const detail = (await as(reviewer).get(q(ready.id)).expect(200)).body;
      expect(detail.latest).toMatchObject({
        status: 'approved',
        reviewer_id: reviewer.id,
      });
      expect(detail.reviews.at(-1)).toMatchObject({
        decision: 'approved',
        reason: 'Sources checked',
      });

      // Publishing twice: the second run finds nothing approved.
      await bulk(publisher, {
        action: 'publish',
        question_ids: [ready.id, ready2.id],
      }).expect(200);
      const again = await bulk(publisher, {
        action: 'publish',
        question_ids: [ready.id],
      }).expect(200);
      expect(again.body.results[0]).toMatchObject({
        ok: false,
        error: { code: 'invalid_transition' },
      });

      // Every question that moved has its own audit entries.
      const audit = await t.db
        .select()
        .from(auditLog)
        .where(eq(auditLog.entityId, ready2.id));
      expect(audit.map((a) => a.action)).toEqual(
        expect.arrayContaining([
          'question.submitted',
          'question.approved',
          'question.published',
        ]),
      );
    });

    it("checks the chosen step's roles and the reviewer rule", async () => {
      const own = await createDraft(completeContent);
      await bulk(editor, { action: 'approve', question_ids: [own.id] }).expect(
        403,
      );
      await bulk(reviewer, {
        action: 'publish',
        question_ids: [own.id],
      }).expect(403);
      await bulk(analyst, { action: 'submit', question_ids: [own.id] }).expect(
        403,
      );

      // A reviewer who also edits cannot approve their own version in bulk either.
      const both = await t.signInAs('content_editor', 'legal_reviewer');
      const mine = (
        await as(both)
          .post('/v1/editor/questions', {
            topic_id: t.topicId,
            ...completeContent,
          })
          .expect(201)
      ).body;
      await bulk(both, { action: 'submit', question_ids: [mine.id] }).expect(
        200,
      );
      const res = await bulk(both, {
        action: 'approve',
        question_ids: [mine.id],
      }).expect(200);
      expect(res.body.results[0]).toMatchObject({
        ok: false,
        error: { code: 'forbidden' },
      });
    });

    it('validates the request', async () => {
      for (const body of [
        { action: 'retire', question_ids: [t.topicId] },
        { action: 'submit', question_ids: [] },
        { action: 'submit', question_ids: ['not-a-uuid'] },
        { action: 'submit', question_ids: [t.topicId, t.topicId] },
        {
          action: 'submit',
          question_ids: Array.from(
            { length: 101 },
            (_, i) => `00000000-0000-7000-8000-${String(i).padStart(12, '0')}`,
          ),
        },
      ])
        await bulk(editor, body).expect(400);
    });
  });
});
