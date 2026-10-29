import { eq } from 'drizzle-orm';
import { newId } from '../src/core/ids.js';
import {
  premiumMemberships,
  questions,
  questionVersions,
  quizSessions,
  subjects,
  topics,
} from '../src/db/schema.js';
import { startApp, type TestApp } from './helpers.js';

type Session = Awaited<ReturnType<TestApp['signInAs']>>;

interface Fixture {
  stem?: string;
  difficulty?: number;
  status?: 'published' | 'draft';
  validFrom?: string;
  validTo?: string | null;
  language?: string;
  retired?: boolean;
  topicId?: string;
}

const SECRET = 'EXPLANATION-SECRET';

describe('learner quizzes', () => {
  let t: TestApp;
  let learner: Session,
    other: Session,
    editor: Session,
    reviewer: Session,
    publisher: Session;

  /** Inserts a question straight into the bank (the editorial flow is covered elsewhere). */
  const addQuestion = async (f: Fixture = {}) => {
    const questionId = newId();
    const versionId = newId();
    const published = (f.status ?? 'published') === 'published';
    await t.db
      .insert(questions)
      .values({ id: questionId, retiredAt: f.retired ? new Date() : null });
    await t.db.insert(questionVersions).values({
      id: versionId,
      questionId,
      versionNo: 1,
      status: f.retired ? 'retired' : (f.status ?? 'published'),
      topicId: f.topicId ?? t.topicId,
      language: f.language ?? 'en',
      difficulty: f.difficulty ?? 1,
      stem: f.stem ?? `Question ${versionId.slice(-6)}`,
      options: [
        { id: 'a', text: 'Right' },
        { id: 'b', text: 'Wrong 1' },
        { id: 'c', text: 'Wrong 2' },
      ],
      correctOptionIds: ['a'],
      explanation: `${SECRET} for ${versionId}`,
      sourceTitle: 'Constitution of India',
      validFrom: f.validFrom ?? '2000-01-01',
      validTo: f.validTo ?? null,
    });
    if (published && !f.retired) {
      await t.db
        .update(questions)
        .set({ liveVersionId: versionId })
        .where(eq(questions.id, questionId));
    }
    return { questionId, versionId };
  };

  const as = (s: Session) => ({
    get: (url: string) => t.http().get(url).auth(s.token, { type: 'bearer' }),
    post: (url: string, body: object = {}) =>
      t.http().post(url).auth(s.token, { type: 'bearer' }).send(body),
  });

  let liveIds: string[];

  beforeAll(async () => {
    t = await startApp();
    [learner, other, editor, reviewer, publisher] = await Promise.all([
      t.signInAs('learner'),
      t.signInAs('learner'),
      t.signInAs('content_editor'),
      t.signInAs('legal_reviewer'),
      t.signInAs('publisher'),
    ]);
    // These tests start many quizzes; energy is covered in economy.e2e-spec.ts.
    await t.db.insert(premiumMemberships).values(
      [learner, other].map((s) => ({
        userId: s.id,
        source: 'test',
        startedAt: new Date(),
      })),
    );
    liveIds = [];
    for (let i = 0; i < 4; i++)
      liveIds.push(
        (await addQuestion({ difficulty: i < 3 ? 1 : 2 })).versionId,
      );
    // None of these may ever reach a learner.
    await addQuestion({ status: 'draft', stem: 'DRAFT' });
    await addQuestion({ retired: true, stem: 'RETIRED' });
    await addQuestion({ validFrom: '2999-01-01', stem: 'FUTURE' });
    await addQuestion({ validTo: '2001-01-01', stem: 'EXPIRED' });
    await addQuestion({ language: 'hi', stem: 'HINDI' });
  });
  afterAll(() => t.close());

  // Duels are plain practice: answers explained at once, any difficulty.
  const start = (s: Session, body: object = {}) =>
    as(s).post('/v1/quiz-sessions', {
      mode: 'duel',
      topic_id: t.topicId,
      ...body,
    });

  it('lists only published questions that are in force', async () => {
    const res = await t.http().get('/v1/quizzes').expect(200);
    expect(res.body.topics).toEqual([
      expect.objectContaining({
        topic_id: t.topicId,
        available: 4,
        by_difficulty: { '1': 3, '2': 1, '3': 0 },
      }),
    ]);
    const hindi = await t.http().get('/v1/quizzes?language=hi').expect(200);
    expect(hindi.body.topics[0].available).toBe(1);
  });

  it('needs a signed-in user to start', async () => {
    await t
      .http()
      .post('/v1/quiz-sessions')
      .send({ mode: 'duel', topic_id: t.topicId })
      .expect(401);
  });

  it('starts with eligible questions only and never sends the answer key', async () => {
    const res = await start(learner, { question_count: 20 }).expect(201);
    const s = res.body;
    expect(s).toMatchObject({
      status: 'in_progress',
      feedback_mode: 'immediate',
      question_count: 4,
      scoring_version: 'standard-v1',
    });
    expect(
      s.questions
        .map((q: { question_version_id: string }) => q.question_version_id)
        .sort(),
    ).toEqual([...liveIds].sort());
    for (const q of s.questions) {
      expect(q.feedback).toBeNull();
      expect(q.options.map((o: { id: string }) => o.id).sort()).toEqual([
        'a',
        'b',
        'c',
      ]);
    }
    const raw = JSON.stringify(s);
    expect(raw).not.toContain('correct');
    expect(raw).not.toContain(SECRET);
    for (const hidden of ['DRAFT', 'RETIRED', 'FUTURE', 'EXPIRED', 'HINDI'])
      expect(raw).not.toContain(hidden);
  });

  it('filters by difficulty and caps at what is available', async () => {
    const res = await start(learner, {
      difficulty: 2,
      question_count: 5,
    }).expect(201);
    expect(res.body.questions).toHaveLength(1);
    expect(res.body.questions[0].difficulty).toBe(2);
    expect(
      (await start(learner, { difficulty: 3 }).expect(422)).body.code,
    ).toBe('no_questions_available');
    await start(learner, {
      topic_id: '00000000-0000-7000-8000-000000000000',
    }).expect(404);
  });

  it('immediate mode: explains each answer once it is final, and retries are safe', async () => {
    const s = (await start(learner, { question_count: 2 }).expect(201)).body;
    const url = `/v1/quiz-sessions/${s.id}`;

    const right = await as(learner)
      .post(`${url}/answers`, { position: 1, selected_option_ids: ['a'] })
      .expect(200);
    expect(right.body.feedback).toMatchObject({
      correct: true,
      correct_option_ids: ['a'],
    });
    expect(right.body.feedback.explanation).toContain(SECRET);

    // Same answer again (network retry) is fine; changing it is not.
    await as(learner)
      .post(`${url}/answers`, { position: 1, selected_option_ids: ['a'] })
      .expect(200);
    const change = await as(learner)
      .post(`${url}/answers`, { position: 1, selected_option_ids: ['b'] })
      .expect(409);
    expect(change.body.code).toBe('already_answered');

    expect(
      (
        await as(learner)
          .post(`${url}/answers`, { position: 2, selected_option_ids: ['z'] })
          .expect(400)
      ).body.code,
    ).toBe('invalid_answer');
    await as(learner)
      .post(`${url}/answers`, { position: 2, selected_option_ids: ['a', 'b'] })
      .expect(400);
    await as(learner)
      .post(`${url}/answers`, { position: 9, selected_option_ids: ['a'] })
      .expect(400);

    // Resuming shows feedback for the answered question only.
    const resumed = (await as(learner).get(url).expect(200)).body;
    expect(resumed.questions[0].feedback).not.toBeNull();
    expect(resumed.questions[1].feedback).toBeNull();
    expect(JSON.stringify(resumed.questions[1])).not.toContain(SECRET);

    await as(learner)
      .post(`${url}/answers`, { position: 2, selected_option_ids: ['c'] })
      .expect(200);
    const result = (await as(learner).post(`${url}/submit`).expect(200)).body;
    expect(result).toMatchObject({
      score: 1,
      total: 2,
      correct_count: 1,
      answered_count: 2,
    });
  });

  it('end mode: reveals nothing until submit, scores on the server, and submit is idempotent', async () => {
    const s = (
      await start(learner, {
        question_count: 3,
        mode: 'exam',
        negative_marking: false,
      }).expect(201)
    ).body;
    const url = `/v1/quiz-sessions/${s.id}`;

    const first = await as(learner)
      .post(`${url}/answers`, { position: 1, selected_option_ids: ['b'] })
      .expect(200);
    expect(first.body.feedback).toBeNull();
    // Answers can change before submit.
    await as(learner)
      .post(`${url}/answers`, { position: 1, selected_option_ids: ['a'] })
      .expect(200);
    await as(learner)
      .post(`${url}/answers`, { position: 2, selected_option_ids: ['c'] })
      .expect(200);

    const during = await as(learner).get(url).expect(200);
    expect(JSON.stringify(during.body)).not.toContain(SECRET);
    expect(JSON.stringify(during.body)).not.toContain('correct_option_ids');
    expect((await as(learner).get(`${url}/result`).expect(409)).body.code).toBe(
      'not_submitted',
    );

    const result = (
      await as(learner)
        .post(`${url}/submit`)
        .set('Idempotency-Key', 'k1')
        .expect(200)
    ).body;
    expect(result).toMatchObject({
      score: 1,
      total: 3,
      correct_count: 1,
      answered_count: 2,
    });
    expect(
      result.questions.every((q: { feedback: unknown }) => q.feedback),
    ).toBe(true);
    expect(result.questions[2]).toMatchObject({
      selected_option_ids: null,
      feedback: { correct: false },
    });

    const again = (
      await as(learner)
        .post(`${url}/submit`)
        .set('Idempotency-Key', 'k1')
        .expect(200)
    ).body;
    expect(again).toEqual(result);
    expect((await as(learner).get(`${url}/result`).expect(200)).body).toEqual(
      result,
    );

    expect(
      (
        await as(learner)
          .post(`${url}/answers`, { position: 3, selected_option_ids: ['a'] })
          .expect(409)
      ).body.code,
    ).toBe('session_submitted');
  });

  it("keeps other learners' sessions invisible", async () => {
    const s = (await start(learner, { question_count: 1 }).expect(201)).body;
    const url = `/v1/quiz-sessions/${s.id}`;
    await as(other).get(url).expect(404);
    await as(other)
      .post(`${url}/answers`, { position: 1, selected_option_ids: ['a'] })
      .expect(404);
    await as(other).post(`${url}/submit`).expect(404);
    await as(other).get(`${url}/result`).expect(404);
  });

  it('refuses answers after the time limit but still lets the learner submit', async () => {
    const s = (
      await start(learner, {
        question_count: 1,
        mode: 'exam',
        negative_marking: false,
      }).expect(201)
    ).body;
    await t.db
      .update(quizSessions)
      // A one-question session gets ten minutes.
      .set({ startedAt: new Date(Date.now() - 11 * 60_000) })
      .where(eq(quizSessions.id, s.id));
    const late = await as(learner)
      .post(`/v1/quiz-sessions/${s.id}/answers`, {
        position: 1,
        selected_option_ids: ['a'],
      })
      .expect(409);
    expect(late.body.code).toBe('session_expired');
    const result = (
      await as(learner).post(`/v1/quiz-sessions/${s.id}/submit`).expect(200)
    ).body;
    expect(result).toMatchObject({ score: 0, answered_count: 0 });
  });

  it('keeps showing the version a learner saw after the question is revised', async () => {
    // A fresh topic so this session can only contain the question being revised.
    const subjectId = newId();
    const topicId = newId();
    await t.db
      .insert(subjects)
      .values({ id: subjectId, slug: `s-${subjectId}`, name: 'Revisions' });
    await t.db.insert(topics).values({
      id: topicId,
      subjectId,
      slug: `t-${topicId}`,
      name: 'Revisions',
    });
    const { questionId, versionId } = await addQuestion({
      topicId,
      stem: 'Original wording',
    });

    const s = (await start(learner, { topic_id: topicId }).expect(201)).body;
    expect(s.questions[0]).toMatchObject({
      question_version_id: versionId,
      stem: 'Original wording',
    });

    const q = (path: string) => `/v1/editor/questions/${questionId}/${path}`;
    await as(editor).post(q('revise'), { change_note: 'Reword' }).expect(200);
    await t
      .http()
      .patch(`/v1/editor/questions/${questionId}`)
      .auth(editor.token, { type: 'bearer' })
      .send({ stem: 'New wording' })
      .expect(200);
    await as(editor).post(q('submit')).expect(200);
    await as(reviewer).post(q('approve')).expect(200);
    await as(publisher).post(q('publish')).expect(200);

    await as(learner)
      .post(`/v1/quiz-sessions/${s.id}/answers`, {
        position: 1,
        selected_option_ids: ['a'],
      })
      .expect(200);
    const result = (
      await as(learner).post(`/v1/quiz-sessions/${s.id}/submit`).expect(200)
    ).body;
    expect(result.questions[0]).toMatchObject({
      question_version_id: versionId,
      stem: 'Original wording',
    });

    // New sessions get the new version.
    const fresh = (await start(learner, { topic_id: topicId }).expect(201))
      .body;
    expect(fresh.questions[0].stem).toBe('New wording');
  });

  it('draws from several topics, a difficulty range, or the same daily set for everyone', async () => {
    const subjectId = newId();
    const otherTopic = newId();
    await t.db
      .insert(subjects)
      .values({ id: subjectId, slug: `multi-${subjectId}`, name: 'Multi' });
    await t.db.insert(topics).values({
      id: otherTopic,
      subjectId,
      slug: `multi-t-${otherTopic}`,
      name: 'Multi',
    });
    const extra = await addQuestion({ topicId: otherTopic, difficulty: 3 });

    const both = (
      await start(learner, {
        topic_id: undefined,
        topic_ids: [t.topicId, otherTopic],
        question_count: 20,
      }).expect(201)
    ).body;
    expect(both.topic_ids.sort()).toEqual([t.topicId, otherTopic].sort());
    expect(
      both.questions.map(
        (q: { question_version_id: string }) => q.question_version_id,
      ),
    ).toContain(extra.versionId);

    const hard = (
      await start(learner, {
        topic_id: undefined,
        min_difficulty: 2,
        question_count: 20,
      }).expect(201)
    ).body;
    expect(hard.topic_ids).toEqual([]);
    expect(
      hard.questions.every((q: { difficulty: number }) => q.difficulty >= 2),
    ).toBe(true);
    const easy = (
      await start(learner, {
        topic_id: undefined,
        max_difficulty: 1,
        question_count: 20,
      }).expect(201)
    ).body;
    expect(
      easy.questions.every((q: { difficulty: number }) => q.difficulty === 1),
    ).toBe(true);

    const ids = (b: { questions: { question_version_id: string }[] }) =>
      b.questions.map((q) => q.question_version_id);
    const mine = (
      await start(learner, {
        topic_id: undefined,
        mode: 'daily_docket',
        question_count: 3,
      }).expect(201)
    ).body;
    const theirs = (
      await start(other, {
        topic_id: undefined,
        mode: 'daily_docket',
        question_count: 3,
      }).expect(201)
    ).body;
    expect(mine.daily).toMatch(/^\d{4}-\d{2}-\d{2}$/);
    expect(ids(theirs)).toEqual(ids(mine));

    await start(learner, {
      topic_id: undefined,
      topic_ids: [t.topicId, '00000000-0000-7000-8000-000000000000'],
    }).expect(404);
  });

  it('names topics and subjects by slug in the catalog', async () => {
    const res = await t.http().get('/v1/quizzes').expect(200);
    const topic = res.body.topics.find(
      (x: { topic_id: string }) => x.topic_id === t.topicId,
    );
    expect(topic).toMatchObject({
      subject_slug: 'constitution',
      topic_slug: 'constitution-basics',
    });
  });

  it('lists attempts newest first and sums progress per topic', async () => {
    const fresh = await t.signInAs('learner');
    for (const answer of ['a', 'b']) {
      const s = (
        await start(fresh, {
          question_count: 2,
          mode: 'exam',
          negative_marking: false,
        }).expect(201)
      ).body;
      await as(fresh)
        .post(`/v1/quiz-sessions/${s.id}/answers`, {
          position: 1,
          selected_option_ids: [answer],
        })
        .expect(200);
      await as(fresh).post(`/v1/quiz-sessions/${s.id}/submit`).expect(200);
    }
    // An unfinished session is not an attempt.
    await start(fresh, { question_count: 1 }).expect(201);

    const attempts = (
      await as(fresh).get('/v1/me/attempts?limit=1').expect(200)
    ).body;
    expect(attempts.items).toHaveLength(1);
    expect(attempts.items[0].score).toBe(0);
    const older = (
      await as(fresh)
        .get(`/v1/me/attempts?cursor=${attempts.next_cursor}`)
        .expect(200)
    ).body;
    expect(older.items.map((a: { score: number }) => a.score)).toEqual([1]);

    const progress = (await as(fresh).get('/v1/me/progress').expect(200)).body;
    expect(progress).toMatchObject({
      attempts: 2,
      questions_answered: 2,
      correct: 1,
    });
    expect(progress.topics[0]).toMatchObject({
      topic_id: t.topicId,
      attempts: 2,
      accuracy: 0.25,
      best: 0.5,
    });
  });
});
