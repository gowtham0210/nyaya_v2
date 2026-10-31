import { startApp, type TestApp } from './helpers.js';

const complete = {
  category: 'supreme_court',
  title: 'Court rules on bail delays',
  summary:
    'The Supreme Court said long delays in hearing bail pleas violate Article 21.',
  key_points: [
    'Bail pleas must be heard quickly.',
    'Delay can itself be a ground.',
  ],
  why_it_matters: 'People waiting in jail get their bail heard sooner.',
  source: 'Supreme Court of India, 3 March 2026',
  source_url: 'https://main.sci.gov.in/judgment',
  event_date: '2026-03-03',
  read_minutes: 2,
};

describe('legal news', () => {
  let t: TestApp;
  let editor: Awaited<ReturnType<TestApp['signInAs']>>;
  let reviewer: Awaited<ReturnType<TestApp['signInAs']>>;
  let publisher: Awaited<ReturnType<TestApp['signInAs']>>;

  beforeAll(async () => {
    t = await startApp();
    editor = await t.signInAs('content_editor');
    reviewer = await t.signInAs('legal_reviewer');
    publisher = await t.signInAs('publisher');
  });
  afterAll(() => t.close());

  const as = (token: string) => ({
    get: (url: string) => t.http().get(url).auth(token, { type: 'bearer' }),
    post: (url: string, body: object = {}) =>
      t.http().post(url).auth(token, { type: 'bearer' }).send(body),
    patch: (url: string, body: object) =>
      t.http().patch(url).auth(token, { type: 'bearer' }).send(body),
  });
  const publicTitles = async () =>
    (await t.http().get('/v1/news').expect(200)).body.items.map(
      (a: { title: string }) => a.title,
    );

  /** Writes, reviews and publishes an article; returns its id. */
  const publishArticle = async (fields: object = {}) => {
    const created = await as(editor.token)
      .post('/v1/editor/news', { ...complete, ...fields })
      .expect(201);
    const id = created.body.id as string;
    await as(editor.token).post(`/v1/editor/news/${id}/submit`).expect(200);
    await as(reviewer.token).post(`/v1/editor/news/${id}/approve`).expect(200);
    await as(publisher.token).post(`/v1/editor/news/${id}/publish`).expect(200);
    return id;
  };

  it("starts with the app's 10 articles, published and newest first, without signing in", async () => {
    const res = await t.http().get('/v1/news').expect(200);
    expect(res.body.items).toHaveLength(10);
    const dates = res.body.items.map((a: { date: string }) => a.date);
    expect(dates).toEqual([...dates].sort().reverse());
    expect(res.body.items[0]).toMatchObject({
      category: 'supreme_court',
      title: 'Supreme Court sets timelines for Governors on State Bills',
      date: '2025-04-08',
      read_minutes: 3,
    });
    expect(res.body.items[0].key_points).toHaveLength(3);
  });

  it('goes from draft to the app only after review and publishing', async () => {
    const draft = await as(editor.token)
      .post('/v1/editor/news', { category: 'legislation', title: 'Draft only' })
      .expect(201);
    expect(draft.body.status).toBe('draft');
    const id = draft.body.id;

    // Incomplete: refused, field by field.
    const refused = await as(editor.token)
      .post(`/v1/editor/news/${id}/submit`)
      .expect(422);
    expect(refused.body.code).toBe('content_incomplete');
    expect(refused.body.details.map((d: { field: string }) => d.field)).toEqual(
      expect.arrayContaining([
        'summary',
        'key_points',
        'why_it_matters',
        'source',
        'event_date',
      ]),
    );

    await as(editor.token)
      .patch(`/v1/editor/news/${id}`, {
        ...complete,
        title: 'Bail delay ruling',
      })
      .expect(200);
    await as(editor.token).post(`/v1/editor/news/${id}/submit`).expect(200);
    expect(await publicTitles()).not.toContain('Bail delay ruling');

    // Not publishable before approval.
    await as(publisher.token).post(`/v1/editor/news/${id}/publish`).expect(409);
    await as(reviewer.token).post(`/v1/editor/news/${id}/approve`).expect(200);
    const live = await as(publisher.token)
      .post(`/v1/editor/news/${id}/publish`)
      .expect(200);
    expect(live.body).toMatchObject({
      status: 'published',
      reviewer_id: reviewer.id,
    });
    expect((await publicTitles())[0]).toBe('Bail delay ruling');
  });

  it("sends it back with the reviewer's reason", async () => {
    const id = (
      await as(editor.token).post('/v1/editor/news', complete).expect(201)
    ).body.id;
    await as(editor.token).post(`/v1/editor/news/${id}/submit`).expect(200);
    await as(reviewer.token)
      .post(`/v1/editor/news/${id}/request-changes`, {
        reason: 'Cite the case name',
      })
      .expect(200);
    const back = await as(editor.token)
      .get(`/v1/editor/news/${id}`)
      .expect(200);
    expect(back.body).toMatchObject({
      status: 'changes_requested',
      changes_reason: 'Cite the case name',
    });
    await as(editor.token)
      .patch(`/v1/editor/news/${id}`, { title: 'X v. Union of India' })
      .expect(200);
    await as(editor.token).post(`/v1/editor/news/${id}/submit`).expect(200);
    const again = await as(editor.token)
      .get(`/v1/editor/news/${id}`)
      .expect(200);
    expect(again.body.changes_reason).toBeNull();
  });

  it('does not let a reviewer approve an article they wrote or edited', async () => {
    const both = await t.signInAs('content_editor', 'legal_reviewer');
    const own = (
      await as(both.token).post('/v1/editor/news', complete).expect(201)
    ).body.id;
    await as(both.token).post(`/v1/editor/news/${own}/submit`).expect(200);
    await as(both.token).post(`/v1/editor/news/${own}/approve`).expect(403);

    // Edited by them, last saved by someone else: still refused.
    const edited = (
      await as(editor.token).post('/v1/editor/news', complete).expect(201)
    ).body.id;
    await as(both.token)
      .patch(`/v1/editor/news/${edited}`, { read_minutes: 4 })
      .expect(200);
    await as(editor.token)
      .patch(`/v1/editor/news/${edited}`, { read_minutes: 5 })
      .expect(200);
    await as(editor.token).post(`/v1/editor/news/${edited}/submit`).expect(200);
    await as(both.token).post(`/v1/editor/news/${edited}/approve`).expect(403);
    await as(reviewer.token)
      .post(`/v1/editor/news/${edited}/approve`)
      .expect(200);
  });

  it('takes an article off the app to correct it, and when retired', async () => {
    const id = await publishArticle({ title: 'To be corrected' });
    const draft = await as(editor.token)
      .post(`/v1/editor/news/${id}/revise`, { reason: 'Wrong date' })
      .expect(200);
    expect(draft.body).toMatchObject({ status: 'draft', reviewer_id: null });
    expect(await publicTitles()).not.toContain('To be corrected');
    // The correction needs a fresh review.
    await as(editor.token).post(`/v1/editor/news/${id}/submit`).expect(200);
    await as(publisher.token).post(`/v1/editor/news/${id}/publish`).expect(409);

    const gone = await publishArticle({ title: 'To be retired' });
    await as(publisher.token)
      .post(`/v1/editor/news/${gone}/retire`, { reason: 'Overruled' })
      .expect(200);
    expect(await publicTitles()).not.toContain('To be retired');
  });

  it('checks roles and the source link', async () => {
    const learner = await t.signInAs('learner');
    await as(learner.token).get('/v1/editor/news').expect(403);
    await as(reviewer.token).post('/v1/editor/news', complete).expect(403);
    await as(editor.token)
      .post('/v1/editor/news', { title: 'No category' })
      .expect(400);

    const id = (
      await as(editor.token)
        .post('/v1/editor/news', {
          ...complete,
          source_url: 'http://insecure.example',
        })
        .expect(201)
    ).body.id;
    const res = await as(editor.token)
      .post(`/v1/editor/news/${id}/submit`)
      .expect(422);
    expect(res.body.details).toEqual([
      { field: 'source_url', reason: 'The source link must use https' },
    ]);
  });

  it('lists articles by status for staff', async () => {
    const res = await as(reviewer.token)
      .get('/v1/editor/news?status=published&limit=100')
      .expect(200);
    expect(res.body.items.length).toBeGreaterThanOrEqual(10);
    expect(
      res.body.items.every((a: { status: string }) => a.status === 'published'),
    ).toBe(true);
  });
});
