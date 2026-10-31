import { Inject, Injectable } from '@nestjs/common';
import { and, arrayContains, asc, eq, isNotNull, or, sql } from 'drizzle-orm';
import { DB, type Db } from '../core/db.js';
import { quizSessions, users } from '../db/schema.js';
import { publicName } from './league.js';
import type { AllTimeDto } from './learn.dto.js';

/** How many places the all-time board lists before the learner's own row. */
export const ALL_TIME_TOP = 50;

/**
 * The all-time board: every active learner with XP, by total XP from
 * finished quizzes. No practice players. Ties go to the older account, the
 * same order for everyone who looks.
 */
@Injectable()
export class LeaderboardService {
  constructor(@Inject(DB) private readonly db: Db) {}

  async allTime(userId: string): Promise<AllTimeDto> {
    const xp = sql`sum(${quizSessions.xpAwarded})`;
    const ranked = this.db.$with('ranked').as(
      this.db
        .select({
          userId: users.id,
          name: users.displayName,
          xp: sql<string>`${xp}`.as('xp'),
          rank: sql<string>`row_number() over (order by ${xp} desc, ${users.createdAt}, ${users.id})`.as(
            'rank',
          ),
          total: sql<string>`count(*) over ()`.as('total'),
        })
        .from(users)
        .innerJoin(quizSessions, eq(quizSessions.userId, users.id))
        .where(
          and(
            eq(users.isActive, true),
            arrayContains(users.roles, ['learner']),
            isNotNull(quizSessions.submittedAt),
          ),
        )
        .groupBy(users.id)
        .having(sql`${xp} > 0`),
    );
    const rows = await this.db
      .with(ranked)
      .select()
      .from(ranked)
      .where(
        or(sql`${ranked.rank} <= ${ALL_TIME_TOP}`, eq(ranked.userId, userId)),
      )
      .orderBy(asc(ranked.rank));
    const all = rows.map((r) => ({
      rank: Number(r.rank),
      name: publicName(r.name),
      xp: Number(r.xp),
      me: r.userId === userId,
    }));
    return {
      total: rows.length ? Number(rows[0].total) : 0,
      top: all.filter((r) => r.rank <= ALL_TIME_TOP),
      me: all.find((r) => r.me) ?? null,
    };
  }
}
