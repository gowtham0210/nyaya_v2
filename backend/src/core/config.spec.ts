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
});
