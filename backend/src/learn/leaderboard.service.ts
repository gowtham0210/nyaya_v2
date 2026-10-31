import { Inject, Injectable } from '@nestjs/common';
import { and, arrayContains, eq, isNotNull, sql } from 'drizzle-orm';
import { DB, type Db } from '../core/db.js';
import { quizSessions, users } from '../db/schema.js';
import { publicName } from './league.js';
import type { AllTimeDto } from './learn.dto.js';

/** How many places the all-time board lists before the learner's own row. */
export const ALL_TIME_TOP = 50;

/** How long one ranking of everyone is shared before it is worked out again. */
export const ALL_TIME_TTL_MS = 60_000;

interface Ranked {
  userId: string;
  name: string;
  xp: number;
  createdAt: number;
}

/** Board order: more XP first; ties go to the older account, then by id. */
const before = (a: Ranked, b: Ranked) =>
  b.xp - a.xp || a.createdAt - b.createdAt || a.userId.localeCompare(b.userId);

/**
 * The all-time board: every active learner with XP, by total XP from
 * finished quizzes. No practice players. Ties go to the older account, the
 * same order for everyone who looks.
 *
 * Summing every quiz of every learner is the costly part, so that ranking is
 * kept in memory for a minute and shared. The viewer's own total is read
 * fresh each time (one learner's quizzes, by index), so their new XP shows
 * straight after a quiz; other learners' totals may be up to a minute old.
 */
@Injectable()
export class LeaderboardService {
  /** Changed by tests. */
  ttlMs = ALL_TIME_TTL_MS;
  private cache: { at: number; rows: Promise<Ranked[]> } | null = null;

  constructor(@Inject(DB) private readonly db: Db) {}

  async allTime(userId: string, now = Date.now()): Promise<AllTimeDto> {
    const [everyone, mine] = await Promise.all([
      this.ranking(now),
      this.learner(userId),
    ]);
    const others = everyone.filter((r) => r.userId !== userId);
    let rows = others;
    let myRank: number | null = null;
    if (mine) {
      // Where the viewer goes among everyone else (the list is in order).
      let lo = 0;
      let hi = others.length;
      while (lo < hi) {
        const mid = (lo + hi) >> 1;
        if (before(others[mid], mine) < 0) lo = mid + 1;
        else hi = mid;
      }
      myRank = lo + 1;
      rows = [...others.slice(0, lo), mine, ...others.slice(lo)];
    }
    const row = (r: Ranked, i: number) => ({
      rank: i + 1,
      name: publicName(r.name),
      xp: r.xp,
      me: r.userId === userId,
    });
    return {
      total: rows.length,
      top: rows.slice(0, ALL_TIME_TOP).map(row),
      me: mine && myRank ? row(mine, myRank - 1) : null,
    };
  }

  /** Everyone on the board, in order; shared for [ttlMs]. */
  private ranking(now: number): Promise<Ranked[]> {
    if (this.cache && now - this.cache.at < this.ttlMs) return this.cache.rows;
    const rows = this.totals();
    this.cache = { at: now, rows };
    // A failed query is not kept: the next request tries again.
    rows.catch(() => {
      if (this.cache?.rows === rows) this.cache = null;
    });
    return rows;
  }

  private async totals(userId?: string): Promise<Ranked[]> {
    const xp = sql`sum(${quizSessions.xpAwarded})`;
    const rows = await this.db
      .select({
        userId: users.id,
        name: users.displayName,
        xp: sql<string>`${xp}`,
        createdAt: users.createdAt,
      })
      .from(users)
      .innerJoin(quizSessions, eq(quizSessions.userId, users.id))
      .where(
        and(
          eq(users.isActive, true),
          arrayContains(users.roles, ['learner']),
          isNotNull(quizSessions.submittedAt),
          userId ? eq(users.id, userId) : undefined,
        ),
      )
      .groupBy(users.id)
      .having(sql`${xp} > 0`);
    return rows
      .map((r) => ({
        userId: r.userId,
        name: r.name,
        xp: Number(r.xp),
        createdAt: r.createdAt.getTime(),
      }))
      .sort(before);
  }

  /** The viewer, read fresh; null when they are not on the board. */
  private async learner(userId: string): Promise<Ranked | null> {
    const [me] = await this.totals(userId);
    return me ?? null;
  }
}
