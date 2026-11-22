import { eq } from 'drizzle-orm';
import { newId } from '../src/core/ids.js';
import {
  auditLog,
  contentSources,
  examQuestionTags,
  exams,
  questions,
  questionVersions,
  type LicenseStatus,
} from '../src/db/schema.js';
import { startApp, type TestApp } from './helpers.js';

type Session = Awaited<ReturnType<TestApp['signInAs']>>;

const completeContent = {
  stem: 'Which Article of the Constitution guarantees equality before the law?',
  options: [
    { id: 'a', text: 'Article 14' },
    { id: 'b', text: 'Article 19' },
    { id: 'c', text: 'Article 21' },
  ],
  correct_option_ids: ['a'],
  explanation: 'Article 14 guarantees equality before the law.',
  source_title: 'Constitution of India',
  source_url: 'https://legislative.gov.in/constitution-of-india/',
  valid_from: '1950-01-26',
};

describe('question API: exam metadata', () => {
  let t: TestApp;
  let admin: Session,
    editor: Session,
    reviewer: Session,
    publisher: Session,
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

  const create = async (body: object = {}, status = 201) =>
    as(editor)
      .post('/v1/editor/questions', { topic_id: t.topicId, ...body })
      .expect(status);

  const source = async (licenseStatus: LicenseStatus) => {
    const id = newId();
    await t.db
      .insert(contentSources)
      .values({
        id,
        kind: 'third_party',
        title: `S ${licenseStatus}`,
        licenseStatus,
      });
    return id;
  };

  const toPublished = async (id: string) => {
    await as(editor).post(q(id, 'submit')).expect(200);
    await as(reviewer).post(q(id, 'approve'), {}).expect(200);
    return as(publisher).post(q(id, 'publish'));
  };

  beforeAll(async () => {
    t = await startApp();
    [admin, editor, reviewer, publisher, learner] = await Promise.all([
      t.signInAs('admin'),
      t.signInAs('content_editor'),
      t.signInAs('legal_reviewer'),
      t.signInAs('publisher'),
      t.signInAs('learner'),
    ]);
    examId = newId();
    await t.db
      .insert(exams)
      .values({ id: examId, slug: 'aibe', name: 'AIBE', shortName: 'AIBE' });
  });
  afterAll(() => t.close());

  it('keeps an ordinary question exactly as before: not exam-only, neutral, no source or tags', async () => {
    const res = (await create(completeContent)).body;
    expect(res).toMatchObject({ exam_only: false, exam_ids: [] });
    expect(res.latest).toMatchObject({
      content_source_id: null,
      law_regime: 'neutral',
      concept_key: null,
      alternate_correct_option_ids: [],
      lock_option_order: false,
    });
    expect((await toPublished(res.id)).status).toBe(200);
  });

  it('stores the exam metadata on create and returns it', async () => {
    const src = await source('permission_granted');
    const res = (
      await create({
        ...completeContent,
        content_source_id: src,
        law_regime: 'new_codes',
        concept_key: 'article-14.equality',
        alternate_correct_option_ids: ['b'],
        lock_option_order: true,
        exam_only: true,
        exam_ids: [examId],
      })
    ).body;
    expect(res).toMatchObject({ exam_only: true, exam_ids: [examId] });
    expect(res.latest).toMatchObject({
      content_source_id: src,
      law_regime: 'new_codes',
      concept_key: 'article-14.equality',
      alternate_correct_option_ids: ['b'],
      lock_option_order: true,
    });
    const [row] = await t.db
      .select()
      .from(questions)
      .where(eq(questions.id, res.id));
    expect(row.examOnly).toBe(true);
  });

  it('updates the metadata on a draft, and can clear the source and concept', async () => {
    const src = await source('permission_granted');
    const draft = (await create(completeContent)).body;
    const res = await as(editor)
      .patch(q(draft.id), {
        content_source_id: src,
        concept_key: 'concept.one',
        law_regime: 'old_codes',
        lock_option_order: true,
      })
      .expect(200);
    expect(res.body.latest).toMatchObject({
      content_source_id: src,
      concept_key: 'concept.one',
      law_regime: 'old_codes',
      lock_option_order: true,
    });
    const cleared = await as(editor)
      .patch(q(draft.id), { content_source_id: null, concept_key: null })
      .expect(200);
    expect(cleared.body.latest).toMatchObject({
      content_source_id: null,
      concept_key: null,
    });
    await as(editor).patch(q(draft.id), { law_regime: null }).expect(400);
  });

  it('refuses an unknown source, an unknown exam, a bad concept key and a bad law regime', async () => {
    await as(editor)
      .post('/v1/editor/questions', {
        topic_id: t.topicId,
        content_source_id: newId(),
      })
      .expect(422);
    await as(editor)
      .post('/v1/editor/questions', {
        topic_id: t.topicId,
        exam_ids: [newId()],
      })
      .expect(422);
    await as(editor)
      .post('/v1/editor/questions', {
        topic_id: t.topicId,
        concept_key: 'Bad Key!',
      })
      .expect(400);
    await as(editor)
      .post('/v1/editor/questions', {
        topic_id: t.topicId,
        law_regime: 'whatever',
      })
      .expect(400);
    await as(editor)
      .post('/v1/editor/questions', { topic_id: t.topicId, exam_only: 'yes' })
      .expect(400);
  });

  describe('alternate answers', () => {
    it('must be listed options that are not also correct, checked before review', async () => {
      const draft = (
        await create({
          ...completeContent,
          alternate_correct_option_ids: ['z'],
        })
      ).body;
      const res = await as(editor).post(q(draft.id, 'submit')).expect(422);
      expect(JSON.stringify(res.body.details)).toMatch(
        /alternate_correct_option_ids/,
      );
      // An alternate that is also correct is refused when it is written.
      const overlap = await as(editor)
        .patch(q(draft.id), { alternate_correct_option_ids: ['a'] })
        .expect(422);
      expect(overlap.body.details[0].field).toBe(
        'alternate_correct_option_ids',
      );
      await as(editor)
        .post('/v1/editor/questions', {
          topic_id: t.topicId,
          correct_option_ids: ['a'],
          alternate_correct_option_ids: ['a'],
        })
        .expect(422);
      await as(editor)
        .patch(q(draft.id), { alternate_correct_option_ids: ['b', 'b'] })
        .expect(200);
      await as(editor).post(q(draft.id, 'submit')).expect(422);
      await as(editor)
        .patch(q(draft.id), { alternate_correct_option_ids: ['b'] })
        .expect(200);
      await as(editor).post(q(draft.id, 'submit')).expect(200);
    });
  });

  describe('exam-only and exam tags', () => {
    it('lets exam_only change only before the first publish', async () => {
      const draft = (await create(completeContent)).body;
      await as(editor).patch(q(draft.id), { exam_only: true }).expect(200);
      const detail = (await as(editor).get(q(draft.id)).expect(200)).body;
      expect(detail.exam_only).toBe(true);
      await as(editor)
        .patch(q(draft.id), { exam_only: false, exam_ids: [examId] })
        .expect(200);

      const live = (await create({ ...completeContent, exam_ids: [examId] }))
        .body;
      expect((await toPublished(live.id)).status).toBe(200);
      const res = await as(editor)
        .post(q(live.id, 'revise'), { change_note: 'Fix wording' })
        .expect(200);
      expect(res.body.latest.version_no).toBe(2);
      const locked = await as(editor)
        .patch(q(live.id), { exam_only: true })
        .expect(409);
      expect(locked.body.code).toBe('exam_only_locked');
    });

    it('sets the exam tags, audits changes, and keeps one tag on a published exam-only question', async () => {
      const draft = (await create({ ...completeContent, exam_only: true }))
        .body;
      const withTag = await as(editor)
        .patch(q(draft.id), { exam_ids: [examId] })
        .expect(200);
      expect(withTag.body.exam_ids).toEqual([examId]);
      const cleared = await as(editor)
        .patch(q(draft.id), { exam_ids: [] })
        .expect(200);
      expect(cleared.body.exam_ids).toEqual([]);
      expect(
        await t.db
          .select()
          .from(examQuestionTags)
          .where(eq(examQuestionTags.questionId, draft.id)),
      ).toHaveLength(0);
      const log = await t.db
        .select()
        .from(auditLog)
        .where(eq(auditLog.entityId, draft.id));
      expect(
        log.filter((l) => l.action === 'question.exam_tags_changed'),
      ).toHaveLength(2);
    });
  });

  describe('publishing rules', () => {
    it('publishes content whatever its source historical licence record says', async () => {
      for (const status of ['pending', 'blocked', 'permitted_by_terms'] as const) {
        const q1 = (
          await create({
            ...completeContent,
            content_source_id: await source(status),
          })
        ).body;
        expect((await toPublished(q1.id)).status).toBe(200);
      }
    });

    it('refuses to publish an exam-only question that has no exam tag', async () => {
      const untagged = (await create({ ...completeContent, exam_only: true }))
        .body;
      const res = await toPublished(untagged.id);
      expect(res.status).toBe(422);
      expect(res.body.code).toBe('exam_tag_required');
      // Tags are not versioned and skip review, so once the version is in
      // review or approved only an admin may set them (an editor would have
      // to ask for changes first).
      await as(editor)
        .put(q(untagged.id, 'exam-tags'), { exam_ids: [examId] })
        .expect(403);
      await as(admin)
        .put(q(untagged.id, 'exam-tags'), { exam_ids: [examId] })
        .expect(200);
      await as(learner)
        .put(q(untagged.id, 'exam-tags'), { exam_ids: [] })
        .expect(403);
      expect(
        (await as(publisher).post(q(untagged.id, 'publish')).expect(200)).body
          .latest.status,
      ).toBe('published');
      // Once published, the last tag cannot be removed (even by an admin).
      const stripped = await as(admin)
        .put(q(untagged.id, 'exam-tags'), { exam_ids: [] })
        .expect(422);
      expect(stripped.body.code).toBe('exam_tag_required');
    });

    it('carries the metadata into a new version when a question is revised', async () => {
      const src = await source('permission_granted');
      const created = (
        await create({
          ...completeContent,
          content_source_id: src,
          law_regime: 'both',
          concept_key: 'carry.over',
          alternate_correct_option_ids: ['b'],
          lock_option_order: true,
          exam_ids: [examId],
        })
      ).body;
      expect((await toPublished(created.id)).status).toBe(200);
      const revised = await as(editor)
        .post(q(created.id, 'revise'), { change_note: 'Reword' })
        .expect(200);
      expect(revised.body.latest).toMatchObject({
        version_no: 2,
        content_source_id: src,
        law_regime: 'both',
        concept_key: 'carry.over',
        alternate_correct_option_ids: ['b'],
        lock_option_order: true,
      });
      const versions = await t.db
        .select()
        .from(questionVersions)
        .where(eq(questionVersions.questionId, created.id));
      expect(versions).toHaveLength(2);
    });
  });
});
