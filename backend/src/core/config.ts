import { randomBytes } from 'node:crypto';

export const APP_CONFIG = Symbol('APP_CONFIG');

export interface AppConfig {
  isProduction: boolean;
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
  };
}
