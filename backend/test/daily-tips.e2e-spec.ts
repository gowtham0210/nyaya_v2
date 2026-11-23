import { DailyTipsService } from '../src/daily-tips/daily-tips.service.js';
import { indiaToday } from '../src/learn/scoring.js';
import { startApp, type TestApp } from './helpers.js';

const DAY = 86_400_000;
const dayFrom = (offset: number) =>
  indiaToday(new Date(Date.now() + offset * DAY));
const today = () => dayFrom(0);

const complete = () => ({
  category: 'consumer_rights',
  title: 'You can ask for a bill',
  summary: 'Every seller must give you a bill on request.',
  explanation:
    'A consumer can ask for a bill or receipt for any purchase. Keep it: it is your proof if the product is faulty.',
  legal_reference: 'Consumer Protection Act, 2019, Section 2(9)',
  source_url: 'https://consumeraffairs.nic.in/acts-and-rules',
  publish_date: today(),
  last_verified_on: today(),
});

describe('daily tips', () => {
  let t: TestApp;
  let editor: Awaited<ReturnType<TestApp['signInAs']>>;
  let reviewer: Awaited<ReturnType<TestApp['signInAs']>>;
  let publisher: Awaited<ReturnType<TestApp['signInAs']>>;
  let learner: Awaited<ReturnType<TestApp['signInAs']>>;

  beforeAll(async () => {
    t = await startApp();
    editor = await t.signInAs('content_editor');
    reviewer = await t.signInAs('legal_reviewer');
    publisher = await t.signInAs('publisher');
    learner = await t.signInAs('learner');
  });
  afterAll(() => t.close());

  const as = (token: string) => ({
    get: (url: string) => t.http().get(url).auth(token, { type: 'bearer' }),
    post: (url: string, body: object = {}) =>
      t.http().post(url).auth(token, { type: 'bearer' }).send(body),
    patch: (url: string, body: object) =>
      t.http().patch(url).auth(token, { type: 'bearer' }).send(body),
  });

  const create = async (fields: object = {}) =>
    (
      await as(editor.token)
        .post('/v1/editor/daily-tips', { ...complete(), ...fields })
        .expect(201)
    ).body.id as string;
  const submit = (id: string) =>
    as(editor.token).post(`/v1/editor/daily-tips/${id}/submit`);
  const approve = (id: string) =>
    as(reviewer.token).post(`/v1/editor/daily-tips/${id}/approve`);
  const publish = (id: string) =>
    as(publisher.token).post(`/v1/editor/daily-tips/${id}/publish`);
  const publishTip = async (fields: object = {}) => {
    const id = await create(fields);
    await submit(id).expect(200);
    await approve(id).expect(200);
    await publish(id).expect(200);
    return id;
  };
  const todayTip = async (language?: string) =>
    (
      await t
        .http()
        .get('/v1/daily-tips/today')
        .query(language ? { language } : {})
        .expect(200)
    ).body.tip;

  it('has no tip for today to begin with, and says so without an error', async () => {
    const res = await t.http().get('/v1/daily-tips/today').expect(200);
    expect(res.body).toEqual({ tip: null });
  });

  it('goes from draft to the app only after review and publishing', async () => {
    const draft = await as(editor.token)
      .post('/v1/editor/daily-tips', {
        category: 'general',
        title: 'Draft only',
      })
      .expect(201);
    expect(draft.body.status).toBe('draft');
    expect(draft.body.created_by).toBe(editor.id);
    const id = draft.body.id;

    // Incomplete: refused, field by field.
    const refused = await submit(id).expect(422);
    expect(refused.body.code).toBe('content_incomplete');
    expect(refused.body.details.map((d: { field: string }) => d.field)).toEqual(
      expect.arrayContaining([
        'summary',
        'explanation',
        'legal_reference',
        'source_url',
        'publish_date',
      ]),
    );

    await as(editor.token)
      .patch(`/v1/editor/daily-tips/${id}`, {
        ...complete(),
        title: 'Ask for a bill',
      })
      .expect(200);
    await submit(id).expect(200);
    // Under review: not in the app, not by id either.
    expect(await todayTip()).toBeNull();
    await t.http().get(`/v1/daily-tips/${id}`).expect(404);

    // Not publishable before approval.
    await publish(id).expect(409);
    await approve(id).expect(200);
    await t.http().get(`/v1/daily-tips/${id}`).expect(404);

    const live = await publish(id).expect(200);
    expect(live.body).toMatchObject({
      status: 'published',
      reviewer_id: reviewer.id,
    });

    // No sign-in needed to read it.
    const tip = await todayTip();
    expect(tip).toEqual({
      id,
      category: 'consumer_rights',
      language: 'en',
      title: 'Ask for a bill',
      summary: complete().summary,
      explanation: complete().explanation,
      legal_reference: complete().legal_reference,
      source_url: complete().source_url,
      publish_date: today(),
      last_verified_on: today(),
    });
    const byId = await t.http().get(`/v1/daily-tips/${id}`).expect(200);
    expect(byId.body).toEqual(tip);
  });

  it('shows a tip only on its day', async () => {
    const tomorrow = await publishTip({
      title: 'Scheduled for tomorrow',
      publish_date: dayFrom(1),
      language: 'hi',
    });
    // Published but not due: not today's tip, and not readable by id yet.
    expect(await todayTip('hi')).toBeNull();
    await t.http().get(`/v1/daily-tips/${tomorrow}`).expect(404);
  });

  it('keeps one live tip per day and language', async () => {
    const other = await create({ title: 'A second tip for today' });
    await submit(other).expect(200);
    await approve(other).expect(200);
    const clash = await publish(other).expect(409);
    expect(clash.body.code).toBe('day_taken');
    // Another language is a different slot.
    const ta = await publishTip({ language: 'ta', title: 'Tamil tip' });
    expect((await todayTip('ta')).id).toBe(ta);
  });

  it('refuses to publish for a day that has passed', async () => {
    const id = await create({ publish_date: dayFrom(-2), language: 'te' });
    await submit(id).expect(200);
    await approve(id).expect(200);
    const res = await publish(id).expect(422);
    expect(res.body.details[0].field).toBe('publish_date');
  });

  it('requires an https official source and valid dates', async () => {
    const id = await create();
    await as(editor.token)
      .patch(`/v1/editor/daily-tips/${id}`, {
        source_url: 'http://example.com',
      })
      .expect(200);
    const res = await submit(id).expect(422);
    expect(res.body.details).toEqual([
      { field: 'source_url', reason: 'The source link must use https' },
    ]);
    await as(editor.token)
      .patch(`/v1/editor/daily-tips/${id}`, { publish_date: 'not-a-date' })
      .expect(400);
    await as(editor.token)
      .post('/v1/editor/daily-tips', { category: 'nonsense' })
      .expect(400);
    await as(editor.token)
      .post('/v1/editor/daily-tips', { category: 'general', language: 'xx' })
      .expect(400);
    await t.http().get('/v1/daily-tips/today?language=xx').expect(400);
  });

  it("sends it back with the reviewer's reason, and the editor can then resubmit", async () => {
    const id = await create({ language: 'kn' });
    await submit(id).expect(200);
    await as(reviewer.token)
      .post(`/v1/editor/daily-tips/${id}/request-changes`, {
        reason: 'Cite the section',
      })
      .expect(200);
    const back = await as(editor.token)
      .get(`/v1/editor/daily-tips/${id}`)
      .expect(200);
    expect(back.body).toMatchObject({
      status: 'changes_requested',
      changes_reason: 'Cite the section',
    });
    await as(editor.token)
      .patch(`/v1/editor/daily-tips/${id}`, {
        legal_reference: 'Section 2(9) of the 2019 Act',
      })
      .expect(200);
    await submit(id).expect(200);
  });

  it('keeps each step to its own role', async () => {
    const id = await create({ language: 'ml' });
    // Learners and reviewers cannot write; editors cannot approve or publish.
    await as(learner.token)
      .post('/v1/editor/daily-tips', complete())
      .expect(403);
    await as(reviewer.token)
      .post('/v1/editor/daily-tips', complete())
      .expect(403);
    await as(learner.token).get('/v1/editor/daily-tips').expect(403);
    await t.http().get('/v1/editor/daily-tips').expect(401);
    await submit(id).expect(200);
    await as(editor.token)
      .post(`/v1/editor/daily-tips/${id}/approve`)
      .expect(403);
    await approve(id).expect(200);
    await as(editor.token)
      .post(`/v1/editor/daily-tips/${id}/publish`)
      .expect(403);
    await as(reviewer.token)
      .post(`/v1/editor/daily-tips/${id}/publish`)
      .expect(403);
  });

  it('does not let a reviewer approve a tip they wrote, except an admin', async () => {
    const both = await t.signInAs('content_editor', 'legal_reviewer');
    const own = (
      await as(both.token).post('/v1/editor/daily-tips', complete()).expect(201)
    ).body.id;
    await as(both.token)
      .post(`/v1/editor/daily-tips/${own}/submit`)
      .expect(200);
    await as(both.token)
      .post(`/v1/editor/daily-tips/${own}/approve`)
      .expect(403);

    const admin = await t.signInAs('admin');
    const id = (
      await as(admin.token)
        .post('/v1/editor/daily-tips', complete())
        .expect(201)
    ).body.id;
    // An admin may do every step, including approving their own tip.
    await as(admin.token)
      .post(`/v1/editor/daily-tips/${id}/submit`)
      .expect(200);
    await as(admin.token)
      .post(`/v1/editor/daily-tips/${id}/approve`)
      .expect(200);
  });

  it('retires a published tip, and revising takes it back to draft', async () => {
    const id = await publishTip({ language: 'hi', title: 'Retire me' });
    expect((await todayTip('hi')).id).toBe(id);
    await as(publisher.token)
      .post(`/v1/editor/daily-tips/${id}/retire`, { reason: 'Law amended' })
      .expect(200);
    expect(await todayTip('hi')).toBeNull();
    await t.http().get(`/v1/daily-tips/${id}`).expect(404);

    const revised = await as(editor.token)
      .post(`/v1/editor/daily-tips/${id}/revise`, {
        reason: 'Update for the amendment',
      })
      .expect(200);
    expect(revised.body).toMatchObject({
      status: 'draft',
      reviewer_id: null,
      approved_at: null,
    });
  });

  it('lists and filters tips for staff', async () => {
    const all = await as(editor.token).get('/v1/editor/daily-tips').expect(200);
    expect(all.body.items.length).toBeGreaterThan(3);
    const onlyDrafts = await as(editor.token)
      .get('/v1/editor/daily-tips?status=draft')
      .expect(200);
    expect(
      onlyDrafts.body.items.every(
        (i: { status: string }) => i.status === 'draft',
      ),
    ).toBe(true);
    const found = await as(editor.token)
      .get('/v1/editor/daily-tips?q=retire&category=consumer_rights')
      .expect(200);
    expect(found.body.items.map((i: { title: string }) => i.title)).toContain(
      'Retire me',
    );
    const none = await as(editor.token)
      .get('/v1/editor/daily-tips?category=workplace')
      .expect(200);
    expect(none.body.items).toEqual([]);
  });

  describe('recording a source check', () => {
    const verify = (
      token: string,
      id: string,
      body: object = { confirmed_against_source: true },
    ) => as(token).post(`/v1/editor/daily-tips/${id}/verify`, body);

    it('sets only the verification date, names who checked, and keeps the tip in draft', async () => {
      const id = await create({ last_verified_on: null });
      const res = await verify(editor.token, id).expect(200);
      expect(res.body.status).toBe('draft');
      expect(res.body.last_verified_on).toBe(today());
      expect(res.body.updated_by).toBe(editor.id);
      const log = await as(editor.token)
        .get(`/v1/editor/daily-tips/${id}`)
        .expect(200);
      expect(log.body.last_verified_on).toBe(today());
    });

    it('needs the editor to confirm, and the exact source link, not a site home page', async () => {
      const id = await create({
        last_verified_on: null,
        source_url: 'https://www.indiacode.nic.in/',
      });
      await verify(editor.token, id, {}).expect(400);
      await verify(editor.token, id, {
        confirmed_against_source: false,
      }).expect(400);
      const res = await verify(editor.token, id).expect(422);
      expect(JSON.stringify(res.body)).toContain('source_url');
      const after = await as(editor.token)
        .get(`/v1/editor/daily-tips/${id}`)
        .expect(200);
      expect(after.body.last_verified_on).toBeNull();
    });

    it('is for editors on drafts only, and the checker cannot approve it afterwards', async () => {
      const id = await create({ last_verified_on: null });
      await verify(reviewer.token, id).expect(403);
      await verify(learner.token, id).expect(403);
      await verify(editor.token, id).expect(200);
      await submit(id).expect(200);
      // Under review the date can no longer be changed this way.
      await verify(editor.token, id).expect(409);
      // A tip still cannot be published without the review.
      await publish(id).expect(409);
    });

    it('is optional: an unverified tip can still be submitted for review', async () => {
      const id = await create({ last_verified_on: null });
      await submit(id).expect(200);
    });
  });

  it('writes the steps to the audit log', async () => {
    const id = await publishTip({ language: 'te', title: 'Audited' });
    const { auditLog } = await import('../src/db/schema.js');
    const { eq } = await import('drizzle-orm');
    const rows = await t.db
      .select()
      .from(auditLog)
      .where(eq(auditLog.entityId, id));
    expect(rows.map((r) => r.action).sort()).toEqual(
      [
        'daily_tip.approved',
        'daily_tip.created',
        'daily_tip.published',
        'daily_tip.submitted',
      ].sort(),
    );
  });
  describe('the daily change at 00:00 India time', () => {
    const SERVER_ZONES = [
      'UTC',
      'America/Los_Angeles',
      'Pacific/Auckland',
      'Asia/Kolkata',
    ];
    const midnightIst = (day: string) => Date.parse(`${day}T00:00:00+05:30`);

    it('hands over to the next tip at 00:00 IST, whatever the server clock zone is', async () => {
      const day = dayFrom(1);
      const id = await publishTip({
        language: 'kn',
        title: 'Tomorrow',
        publish_date: day,
      });
      const next = await publishTip({
        language: 'kn',
        title: 'Day after',
        publish_date: dayFrom(2),
      });
      const service = t.app.get(DailyTipsService);
      const at = (ms: number) => service.today('kn', new Date(ms));
      const zone = process.env.TZ;
      try {
        for (const tz of SERVER_ZONES) {
          process.env.TZ = tz;
          const m = midnightIst(day);
          // One millisecond before midnight IST it is still the day before: nothing for 'kn'.
          expect((await at(m - 1)).tip).toBeNull();
          // At midnight IST (18:30 UTC the evening before) the tip appears by itself.
          expect((await at(m)).tip?.id).toBe(id);
          expect((await at(m + 86_400_000 - 1)).tip?.id).toBe(id);
          // And one day later the next one takes over.
          expect((await at(m + 86_400_000)).tip?.id).toBe(next);
        }
      } finally {
        if (zone === undefined) delete process.env.TZ;
        else process.env.TZ = zone;
      }
    });

    it('never gives a future-dated tip early, by date or by id', async () => {
      const day = dayFrom(3);
      const id = await publishTip({
        language: 'ml',
        title: 'Not yet',
        publish_date: day,
      });
      const service = t.app.get(DailyTipsService);
      const m = midnightIst(day);
      // The whole of the days before: no tip today, and not readable by id either.
      for (const ms of [Date.now(), m - 86_400_000, m - 1]) {
        expect((await service.today('ml', new Date(ms))).tip).toBeNull();
        await expect(service.published(id, new Date(ms))).rejects.toMatchObject(
          { status: 404 },
        );
      }
      expect((await service.published(id, new Date(m))).title).toBe('Not yet');
      // Over HTTP too: still not today's tip.
      expect(await todayTip('ml')).toBeNull();
    });

    it('can be published ahead for tomorrow without any further step', async () => {
      // Written, reviewed and published today, with tomorrow's date: accepted.
      const id = await create({
        language: 'ta',
        title: 'Prepared ahead',
        publish_date: dayFrom(1),
      });
      await submit(id).expect(200);
      await approve(id).expect(200);
      const live = await publish(id).expect(200);
      expect(live.body).toMatchObject({
        status: 'published',
        publish_date: dayFrom(1),
      });
    });

    it('is not cacheable, so yesterday is never served after midnight', async () => {
      const res = await t.http().get('/v1/daily-tips/today').expect(200);
      expect(res.headers['cache-control']).toBe('no-cache');
    });
  });
});
