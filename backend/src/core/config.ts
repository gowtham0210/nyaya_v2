import { randomBytes } from 'node:crypto';

export const APP_CONFIG = Symbol('APP_CONFIG');

export interface AppConfig {
  isProduction: boolean;
  /** DEPLOY_ENV=staging: production settings, but the seed may add dev data. */
  isStaging: boolean;
  /** Postgres connection string. When unset, an embedded PGlite database is used. */
  databaseUrl?: string;
  /** PGlite data directory; unset means in-memory (tests). */
  pgliteDir?: string;
  jwtSecret: string;
  accessTokenTtlSec: number;
  refreshTokenTtlDays: number;
  /** Sign-in/refresh attempts allowed per client per minute. */
  authRateLimitPerMinute: number;
  corsOrigins: string[];
  /** Reverse proxies in front of the API (Express `trust proxy` hops), so rate limits see client IPs. */
  trustProxyHops: number;
  /** Azure OpenAI chat for Ask AI; chat is unavailable when endpoint or key is missing. */
  azureOpenAi?: { endpoint: string; apiKey: string; chatDeployment: string };
  /** AI answers a premium learner may get per India date (also the abuse cap). */
  chatDailyLimit: number;
  /** AI answers a free learner may get per India date. */
  chatFreeDailyLimit: number;
}

export function loadConfig(env: NodeJS.ProcessEnv = process.env): AppConfig {
  const isProduction = env.NODE_ENV === 'production';
  let jwtSecret = env.JWT_SECRET ?? '';
  if (!jwtSecret) {
    if (isProduction) throw new Error('JWT_SECRET must be set in production');
    // Dev only: tokens stop working when the process restarts.
    jwtSecret = randomBytes(32).toString('base64url');
  }
  if (isProduction && !env.DATABASE_URL) {
    throw new Error('DATABASE_URL must be set in production');
  }
  return {
    isProduction,
    isStaging: env.DEPLOY_ENV === 'staging',
    databaseUrl: env.DATABASE_URL || undefined,
    pgliteDir: env.PGLITE_DIR || undefined,
    jwtSecret,
    accessTokenTtlSec: Number(env.ACCESS_TOKEN_TTL_SEC ?? 15 * 60),
    refreshTokenTtlDays: Number(env.REFRESH_TOKEN_TTL_DAYS ?? 30),
    authRateLimitPerMinute: Number(env.AUTH_RATE_LIMIT_PER_MINUTE ?? 10),
    corsOrigins: (env.CORS_ORIGINS ?? 'http://localhost:3001')
      .split(',')
      .map((s) => s.trim())
      .filter(Boolean),
    trustProxyHops: Number(env.TRUST_PROXY_HOPS ?? 0),
    azureOpenAi:
      env.AZURE_OPENAI_ENDPOINT && env.AZURE_OPENAI_API_KEY
        ? {
            endpoint: env.AZURE_OPENAI_ENDPOINT.replace(/\/+$/, ''),
            apiKey: env.AZURE_OPENAI_API_KEY,
            chatDeployment: env.AZURE_OPENAI_CHAT_DEPLOYMENT || 'gpt-5.4-mini',
          }
        : undefined,
    chatDailyLimit: positiveInt(env.CHAT_DAILY_LIMIT, 'CHAT_DAILY_LIMIT', 50),
    chatFreeDailyLimit: positiveInt(
      env.CHAT_FREE_DAILY_LIMIT,
      'CHAT_FREE_DAILY_LIMIT',
      5,
    ),
  };
}

/** An unset value takes the default; anything but a whole number above 0 stops startup. */
function positiveInt(
  value: string | undefined,
  name: string,
  fallback: number,
) {
  if (value === undefined || value === '') return fallback;
  const n = Number(value);
  if (!Number.isInteger(n) || n < 1)
    throw new Error(`${name} must be a whole number above 0, got "${value}"`);
  return n;
}
