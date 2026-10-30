import { startApp, type TestApp } from './helpers.js';

describe('app settings for the app', () => {
  let t: TestApp;
  afterEach(() => t.close());

  it('says no build is blocked until a minimum version is set', async () => {
    t = await startApp();
    const res = await t.http().get('/v1/app-config').expect(200);
    expect(res.body).toEqual({ min_app_version: null, update_url: null });
  });

  it('gives the minimum version and update page, with no sign-in needed', async () => {
    t = await startApp({
      minAppVersion: '0.2.0',
      appUpdateUrl: 'https://apps.apple.com/app/id1',
    });
    const res = await t.http().get('/v1/app-config').expect(200);
    expect(res.body).toEqual({
      min_app_version: '0.2.0',
      update_url: 'https://apps.apple.com/app/id1',
    });
  });
});
