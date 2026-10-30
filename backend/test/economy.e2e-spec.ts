import { and, eq } from 'drizzle-orm';
import { newId } from '../src/core/ids.js';
import {
  auditLog,
  coinLedger,
  premiumMemberships,
  questions,
  questionVersions,
  users,
} from '../src/db/schema.js';
import { startApp, type TestApp } from './helpers.js';

type Session = Awaited<ReturnType<TestApp['signInAs']>>;

describe('coins, energy, premium and settings', () => {
  let t: TestApp;

  const as = (s: Session) => ({
    get: (url: string) => t.http().get(url).auth(s.token, { type: 'bearer' }),
    post: (url: string, body: object = {}) =>
      t.http().post(url).auth(s.token, { type: 'bearer' }).send(body),
    put: (url: string, body: object) =>
      t.http().put(url).auth(s.token, { type: 'bearer' }).send(body),
    del: (url: string) =>
      t.http().delete(url).auth(s.token, { type: 'bearer' }),
  });
  const progress = async (s: Session) =>
    (await as(s).get('/v1/me/progress').expect(200)).body;
  const level = (difficulty = 1) => ({
    mode: 'case_path',
    topic_id: t.topicId,
    difficulty,
    question_count: 2,
  });
  const play = async (s: Session, body: object, answer = 'a') => {
    const started = (await as(s).post('/v1/quiz-sessions', body).expect(201))
      .body;
    for (const q of started.questions)
      await as(s)
        .post(`/v1/quiz-sessions/${started.id}/answers`, {
          position: q.position,
          selected_option_ids: [answer],
        })
        .expect(200);
    return (
      await as(s).post(`/v1/quiz-sessions/${started.id}/submit`).expect(200)
    ).body;
  };
  const giveCoins = (s: Session, amount: number) =>
    t.db.insert(coinLedger).values({
      id: newId(),
      userId: s.id,
      amount,
      reason: 'chest',
    });

  beforeAll(async () => {
    t = await startApp({ demoPremium: true });
    for (const d of [1, 1, 2, 2, 3, 3]) {
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
        difficulty: d,
        stem: `Q${d}`,
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
    }
  });
  afterAll(() => t.close());

  it('starts a learner with 60 coins, 5 energy and no settings', async () => {
    const s = await t.signInAs('learner');
    expect(await progress(s)).toMatchObject({
      coins: 60,
      energy: { today: 5, free_daily: 5, unlimited: false },
      premium: false,
      settings: null,
      chat: { daily_limit: 5, used_today: 0 },
    });
    // The welcome coins are paid once.
    expect((await progress(s)).coins).toBe(60);
  });

  it('charges energy at start, refuses when short, and keeps the docket free', async () => {
    const s = await t.signInAs('learner');
    const exam = { mode: 'exam', topic_id: t.topicId, question_count: 2 };
    await as(s).post('/v1/quiz-sessions', exam).expect(201);
    await as(s).post('/v1/quiz-sessions', exam).expect(201);
    expect((await progress(s)).energy.today).toBe(1);
    const short = await as(s).post('/v1/quiz-sessions', exam).expect(409);
    expect(short.body.code).toBe('not_enough_energy');
    await as(s)
      .post('/v1/quiz-sessions', { mode: 'daily_docket', question_count: 2 })
      .expect(201);
    expect((await progress(s)).energy.today).toBe(1);
  });

  it('gives energy back when a quiz is left before the first answer', async () => {
    const s = await t.signInAs('learner');
    const started = (await as(s).post('/v1/quiz-sessions', level()).expect(201))
      .body;
    expect((await progress(s)).energy.today).toBe(4);
    await as(s).post(`/v1/quiz-sessions/${started.id}/abandon`).expect(204);
    expect((await progress(s)).energy.today).toBe(5);
    await as(s).get(`/v1/quiz-sessions/${started.id}`).expect(404);

    const answered = (
      await as(s).post('/v1/quiz-sessions', level()).expect(201)
    ).body;
    await as(s)
      .post(`/v1/quiz-sessions/${answered.id}/answers`, {
        position: 1,
        selected_option_ids: ['a'],
      })
      .expect(200);
    const late = await as(s)
      .post(`/v1/quiz-sessions/${answered.id}/abandon`)
      .expect(409);
    expect(late.body.code).toBe('quiz_started');
  });

  it('pays coins and the 3-star energy bonus at submit', async () => {
    const s = await t.signInAs('learner');
    await as(s)
      .put('/v1/me/settings', {
        name: 'Asha',
        persona: 'aspirant',
        language: 'en',
        daily_goal: 1,
        onboarded: true,
      })
      .expect(200);
    const result = await play(s, level());
    expect(result.rewards.coins).toEqual({
      new_stars: 15,
      daily_docket: 0,
      daily_goal: 15,
      streak_milestone: 0,
      total: 30,
    });
    expect(result.rewards.energy_bonus).toBe(1);
    // Fetching the result again reports what was paid.
    const again = (
      await as(s)
        .get(`/v1/quiz-sessions/${result.session_id}/result`)
        .expect(200)
    ).body;
    expect(again.rewards.coins.total).toBe(30);
    // 60 + 30; energy: 5 − 1 + 1.
    expect(await progress(s)).toMatchObject({
      coins: 90,
      energy: { today: 5 },
    });

    const docket = await play(s, { mode: 'daily_docket', question_count: 2 });
    expect(docket.rewards.coins.daily_docket).toBe(10);
  });

  it('pays the daily goal once a day, even if the goal is raised', async () => {
    const s = await t.signInAs('learner');
    const settings = (goal: number) =>
      as(s)
        .put('/v1/me/settings', {
          name: 'Asha',
          persona: 'aspirant',
          language: 'en',
          daily_goal: goal,
          onboarded: true,
        })
        .expect(200);
    await settings(1);
    expect((await play(s, level(), 'b')).rewards.coins.daily_goal).toBe(15);
    await settings(2);
    expect((await play(s, level(), 'b')).rewards.coins.daily_goal).toBe(0);
  });

  it('pays 30 coins for a chest', async () => {
    const s = await t.signInAs('learner');
    for (const d of [1, 2, 3]) await play(s, level(d), 'b');
    for (const d of [1, 2, 3]) await play(s, level(d));
    const before = (await progress(s)).coins;
    const opened = (
      await as(s).post('/v1/me/chests/constitution_chest/open').expect(200)
    ).body;
    expect(opened.coins).toBe(before + 30);
    // Opening again pays nothing.
    await as(s).post('/v1/me/chests/constitution_chest/open').expect(200);
    expect((await progress(s)).coins).toBe(before + 30);
  });

  it('refills energy and sells up to 2 streak freezes for coins', async () => {
    const s = await t.signInAs('learner');
    const refilled = (await as(s).post('/v1/me/energy/refill').expect(200))
      .body;
    expect(refilled).toMatchObject({ coins: 30, energy: { today: 6 } });
    await as(s).post('/v1/me/energy/refill').expect(200);
    const broke = await as(s).post('/v1/me/energy/refill').expect(409);
    expect(broke.body.code).toBe('not_enough_coins');

    await giveCoins(s, 300);
    for (const held of [1, 2]) {
      const p = (await as(s).post('/v1/me/streak-freezes').expect(200)).body;
      expect(p.streak.freezes).toBe(held);
    }
    const full = await as(s).post('/v1/me/streak-freezes').expect(409);
    expect(full.body.code).toBe('freezes_full');
    expect((await progress(s)).coins).toBe(100);
  });

  it('turns demo premium on and off, with an audit trail', async () => {
    const s = await t.signInAs('learner');
    const on = (await as(s).post('/v1/me/premium').expect(200)).body;
    expect(on).toMatchObject({
      premium: true,
      energy: { unlimited: true },
      chat: { daily_limit: 50 },
    });
    // Premium quizzes cost nothing.
    await as(s)
      .post('/v1/quiz-sessions', {
        mode: 'exam',
        topic_id: t.topicId,
        question_count: 2,
      })
      .expect(201);
    expect((await progress(s)).energy.today).toBe(5);
    const off = (await as(s).del('/v1/me/premium').expect(200)).body;
    expect(off.premium).toBe(false);
    const audit = await t.db
      .select({ action: auditLog.action })
      .from(auditLog)
      .where(and(eq(auditLog.entityId, s.id), eq(auditLog.entityType, 'user')));
    expect(
      audit
        .map((a) => a.action)
        .filter((a) => a.startsWith('premium.'))
        .sort(),
    ).toEqual(['premium.ended', 'premium.started']);
  });

  it('ignores and refuses demo premium unless the API allows it', async () => {
    const beta = await startApp(); // DEMO_PREMIUM unset, as in the beta
    try {
      const s = await beta.signInAs('learner');
      const call = (method: 'post' | 'get', url: string) =>
        beta.http()[method](url).auth(s.token, { type: 'bearer' });
      const refused = await call('post', '/v1/me/premium').expect(404);
      expect(refused.body.code).toBe('premium_unavailable');
      // A demo membership made while it was allowed no longer counts.
      await beta.db
        .insert(premiumMemberships)
        .values({ userId: s.id, source: 'demo', startedAt: new Date() });
      const p = (await call('get', '/v1/me/progress').expect(200)).body;
      expect(p).toMatchObject({
        premium: false,
        energy: { unlimited: false },
        chat: { daily_limit: 5 },
      });
    } finally {
      await beta.close();
    }
  });

  it('saves learning settings and the name on the account', async () => {
    const s = await t.signInAs('learner');
    await as(s).get('/v1/me/settings').expect(200);
    const saved = (
      await as(s)
        .put('/v1/me/settings', {
          name: '  Ravi  ',
          persona: 'citizen',
          language: 'ta',
          daily_goal: 4,
          onboarded: true,
        })
        .expect(200)
    ).body;
    expect(saved).toEqual({
      name: 'Ravi',
      persona: 'citizen',
      language: 'ta',
      daily_goal: 4,
      onboarded: true,
    });
    const [u] = await t.db
      .select({ name: users.displayName })
      .from(users)
      .where(eq(users.id, s.id));
    expect(u.name).toBe('Ravi');
    expect((await progress(s)).settings).toEqual(saved);
    await as(s)
      .put('/v1/me/settings', { ...saved, persona: 'judge' })
      .expect(400);
    // A name of only spaces is refused, not saved empty.
    await as(s)
      .put('/v1/me/settings', { ...saved, name: '   ' })
      .expect(400);
  });
});
