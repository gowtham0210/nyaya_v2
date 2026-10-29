import { and, eq, sql } from 'drizzle-orm';
import type { Tx } from '../core/db.js';
import { newId } from '../core/ids.js';
import {
  coinLedger,
  energyLedger,
  premiumMemberships,
  type CoinReason,
  type EnergyReason,
} from '../db/schema.js';
import { ECONOMY } from './rewards.js';
import { indiaToday } from './scoring.js';

/** India date of a timestamp column, for "today" in the ledgers. */
const indiaDay = (col: unknown) =>
  sql`(${col} at time zone 'Asia/Kolkata')::date`;

/** Every learner starts with the welcome coins, once. */
export async function ensureWelcome(tx: Tx, userId: string): Promise<void> {
  await tx
    .insert(coinLedger)
    .values({
      id: newId(),
      userId,
      amount: ECONOMY.startingCoins,
      reason: 'welcome',
    })
    .onConflictDoNothing();
}

export async function coinBalance(tx: Tx, userId: string): Promise<number> {
  const [row] = await tx
    .select({ n: sql<number>`coalesce(sum(${coinLedger.amount}), 0)` })
    .from(coinLedger)
    .where(eq(coinLedger.userId, userId));
  return Number(row.n);
}

/** Pays or charges coins; a reward already paid for this session or chest is skipped. */
export async function addCoins(
  tx: Tx,
  entry: {
    userId: string;
    amount: number;
    reason: CoinReason;
    sessionId?: string;
    subjectId?: string;
    cohortId?: string;
  },
): Promise<void> {
  if (entry.amount === 0) return;
  await tx
    .insert(coinLedger)
    .values({ id: newId(), ...entry })
    .onConflictDoNothing();
}

export async function addEnergy(
  tx: Tx,
  entry: {
    userId: string;
    amount: number;
    reason: EnergyReason;
    sessionId?: string;
  },
): Promise<void> {
  if (entry.amount === 0) return;
  await tx
    .insert(energyLedger)
    .values({ id: newId(), ...entry })
    .onConflictDoNothing();
}

/** The free daily energy plus everything used or gained today (India date). */
export async function energyToday(
  tx: Tx,
  userId: string,
  now = new Date(),
): Promise<number> {
  const [row] = await tx
    .select({ n: sql<number>`coalesce(sum(${energyLedger.amount}), 0)` })
    .from(energyLedger)
    .where(
      and(
        eq(energyLedger.userId, userId),
        sql`${indiaDay(energyLedger.createdAt)} = ${indiaToday(now)}::date`,
      ),
    );
  return ECONOMY.freeDailyEnergy + Number(row.n);
}

/** India dates of streak freezes bought, one per purchase. */
export async function freezePurchaseDays(
  tx: Tx,
  userId: string,
): Promise<string[]> {
  const rows = await tx
    .select({ at: coinLedger.createdAt })
    .from(coinLedger)
    .where(
      and(
        eq(coinLedger.userId, userId),
        eq(coinLedger.reason, 'streak_freeze'),
      ),
    );
  return rows.map((r) => indiaToday(r.at));
}

/** Whether a coin reward was already paid on this India date (other than for one session). */
export async function paidOnDay(
  tx: Tx,
  userId: string,
  reason: CoinReason,
  day: string,
  exceptSessionId: string,
): Promise<boolean> {
  const [row] = await tx
    .select({ id: coinLedger.id })
    .from(coinLedger)
    .where(
      and(
        eq(coinLedger.userId, userId),
        eq(coinLedger.reason, reason),
        sql`${indiaDay(coinLedger.createdAt)} = ${day}::date`,
        sql`${coinLedger.sessionId} is distinct from ${exceptSessionId}`,
      ),
    )
    .limit(1);
  return !!row;
}

export async function isPremium(tx: Tx, userId: string): Promise<boolean> {
  const [row] = await tx
    .select({ id: premiumMemberships.userId })
    .from(premiumMemberships)
    .where(eq(premiumMemberships.userId, userId))
    .limit(1);
  return !!row;
}
