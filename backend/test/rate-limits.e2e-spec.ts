import { rateLimits } from '../src/db/schema.js';
import { RateLimitStore } from '../src/core/rate-limits.js';
import { startApp, type TestApp } from './helpers.js';

const SECRET = 'portal-secret-'.padEnd(40, 'x');

describe('password attempts per account', () => {
  let t: TestApp;
  beforeAll(
    async () =>
      (t = await startApp({
        passwordAttemptsPerAccount: 3,
        trustProxyHops: 1,
      })),
  );
  afterAll(() => t.close());

  const signIn = (email: string, password: string, ip = '203.0.113.1') =>
    t
      .http()
      .post('/v1/auth/session')
      .set('X-Forwarded-For', ip)
      .send({ email, password });

  it('locks the account after too many wrong passwords, from any address', async () => {
    const user = await t.signInAs('learner');
    for (const ip of ['203.0.113.1', '203.0.113.2', '203.0.113.3'])
      await signIn(user.email, 'wrong password', ip).expect(401);
    // Even the right password waits, and a new address does not help.
    const res = await signIn(user.email, user.password, '203.0.113.9').expect(
      429,
    );
    expect(res.body.code).toBe('rate_limited');
    expect(res.body.message).toMatch(/Try again in 15 minutes/);
    // Other accounts are not affected.
    const other = await t.signInAs('learner');
    await signIn(other.email, other.password).expect(200);
  });

  it('starts again after the right password', async () => {
    const user = await t.signInAs('learner');
    for (let i = 0; i < 2; i++) await signIn(user.email, 'wrong').expect(401);
    await signIn(user.email.toUpperCase(), user.password).expect(200);
    for (let i = 0; i < 3; i++) await signIn(user.email, 'wrong').expect(401);
  });

  it('treats unknown emails the same, so they look like real ones', async () => {
    for (let i = 0; i < 3; i++)
      await signIn('nobody@test.local', 'wrong').expect(401);
    await signIn('nobody@test.local', 'wrong').expect(429);
  });

  it('counts wrong passwords when deleting the account', async () => {
    const user = await t.signInAs('learner');
    for (let i = 0; i < 3; i++)
      await t
        .http()
        .post('/v1/me/delete-account')
        .auth(user.token, { type: 'bearer' })
        .send({ password: 'wrong' })
        .expect(403);
    await t
      .http()
      .post('/v1/me/delete-account')
      .auth(user.token, { type: 'bearer' })
      .send({ password: user.password })
      .expect(429);
    await signIn(user.email, user.password).expect(429);
  });

  it('stores hashed keys, never the email', async () => {
    const rows = await t.db.select().from(rateLimits);
    expect(rows.length).toBeGreaterThan(0);
    for (const row of rows) expect(row.key).not.toContain('@');
  });
});

describe('browser address from the content portal', () => {
  const attempt = (t: TestApp, clientIp: string, secret?: string) => {
    const req = t
      .http()
      .post('/v1/auth/session')
      .set('X-Nyaya-Client-Ip', clientIp);
    if (secret) req.set('X-Nyaya-Proxy-Secret', secret);
    return req.send({ email: 'a@test.local', password: 'x' });
  };

  describe('with the shared secret set', () => {
    let t: TestApp;
    beforeAll(
      async () =>
        (t = await startApp({
          authRateLimitPerMinute: 1,
          portalProxySecret: SECRET,
        })),
    );
    afterAll(() => t.close());

    it('limits each browser separately when the secret matches', async () => {
      await attempt(t, '198.51.100.1', SECRET).expect(401);
      await attempt(t, '198.51.100.1', SECRET).expect(429);
      await attempt(t, '198.51.100.2', SECRET).expect(401);
    });

    it('ignores the address without the right secret', async () => {
      // Both fall back to the caller's own address, which shares one count.
      await attempt(t, '198.51.100.3', 'wrong-secret').expect(401);
      await attempt(t, '198.51.100.4').expect(429);
    });

    it('ignores something that is not an address', async () => {
      await attempt(t, 'not-an-ip', SECRET).expect(429);
    });
  });

  it('ignores the address when no secret is set', async () => {
    const t = await startApp({ authRateLimitPerMinute: 1 });
    try {
      await attempt(t, '198.51.100.5', SECRET).expect(401);
      await attempt(t, '198.51.100.6', SECRET).expect(429);
    } finally {
      await t.close();
    }
  });
});

describe('shared attempt counters', () => {
  let t: TestApp;
  beforeAll(async () => (t = await startApp()));
  afterAll(() => t.close());

  it('are shared by every API copy on the same database', async () => {
    const a = new RateLimitStore(t.db);
    const b = new RateLimitStore(t.db);
    expect((await a.hit('shared', 60_000)).hits).toBe(1);
    expect((await b.hit('shared', 60_000)).hits).toBe(2);
    const third = await a.hit('shared', 60_000);
    expect(third.hits).toBe(3);
    expect(third.msLeft).toBeGreaterThan(55_000);
    expect(third.msLeft).toBeLessThanOrEqual(60_000);
  });

  it('start again when the window ends, and when cleared', async () => {
    const store = new RateLimitStore(t.db);
    await store.hit('short', 50);
    await store.hit('short', 50);
    await new Promise((r) => setTimeout(r, 80));
    expect((await store.hit('short', 50)).hits).toBe(1);

    await store.hit('cleared', 60_000);
    await store.clear('cleared');
    expect((await store.hit('cleared', 60_000)).hits).toBe(1);
  });
});
