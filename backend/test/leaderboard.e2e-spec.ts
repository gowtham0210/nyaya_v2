import { eq } from 'drizzle-orm';
import { newId } from '../src/core/ids.js';
import { quizSessions, users } from '../src/db/schema.js';
import { startApp, type TestApp } from './helpers.js';

type Session = Awaited<ReturnType<TestApp['signInAs']>>;

describe('all-time leaderboard', () => {
  let t: TestApp;

  const board = async (s: Session) =>
    (
      await t
        .http()
        .get('/v1/me/leaderboard/all-time')
        .auth(s.token, { type: 'bearer' })
        .expect(200)
    ).body;
  /** A finished quiz worth this much XP. */
  const earn = (userId: string, xp: number) =>
    t.db.insert(quizSessions).values({
      id: newId(),
      userId,
      mode: 'duel',
      language: 'en',
      scoringVersion: 'standard-v1',
      questionCount: 1,
      startedAt: new Date(),
      submittedAt: new Date(),
      correctCount: 1,
      answeredCount: 1,
      xpAwarded: xp,
    });
  const named = async (
    name: string,
    ...roles: Parameters<TestApp['signInAs']>
  ) => {
    const s = await t.signInAs(
      ...(roles.length ? roles : ['learner' as const]),
    );
    await t.db
      .update(users)
      .set({ displayName: name })
      .where(eq(users.id, s.id));
    return s;
  };
  /** A learner made straight in the database, older than everyone else. */
  const learner = async (name: string, xp: number) => {
    const id = newId();
    await t.db.insert(users).values({
      id,
      email: `${id}@example.test`,
      displayName: name,
      passwordHash: 'x',
      roles: ['learner'],
      createdAt: new Date(2020, 0, 1),
    });
    await earn(id, xp);
    return id;
  };

  beforeAll(async () => {
    t = await startApp();
  });
  afterAll(() => t.close());

  it('ranks learners by total XP; learners without XP and staff are left out', async () => {
    const asha = await named('Asha Krishnan');
    const ravi = await named('Ravi');
    const new_ = await named('Nila Das');
    const editor = await named('Staff Person', 'editor');
    await earn(asha.id, 40);
    await earn(asha.id, 30);
    await earn(ravi.id, 90);
    await earn(editor.id, 500);
    // An unfinished quiz counts for nothing.
    await t.db.insert(quizSessions).values({
      id: newId(),
      userId: new_.id,
      mode: 'duel',
      language: 'en',
      scoringVersion: 'standard-v1',
      questionCount: 1,
      startedAt: new Date(),
      xpAwarded: null,
    });

    const b = await board(asha);
    expect(b.total).toBe(2);
    expect(b.top).toEqual([
      { rank: 1, name: 'Ravi', xp: 90, me: false },
      { rank: 2, name: 'Asha K.', xp: 70, me: true },
    ]);
    expect(b.me).toEqual({ rank: 2, name: 'Asha K.', xp: 70, me: true });
    expect((await board(new_)).me).toBeNull();
  });

  it('breaks ties by the older account, the same for everyone', async () => {
    const first = await named('Tie First');
    const second = await named('Tie Second');
    await earn(second.id, 80);
    await earn(first.id, 80);
    for (const s of [first, second]) {
      const names = (await board(s)).top.map((r: { name: string }) => r.name);
      expect(names.indexOf('Tie F.')).toBeLessThan(names.indexOf('Tie S.'));
    }
  });

  it('lists the top 50 and still shows a learner further down', async () => {
    for (let i = 0; i < 50; i++) await learner(`Top ${i}`, 1000 + i);
    const low = await named('Low Score');
    await earn(low.id, 1);
    const b = await board(low);
    expect(b.top).toHaveLength(50);
    expect(b.top[0]).toMatchObject({ rank: 1, xp: 1049 });
    expect(b.top.some((r: { me: boolean }) => r.me)).toBe(false);
    expect(b.me).toMatchObject({ rank: b.total, xp: 1, me: true });
  });

  it('drops deactivated learners', async () => {
    const s = await named('Gone Soon');
    await earn(s.id, 5000);
    expect((await board(s)).me.rank).toBe(1);
    await t.db.update(users).set({ isActive: false }).where(eq(users.id, s.id));
    const other = await named('Still Here');
    const names = (await board(other)).top.map((r: { name: string }) => r.name);
    expect(names).not.toContain('Gone S.');
  });
});
