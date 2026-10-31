import { describe, expect, it } from 'vitest';
import { loadConfig } from './config.js';

const production = {
  NODE_ENV: 'production',
  JWT_SECRET: 'secret',
  DATABASE_URL: 'postgres://db/nyaya',
};

describe('loadConfig', () => {
  it('is staging only when DEPLOY_ENV says so', () => {
    expect(loadConfig(production).isStaging).toBe(false);
    const staging = loadConfig({ ...production, DEPLOY_ENV: 'staging' });
    expect(staging.isStaging).toBe(true);
    expect(staging.isProduction).toBe(true);
  });

  it('trusts no proxy unless TRUST_PROXY_HOPS is set', () => {
    expect(loadConfig({}).trustProxyHops).toBe(0);
    expect(loadConfig({ TRUST_PROXY_HOPS: '1' }).trustProxyHops).toBe(1);
  });

  it('turns on Azure chat only with an endpoint and a key', () => {
    expect(loadConfig({}).azureOpenAi).toBeUndefined();
    expect(
      loadConfig({ AZURE_OPENAI_ENDPOINT: 'https://x.openai.azure.com/' })
        .azureOpenAi,
    ).toBeUndefined();
    expect(
      loadConfig({
        AZURE_OPENAI_ENDPOINT: 'https://x.openai.azure.com/',
        AZURE_OPENAI_API_KEY: 'k',
      }).azureOpenAi,
    ).toEqual({
      endpoint: 'https://x.openai.azure.com',
      apiKey: 'k',
      chatDeployment: 'gpt-5.4-mini',
    });
  });

  it('stops on a daily chat limit that is not a whole number above 0', () => {
    expect(loadConfig({}).chatDailyLimit).toBe(50);
    expect(loadConfig({ CHAT_DAILY_LIMIT: '5' }).chatDailyLimit).toBe(5);
    for (const bad of ['abc', '0', '-3', '2.5'])
      expect(() => loadConfig({ CHAT_DAILY_LIMIT: bad })).toThrow(
        'CHAT_DAILY_LIMIT',
      );
  });

  it('has no minimum app version unless one is set, and rejects a bad one', () => {
    expect(loadConfig({}).minAppVersion).toBeUndefined();
    expect(loadConfig({ MIN_APP_VERSION: '' }).minAppVersion).toBeUndefined();
    expect(loadConfig({ MIN_APP_VERSION: '0.2.0' }).minAppVersion).toBe(
      '0.2.0',
    );
    expect(() => loadConfig({ MIN_APP_VERSION: '0.2' })).toThrow(/1\.2\.3/);
    expect(() => loadConfig({ MIN_APP_VERSION: 'v1.0.0' })).toThrow();
  });

  it('takes only an https link for the update page', () => {
    expect(loadConfig({}).appUpdateUrl).toBeUndefined();
    expect(
      loadConfig({ APP_UPDATE_URL: 'https://apps.apple.com/app/id1' })
        .appUpdateUrl,
    ).toBe('https://apps.apple.com/app/id1');
    expect(() => loadConfig({ APP_UPDATE_URL: 'http://x.test' })).toThrow();
    expect(() => loadConfig({ APP_UPDATE_URL: 'not a link' })).toThrow();
  });

  it('takes a portal secret only when it is long enough', () => {
    expect(loadConfig({}).portalProxySecret).toBeUndefined();
    expect(() => loadConfig({ PORTAL_PROXY_SECRET: 'short' })).toThrow(
      /at least 32 characters/,
    );
    const secret = 'a'.repeat(32);
    expect(loadConfig({ PORTAL_PROXY_SECRET: secret }).portalProxySecret).toBe(
      secret,
    );
  });

  it('allows 5 password attempts per account unless set', () => {
    expect(loadConfig({}).passwordAttemptsPerAccount).toBe(5);
    expect(
      loadConfig({ PASSWORD_ATTEMPTS_PER_ACCOUNT: '8' })
        .passwordAttemptsPerAccount,
    ).toBe(8);
    expect(() => loadConfig({ PASSWORD_ATTEMPTS_PER_ACCOUNT: '0' })).toThrow();
  });

  it('reports crashes only with an https SENTRY_DSN', () => {
    expect(loadConfig({}).sentryDsn).toBeUndefined();
    expect(loadConfig({ SENTRY_DSN: '' }).sentryDsn).toBeUndefined();
    const dsn = 'https://key@o1.ingest.us.sentry.io/42';
    expect(loadConfig({ SENTRY_DSN: dsn }).sentryDsn).toBe(dsn);
    expect(() => loadConfig({ SENTRY_DSN: 'not a key' })).toThrow(/SENTRY_DSN/);
  });
});
