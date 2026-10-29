import { eq } from 'drizzle-orm';
import { newId } from '../src/core/ids.js';
import {
  questions,
  questionVersions,
  quizSessions,
  subjects,
  topics,
} from '../src/db/schema.js';
import { startApp, type TestApp } from './helpers.js';

type Session = Awaited<ReturnType<TestApp['signInAs']>>;

describe('learner progress', () => {
  let t: TestApp;
  let otherTopic: string;

  const addQuestion = async (difficulty: number, topicId = t.topicId) => {
    const questionId = newId();
    const versionId = newId();
    await t.db.insert(questions).values({ id: questionId });
    await t.db.insert(questionVersions).values({
      id: versionId,
      questionId,
      versionNo: 1,
      status: 'published',
      topicId,
      language: 'en',
      difficulty,
      stem: `Q${difficulty} ${versionId.slice(-6)}`,
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
  };

  const as = (s: Session) => ({
    get: (url: string) => t.http().get(url).auth(s.token, { type: 'bearer' }),
    post: (url: string, body: object = {}) =>
      t.http().post(url).auth(s.token, { type: 'bearer' }).send(body),
  });

  /** Starts, answers (a = right, b = wrong) and submits; returns the result. */
  const play = async (
    s: Session,
    body: object,
    answers: ('a' | 'b' | null)[],
  ) => {
    const started = (await as(s).post('/v1/quiz-sessions', body).expect(201))
      .body;
    for (const [i, a] of answers.entries())
      if (a)
        await as(s)
          .post(`/v1/quiz-sessions/${started.id}/answers`, {
            position: i + 1,
            selected_option_ids: [a],
          })
          .expect(200);
    return (
      await as(s).post(`/v1/quiz-sessions/${started.id}/submit`).expect(200)
    ).body;
  };

  const level = (difficulty: number) => ({
    mode: 'case_path',
    topic_id: t.topicId,
    difficulty,
    question_count: 2,
  });

  beforeAll(async () => {
    t = await startApp();
    for (const d of [1, 1, 2, 2, 3, 3]) await addQuestion(d);
    // A second subject, to check a level must stay within one.
    const subjectId = newId();
    otherTopic = newId();
    await t.db
      .insert(subjects)
      .values({ id: subjectId, slug: 'rights', name: 'Rights', sortOrder: 1 });
    await t.db.insert(topics).values({
      id: otherTopic,
      subjectId,
      slug: 'rights-basics',
      name: 'Rights',
    });
    await addQuestion(1, otherTopic);
  });
  afterAll(() => t.close());

  it('starts every account at zero', async () => {
    const s = await t.signInAs('learner');
    const p = (await as(s).get('/v1/me/progress').expect(200)).body;
    expect(p).toMatchObject({
      total_xp: 0,
      week: { xp: 0 },
      streak: { current: 0, longest: 0, freezes: 0, active_days: [] },
      stars: {},
      opened_chests: [],
      quizzes_completed: 0,
      docket_done_today: false,
    });
    expect(p.week.week_id).toMatch(/^\d{4}-W\d{2}$/);
  });

  it('awards stars, XP and the streak for a Case Path level', async () => {
    const s = await t.signInAs('learner');
    const result = await play(s, level(1), ['a', 'a']);
    expect(result.mode).toBe('case_path');
    expect(result.rewards).toMatchObject({
      level_id: 'constitution_1',
      stars: 3,
      best_stars_before: 0,
      new_stars: 3,
      streak: 1,
      streak_extended: true,
      streak_milestone: null,
    });
    // Answered at once, so the server-timed speed bonus is close to full:
    // 2 × (10 + 5) + 10 completion + 10 perfect.
    expect(result.rewards.xp).toMatchObject({
      question_xp: 30,
      completion_bonus: 10,
      perfect_bonus: 10,
      mode_multiplier: 1,
      total: 50,
    });

    const p = (await as(s).get('/v1/me/progress').expect(200)).body;
    expect(p).toMatchObject({
      total_xp: 50,
      week: { xp: 50 },
      streak: { current: 1, longest: 1 },
      stars: { constitution_1: 3 },
      quizzes_completed: 1,
      quizzes_today: 1,
    });
    expect(p.streak.active_days).toEqual([p.today]);

    // Replaying a 3-star level pays half, keeps the best stars and doesn't extend the streak again.
    const replay = await play(s, level(1), ['a', 'b']);
    expect(replay.rewards).toMatchObject({
      stars: 1,
      best_stars_before: 3,
      new_stars: 0,
      streak_extended: false,
    });
    expect(replay.rewards.xp.mode_multiplier).toBe(0.5);
    const after = (await as(s).get('/v1/me/progress').expect(200)).body;
    expect(after.stars.constitution_1).toBe(3);
    expect(after.total_xp).toBe(50 + replay.rewards.xp.total);

    // The result can be fetched again with the same rewards.
    const again = (
      await as(s)
        .get(`/v1/quiz-sessions/${replay.session_id}/result`)
        .expect(200)
    ).body;
    expect(again.rewards).toEqual(replay.rewards);
  });

  it('counts a streak across days and times answers on the server', async () => {
    const s = await t.signInAs('learner');
    const yesterday = await play(s, level(1), ['a', 'a']);
    await t.db
      .update(quizSessions)
      .set({ submittedAt: new Date(Date.now() - 86_400_000) })
      .where(eq(quizSessions.id, yesterday.session_id));

    // Slow answers (over 30 s each) earn no speed bonus.
    const started = (
      await as(s).post('/v1/quiz-sessions', level(2)).expect(201)
    ).body;
    await t.db
      .update(quizSessions)
      .set({ startedAt: new Date(Date.now() - 5 * 60_000) })
      .where(eq(quizSessions.id, started.id));
    for (const position of [1, 2])
      await as(s)
        .post(`/v1/quiz-sessions/${started.id}/answers`, {
          position,
          selected_option_ids: ['a'],
        })
        .expect(200);
    const today = (
      await as(s).post(`/v1/quiz-sessions/${started.id}/submit`).expect(200)
    ).body;
    expect(today.rewards.streak).toBe(2);
    // First answer waited 5 minutes (no bonus); the second came at once (+5).
    // Difficulty 2: (10 + 15) × 1.25 = 31.25 → 31.
    expect(today.rewards.xp.question_xp).toBe(31);
  });

  it('allows one docket a day at 1.25× XP', async () => {
    const s = await t.signInAs('learner');
    const body = { mode: 'daily_docket', question_count: 2 };
    const docket = await play(s, body, ['a', 'a']);
    expect(docket.rewards.xp.mode_multiplier).toBe(1.25);
    const second = await as(s).post('/v1/quiz-sessions', body).expect(409);
    expect(second.body.code).toBe('docket_done_today');
    expect(
      (await as(s).get('/v1/me/progress').expect(200)).body.docket_done_today,
    ).toBe(true);
  });

  it('takes 0.25 off per wrong exam answer unless turned off', async () => {
    const s = await t.signInAs('learner');
    const exam = { mode: 'exam', topic_id: t.topicId, question_count: 4 };
    const marked = await play(s, exam, ['a', 'b', 'b', null]);
    expect(marked).toMatchObject({
      scoring_version: 'exam-negative-v1',
      score: 0.5,
      correct_count: 1,
      answered_count: 3,
    });
    // XP is never reduced by minus marks.
    expect(marked.rewards.xp.total).toBeGreaterThan(0);
    const plain = await play(s, { ...exam, negative_marking: false }, [
      'a',
      'b',
    ]);
    expect(plain).toMatchObject({ scoring_version: 'standard-v1', score: 1 });
  });

  it('refuses a Case Path level across subjects or difficulties', async () => {
    const s = await t.signInAs('learner');
    for (const body of [
      { ...level(1), topic_id: undefined, topic_ids: [t.topicId, otherTopic] },
      {
        ...level(1),
        difficulty: undefined,
        min_difficulty: 1,
        max_difficulty: 2,
      },
    ]) {
      const res = await as(s).post('/v1/quiz-sessions', body).expect(400);
      expect(res.body.code).toBe('invalid_quiz');
    }
  });

  it('opens a chest only when it is the next step on the road', async () => {
    const s = await t.signInAs('learner');
    const open = (id: string) => as(s).post(`/v1/me/chests/${id}/open`);
    expect((await open('constitution_chest').expect(409)).body.code).toBe(
      'chest_locked',
    );
    await open('nowhere_chest').expect(404);
    await play(s, level(1), ['a', 'b']);
    await play(s, level(2), ['a', 'a']);
    await play(s, level(3), ['a', 'b']);
    const p = (await open('constitution_chest').expect(200)).body;
    expect(p.opened_chests).toEqual(['constitution_chest']);
    expect(p.stars).toEqual({
      constitution_1: 1,
      constitution_2: 3,
      constitution_3: 1,
    });
    // Opening again is harmless.
    await open('constitution_chest').expect(200);
  });
});
