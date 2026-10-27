import { eq } from 'drizzle-orm';
import { createHash } from 'node:crypto';
import { auditLog, refreshTokens, users } from '../src/db/schema.js';

const sha256 = (v: string) => createHash('sha256').update(v).digest('hex');
import { startApp, type TestApp } from './helpers.js';

describe('auth', () => {
  let t: TestApp;
  beforeAll(async () => (t = await startApp()));
  afterAll(() => t.close());

  it('serves the taxonomy without signing in', async () => {
    const res = await t.http().get('/v1/taxonomy').expect(200);
    expect(res.body.subjects).toHaveLength(1);
    expect(res.body.subjects[0].topics[0]).toMatchObject({
      id: t.topicId,
      slug: 'constitution-basics',
    });
  });

  it('rejects protected routes without a token, in the standard error envelope', async () => {
    const res = await t
      .http()
      .get('/v1/me')
      .set('X-Request-Id', 'test-request-0001')
      .expect(401);
    expect(res.body).toEqual({
      code: 'unauthenticated',
      message: 'Sign in to continue',
      details: null,
      request_id: 'test-request-0001',
    });
    expect(res.headers['x-request-id']).toBe('test-request-0001');
  });

  it('signs in, returns the current user and records it', async () => {
    const s = await t.signInAs('content_editor');
    const me = await t
      .http()
      .get('/v1/me')
      .auth(s.token, { type: 'bearer' })
      .expect(200);
    expect(me.body).toMatchObject({
      id: s.id,
      email: s.email,
      roles: ['content_editor'],
    });
    const audit = await t.db
      .select()
      .from(auditLog)
      .where(eq(auditLog.actorId, s.id));
    expect(audit.map((a) => a.action)).toContain('auth.signed_in');
  });

  it('gives the same answer for a wrong password and an unknown email', async () => {
    const s = await t.signInAs('content_editor');
    const wrong = await t
      .http()
      .post('/v1/auth/session')
      .send({ email: s.email, password: 'not-it' })
      .expect(401);
    const unknown = await t
      .http()
      .post('/v1/auth/session')
      .send({ email: 'nobody@test.local', password: 'x' })
      .expect(401);
    expect(wrong.body.code).toBe('invalid_credentials');
    expect(unknown.body.message).toBe(wrong.body.message);
  });

  it('rotates refresh tokens and revokes every session when an old one is reused', async () => {
    const s = await t.signInAs('learner');
    const refresh = (token: string) =>
      t.http().post('/v1/auth/refresh').send({ refresh_token: token });
    const first = await refresh(s.refresh).expect(200);
    expect(first.body.refresh_token).not.toBe(s.refresh);

    // Moments later (parallel page loads) a reuse is only rejected.
    expect((await refresh(s.refresh).expect(401)).body.code).toBe(
      'invalid_refresh_token',
    );
    const second = await refresh(first.body.refresh_token).expect(200);

    // Well after rotation it is treated as theft: every session ends.
    await t.db
      .update(refreshTokens)
      .set({ revokedAt: new Date(Date.now() - 60_000) })
      .where(eq(refreshTokens.userId, s.id));
    await t.db
      .update(refreshTokens)
      .set({ revokedAt: null })
      .where(eq(refreshTokens.tokenHash, sha256(second.body.refresh_token)));
    await refresh(s.refresh).expect(401);
    await refresh(second.body.refresh_token).expect(401);
  });

  it('signs out by revoking the refresh token', async () => {
    const s = await t.signInAs('learner');
    await t
      .http()
      .post('/v1/auth/sign-out')
      .send({ refresh_token: s.refresh })
      .expect(204);
    await t
      .http()
      .post('/v1/auth/refresh')
      .send({ refresh_token: s.refresh })
      .expect(401);
  });

  it('locks out deactivated users immediately', async () => {
    const s = await t.signInAs('content_editor');
    await t.db.update(users).set({ isActive: false }).where(eq(users.id, s.id));
    await t.http().get('/v1/me').auth(s.token, { type: 'bearer' }).expect(401);
  });

  it('rejects a tampered token', async () => {
    const s = await t.signInAs('admin');
    const forged =
      s.token.slice(0, -3) + (s.token.endsWith('aaa') ? 'bbb' : 'aaa');
    const res = await t
      .http()
      .get('/v1/me')
      .auth(forged, { type: 'bearer' })
      .expect(401);
    expect(res.body.code).toBe('token_expired');
  });

  it('reports invalid bodies field by field', async () => {
    const res = await t
      .http()
      .post('/v1/auth/session')
      .send({ email: 'not-an-email', extra: 1 })
      .expect(400);
    expect(res.body.code).toBe('validation_failed');
    expect(res.body.details.map((d: { field: string }) => d.field)).toEqual(
      expect.arrayContaining(['email', 'password', 'extra']),
    );
  });
});

describe('sign-in rate limit', () => {
  let t: TestApp;
  beforeAll(async () => (t = await startApp({ authRateLimitPerMinute: 2 })));
  afterAll(() => t.close());

  it('returns 429 after too many attempts', async () => {
    for (let i = 0; i < 2; i++)
      await t
        .http()
        .post('/v1/auth/session')
        .send({ email: 'a@test.local', password: 'x' })
        .expect(401);
    const res = await t
      .http()
      .post('/v1/auth/session')
      .send({ email: 'a@test.local', password: 'x' })
      .expect(429);
    expect(res.body.code).toBe('rate_limited');
  });
});
