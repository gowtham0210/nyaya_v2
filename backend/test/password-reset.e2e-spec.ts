import { eq } from 'drizzle-orm';
import { Mailer } from '../src/core/mailer.js';
import { auditLog, passwordResetCodes } from '../src/db/schema.js';
import { startApp, type TestApp } from './helpers.js';

describe('password reset', () => {
  let t: TestApp;
  let mailer: Mailer;
  beforeAll(async () => {
    t = await startApp();
    mailer = t.app.get(Mailer);
  });
  afterAll(() => t.close());

  const request = (email: string) =>
    t.http().post('/v1/auth/password-reset').send({ email });
  const confirm = (
    email: string,
    code: string,
    new_password = 'new-password-1',
  ) =>
    t
      .http()
      .post('/v1/auth/password-reset/confirm')
      .send({ email, code, new_password });
  /** The code in the newest mail to [email]. */
  const codeFor = (email: string) => {
    const mail = mailer.outbox.filter((m) => m.to === email).at(-1);
    return mail?.text.match(/\b(\d{6})\b/)?.[1];
  };
  const sentTo = (email: string) =>
    mailer.outbox.filter((m) => m.to === email).length;

  it('emails a code that sets a new password and ends other sessions', async () => {
    const s = await t.signInAs('learner');
    await request(s.email.toUpperCase()).expect(204);
    const code = codeFor(s.email);
    expect(code).toMatch(/^\d{6}$/);

    const res = await confirm(s.email, code!).expect(200);
    expect(res.body.user).toMatchObject({ id: s.id, email: s.email });
    await t
      .http()
      .get('/v1/me')
      .auth(res.body.access_token, { type: 'bearer' })
      .expect(200);

    await t
      .http()
      .post('/v1/auth/session')
      .send({ email: s.email, password: s.password })
      .expect(401);
    await t
      .http()
      .post('/v1/auth/session')
      .send({ email: s.email, password: 'new-password-1' })
      .expect(200);
    await t
      .http()
      .post('/v1/auth/refresh')
      .send({ refresh_token: s.refresh })
      .expect(401);
    const audit = await t.db
      .select()
      .from(auditLog)
      .where(eq(auditLog.actorId, s.id));
    expect(audit.map((a) => a.action)).toContain('auth.password_reset');
  });

  it('works once', async () => {
    const s = await t.signInAs('learner');
    await request(s.email).expect(204);
    const code = codeFor(s.email)!;
    await confirm(s.email, code).expect(200);
    const again = await confirm(s.email, code).expect(400);
    expect(again.body.code).toBe('invalid_reset_code');
  });

  it('answers the same for unknown emails and staff, and sends nothing', async () => {
    const staff = await t.signInAs('content_editor');
    const before = mailer.outbox.length;
    await request('nobody@test.local').expect(204);
    await request(staff.email).expect(204);
    expect(mailer.outbox.length).toBe(before);
    await confirm('nobody@test.local', '123456').expect(400);
  });

  it('stops a code after five wrong tries', async () => {
    const s = await t.signInAs('learner');
    await request(s.email).expect(204);
    const code = codeFor(s.email)!;
    const wrong = code === '000000' ? '111111' : '000000';
    for (let i = 0; i < 5; i++) await confirm(s.email, wrong).expect(400);
    await confirm(s.email, code).expect(400);
  });

  // The test database runs one statement at a time, so this can't race; the
  // single-statement try counter is what keeps real Postgres safe.
  it('stops a code when many wrong guesses arrive together', async () => {
    const s = await t.signInAs('learner');
    await request(s.email).expect(204);
    const code = codeFor(s.email)!;
    const wrong = code === '000000' ? '111111' : '000000';
    const answers = await Promise.all(
      Array.from({ length: 20 }, () => confirm(s.email, wrong)),
    );
    expect(answers.every((r) => r.status === 400)).toBe(true);
    const rows = await t.db
      .select()
      .from(passwordResetCodes)
      .where(eq(passwordResetCodes.userId, s.id));
    expect(rows).toHaveLength(0);
    await confirm(s.email, code).expect(400);
  });

  it('refuses an expired code', async () => {
    const s = await t.signInAs('learner');
    await request(s.email).expect(204);
    await t.db
      .update(passwordResetCodes)
      .set({ expiresAt: new Date(Date.now() - 1000) })
      .where(eq(passwordResetCodes.userId, s.id));
    await confirm(s.email, codeFor(s.email)!).expect(400);
  });

  it('a new code replaces the old one', async () => {
    const s = await t.signInAs('learner');
    await request(s.email).expect(204);
    const first = codeFor(s.email)!;
    await request(s.email).expect(204);
    const second = codeFor(s.email)!;
    if (first !== second) await confirm(s.email, first).expect(400);
    await confirm(s.email, second).expect(200);
  });

  it('sends at most three mails per address in 15 minutes', async () => {
    const s = await t.signInAs('learner');
    for (let i = 0; i < 4; i++) await request(s.email).expect(204);
    expect(sentTo(s.email)).toBe(3);
  });

  it('checks the code and the new password', async () => {
    const s = await t.signInAs('learner');
    await confirm(s.email, '12345').expect(400);
    await request(s.email).expect(204);
    const res = await confirm(s.email, codeFor(s.email)!, 'short').expect(400);
    expect(res.body.code).not.toBe('invalid_reset_code');
  });
});

describe('password reset without mail in production', () => {
  let t: TestApp;
  beforeAll(async () => (t = await startApp({ isProduction: true })));
  afterAll(() => t.close());

  it('says it is unavailable', async () => {
    const res = await t
      .http()
      .post('/v1/auth/password-reset')
      .send({ email: 'asha@test.local' })
      .expect(503);
    expect(res.body.code).toBe('password_reset_unavailable');
  });
});
