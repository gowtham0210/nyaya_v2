import { eq } from 'drizzle-orm';
import { newId } from '../src/core/ids.js';
import {
  coinLedger,
  duelMatches,
  questions,
  questionVersions,
  users,
} from '../src/db/schema.js';
import { duelPoints, nextRating } from '../src/learn/duel.js';
import { startApp, type TestApp } from './helpers.js';

type Session = Awaited<ReturnType<TestApp['signInAs']>>;

describe('Moot Court Duel', () => {
  let t: TestApp;

  /** A live question whose right answer is "a". */
  const addQuestion = async (difficulty = 1) => {
    const questionId = newId();
    const versionId = newId();
    await t.db.insert(questions).values({ id: questionId });
    await t.db.insert(questionVersions).values({
      id: versionId,
      questionId,
      versionNo: 1,
      status: 'published',
      topicId: t.topicId,
      difficulty,
      stem: `Question ${versionId.slice(-6)}`,
      options: [
        { id: 'a', text: 'Right' },
        { id: 'b', text: 'Wrong' },
      ],
      correctOptionIds: ['a'],
      explanation: 'Because',
      sourceTitle: 'Constitution of India',
      validFrom: '2000-01-01',
    });
    await t.db
      .update(questions)
      .set({ liveVersionId: versionId })
      .where(eq(questions.id, questionId));
    return versionId;
  };

  const as = (s: Session) => ({
    get: (url: string) => t.http().get(url).auth(s.token, { type: 'bearer' }),
    post: (url: string, body: object = {}) =>
      t.http().post(url).auth(s.token, { type: 'bearer' }).send(body),
  });

  const start = (s: Session) =>
    as(s)
      .post('/v1/quiz-sessions', {
        mode: 'duel',
        topic_id: t.topicId,
        question_count: 3,
      })
      .expect(201);

  /** Answers every question ([right] says which are right) in [ms] each, then submits. */
  const play = async (
    s: Session,
    session: { id: string },
    right: boolean[],
    ms = 3000,
  ) => {
    for (const [i, ok] of right.entries())
      await as(s)
        .post(`/v1/quiz-sessions/${session.id}/answers`, {
          position: i + 1,
          selected_option_ids: [ok ? 'a' : 'b'],
          elapsed_ms: ms,
        })
        .expect(200);
    return (
      await as(s).post(`/v1/quiz-sessions/${session.id}/submit`).expect(200)
    ).body;
  };

  const rename = (s: Session, name: string) =>
    t.db.update(users).set({ displayName: name }).where(eq(users.id, s.id));

  beforeAll(async () => {
    t = await startApp();
    for (let i = 0; i < 4; i++) await addQuestion((i % 3) + 1);
  });
  afterAll(() => t.close());

  it('starts against a labelled practice player when nobody else has played', async () => {
    const asha = await t.signInAs('learner');
    const s = (await start(asha)).body;
    expect(s.duel.opponent).toMatchObject({ practice: true });
    expect(s.duel.opponent.name).toMatch(/^\S+ [A-Z]\.$/);
    expect(s.duel.opponent_answers).toHaveLength(3);
    for (const a of s.duel.opponent_answers) {
      expect(typeof a.correct).toBe('boolean');
      expect(a.elapsed_ms).toBeGreaterThanOrEqual(2500);
    }
    // Answer keys still stay on the server until each answer.
    expect(
      s.questions.every((q: { feedback: unknown }) => q.feedback === null),
    ).toBe(true);
  });

  it('races the next learner against a recorded run on the same questions', async () => {
    const ravi = await t.signInAs('learner');
    await rename(ravi, 'Ravi Kumar');
    const first = (await start(ravi)).body;
    await play(ravi, first, [true, true, false], 4000);

    const meena = await t.signInAs('learner');
    const second = (await start(meena)).body;
    expect(second.duel.opponent).toEqual({
      name: 'Ravi K.',
      rating: 1000,
      practice: false,
    });
    const ids = (x: { questions: { question_version_id: string }[] }) =>
      x.questions.map((q) => q.question_version_id);
    expect(ids(second)).toEqual(ids(first));
    expect(second.duel.opponent_answers).toEqual([
      { correct: true, elapsed_ms: expect.any(Number) },
      { correct: true, elapsed_ms: expect.any(Number) },
      { correct: false, elapsed_ms: expect.any(Number) },
    ]);

    // Faster and all right: Meena wins, gets the bonus, and both ratings are on the server.
    const result = await play(meena, second, [true, true, true], 1000);
    const ravisPoints = second.duel.opponent_answers.reduce(
      (sum: number, a: { correct: boolean; elapsed_ms: number }) =>
        sum + duelPoints(a.correct, a.elapsed_ms),
      0,
    );
    expect(result.duel).toMatchObject({
      outcome: 'won',
      opponent_points: ravisPoints,
      rating_before: 1000,
      rating_after: nextRating({
        rating: 1000,
        opponent: 1000,
        outcome: 'won',
        played: 0,
      }),
    });
    // Answered within moments here, so each time counts as no more than the server saw.
    expect(result.duel.player_points).toBeGreaterThanOrEqual(
      3 * duelPoints(true, 1000),
    );
    expect(result.duel.player_points).toBeLessThanOrEqual(
      3 * duelPoints(true, 500),
    );
    expect(result.rewards.xp.duel_win_bonus).toBe(15);
    expect(result.rewards.coins.duel_win).toBe(10);
    const paid = await t.db
      .select()
      .from(coinLedger)
      .where(eq(coinLedger.userId, meena.id));
    expect(
      paid.filter((p) => p.reason === 'duel_win').map((p) => p.amount),
    ).toEqual([10]);

    const progress = (await as(meena).get('/v1/me/progress').expect(200)).body;
    expect(progress.duel).toEqual({ rating: 1016, played: 1, won: 1 });

    // Submitting again changes nothing.
    const again = (
      await as(meena).post(`/v1/quiz-sessions/${second.id}/submit`).expect(200)
    ).body;
    expect(again.duel).toEqual(result.duel);
  });

  it('does not race yourself or the same learner again and again', async () => {
    const kiran = await t.signInAs('learner');
    await rename(kiran, 'Kiran');
    await play(kiran, (await start(kiran)).body, [true, false, true]);
    // Only Kiran's own run and older ones exist; Kiran never meets Kiran.
    for (let i = 0; i < 2; i++) {
      const s = (await start(kiran)).body;
      expect(s.duel.opponent.name).not.toBe('Kiran');
      await play(kiran, s, [true, true, true]);
    }
  });

  it('counts the time the app measured, but never more than the server saw', async () => {
    const leela = await t.signInAs('learner');
    const s = (await start(leela)).body;
    await as(leela)
      .post(`/v1/quiz-sessions/${s.id}/answers`, {
        position: 1,
        selected_option_ids: ['a'],
        elapsed_ms: 600_000,
      })
      .expect(200);
    await as(leela)
      .post(`/v1/quiz-sessions/${s.id}/answers`, {
        position: 2,
        selected_option_ids: ['a'],
        elapsed_ms: 0,
      })
      .expect(200);
    const result = (
      await as(leela).post(`/v1/quiz-sessions/${s.id}/submit`).expect(200)
    ).body;
    // Q1 took under a second on the server, Q2 counts as the 0.5 s floor, Q3 timed out.
    expect(result.duel.player_points).toBeGreaterThan(
      2 * duelPoints(true, 1000) - 10,
    );
    expect(result.duel.player_points).toBeLessThanOrEqual(
      2 * duelPoints(true, 500),
    );
  });

  it("removes a deleted learner's name from the duels others raced", async () => {
    const gone = await t.signInAs('learner');
    await rename(gone, 'Zara Q');
    const run = (await start(gone)).body;
    await play(gone, run, [true, true, true]);
    const rival = await t.signInAs('learner');
    await rename(rival, 'Rival');
    // Keep starting until Zara's run is picked (several runs are now near 1000).
    let mine: { id: string; duel: { opponent: { name: string } } } | null =
      null;
    for (let i = 0; i < 8 && mine?.duel.opponent.name !== 'Zara Q.'; i++) {
      mine = (await start(rival)).body;
      await play(rival, mine!, [false, false, false]);
    }
    expect(mine!.duel.opponent.name).toBe('Zara Q.');
    await as(gone)
      .post('/v1/me/delete-account', { password: gone.password })
      .expect(204);
    const [m] = await t.db
      .select()
      .from(duelMatches)
      .where(eq(duelMatches.sessionId, mine!.id));
    expect(m.opponentName).toBe('Former learner');
    expect(m.opponentSessionId).toBeNull();
  });
});
