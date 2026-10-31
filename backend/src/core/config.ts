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
  /** Sign-in/refresh attempts allowed per client address per minute. */
  authRateLimitPerMinute: number;
  /** Password attempts allowed per account in 15 minutes, from any address. */
  passwordAttemptsPerAccount: number;
  /**
   * Shared with the content portal, which calls the API from its own server:
   * with it the portal may say which browser address a sign-in came from.
   * Unset: the header is ignored and every portal user counts as one address.
   */
  portalProxySecret?: string;
  corsOrigins: string[];
  /** Reverse proxies in front of the API (Express `trust proxy` hops), so rate limits see client IPs. */
  trustProxyHops: number;
  /** Azure OpenAI chat for Ask AI; chat is unavailable when endpoint or key is missing. */
  azureOpenAi?: { endpoint: string; apiKey: string; chatDeployment: string };
  /** AI answers a premium learner may get per India date (also the abuse cap). */
  chatDailyLimit: number;
  /** AI answers a free learner may get per India date. */
  chatFreeDailyLimit: number;
  /**
   * DEMO_PREMIUM=true lets the app turn premium on for testing. Off (the
   * default, and the beta's setting), demo premium counts for nothing.
   */
  demoPremium: boolean;
  /** The oldest app version still allowed (e.g. "0.2.0"); older builds are told to update. Unset: none is blocked. */
  minAppVersion?: string;
  /** Where the update screen sends people: the store page. Must be https. */
  appUpdateUrl?: string;
  /** Sentry project key for crash reports (errors only). Unset: nothing is reported. */
  sentryDsn?: string;
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
    authRateLimitPerMinute: Number(env.AUTH_RATE_LIMIT_PER_MINUTE ?? 20),
    passwordAttemptsPerAccount: positiveInt(
      env.PASSWORD_ATTEMPTS_PER_ACCOUNT,
      'PASSWORD_ATTEMPTS_PER_ACCOUNT',
      5,
    ),
    portalProxySecret: secret(env.PORTAL_PROXY_SECRET, 'PORTAL_PROXY_SECRET'),
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
    demoPremium: env.DEMO_PREMIUM === 'true',
    minAppVersion: appVersion(env.MIN_APP_VERSION),
    appUpdateUrl: httpsUrl(env.APP_UPDATE_URL, 'APP_UPDATE_URL'),
    sentryDsn: httpsUrl(env.SENTRY_DSN, 'SENTRY_DSN'),
  };
}

/** Empty means "no minimum"; anything but three whole numbers like 1.2.3 stops startup. */
function appVersion(value: string | undefined) {
  if (!value) return undefined;
  if (!/^\d+\.\d+\.\d+$/.test(value))
    throw new Error(
      `MIN_APP_VERSION must look like 1.2.3 (three whole numbers), got "${value}"`,
    );
  return value;
}

function httpsUrl(value: string | undefined, name: string) {
  if (!value) return undefined;
  let url: URL | undefined;
  try {
    url = new URL(value);
  } catch {
    // fall through to the error below
  }
  if (url?.protocol !== 'https:')
    throw new Error(`${name} must be a full https link, got "${value}"`);
  return value;
}

/** Empty means unset; anything shorter than 32 characters is too easy to guess and stops startup. */
function secret(value: string | undefined, name: string) {
  if (!value) return undefined;
  if (value.length < 32)
    throw new Error(`${name} must be at least 32 characters long`);
  return value;
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
