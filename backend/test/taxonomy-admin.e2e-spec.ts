import { eq } from 'drizzle-orm';
import { newId } from '../src/core/ids.js';
import { auditLog, questions, questionVersions } from '../src/db/schema.js';
import { startApp, type TestApp } from './helpers.js';

type Session = Awaited<ReturnType<TestApp['signInAs']>>;
interface Topic {
  id: string;
  slug: string;
  name: string;
  is_active: boolean;
  question_count: number;
  live_count: number;
  act_id: string | null;
}
interface Subject {
  id: string;
  slug: string;
  is_active: boolean;
  topics: Topic[];
}

describe('taxonomy administration', () => {
  let t: TestApp;
  let admin: Session, editor: Session, reviewer: Session;

  const as = (s: Session) => ({
    get: (url: string) => t.http().get(url).auth(s.token, { type: 'bearer' }),
    post: (url: string, body: object) =>
      t.http().post(url).auth(s.token, { type: 'bearer' }).send(body),
    patch: (url: string, body: object) =>
      t.http().patch(url).auth(s.token, { type: 'bearer' }).send(body),
  });
  const subjectBy = (body: { subjects: Subject[] }, slug: string) =>
    body.subjects.find((s) => s.slug === slug)!;
  const topicIn = (body: { subjects: Subject[] }, slug: string) =>
    body.subjects.flatMap((s) => s.topics).find((x) => x.slug === slug)!;

  beforeAll(async () => {
    t = await startApp();
    [admin, editor, reviewer] = await Promise.all([
      t.signInAs('admin'),
      t.signInAs('content_editor'),
      t.signInAs('legal_reviewer'),
    ]);
    // One live question and one draft in the helper's topic.
    for (const status of ['published', 'draft'] as const) {
      const questionId = newId();
      const versionId = newId();
      await t.db.insert(questions).values({ id: questionId });
      await t.db.insert(questionVersions).values({
        id: versionId,
        questionId,
        versionNo: 1,
        status,
        topicId: t.topicId,
        stem: `A ${status} question`,
        validFrom: '2000-01-01',
      });
      if (status === 'published')
        await t.db
          .update(questions)
          .set({ liveVersionId: versionId })
          .where(eq(questions.id, questionId));
    }
  });
  afterAll(() => t.close());

  it('lists everything with question counts', async () => {
    const res = await as(reviewer).get('/v1/admin/taxonomy').expect(200);
    expect(topicIn(res.body, 'constitution-basics')).toMatchObject({
      id: t.topicId,
      is_active: true,
      question_count: 2,
      live_count: 1,
    });
  });

  it('adds subjects hidden; only admins change subjects', async () => {
    await as(editor)
      .post('/v1/admin/subjects', { slug: 'family-law', name: 'Family Law' })
      .expect(403);
    const res = await as(admin)
      .post('/v1/admin/subjects', {
        slug: 'family-law',
        name: 'Family Law',
        sort_order: 7,
      })
      .expect(201);
    const family = subjectBy(res.body, 'family-law');
    expect(family).toMatchObject({ is_active: false, topics: [] });

    // Hidden subjects stay out of the public taxonomy until shown.
    const isPublic = async () =>
      (await t.http().get('/v1/taxonomy').expect(200)).body.subjects.some(
        (s: Subject) => s.slug === 'family-law',
      );
    expect(await isPublic()).toBe(false);
    await as(editor)
      .patch(`/v1/admin/subjects/${family.id}`, { is_active: true })
      .expect(403);
    await as(admin)
      .patch(`/v1/admin/subjects/${family.id}`, {
        is_active: true,
        name: 'Family and Personal Law',
        description: null,
      })
      .expect(200);
    expect(await isPublic()).toBe(true);

    const dup = await as(admin)
      .post('/v1/admin/subjects', { slug: 'family-law', name: 'Again' })
      .expect(409);
    expect(dup.body.code).toBe('slug_taken');

    const audit = await t.db
      .select()
      .from(auditLog)
      .where(eq(auditLog.entityId, family.id));
    expect(audit.map((a) => a.action)).toEqual([
      'taxonomy.subject_created',
      'taxonomy.subject_updated',
    ]);
  });

  it('lets editors add and edit topics and acts, never their slugs', async () => {
    const act = (
      await as(editor)
        .post('/v1/admin/acts', {
          slug: 'hindu-marriage-act-1955',
          name: 'Hindu Marriage Act, 1955',
          short_name: 'HMA',
          year: 1955,
        })
        .expect(201)
    ).body.acts.find(
      (a: { slug: string }) => a.slug === 'hindu-marriage-act-1955',
    );
    expect(act).toMatchObject({
      is_active: true,
      jurisdiction: 'IN',
      topic_count: 0,
    });

    const family = subjectBy(
      (await as(editor).get('/v1/admin/taxonomy').expect(200)).body,
      'family-law',
    );
    const res = await as(editor)
      .post('/v1/admin/topics', {
        subject_id: family.id,
        slug: 'marriage',
        name: 'Marriage and divorce',
        act_id: act.id,
      })
      .expect(201);
    const topic = topicIn(res.body, 'marriage');
    expect(topic).toMatchObject({ is_active: true, act_id: act.id });

    const renamed = await as(editor)
      .patch(`/v1/admin/topics/${topic.id}`, {
        name: 'Marriage',
        act_id: null,
        slug: 'changed',
        subject_id: t.topicId,
      })
      .expect(400);
    expect(renamed.body.details.map((d: { field: string }) => d.field)).toEqual(
      expect.arrayContaining(['slug', 'subject_id']),
    );
    const ok = await as(editor)
      .patch(`/v1/admin/topics/${topic.id}`, { name: 'Marriage', act_id: null })
      .expect(200);
    expect(topicIn(ok.body, 'marriage')).toMatchObject({
      name: 'Marriage',
      act_id: null,
    });
  });

  it('hides a topic, which takes its questions out of quizzes', async () => {
    const quizTopics = async () =>
      (await t.http().get('/v1/quizzes').expect(200)).body.topics.map(
        (x: { topic_id: string }) => x.topic_id,
      );
    expect(await quizTopics()).toContain(t.topicId);
    await as(reviewer)
      .patch(`/v1/admin/topics/${t.topicId}`, { is_active: false })
      .expect(403);
    await as(editor)
      .patch(`/v1/admin/topics/${t.topicId}`, { is_active: false })
      .expect(200);
    expect(await quizTopics()).not.toContain(t.topicId);
    await as(editor)
      .patch(`/v1/admin/topics/${t.topicId}`, { is_active: true })
      .expect(200);
    expect(await quizTopics()).toContain(t.topicId);
  });

  it('validates input', async () => {
    for (const body of [
      { slug: 'Bad Slug', name: 'X y' },
      { slug: 'ok-slug', name: 'X' },
      { slug: '-lead', name: 'Fine name' },
    ])
      await as(admin).post('/v1/admin/subjects', body).expect(400);
    await as(editor)
      .post('/v1/admin/topics', {
        subject_id: '00000000-0000-7000-8000-000000000000',
        slug: 'orphan',
        name: 'Orphan topic',
      })
      .expect(422);
    await as(editor)
      .patch('/v1/admin/topics/00000000-0000-7000-8000-000000000000', {
        name: 'Nothing here',
      })
      .expect(404);
    await as(editor)
      .patch(`/v1/admin/topics/${t.topicId}`, { name: null })
      .expect(200);
    const after = topicIn(
      (await as(editor).get('/v1/admin/taxonomy').expect(200)).body,
      'constitution-basics',
    );
    expect(after.name).toBe('Preamble and Parliament');
  });
});
