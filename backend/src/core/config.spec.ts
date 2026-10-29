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
});
