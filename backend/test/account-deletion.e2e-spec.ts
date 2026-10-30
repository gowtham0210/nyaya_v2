import { eq, or } from 'drizzle-orm';
import { newId } from '../src/core/ids.js';
import {
  auditLog,
  coinLedger,
  contentReports,
  energyLedger,
  learnerSettings,
  questionBookmarks,
  questions,
  questionVersions,
  quizSessions,
  refreshTokens,
  users,
} from '../src/db/schema.js';
import { startApp, type TestApp } from './helpers.js';

const PASSWORD = 'a learner password';

describe('deleting a learner account', () => {
  let t: TestApp;
  let questionId: string;
  let versionId: string;

  const register = async (email: string) =>
    (
      await t
        .http()
        .post('/v1/auth/register')
        .send({ email, password: PASSWORD, display_name: 'Asha' })
        .expect(201)
    ).body as {
      access_token: string;
      refresh_token: string;
      user: { id: string };
    };
  const as = (token: string) => ({
    get: (url: string) => t.http().get(url).auth(token, { type: 'bearer' }),
    post: (url: string, body: object = {}) =>
      t.http().post(url).auth(token, { type: 'bearer' }).send(body),
  });
  const rowsOf = async (userId: string) => ({
    sessions: await t.db
      .select()
      .from(quizSessions)
      .where(eq(quizSessions.userId, userId)),
    coins: await t.db
      .select()
      .from(coinLedger)
      .where(eq(coinLedger.userId, userId)),
    energy: await t.db
      .select()
      .from(energyLedger)
      .where(eq(energyLedger.userId, userId)),
    settings: await t.db
      .select()
      .from(learnerSettings)
      .where(eq(learnerSettings.userId, userId)),
    bookmarks: await t.db
      .select()
      .from(questionBookmarks)
      .where(eq(questionBookmarks.userId, userId)),
    tokens: await t.db
      .select()
      .from(refreshTokens)
      .where(eq(refreshTokens.userId, userId)),
    audit: await t.db
      .select()
      .from(auditLog)
      .where(or(eq(auditLog.actorId, userId), eq(auditLog.entityId, userId))),
  });

  beforeAll(async () => {
    t = await startApp();
    questionId = newId();
    versionId = newId();
    await t.db.insert(questions).values({ id: questionId });
    await t.db.insert(questionVersions).values({
      id: versionId,
      questionId,
      versionNo: 1,
      status: 'published',
      topicId: t.topicId,
      stem: 'Which Article abolishes untouchability?',
      options: [
        { id: 'a', text: 'Article 17' },
        { id: 'b', text: 'Article 21' },
      ],
      correctOptionIds: ['a'],
      explanation: 'Article 17.',
      validFrom: '2000-01-01',
    });
    await t.db
      .update(questions)
      .set({ liveVersionId: versionId })
      .where(eq(questions.id, questionId));
  });
  afterAll(() => t.close());

  it('removes the learner and their personal data, and frees the email', async () => {
    const asha = await register('asha@test.local');
    const other = await register('ravi@test.local');
    const id = asha.user.id;
    const me = as(asha.access_token);

    // Something of everything: a quiz, a saved question, a report, settings.
    const quiz = (
      await me
        .post('/v1/quiz-sessions', {
          mode: 'duel',
          topic_id: t.topicId,
          question_count: 1,
        })
        .expect(201)
    ).body;
    await me
      .post(`/v1/quiz-sessions/${quiz.id}/answers`, {
        position: 1,
        selected_option_ids: ['a'],
      })
      .expect(200);
    await me.post(`/v1/quiz-sessions/${quiz.id}/submit`).expect(200);
    await me.post('/v1/me/bookmarks', { question_id: questionId }).expect(201);
    await me
      .post('/v1/content-reports', {
        question_version_id: versionId,
        reason: 'typo',
        comment: 'A small typo',
      })
      .expect(201);
    await t
      .http()
      .put('/v1/me/settings')
      .auth(asha.access_token, { type: 'bearer' })
      .send({
        name: 'Asha',
        persona: 'citizen',
        language: 'en',
        daily_goal: 3,
        onboarded: true,
      });

    const before = await rowsOf(id);
    expect(before.sessions).toHaveLength(1);
    expect(before.coins.length).toBeGreaterThan(0);
    expect(before.bookmarks).toHaveLength(1);
    expect(before.tokens.length).toBeGreaterThan(0);
    expect(before.audit.length).toBeGreaterThan(0);

    await me.post('/v1/me/delete-account', { password: PASSWORD }).expect(204);

    const after = await rowsOf(id);
    expect(after).toMatchObject({
      sessions: [],
      coins: [],
      energy: [],
      settings: [],
      bookmarks: [],
      tokens: [],
    });
    // Only a bare "this happened" entry is left, with nobody behind it.
    expect(after.audit).toMatchObject([
      { action: 'account.deleted', actorId: null, data: null },
    ]);
    expect(await t.db.select().from(users).where(eq(users.id, id))).toEqual([]);

    // The report stays for the editors with its reason, without the learner or their comment.
    const reports = await t.db.select().from(contentReports);
    expect(reports).toMatchObject([
      {
        userId: null,
        questionVersionId: versionId,
        reason: 'typo',
        comment: null,
      },
    ]);

    const editor = await t.signInAs('content_editor');
    const open = await t
      .http()
      .get('/v1/admin/content-reports')
      .auth(editor.token, { type: 'bearer' })
      .expect(200);
    expect(open.body.items).toHaveLength(1);

    // The old sign-in stops working at once; the email can be used again.
    await me.get('/v1/me').expect(401);
    await t
      .http()
      .post('/v1/auth/refresh')
      .send({ refresh_token: asha.refresh_token })
      .expect(401);
    await t
      .http()
      .post('/v1/auth/session')
      .send({ email: 'asha@test.local', password: PASSWORD })
      .expect(401);
    const again = await register('asha@test.local');
    expect(again.user.id).not.toBe(id);

    // Somebody else's account is untouched.
    await as(other.access_token).get('/v1/me').expect(200);
  });

  it('needs the right password and changes nothing without it', async () => {
    const s = await register('meena@test.local');
    const me = as(s.access_token);
    const wrong = await me
      .post('/v1/me/delete-account', { password: 'not the password' })
      .expect(403);
    expect(wrong.body.code).toBe('wrong_password');
    await me.post('/v1/me/delete-account', {}).expect(400);
    await me.get('/v1/me').expect(200);
    expect((await rowsOf(s.user.id)).tokens.length).toBeGreaterThan(0);
    await t
      .http()
      .post('/v1/me/delete-account')
      .send({ password: PASSWORD })
      .expect(401);
  });

  it('leaves staff accounts to the admins', async () => {
    const editor = await t.signInAs('content_editor');
    const res = await t
      .http()
      .post('/v1/me/delete-account')
      .auth(editor.token, { type: 'bearer' })
      .send({ password: editor.password })
      .expect(409);
    expect(res.body.code).toBe('staff_account');
    await t
      .http()
      .get('/v1/me')
      .auth(editor.token, { type: 'bearer' })
      .expect(200);
  });
});
