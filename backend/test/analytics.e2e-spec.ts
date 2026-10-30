import { eq } from 'drizzle-orm';
import { newId } from '../src/core/ids.js';
import {
  appOpens,
  chatUsage,
  contentReports,
  learnerSettings,
  questions,
  questionVersions,
  quizSessionQuestions,
  quizSessions,
  users,
  type QuizMode,
} from '../src/db/schema.js';
import { indiaToday } from '../src/learn/scoring.js';
import { startApp, type TestApp } from './helpers.js';

type Session = Awaited<ReturnType<TestApp['signInAs']>>;

/** A moment a whole number of days ago: the India date moves by exactly that many days. */
const ago = (days: number) => new Date(Date.now() - days * 86_400_000);
const dayAgo = (days: number) => indiaToday(ago(days));

describe('usage analytics', () => {
  let t: TestApp;
  let admin: Session, analyst: Session, editor: Session;
  let q1: { questionId: string; versionId: string };
  let q2: { questionId: string; versionId: string };

  const learner = async (name: string, signedUp: number) => {
    const id = newId();
    await t.db.insert(users).values({
      id,
      email: `${name}@test.local`,
      displayName: name,
      passwordHash: 'x',
      roles: ['learner'],
      createdAt: ago(signedUp),
    });
    return id;
  };
  const question = async (stem: string) => {
    const questionId = newId();
    const versionId = newId();
    await t.db.insert(questions).values({ id: questionId });
    await t.db.insert(questionVersions).values({
      id: versionId,
      questionId,
      versionNo: 1,
      status: 'published',
      topicId: t.topicId,
      stem,
      options: [
        { id: 'a', text: 'Right' },
        { id: 'b', text: 'Wrong' },
      ],
      correctOptionIds: ['a'],
      explanation: 'Because.',
      validFrom: '2000-01-01',
    });
    await t.db
      .update(questions)
      .set({ liveVersionId: versionId })
      .where(eq(questions.id, questionId));
    return { questionId, versionId };
  };
  /** One quiz with one answered question each. */
  const quiz = async (
    userId: string,
    mode: QuizMode,
    startedDaysAgo: number,
    o: {
      finished: boolean;
      correct: number | null;
      count: number;
      answers?: { versionId: string; selected: string }[];
    },
  ) => {
    const id = newId();
    const startedAt = ago(startedDaysAgo);
    await t.db.insert(quizSessions).values({
      id,
      userId,
      mode,
      language: 'en',
      scoringVersion: 'standard-v1',
      questionCount: o.count,
      startedAt,
      submittedAt: o.finished ? startedAt : null,
      correctCount: o.finished ? o.correct : null,
    });
    for (const [i, a] of (o.answers ?? []).entries())
      await t.db.insert(quizSessionQuestions).values({
        sessionId: id,
        position: i + 1,
        questionVersionId: a.versionId,
        optionOrder: ['a', 'b'],
        selectedOptionIds: [a.selected],
        answeredAt: startedAt,
        isCorrect: a.selected === 'a',
      });
    return id;
  };
  const overview = (s: Session, days?: number) =>
    t
      .http()
      .get(`/v1/admin/analytics/overview${days ? `?days=${days}` : ''}`)
      .auth(s.token, { type: 'bearer' });

  beforeAll(async () => {
    t = await startApp();
    [admin, analyst, editor] = await Promise.all([
      t.signInAs('admin'),
      t.signInAs('analyst'),
      t.signInAs('content_editor'),
    ]);
    q1 = await question('Which Article abolishes untouchability?');
    q2 = await question('Which Article guarantees equality?');

    // Asha signed up 10 days ago and came back on days 1 and 7. Ravi never did.
    const asha = await learner('asha', 10);
    const ravi = await learner('ravi', 10);
    // Meena signed up today and played a lot.
    const meena = await learner('meena', 0);
    await t.db.insert(appOpens).values([
      { userId: asha, day: dayAgo(9) },
      { userId: ravi, day: dayAgo(10) }, // the day they signed up: not retention
    ]);
    await quiz(asha, 'duel', 3, {
      finished: true,
      correct: 3,
      count: 3,
      answers: [{ versionId: q2.versionId, selected: 'b' }],
    });
    await t.db
      .insert(chatUsage)
      .values({ userId: asha, day: dayAgo(3), answers: 2 });
    // Meena: five quick quizzes, one answer right and four wrong on question 1.
    for (const selected of ['a', 'b', 'b', 'b', 'b'])
      await quiz(meena, 'case_path', 0, {
        finished: true,
        correct: selected === 'a' ? 1 : 0,
        count: 1,
        answers: [{ versionId: q1.versionId, selected }],
      });
    // An exam that was never submitted: its answer must not count.
    await quiz(meena, 'exam', 0, {
      finished: false,
      correct: null,
      count: 1,
      answers: [{ versionId: q1.versionId, selected: 'b' }],
    });
    await t.db.insert(learnerSettings).values(
      [asha, meena].map((userId) => ({
        userId,
        persona: 'citizen' as const,
        language: 'en',
        dailyGoal: 3,
        onboardedAt: new Date(),
      })),
    );
    await t.db.insert(contentReports).values({
      id: newId(),
      userId: meena,
      questionVersionId: q1.versionId,
      reason: 'typo',
    });
  });
  afterAll(() => t.close());

  it('calculates learners, activity, retention, quizzes and content health', async () => {
    const res = await overview(analyst).expect(200);
    const o = res.body;
    expect(o).toMatchObject({ as_of: dayAgo(0), days: 30 });

    // Staff accounts are not learners.
    expect(o.learners).toEqual({
      total: 3,
      new_in_period: 3,
      onboarded: 2,
      finished_a_quiz: 2,
    });
    // Today: Meena. Last 7 days: Asha (3 days ago) and Meena. Ravi opened the app only on sign-up day, long ago.
    expect(o.active).toEqual({ today: 1, last_7_days: 2, last_30_days: 3 });

    expect(o.daily).toHaveLength(30);
    expect(o.daily[0].date).toBe(dayAgo(29));
    const day = (n: number) =>
      o.daily.find((d: { date: string }) => d.date === dayAgo(n));
    expect(day(0)).toEqual({
      date: dayAgo(0),
      new_learners: 1,
      active_learners: 1,
      quizzes_started: 6,
      quizzes_finished: 5,
      ai_answers: 0,
    });
    expect(day(3)).toMatchObject({
      active_learners: 1,
      quizzes_started: 1,
      quizzes_finished: 1,
      ai_answers: 2,
    });
    expect(day(10)).toMatchObject({ new_learners: 2, active_learners: 1 });

    // Signed up 10 days ago: Asha came back on day 1 (app) and day 7 (quiz); Ravi did not.
    // Meena signed up today, too recent to measure; nobody is 30 days old yet.
    expect(o.retention).toEqual([
      { day: 1, eligible: 2, retained: 1 },
      { day: 7, eligible: 2, retained: 1 },
      { day: 30, eligible: 0, retained: 0 },
    ]);

    expect(o.modes).toEqual(
      [
        {
          mode: 'case_path',
          started: 5,
          finished: 5,
          average_score_percent: 20,
        },
        { mode: 'exam', started: 1, finished: 0, average_score_percent: null },
        { mode: 'duel', started: 1, finished: 1, average_score_percent: 100 },
      ].sort((a, b) => b.started - a.started || a.mode.localeCompare(b.mode)),
    );

    // Question 1: 5 final answers, 1 right. The unsubmitted exam answer is left out,
    // and question 2 has too few answers to be ranked.
    expect(o.content).toMatchObject({
      open_reports: 1,
      reports_in_period: 1,
      min_answers: 5,
      hardest_questions: [
        {
          question_id: q1.questionId,
          stem: 'Which Article abolishes untouchability?',
          topic: 'Preamble and Parliament',
          answers: 5,
          correct_percent: 20,
        },
      ],
    });
  });

  it('shortens the period without changing the totals', async () => {
    const o = (await overview(admin, 7).expect(200)).body;
    expect(o.days).toBe(7);
    expect(o.daily).toHaveLength(7);
    expect(o.learners).toMatchObject({ total: 3, new_in_period: 1 });
    // Asha's quiz 3 days ago is inside 7 days; her sign-up (10 days ago) is not.
    expect(
      o.modes.find((m: { mode: string }) => m.mode === 'duel'),
    ).toMatchObject({
      started: 1,
    });
  });

  it('is for admins and analysts only, with a fixed list of periods', async () => {
    await overview(editor).expect(403);
    await t.http().get('/v1/admin/analytics/overview').expect(401);
    await overview(admin, 45).expect(400);
    const learnerSession = await t.signInAs('learner');
    await overview(learnerSession).expect(403);
  });

  it('only counts accounts that are learners', async () => {
    // The staff accounts made in beforeAll played nothing, but give one a quiz anyway.
    await quiz(editor.id, 'case_path', 0, {
      finished: true,
      correct: 1,
      count: 1,
    });
    const o = (await overview(admin).expect(200)).body;
    expect(o.learners.total).toBe(4); // + the learner who just signed in above
    expect(o.daily.at(-1).quizzes_started).toBe(6);
  });
});

describe('the daily app-open marker', () => {
  let t: TestApp;
  beforeAll(async () => {
    t = await startApp();
  });
  afterAll(() => t.close());

  it('keeps one row per learner per day', async () => {
    const s = await t.signInAs('learner');
    const post = () =>
      t.http().post('/v1/me/app-open').auth(s.token, { type: 'bearer' }).send();
    await post().expect(204);
    await post().expect(204);
    const rows = await t.db
      .select()
      .from(appOpens)
      .where(eq(appOpens.userId, s.id));
    expect(rows).toEqual([{ userId: s.id, day: indiaToday(new Date()) }]);
    await t.http().post('/v1/me/app-open').expect(401);
  });
});
