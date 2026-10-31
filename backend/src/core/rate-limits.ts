import { createHash } from 'node:crypto';
import { Inject, Injectable } from '@nestjs/common';
import type { ThrottlerStorage } from '@nestjs/throttler';
import { eq, lt, sql } from 'drizzle-orm';
import { rateLimits } from '../db/schema.js';
import { DB, type Db } from './db.js';

export interface Hit {
  /** Attempts in the current window, this one included. */
  hits: number;
  /** Milliseconds until the window ends and the count starts again. */
  msLeft: number;
}

/**
 * Attempt counters in Postgres, so every API copy shares them and a restart
 * does not reset them. Times come from the database clock.
 */
@Injectable()
export class RateLimitStore {
  constructor(@Inject(DB) private readonly db: Db) {}

  /** Counts one attempt for [key]; a window of [windowMs] starts with the first. */
  async hit(key: string, windowMs: number): Promise<Hit> {
    const resetAt = sql`now() + ${Math.round(windowMs)} * interval '1 millisecond'`;
    const expired = sql`${rateLimits.resetAt} <= now()`;
    const [row] = await this.db
      .insert(rateLimits)
      .values({ key: hashKey(key), hits: 1, resetAt })
      .onConflictDoUpdate({
        target: rateLimits.key,
        set: {
          hits: sql`case when ${expired} then 1 else ${rateLimits.hits} + 1 end`,
          resetAt: sql`case when ${expired} then excluded.reset_at else ${rateLimits.resetAt} end`,
        },
      })
      .returning({
        hits: rateLimits.hits,
        msLeft: sql<string>`ceil(extract(epoch from (${rateLimits.resetAt} - now())) * 1000)`,
      });
    // About one call in a hundred clears counters that ended over an hour ago.
    if (Math.random() < 0.01)
      await this.db
        .delete(rateLimits)
        .where(lt(rateLimits.resetAt, sql`now() - interval '1 hour'`));
    return { hits: row.hits, msLeft: Math.max(0, Number(row.msLeft)) };
  }

  /** Forgets the attempts for [key] (after a right password). */
  async clear(key: string) {
    await this.db.delete(rateLimits).where(eq(rateLimits.key, hashKey(key)));
  }
}

type ThrottlerStorageRecord = Awaited<
  ReturnType<ThrottlerStorage['increment']>
>;

const hashKey = (key: string) =>
  createHash('sha256').update(key).digest('base64url');

/** Lets @nestjs/throttler keep its per-address counts in [RateLimitStore]. */
export class SharedThrottlerStorage implements ThrottlerStorage {
  constructor(private readonly store: RateLimitStore) {}

  async increment(
    key: string,
    ttl: number,
    limit: number,
    _blockDuration: number,
    throttlerName: string,
  ): Promise<ThrottlerStorageRecord> {
    const { hits, msLeft } = await this.store.hit(
      `throttle:${throttlerName}:${key}`,
      ttl,
    );
    const seconds = Math.ceil(msLeft / 1000);
    const isBlocked = hits > limit;
    return {
      totalHits: hits,
      timeToExpire: seconds,
      isBlocked,
      timeToBlockExpire: isBlocked ? seconds : 0,
    };
  }
}
