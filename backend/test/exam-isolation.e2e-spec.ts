import { eq } from 'drizzle-orm';
import { newId } from '../src/core/ids.js';
import {
  premiumMemberships,
  questions,
  questionVersions,
  subjects,
  topics,
} from '../src/db/schema.js';
import { startApp, type TestApp } from './helpers.js';

type Session = Awaited<ReturnType<TestApp['signInAs']>>;
interface Q {
  questionId: string;
  versionId: string;
}

/**
 * Questions meant only for the mock exams must never reach an existing game
 * mode, even when they are published, live and otherwise eligible.
 */
describe('exam-only questions and the game modes', () => {
  let t: TestApp;
  let ordinary: Q[];
  let examOnly: Q[];
  let examOnlyTopicId: string;

  const as = (s: Session) => ({
    get: (url: string) => t.http().get(url).auth(s.token, { type: 'bearer' }),
    post: (url: string, body: object = {}) =>
      t.http().post(url).auth(s.token, { type: 'bearer' }).send(body),
  });

  /** A published, live question, so only the exam-only flag keeps it out. */
  const addQuestion = async (
    topicId: string,
    isExamOnly: boolean,
  ): Promise<Q> => {
    const questionId = newId();
    const versionId = newId();
    await t.db
      .insert(questions)
      .values({ id: questionId, examOnly: isExamOnly });
    await t.db.insert(questionVersions).values({
      id: versionId,
      questionId,
      versionNo: 1,
      status: 'published',
      topicId,
      language: 'en',
      difficulty: 1,
      stem: `${isExamOnly ? 'Exam-only' : 'Ordinary'} ${versionId.slice(-6)}`,
      options: [
        { id: 'a', text: 'Right' },
        { id: 'b', text: 'Wrong' },
      ],
      correctOptionIds: ['a'],
      explanation: 'Because.',
      sourceTitle: 'Constitution of India',
      sourceUrl: 'https://legislative.gov.in/constitution-of-india/',
      validFrom: '2000-01-01',
    });
    await t.db
      .update(questions)
      .set({ liveVersionId: versionId })
      .where(eq(questions.id, questionId));
    return { questionId, versionId };
  };

  const learner = async () => {
    const s = await t.signInAs('learner');
    await t.db
      .insert(premiumMemberships)
      .values({ userId: s.id, source: 'test', startedAt: new Date() });
    return s;
  };

  const start = (s: Session, body: object) =>
    as(s).post('/v1/quiz-sessions', body);
  const versionIds = (session: {
    questions: { question_version_id: string }[];
  }) => session.questions.map((q) => q.question_version_id).sort();
  const answerAll = async (s: Session, session: any, right = true) => {
    for (const q of session.questions)
      await as(s)
        .post(`/v1/quiz-sessions/${session.id}/answers`, {
          position: q.position,
          selected_option_ids: [right ? 'a' : 'b'],
        })
        .expect(200);
    await as(s).post(`/v1/quiz-sessions/${session.id}/submit`).expect(200);
  };

  beforeAll(async () => {
    t = await startApp();
    ordinary = [];
    examOnly = [];
    for (let i = 0; i < 3; i++)
      ordinary.push(await addQuestion(t.topicId, false));
    for (let i = 0; i < 3; i++)
      examOnly.push(await addQuestion(t.topicId, true));
    const subjectId = newId();
    examOnlyTopicId = newId();
    await t.db
      .insert(subjects)
      .values({ id: subjectId, slug: 'exam-only-subject', name: 'Exam only' });
    await t.db.insert(topics).values({
      id: examOnlyTopicId,
      subjectId,
      slug: 'exam-only-topic',
      name: 'Exam only topic',
    });
    for (let i = 0; i < 2; i++) await addQuestion(examOnlyTopicId, true);
  });
  afterAll(() => t.close());

  it('leaves exam-only questions out of the catalog, and out of topics that hold only them', async () => {
    const res = await t.http().get('/v1/quizzes').expect(200);
    expect(res.body.topics).toEqual([
      expect.objectContaining({
        topic_id: t.topicId,
        available: 3,
        by_difficulty: { '1': 3, '2': 0, '3': 0 },
      }),
    ]);
  });

  it.each(['case_path', 'duel', 'exam', 'daily_docket'])(
    'never puts an exam-only question in a %s quiz',
    async (mode) => {
      const s = await learner();
      const body =
        mode === 'daily_docket'
          ? { mode, question_count: 10 }
          : {
              mode,
              topic_id: t.topicId,
              question_count: 10,
              ...(mode === 'case_path' ? { difficulty: 1 } : {}),
            };
      const session = (await start(s, body).expect(201)).body;
      // The three ordinary questions all fit, so the exam-only ones were skipped, not just unlucky.
      expect(versionIds(session)).toEqual(
        ordinary.map((q) => q.versionId).sort(),
      );
    },
  );

  it.each(['case_path', 'duel', 'exam'])(
    'finds no questions for a %s quiz on a topic that holds only exam-only ones',
    async (mode) => {
      const s = await learner();
      const res = await start(s, {
        mode,
        topic_id: examOnlyTopicId,
        ...(mode === 'case_path' ? { difficulty: 1 } : {}),
      }).expect(422);
      expect(res.body.code).toBe('no_questions_available');
    },
  );

  it('takes a question off the mistake list and the saved list once it is exam-only, and brings it back when it is not', async () => {
    const s = await learner();
    const session = (
      await start(s, {
        mode: 'duel',
        topic_id: t.topicId,
        question_count: 3,
      }).expect(201)
    ).body;
    await answerAll(s, session, false);
    const [q0, q1] = ordinary;
    await as(s)
      .post('/v1/me/bookmarks', { question_id: q1.questionId })
      .expect(201);

    const mistakes = async () =>
      (await as(s).get('/v1/me/mistakes').expect(200)).body.items as {
        question: {
          question_id: string;
          available: boolean;
          correct_option_ids: string[];
        };
      }[];
    const saved = async () =>
      (await as(s).get('/v1/me/bookmarks').expect(200)).body.items as {
        question: { available: boolean };
      }[];
    const q0Entry = async () =>
      (await mistakes()).find((m) => m.question.question_id === q0.questionId)!;

    expect((await q0Entry()).question.available).toBe(true);
    expect((await saved())[0].question.available).toBe(true);

    await t.db
      .update(questions)
      .set({ examOnly: true })
      .where(eq(questions.id, q0.questionId));
    await t.db
      .update(questions)
      .set({ examOnly: true })
      .where(eq(questions.id, q1.questionId));
    // Review no longer shows the answer key for either.
    expect((await q0Entry()).question).toMatchObject({
      available: false,
      correct_option_ids: [],
    });
    expect((await saved())[0].question).toMatchObject({ available: false });
    // Mistake practice cannot draw them.
    const practice = (
      await start(s, { mode: 'mistake_review', question_count: 10 }).expect(201)
    ).body;
    expect(versionIds(practice)).not.toContain(q0.versionId);
    expect(versionIds(practice)).not.toContain(q1.versionId);

    await t.db
      .update(questions)
      .set({ examOnly: false })
      .where(eq(questions.id, q0.questionId));
    await t.db
      .update(questions)
      .set({ examOnly: false })
      .where(eq(questions.id, q1.questionId));
    expect((await q0Entry()).question.available).toBe(true);
  });

  it('does not race a duel opponent over a question that has since become exam-only', async () => {
    const a = await learner();
    const first = (
      await start(a, {
        mode: 'duel',
        topic_id: t.topicId,
        question_count: 3,
      }).expect(201)
    ).body;
    await answerAll(a, first);

    // Control: with every question still ordinary, the next learner races A.
    const b = await learner();
    const second = (
      await start(b, {
        mode: 'duel',
        topic_id: t.topicId,
        question_count: 3,
      }).expect(201)
    ).body;
    expect(second.duel.opponent.practice).toBe(false);

    await t.db
      .update(questions)
      .set({ examOnly: true })
      .where(eq(questions.id, ordinary[0].questionId));
    const c = await learner();
    const third = (
      await start(c, {
        mode: 'duel',
        topic_id: t.topicId,
        question_count: 3,
      }).expect(201)
    ).body;
    expect(third.duel.opponent.practice).toBe(true);
    expect(versionIds(third)).not.toContain(ordinary[0].versionId);
    await t.db
      .update(questions)
      .set({ examOnly: false })
      .where(eq(questions.id, ordinary[0].questionId));
  });
});
