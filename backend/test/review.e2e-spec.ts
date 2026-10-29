import { eq } from 'drizzle-orm';
import { newId } from '../src/core/ids.js';
import {
  premiumMemberships,
  questions,
  questionVersions,
} from '../src/db/schema.js';
import { startApp, type TestApp } from './helpers.js';

type Session = Awaited<ReturnType<TestApp['signInAs']>>;
interface Q {
  questionId: string;
  versionId: string;
}

describe('saved questions and mistakes', () => {
  let t: TestApp;
  let qs: Q[];

  const as = (s: Session) => ({
    get: (url: string) => t.http().get(url).auth(s.token, { type: 'bearer' }),
    post: (url: string, body: object = {}) =>
      t.http().post(url).auth(s.token, { type: 'bearer' }).send(body),
    del: (url: string) =>
      t.http().delete(url).auth(s.token, { type: 'bearer' }),
  });
  /** Plays a quiz; `wrong` lists question ids to answer wrong (the rest right). */
  const play = async (
    s: Session,
    body: object,
    wrong: string[] = [],
    submit = true,
  ) => {
    const started = (await as(s).post('/v1/quiz-sessions', body).expect(201))
      .body;
    for (const q of started.questions) {
      const id = qs.find(
        (x) => x.versionId === q.question_version_id,
      )!.questionId;
      await as(s)
        .post(`/v1/quiz-sessions/${started.id}/answers`, {
          position: q.position,
          selected_option_ids: [wrong.includes(id) ? 'b' : 'a'],
        })
        .expect(200);
    }
    if (submit)
      await as(s).post(`/v1/quiz-sessions/${started.id}/submit`).expect(200);
    return started;
  };
  const duel = () => ({ mode: 'duel', topic_id: t.topicId, question_count: 3 });
  const mistakes = async (s: Session) =>
    (await as(s).get('/v1/me/mistakes').expect(200)).body.items;
  const learner = async () => {
    const s = await t.signInAs('learner');
    await t.db
      .insert(premiumMemberships)
      .values({ userId: s.id, source: 'test', startedAt: new Date() });
    return s;
  };

  beforeAll(async () => {
    t = await startApp();
    qs = [];
    for (let i = 0; i < 3; i++) {
      const questionId = newId();
      const versionId = newId();
      await t.db.insert(questions).values({ id: questionId });
      await t.db.insert(questionVersions).values({
        id: versionId,
        questionId,
        versionNo: 1,
        status: 'published',
        topicId: t.topicId,
        language: 'en',
        difficulty: 1,
        stem: `Question ${i}`,
        options: [
          { id: 'a', text: 'Right' },
          { id: 'b', text: 'Wrong' },
        ],
        correctOptionIds: ['a'],
        explanation: `Because ${i}.`,
        provisionReference: `Article ${i}`,
        sourceTitle: 'Constitution of India',
        sourceUrl: 'https://legislative.gov.in/constitution-of-india/',
        validFrom: '2000-01-01',
      });
      await t.db
        .update(questions)
        .set({ liveVersionId: versionId })
        .where(eq(questions.id, questionId));
      qs.push({ questionId, versionId });
    }
  });
  afterAll(() => t.close());

  it('lists wrong answers once each, counts repeats, and drops one answered right later', async () => {
    const s = await learner();
    expect(await mistakes(s)).toEqual([]);
    const [q0, q1] = qs;
    const ids = (items: { question: { question_id: string } }[]) =>
      items.map((m) => m.question.question_id).sort();
    await play(s, duel(), [q0.questionId, q1.questionId]);
    expect(ids(await mistakes(s))).toEqual(
      [q0.questionId, q1.questionId].sort(),
    );
    await play(s, duel(), [q0.questionId]);
    const list = await mistakes(s);
    const first = list.find(
      (m: { question: { question_id: string } }) =>
        m.question.question_id === q0.questionId,
    );
    expect(first).toMatchObject({
      wrong_count: 2,
      saved: false,
      question: {
        available: true,
        stem: 'Question 0',
        correct_option_ids: ['a'],
        explanation: 'Because 0.',
        provision_reference: 'Article 0',
        source_title: 'Constitution of India',
        source_url: 'https://legislative.gov.in/constitution-of-india/',
        citation: null,
      },
    });
    // q1 was answered right in the second duel, so only q0 is left.
    expect(list).toHaveLength(1);
  });

  it('counts exam answers only after the exam is submitted', async () => {
    const s = await learner();
    const exam = { mode: 'exam', topic_id: t.topicId, question_count: 3 };
    await play(s, exam, [qs[2].questionId], false);
    expect(await mistakes(s)).toEqual([]);
    await play(s, exam, [qs[2].questionId]);
    expect(
      (await mistakes(s)).map(
        (m: { question: { question_id: string } }) => m.question.question_id,
      ),
    ).toEqual([qs[2].questionId]);
  });

  it('practises mistakes for free and clears the ones answered right', async () => {
    const s = await t.signInAs('learner'); // not premium: energy matters
    await play(s, duel(), [qs[0].questionId, qs[1].questionId]);
    const energy = async () =>
      (await as(s).get('/v1/me/progress').expect(200)).body.energy.today;
    const before = await energy();
    const practice = await play(s, {
      mode: 'mistake_review',
      question_count: 10,
    });
    expect(
      practice.questions
        .map((q: { question_version_id: string }) => q.question_version_id)
        .sort(),
    ).toEqual([qs[0].versionId, qs[1].versionId].sort());
    expect(await energy()).toBe(before);
    expect(await mistakes(s)).toEqual([]);
    const none = await as(s)
      .post('/v1/quiz-sessions', { mode: 'mistake_review', question_count: 10 })
      .expect(422);
    expect(none.body.code).toBe('no_questions_available');
  });

  it('shows the version you answered when the question was revised since', async () => {
    const s = await learner();
    const q = qs[1];
    await play(s, duel(), [q.questionId]);
    // Staff publish v2 with a different answer.
    const v2 = newId();
    await t.db.insert(questionVersions).values({
      id: v2,
      questionId: q.questionId,
      versionNo: 2,
      status: 'published',
      topicId: t.topicId,
      language: 'en',
      difficulty: 1,
      stem: 'Question 1 (revised)',
      options: [
        { id: 'a', text: 'Old answer' },
        { id: 'b', text: 'New answer' },
      ],
      correctOptionIds: ['b'],
      explanation: 'Changed by the 2024 law.',
      validFrom: '2000-01-01',
    });
    await t.db
      .update(questions)
      .set({ liveVersionId: v2 })
      .where(eq(questions.id, q.questionId));
    try {
      const [m] = (await mistakes(s)).filter(
        (x: { question: { question_id: string } }) =>
          x.question.question_id === q.questionId,
      );
      // The answered version, with its answer; never v2's answer.
      expect(m.question).toMatchObject({
        available: true,
        updated_since: true,
        stem: 'Question 1',
        correct_option_ids: ['a'],
      });
      expect(JSON.stringify(m)).not.toContain('Changed by the 2024 law');
      // Practice uses the live version.
      const started = (
        await as(s)
          .post('/v1/quiz-sessions', {
            mode: 'mistake_review',
            question_count: 10,
          })
          .expect(201)
      ).body;
      expect(
        started.questions.map(
          (x: { question_version_id: string }) => x.question_version_id,
        ),
      ).toContain(v2);
    } finally {
      await t.db
        .update(questions)
        .set({ liveVersionId: q.versionId })
        .where(eq(questions.id, q.questionId));
    }
  });

  it('saves only answered questions, once, and shows retired ones as unavailable', async () => {
    const s = await learner();
    const [q0] = qs;
    const notYet = await as(s)
      .post('/v1/me/bookmarks', { question_id: q0.questionId })
      .expect(404);
    expect(notYet.body.code).toBe('not_found');
    await play(s, duel(), [q0.questionId]);
    for (let i = 0; i < 2; i++)
      await as(s)
        .post('/v1/me/bookmarks', { question_id: q0.questionId })
        .expect(201);
    const saved = (await as(s).get('/v1/me/bookmarks').expect(200)).body.items;
    expect(saved).toHaveLength(1);
    expect(saved[0].question).toMatchObject({
      question_id: q0.questionId,
      available: true,
      updated_since: false,
      correct_option_ids: ['a'],
    });
    expect((await mistakes(s))[0].saved).toBe(true);

    // Retired: still listed, but without its answer.
    await t.db
      .update(questions)
      .set({ retiredAt: new Date() })
      .where(eq(questions.id, q0.questionId));
    const retired = (await as(s).get('/v1/me/bookmarks').expect(200)).body
      .items[0].question;
    expect(retired).toMatchObject({
      available: false,
      stem: 'Question 0',
      correct_option_ids: [],
      explanation: null,
    });
    await t.db
      .update(questions)
      .set({ retiredAt: null })
      .where(eq(questions.id, q0.questionId));

    await as(s).del(`/v1/me/bookmarks/${q0.questionId}`).expect(204);
    expect(
      (await as(s).get('/v1/me/bookmarks').expect(200)).body.items,
    ).toEqual([]);
  });
});
