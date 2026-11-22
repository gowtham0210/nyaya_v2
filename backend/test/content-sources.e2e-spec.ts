import { and, eq } from 'drizzle-orm';
import { newId } from '../src/core/ids.js';
import {
  auditLog,
  contentSources,
  examQuestionTags,
  exams,
  questions,
  questionVersions,
} from '../src/db/schema.js';
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

const SHA = 'ab'.repeat(32);

describe('content sources (attribution only) and publishing', () => {
  let t: TestApp;
  let admin: Session,
    editor: Session,
    reviewer: Session,
    publisher: Session,
    analyst: Session,
    learner: Session;

  const as = (s: Session) => ({
    get: (url: string) => t.http().get(url).auth(s.token, { type: 'bearer' }),
    post: (url: string, body: object = {}) =>
      t.http().post(url).auth(s.token, { type: 'bearer' }).send(body),
    patch: (url: string, body: object) =>
      t.http().patch(url).auth(s.token, { type: 'bearer' }).send(body),
  });

  const createSource = async (body: object = {}) =>
    (
      await as(admin)
        .post('/v1/admin/content-sources', {
          kind: 'third_party',
          title: 'A paper compilation',
          publisher: 'A publisher',
          url: 'https://example.com/paper.pdf',
          retrieved_on: '2026-11-18',
          sha256: SHA,
          ...body,
        })
        .expect(201)
    ).body;

  /** Sets the historical licence column directly: the app never reads or writes it. */
  const setHistoricalLicense = (
    id: string,
    status: 'pending' | 'blocked' | 'permission_granted',
  ) =>
    t.db
      .update(contentSources)
      .set({ licenseStatus: status })
      .where(eq(contentSources.id, id));

  beforeAll(async () => {
    t = await startApp();
    [admin, editor, reviewer, publisher, analyst, learner] = await Promise.all([
      t.signInAs('admin'),
      t.signInAs('content_editor'),
      t.signInAs('legal_reviewer'),
      t.signInAs('publisher'),
      t.signInAs('analyst'),
      t.signInAs('learner'),
    ]);
  });
  afterAll(() => t.close());

  describe('the source record', () => {
    it('is written by admins only, and read by staff', async () => {
      const body = { kind: 'official_bci', title: 'BCI key' };
      await t.http().post('/v1/admin/content-sources').send(body).expect(401);
      await as(editor).post('/v1/admin/content-sources', body).expect(403);
      await as(learner).post('/v1/admin/content-sources', body).expect(403);
      const source = await createSource();
      await as(analyst)
        .get(`/v1/admin/content-sources/${source.id}`)
        .expect(200);
      await as(learner)
        .get(`/v1/admin/content-sources/${source.id}`)
        .expect(403);
      await as(editor)
        .patch(`/v1/admin/content-sources/${source.id}`, { title: 'x' })
        .expect(403);
    });

    it('records the type, publisher, address, date and hash, and shows no licence information', async () => {
      const source = await createSource();
      expect(source).toMatchObject({
        kind: 'third_party',
        title: 'A paper compilation',
        publisher: 'A publisher',
        url: 'https://example.com/paper.pdf',
        retrieved_on: '2026-11-18',
        sha256: SHA,
        allowed_uses: [],
        created_by: admin.id,
      });
      for (const key of ['license_status', 'license_note', 'cleared'])
        expect(source).not.toHaveProperty(key);
    });

    it('has no licence action, and refuses licence fields', async () => {
      const source = await createSource();
      await as(admin)
        .post(`/v1/admin/content-sources/${source.id}/license`, {
          status: 'permission_granted',
          note: 'I would like it to be cleared',
        })
        .expect(404);
      await as(admin)
        .post('/v1/admin/content-sources', {
          kind: 'third_party',
          title: 'x',
          license_status: 'permission_granted',
        })
        .expect(400);
      await as(admin)
        .patch(`/v1/admin/content-sources/${source.id}`, {
          license_status: 'permission_granted',
        })
        .expect(400);
      await as(analyst)
        .get('/v1/admin/content-sources?license_status=pending')
        .expect(400);
    });

    it('checks the address, hash, kind and title', async () => {
      const bad = (body: object) =>
        as(admin)
          .post('/v1/admin/content-sources', {
            kind: 'third_party',
            title: 'x',
            ...body,
          })
          .expect(400);
      await bad({ url: 'http://example.com' });
      await bad({ sha256: 'NOT-A-HASH' });
      await bad({ retrieved_on: '18/11/2026' });
      await bad({ kind: 'mine' });
      await bad({ title: '' });
    });

    it('changes its details, is audited, and lists with a kind filter', async () => {
      const source = await createSource({ title: 'Listed one' });
      const updated = await as(admin)
        .patch(`/v1/admin/content-sources/${source.id}`, {
          title: 'Renamed',
          allowed_uses: ['practice questions'],
        })
        .expect(200);
      expect(updated.body).toMatchObject({
        title: 'Renamed',
        allowed_uses: ['practice questions'],
      });
      const entries = await t.db
        .select()
        .from(auditLog)
        .where(
          and(
            eq(auditLog.entityType, 'content_source'),
            eq(auditLog.entityId, source.id),
          ),
        );
      expect(entries.map((e) => e.action).sort()).toEqual([
        'content_source.created',
        'content_source.updated',
      ]);
      const third = await as(analyst)
        .get('/v1/admin/content-sources?kind=third_party')
        .expect(200);
      expect(third.body.items.map((s: { id: string }) => s.id)).toContain(
        source.id,
      );
      const official = await as(analyst)
        .get('/v1/admin/content-sources?kind=official_bci')
        .expect(200);
      expect(
        official.body.items.map((s: { id: string }) => s.id),
      ).not.toContain(source.id);
      await as(analyst).get('/v1/admin/content-sources/not-a-uuid').expect(400);
      await as(analyst).get(`/v1/admin/content-sources/${newId()}`).expect(404);
    });
  });

  /** Takes a question through the editorial steps up to approved, with a source set. */
  const approvedQuestion = async (
    sourceId: string | null,
    extra: object = {},
  ) => {
    const draft = (
      await as(editor)
        .post('/v1/editor/questions', {
          topic_id: t.topicId,
          ...completeContent,
          ...extra,
        })
        .expect(201)
    ).body;
    if (sourceId)
      await t.db
        .update(questionVersions)
        .set({ contentSourceId: sourceId })
        .where(eq(questionVersions.questionId, draft.id));
    await as(editor)
      .post(`/v1/editor/questions/${draft.id}/submit`)
      .expect(200);
    await as(reviewer)
      .post(`/v1/editor/questions/${draft.id}/approve`, { note: 'Checked' })
      .expect(200);
    return draft.id as string;
  };
  const publish = (id: string) =>
    as(publisher).post(`/v1/editor/questions/${id}/publish`);

  describe('publishing', () => {
    it('is unchanged for an ordinary question with no source', async () => {
      const id = await approvedQuestion(null);
      const res = await publish(id).expect(200);
      expect(res.body.latest.status).toBe('published');
    });

    it('needs no explanation: a question without one is reviewed and published', async () => {
      for (const explanation of ['', '   ']) {
        const id = await approvedQuestion(null, { explanation });
        const res = await publish(id).expect(200);
        expect(res.body.latest.status).toBe('published');
      }
    });

    it('is never held up by the source, whatever a historical licence record says', async () => {
      for (const status of ['pending', 'blocked'] as const) {
        const source = await createSource();
        await setHistoricalLicense(source.id, status);
        const id = await approvedQuestion(source.id);
        const res = await publish(id).expect(200);
        expect(res.body.latest.status).toBe('published');
      }
    });

    it('also holds for bulk publishing', async () => {
      const source = await createSource();
      await setHistoricalLicense(source.id, 'blocked');
      const withSource = await approvedQuestion(source.id);
      const plain = await approvedQuestion(null);
      const res = await as(publisher)
        .post('/v1/editor/questions/bulk', {
          action: 'publish',
          question_ids: [withSource, plain],
        })
        .expect(200);
      expect(res.body.results.map((r: { ok: boolean }) => r.ok)).toEqual([
        true,
        true,
      ]);
    });

    it('still needs an exam tag for an exam-only question', async () => {
      const id = await approvedQuestion(null);
      await t.db
        .update(questions)
        .set({ examOnly: true })
        .where(eq(questions.id, id));
      const res = await publish(id).expect(422);
      expect(res.body.code).toBe('exam_tag_required');

      const examId = newId();
      await t.db
        .insert(exams)
        .values({ id: examId, slug: 'aibe', name: 'AIBE', shortName: 'AIBE' });
      await t.db.insert(examQuestionTags).values({ questionId: id, examId });
      const ok = await publish(id).expect(200);
      expect(ok.body.latest.status).toBe('published');
    });
  });

  it('leaves a historical licence record exactly as it was, even after publishing', async () => {
    const source = await createSource();
    await setHistoricalLicense(source.id, 'permission_granted');
    const id = await approvedQuestion(source.id);
    await publish(id).expect(200);
    const [row] = await t.db
      .select()
      .from(contentSources)
      .where(eq(contentSources.id, source.id));
    expect(row.licenseStatus).toBe('permission_granted');
  });
});
