import { and, eq } from 'drizzle-orm';
import { newId } from '../src/core/ids.js';
import {
  leagueCohorts,
  leagueMemberships,
  questions,
  questionVersions,
  quizSessions,
  users,
} from '../src/db/schema.js';
import { indiaToday, isoWeek } from '../src/learn/scoring.js';
import { startApp, type TestApp } from './helpers.js';

type Session = Awaited<ReturnType<TestApp['signInAs']>>;

describe('weekly leagues', () => {
  let t: TestApp;
  const thisWeek = isoWeek(indiaToday(new Date()));
  const lastWeek = isoWeek(indiaToday(new Date(Date.now() - 7 * 86_400_000)));

  const as = (s: Session) => ({
    get: (url: string) => t.http().get(url).auth(s.token, { type: 'bearer' }),
    post: (url: string, body: object = {}) =>
      t.http().post(url).auth(s.token, { type: 'bearer' }).send(body),
  });
  const league = async (s: Session) =>
    (await as(s).get('/v1/me/league').expect(200)).body;
  const play = async (s: Session) => {
    const started = (
      await as(s)
        .post('/v1/quiz-sessions', {
          mode: 'duel',
          topic_id: t.topicId,
          question_count: 1,
        })
        .expect(201)
    ).body;
    await as(s)
      .post(`/v1/quiz-sessions/${started.id}/answers`, {
        position: 1,
        selected_option_ids: ['a'],
      })
      .expect(200);
    return (
      await as(s).post(`/v1/quiz-sessions/${started.id}/submit`).expect(200)
    ).body;
  };
  const named = async (name: string) => {
    const s = await t.signInAs('learner');
    await t.db
      .update(users)
      .set({ displayName: name })
      .where(eq(users.id, s.id));
    return s;
  };
  /** Puts a learner in a finished group last week with this much XP. */
  const lastWeekAt = async (s: Session, tier: number, xp: number) => {
    const cohortId = newId();
    await t.db
      .insert(leagueCohorts)
      .values({ id: cohortId, weekId: lastWeek, tier });
    await t.db.insert(leagueMemberships).values({
      userId: s.id,
      weekId: lastWeek,
      cohortId,
      joinedAt: new Date(Date.now() - 7 * 86_400_000),
    });
    const sessionId = newId();
    const when = new Date(Date.now() - 7 * 86_400_000);
    await t.db.insert(quizSessions).values({
      id: sessionId,
      userId: s.id,
      mode: 'duel',
      language: 'en',
      scoringVersion: 'standard-v1',
      questionCount: 1,
      startedAt: when,
      submittedAt: when,
      correctCount: 1,
      answeredCount: 1,
      xpAwarded: xp,
    });
    return cohortId;
  };

  beforeAll(async () => {
    t = await startApp();
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
      stem: 'Q',
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
  });
  afterAll(() => t.close());

  it('joins with the first quiz of the week, in a group topped up to 30', async () => {
    const s = await named('Asha Krishnan');
    expect(await league(s)).toMatchObject({
      week_id: thisWeek,
      tier: 1,
      joined: false,
      standings: [],
      last_result: null,
      promote: 15,
      demote: 0,
    });
    const result = await play(s);
    const l = await league(s);
    expect(l.joined).toBe(true);
    expect(l.standings).toHaveLength(30);
    const me = l.standings.find((r: { me: boolean }) => r.me);
    expect(me).toMatchObject({
      name: 'Asha K.',
      xp: result.rewards.xp.total,
      practice: false,
    });
    expect(
      l.standings.filter((r: { practice: boolean }) => r.practice),
    ).toHaveLength(29);
    // Ranked by XP, 1…30.
    const xps = l.standings.map((r: { xp: number }) => r.xp);
    expect(xps).toEqual([...xps].sort((a, b) => b - a));
    expect(l.standings.map((r: { rank: number }) => r.rank)).toEqual(
      Array.from({ length: 30 }, (_, i) => i + 1),
    );
    // A second quiz doesn't move the learner to another group.
    await play(s);
    const groups = await t.db
      .select()
      .from(leagueMemberships)
      .where(eq(leagueMemberships.userId, s.id));
    expect(groups).toHaveLength(1);
  });

  it('puts learners at the same tier together, and shows no emails or full names', async () => {
    const [a, b] = [await named('Ravi Kumar Shah'), await named('Meena Iyer')];
    await play(a);
    await play(b);
    const view = await league(b);
    const real = view.standings.filter(
      (r: { practice: boolean }) => !r.practice,
    );
    expect(real.map((r: { name: string }) => r.name)).toEqual(
      expect.arrayContaining(['Ravi S.', 'Meena I.']),
    );
    const raw = JSON.stringify(view);
    expect(raw).not.toContain('@');
    expect(raw).not.toContain('Kumar');
  });

  it('ranks tied learners the same way for everyone, earliest to join first', async () => {
    const [first, second] = [
      await named('Early Bird'),
      await named('Late Owl'),
    ];
    await play(first);
    await play(second);
    // Same XP this week for both.
    for (const s of [first, second])
      await t.db
        .update(quizSessions)
        .set({ xpAwarded: 5000 })
        .where(eq(quizSessions.userId, s.id));
    const order = async (viewer: Session) =>
      (await league(viewer)).standings
        .filter((r: { practice: boolean }) => !r.practice)
        .slice(0, 2)
        .map((r: { name: string; rank: number }) => `${r.rank} ${r.name}`);
    expect(await order(first)).toEqual(['1 Early B.', '2 Late O.']);
    expect(await order(second)).toEqual(['1 Early B.', '2 Late O.']);
  });

  it('opens a new group when one is full', async () => {
    const cohortId = newId();
    await t.db
      .insert(leagueCohorts)
      .values({ id: cohortId, weekId: thisWeek, tier: 2 });
    // Fill a tier-2 group with 30 members.
    for (let i = 0; i < 30; i++) {
      const id = newId();
      await t.db.insert(users).values({
        id,
        email: `filler-${id}@test.local`,
        displayName: 'Filler',
        passwordHash: 'x',
        roles: ['learner'],
      });
      await t.db.insert(leagueMemberships).values({
        userId: id,
        weekId: thisWeek,
        cohortId,
        joinedAt: new Date(),
      });
    }
    const s = await named('Late Joiner');
    await lastWeekAt(s, 1, 1_000_000); // rank 1 last week → tier 2 now
    await play(s);
    const [mine] = await t.db
      .select({
        cohortId: leagueMemberships.cohortId,
        tier: leagueCohorts.tier,
      })
      .from(leagueMemberships)
      .innerJoin(
        leagueCohorts,
        eq(leagueCohorts.id, leagueMemberships.cohortId),
      )
      .where(
        and(
          eq(leagueMemberships.userId, s.id),
          eq(leagueMemberships.weekId, thisWeek),
        ),
      );
    expect(mine.tier).toBe(2);
    expect(mine.cohortId).not.toBe(cohortId);
  });

  it('closes last week: promotion and a top-3 bonus paid once', async () => {
    const s = await named('Top Player');
    await lastWeekAt(s, 1, 1_000_000);
    const coins = async () =>
      (await as(s).get('/v1/me/progress').expect(200)).body.coins;
    const l = await league(s);
    expect(l).toMatchObject({
      tier: 2,
      joined: false,
      last_result: {
        week_id: lastWeek,
        rank: 1,
        from_tier: 1,
        to_tier: 2,
        bonus_coins: 50,
      },
    });
    expect(await coins()).toBe(110); // 60 welcome + 50
    await league(s);
    expect(await coins()).toBe(110);
  });

  it('demotes the bottom 5 above the entry tiers, but never in them', async () => {
    const low = await named('Quiet Week');
    await lastWeekAt(low, 3, 0);
    expect((await league(low)).last_result).toMatchObject({
      rank: 30,
      from_tier: 3,
      to_tier: 2,
      bonus_coins: 0,
    });
    const entry = await named('New Learner');
    await lastWeekAt(entry, 1, 0);
    expect((await league(entry)).last_result).toMatchObject({
      rank: 30,
      to_tier: 1,
    });
  });

  it('needs sign-in', async () => {
    await t.http().get('/v1/me/league').expect(401);
  });
});
