import { RULES } from './rewards.js';

/** Whole days from one YYYY-MM-DD date to another. */
export function daysBetween(from: string, to: string): number {
  return Math.round((Date.parse(to) - Date.parse(from)) / 86_400_000);
}

const addDays = (day: string, n: number) =>
  new Date(Date.parse(day) + n * 86_400_000).toISOString().slice(0, 10);

export interface StreakState {
  /** Current streak on `today`; 0 once it has lapsed. */
  streak: number;
  longest: number;
  /** Free freezes left, earned at 7/30/100 days (at most 2). */
  freezes: number;
  /** Missed days a freeze covered (including ones about to be covered today). */
  frozenDays: string[];
  lastActiveDay: string | null;
}

/**
 * Replays the days a learner finished a quiz (India dates). A missed day is
 * covered by a freeze when enough are left, otherwise the streak restarts.
 * Freezes are earned at 7/30/100 days or bought (`boughtDays`, one date per
 * purchase); one bought before a day is played can cover the gap before it.
 * At most 2 are held. Same rules as the app's DailyPolicy, but derived from
 * history instead of stored, so nothing can drift.
 */
export function streakOn(
  activeDays: readonly string[],
  today: string,
  boughtDays: readonly string[] = [],
): StreakState {
  const days = [...new Set(activeDays)].filter((d) => d <= today).sort();
  const bought = boughtDays.filter((d) => d <= today).sort();
  let streak = 0;
  let longest = 0;
  let freezes = 0;
  const frozenDays: string[] = [];
  let last: string | null = null;

  let nextBought = 0;
  /** Adds the freezes bought before `day` (or on it, when inclusive). */
  const buyUntil = (day: string, inclusive: boolean) => {
    while (
      nextBought < bought.length &&
      (inclusive ? bought[nextBought] <= day : bought[nextBought] < day)
    ) {
      freezes = Math.min(RULES.maxStreakFreezes, freezes + 1);
      nextBought++;
    }
  };

  const coverGap = (from: string, missed: number): boolean => {
    if (missed <= 0) return true;
    if (freezes < missed) return false;
    freezes -= missed;
    for (let i = 1; i <= missed; i++) frozenDays.push(addDays(from, i));
    return true;
  };

  for (const day of days) {
    buyUntil(day, false);
    if (last === null || !coverGap(last, daysBetween(last, day) - 1)) {
      streak = 1;
    } else {
      streak++;
    }
    if ((RULES.freezeMilestones as readonly number[]).includes(streak))
      freezes = Math.min(RULES.maxStreakFreezes, freezes + 1);
    longest = Math.max(longest, streak);
    last = day;
  }
  buyUntil(today, true);
  // Today not played yet: the streak survives if freezes cover the gap so far.
  if (
    last !== null &&
    last < today &&
    !coverGap(last, daysBetween(last, today) - 1)
  )
    streak = 0;
  return { streak, longest, freezes, frozenDays, lastActiveDay: last };
}

/** The milestone (3, 7, 14 … days) a streak has just reached, if any. */
export function milestoneFor(streak: number): number | null {
  return (RULES.streakMilestones as readonly number[]).includes(streak)
    ? streak
    : null;
}
