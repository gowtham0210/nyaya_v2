import { Inject, Injectable } from '@nestjs/common';
import {
  and,
  asc,
  desc,
  eq,
  gte,
  inArray,
  isNotNull,
  lt,
  sql,
} from 'drizzle-orm';
import { DB, type Db, type Tx } from '../core/db.js';
import { newId } from '../core/ids.js';
import {
  leagueCohorts,
  leagueMemberships,
  quizSessions,
  users,
} from '../db/schema.js';
import {
  COHORT_SIZE,
  TOP3_BONUS_COINS,
  nextTier,
  practicePlayers,
  publicName,
  tierOf,
  weekEnd,
  weekProgress,
  weekStart,
} from './league.js';
import type { LeagueDto, StandingDto } from './learn.dto.js';
import { indiaToday, isoWeek } from './scoring.js';
import { addCoins } from './wallet.js';

interface Membership {
  weekId: string;
  cohortId: string;
  tier: number;
}

/**
 * Weekly leagues. A learner joins with the first finished quiz of a week;
 * standings, results and tier changes are worked out from the group's quiz
 * XP. A week is closed lazily, the first time the learner shows up after it
 * (paying the top-3 bonus once), so no scheduled job is needed.
 */
@Injectable()
export class LeagueService {
  constructor(@Inject(DB) private readonly db: Db) {}

  /** Called on submit: places the learner in this week's group if not yet in one. */
  async join(tx: Tx, userId: string, now: Date): Promise<void> {
    const week = isoWeek(indiaToday(now));
    if (await this.membership(tx, userId, week)) return;
    const previous = await this.settlePrevious(tx, userId, week);
    const tier = previous ? previous.toTier : 1;
    // One placement at a time per week and tier, so groups don't overfill.
    await tx.execute(
      sql`select pg_advisory_xact_lock(hashtext(${`league:${week}:${tier}`}))`,
    );
    const [open] = await tx
      .select({ id: leagueCohorts.id })
      .from(leagueCohorts)
      .leftJoin(
        leagueMemberships,
        eq(leagueMemberships.cohortId, leagueCohorts.id),
      )
      .where(and(eq(leagueCohorts.weekId, week), eq(leagueCohorts.tier, tier)))
      .groupBy(leagueCohorts.id)
      .having(sql`count(${leagueMemberships.userId}) < ${COHORT_SIZE}`)
      .orderBy(asc(leagueCohorts.createdAt))
      .limit(1);
    let cohortId = open?.id;
    if (!cohortId) {
      cohortId = newId();
      await tx
        .insert(leagueCohorts)
        .values({ id: cohortId, weekId: week, tier });
    }
    await tx
      .insert(leagueMemberships)
      .values({ userId, weekId: week, cohortId, joinedAt: now })
      .onConflictDoNothing();
  }

  /** This week's league for the learner, and how their last week ended. */
  async view(userId: string, now = new Date()): Promise<LeagueDto> {
    return this.db.transaction(async (tx) => {
      const week = isoWeek(indiaToday(now));
      const previous = await this.settlePrevious(tx, userId, week);
      const mine = await this.membership(tx, userId, week);
      const tier = mine?.tier ?? previous?.toTier ?? 1;
      const t = tierOf(tier);
      return {
        week_id: week,
        ends_at: weekEnd(week).toISOString(),
        tier,
        joined: !!mine,
        cohort_size: COHORT_SIZE,
        promote: t.promote,
        demote: t.demote,
        standings: mine ? await this.standings(tx, mine, userId, now) : [],
        last_result: previous
          ? {
              week_id: previous.weekId,
              rank: previous.rank,
              from_tier: previous.fromTier,
              to_tier: previous.toTier,
              bonus_coins: previous.bonus,
            }
          : null,
      };
    });
  }

  // ---------------------------------------------------------------- helpers

  private async membership(
    tx: Tx,
    userId: string,
    weekId: string,
  ): Promise<Membership | null> {
    const [row] = await tx
      .select({
        weekId: leagueMemberships.weekId,
        cohortId: leagueMemberships.cohortId,
        tier: leagueCohorts.tier,
      })
      .from(leagueMemberships)
      .innerJoin(
        leagueCohorts,
        eq(leagueCohorts.id, leagueMemberships.cohortId),
      )
      .where(
        and(
          eq(leagueMemberships.userId, userId),
          eq(leagueMemberships.weekId, weekId),
        ),
      );
    return row ?? null;
  }

  /**
   * The learner's latest finished week before `week`: final rank, tier move
   * and top-3 bonus (paid here, once). Weeks without play don't move the tier.
   */
  private async settlePrevious(tx: Tx, userId: string, week: string) {
    const [last] = await tx
      .select({
        weekId: leagueMemberships.weekId,
        cohortId: leagueMemberships.cohortId,
        tier: leagueCohorts.tier,
      })
      .from(leagueMemberships)
      .innerJoin(
        leagueCohorts,
        eq(leagueCohorts.id, leagueMemberships.cohortId),
      )
      .where(
        and(
          eq(leagueMemberships.userId, userId),
          lt(leagueMemberships.weekId, week),
        ),
      )
      .orderBy(desc(leagueMemberships.weekId))
      .limit(1);
    if (!last) return null;
    const final = await this.standings(tx, last, userId, weekEnd(last.weekId));
    const rank = final.find((s) => s.me)!.rank;
    const bonus = rank <= 3 ? TOP3_BONUS_COINS : 0;
    await addCoins(tx, {
      userId,
      amount: bonus,
      reason: 'league_top3',
      cohortId: last.cohortId,
    });
    return {
      weekId: last.weekId,
      rank,
      fromTier: last.tier,
      toTier: nextTier(last.tier, rank),
      bonus,
    };
  }

  /** The group's ranking: real members by week XP, topped up with practice players. */
  private async standings(
    tx: Tx,
    m: Membership,
    userId: string,
    now: Date,
  ): Promise<StandingDto[]> {
    const members = await tx
      .select({
        userId: users.id,
        name: users.displayName,
        joinedAt: leagueMemberships.joinedAt,
      })
      .from(leagueMemberships)
      .innerJoin(users, eq(users.id, leagueMemberships.userId))
      .where(eq(leagueMemberships.cohortId, m.cohortId));
    const xp = await this.weekXp(
      tx,
      members.map((u) => u.userId),
      m.weekId,
    );
    const rows = [
      ...members.map((u) => ({
        name: publicName(u.name),
        xp: xp.get(u.userId) ?? 0,
        me: u.userId === userId,
        practice: false,
        joinedAt: u.joinedAt.getTime(),
        userId: u.userId,
      })),
      ...practicePlayers(
        m.cohortId,
        m.tier,
        COHORT_SIZE - members.length,
        weekProgress(m.weekId, now),
      ).map((p) => ({
        ...p,
        me: false,
        practice: true,
        joinedAt: 0,
        userId: '',
      })),
    ];
    // Ties: real learners before practice players (so a tie with one goes to
    // you); between real learners, whoever joined the group first, the same
    // order for everyone who looks.
    rows.sort(
      (a, b) =>
        b.xp - a.xp ||
        Number(a.practice) - Number(b.practice) ||
        a.joinedAt - b.joinedAt ||
        a.userId.localeCompare(b.userId) ||
        a.name.localeCompare(b.name),
    );
    return rows.map((r, i) => ({
      rank: i + 1,
      name: r.name,
      xp: r.xp,
      me: r.me,
      practice: r.practice,
    }));
  }

  /** XP each learner earned in a week (sessions submitted in its India dates). */
  private async weekXp(tx: Tx, userIds: string[], weekId: string) {
    const out = new Map<string, number>();
    if (!userIds.length) return out;
    const rows = await tx
      .select({
        userId: quizSessions.userId,
        xp: sql<number>`coalesce(sum(${quizSessions.xpAwarded}), 0)`,
      })
      .from(quizSessions)
      .where(
        and(
          inArray(quizSessions.userId, userIds),
          isNotNull(quizSessions.submittedAt),
          gte(quizSessions.submittedAt, weekStart(weekId)),
          lt(quizSessions.submittedAt, weekEnd(weekId)),
        ),
      )
      .groupBy(quizSessions.userId);
    for (const r of rows) out.set(r.userId, Number(r.xp));
    return out;
  }
}
