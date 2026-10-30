import { eq } from 'drizzle-orm';
import { auditLog, staffSetupTokens } from '../src/db/schema.js';
import { startApp, type TestApp } from './helpers.js';

type Session = Awaited<ReturnType<TestApp['signInAs']>>;

const GOOD_PASSWORD = 'correct horse battery';

describe('staff accounts', () => {
  let t: TestApp;
  let admin: Session, editor: Session;

  const as = (s: Session) => ({
    get: (url: string) => t.http().get(url).auth(s.token, { type: 'bearer' }),
    post: (url: string, body: object = {}) =>
      t.http().post(url).auth(s.token, { type: 'bearer' }).send(body),
    patch: (url: string, body: object) =>
      t.http().patch(url).auth(s.token, { type: 'bearer' }).send(body),
  });
  const signIn = (email: string, password: string) =>
    t.http().post('/v1/auth/session').send({ email, password });
  const setPassword = (token: string, password: string) =>
    t.http().post('/v1/auth/setup-password').send({ token, password });

  beforeAll(async () => {
    t = await startApp();
    [admin, editor] = await Promise.all([
      t.signInAs('admin'),
      t.signInAs('content_editor'),
    ]);
  });
  afterAll(() => t.close());

  it('invites with a one-time link; the person chooses their own password', async () => {
    await as(editor).get('/v1/admin/staff').expect(403);
    await as(editor)
      .post('/v1/admin/staff', {
        email: 'x@test.local',
        display_name: 'X',
        roles: ['admin'],
      })
      .expect(403);

    const res = await as(admin)
      .post('/v1/admin/staff', {
        email: 'Priya@Test.local',
        display_name: 'Priya Raman',
        roles: ['legal_reviewer'],
      })
      .expect(201);
    expect(res.body.staff).toMatchObject({
      email: 'priya@test.local',
      roles: ['legal_reviewer'],
      is_active: true,
      setup: { expired: false },
    });
    const token: string = res.body.setup_token;
    expect(token.length).toBeGreaterThan(30);
    // Only a hash of the token is stored.
    const stored = await t.db.select().from(staffSetupTokens);
    expect(stored.some((r) => r.tokenHash === token)).toBe(false);

    // No password works until the link is used.
    await signIn('priya@test.local', GOOD_PASSWORD).expect(401);
    const short = await setPassword(token, 'too short').expect(400);
    expect(short.body.code).toBe('validation_failed');
    await setPassword(token, GOOD_PASSWORD).expect(204);
    const session = await signIn('priya@test.local', GOOD_PASSWORD).expect(200);
    expect(session.body.user.roles).toEqual(['legal_reviewer']);

    // The link works once.
    const again = await setPassword(token, 'another long password').expect(400);
    expect(again.body.code).toBe('invalid_link');

    const list = await as(admin).get('/v1/admin/staff').expect(200);
    expect(
      list.body.items.find(
        (m: { email: string }) => m.email === 'priya@test.local',
      ),
    ).toMatchObject({ setup: null, is_active: true });
    expect(
      list.body.items.some((m: { roles: string[] }) =>
        m.roles.includes('learner' as never),
      ),
    ).toBe(false);

    const dup = await as(admin)
      .post('/v1/admin/staff', {
        email: 'priya@test.local',
        display_name: 'Again',
        roles: ['publisher'],
      })
      .expect(409);
    expect(dup.body.code).toBe('email_taken');
  });

  it('changes roles and disables at once, signing the person out', async () => {
    const invited = await as(admin)
      .post('/v1/admin/staff', {
        email: 'ravi@test.local',
        display_name: 'Ravi',
        roles: ['content_editor'],
      })
      .expect(201);
    const id = invited.body.staff.id;
    await setPassword(invited.body.setup_token, GOOD_PASSWORD).expect(204);
    const session = (await signIn('ravi@test.local', GOOD_PASSWORD).expect(200))
      .body;
    const ravi = { token: session.access_token } as Session;
    await as(ravi).get('/v1/editor/questions').expect(200);

    const changed = await as(admin)
      .patch(`/v1/admin/staff/${id}`, {
        roles: ['analyst', 'publisher'],
        display_name: 'Ravi K',
      })
      .expect(200);
    expect(changed.body).toMatchObject({
      roles: ['analyst', 'publisher'],
      display_name: 'Ravi K',
    });
    // Roles are read on every request, so the change applies straight away.
    await as(ravi)
      .post('/v1/editor/questions', { topic_id: t.topicId })
      .expect(403);

    await as(admin)
      .patch(`/v1/admin/staff/${id}`, { is_active: false })
      .expect(200);
    await as(ravi).get('/v1/editor/questions').expect(401);
    await t
      .http()
      .post('/v1/auth/refresh')
      .send({ refresh_token: session.refresh_token })
      .expect(401);
    await signIn('ravi@test.local', GOOD_PASSWORD).expect(401);
    await as(admin).post(`/v1/admin/staff/${id}/setup-link`).expect(409);

    await as(admin)
      .patch(`/v1/admin/staff/${id}`, { is_active: true })
      .expect(200);
    await signIn('ravi@test.local', GOOD_PASSWORD).expect(200);

    const actions = (
      await t.db.select().from(auditLog).where(eq(auditLog.entityId, id))
    ).map((a) => a.action);
    expect(actions).toEqual(
      expect.arrayContaining([
        'staff.invited',
        'staff.password_set',
        'staff.updated',
      ]),
    );
  });

  it('a new setup link replaces the old one and the old password', async () => {
    const invited = await as(admin)
      .post('/v1/admin/staff', {
        email: 'meena@test.local',
        display_name: 'Meena',
        roles: ['publisher'],
      })
      .expect(201);
    const id = invited.body.staff.id;
    await setPassword(invited.body.setup_token, GOOD_PASSWORD).expect(204);
    const old = (await signIn('meena@test.local', GOOD_PASSWORD).expect(200))
      .body;

    const first = (
      await as(admin).post(`/v1/admin/staff/${id}/setup-link`).expect(200)
    ).body;
    const second = (
      await as(admin).post(`/v1/admin/staff/${id}/setup-link`).expect(200)
    ).body;
    expect(second.staff.setup).toMatchObject({ expired: false });
    await signIn('meena@test.local', GOOD_PASSWORD).expect(401);
    await t
      .http()
      .post('/v1/auth/refresh')
      .send({ refresh_token: old.refresh_token })
      .expect(401);
    await setPassword(first.setup_token, 'a brand new password').expect(400);
    await setPassword(second.setup_token, 'a brand new password').expect(204);
    await signIn('meena@test.local', 'a brand new password').expect(200);
  });

  it('never leaves the portal without an active admin', async () => {
    const own = await as(admin)
      .patch(`/v1/admin/staff/${admin.id}`, { roles: ['content_editor'] })
      .expect(409);
    expect(own.body.code).toBe('own_account');
    await as(admin)
      .patch(`/v1/admin/staff/${admin.id}`, { is_active: false })
      .expect(409);
    const reset = await as(admin)
      .post(`/v1/admin/staff/${admin.id}/setup-link`)
      .expect(409);
    expect(reset.body.code).toBe('own_account');
    // Renaming yourself is fine.
    await as(admin)
      .patch(`/v1/admin/staff/${admin.id}`, { display_name: 'Chief' })
      .expect(200);

    const second = await t.signInAs('admin');
    await as(second)
      .patch(`/v1/admin/staff/${admin.id}`, { roles: ['publisher'] })
      .expect(200);
    const last = await as(admin).get('/v1/admin/staff').expect(403);
    expect(last.body.code).toBe('forbidden');
    // `second` is now the only active admin and cannot be removed by anyone.
    const alone = await as(second)
      .patch(`/v1/admin/staff/${second.id}`, { roles: ['publisher'] })
      .expect(409);
    expect(alone.body.code).toBe('own_account');
  });

  it('validates input and only touches staff accounts', async () => {
    for (const body of [
      { email: 'bad', display_name: 'X', roles: ['admin'] },
      { email: 'ok@test.local', display_name: 'X', roles: [] },
      { email: 'ok@test.local', display_name: 'X', roles: ['learner'] },
      { email: 'ok@test.local', display_name: '', roles: ['admin'] },
    ])
      await as(await t.signInAs('admin'))
        .post('/v1/admin/staff', body)
        .expect(400);
    const learner = await t.signInAs('learner');
    const admin3 = await t.signInAs('admin');
    await as(admin3)
      .patch(`/v1/admin/staff/${learner.id}`, { roles: ['admin'] })
      .expect(404);
    await setPassword('x'.repeat(40), GOOD_PASSWORD).expect(400);
  });
});
