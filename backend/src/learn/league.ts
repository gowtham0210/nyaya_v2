/**
 * Weekly leagues, themed on the Indian court hierarchy. Mirrors the app's
 * league.dart (keep both in step): groups of 30, Monday–Sunday in India
 * time, one tier move per week, no demotion in the two entry tiers.
 */
export const COHORT_SIZE = 30;
export const TOP3_BONUS_COINS = 50;

export interface Tier {
  level: number;
  /** Ranks 1…promote move up. */
  promote: number;
  /** The last `demote` ranks move down. */
  demote: number;
}

export const TIERS: Tier[] = [
  { level: 1, promote: 15, demote: 0 }, // Nyaya Panchayat
  { level: 2, promote: 12, demote: 0 }, // Gram Nyayalaya
  { level: 3, promote: 10, demote: 5 }, // Munsiff Court
  { level: 4, promote: 10, demote: 5 }, // Magistrate Court
  { level: 5, promote: 7, demote: 5 }, // District Court
  { level: 6, promote: 7, demote: 5 }, // Sessions Court
  { level: 7, promote: 5, demote: 5 }, // High Court
  { level: 8, promote: 0, demote: 5 }, // Supreme Court
];

export const tierOf = (level: number): Tier =>
  TIERS[Math.min(TIERS.length, Math.max(1, level)) - 1];

/** The tier after a week closes at `rank` (1-based). */
export function nextTier(current: number, rank: number): number {
  const t = tierOf(current);
  if (t.promote > 0 && rank <= t.promote)
    return Math.min(current + 1, TIERS.length);
  if (t.demote > 0 && rank > COHORT_SIZE - t.demote)
    return Math.max(current - 1, 1);
  return current;
}

/** Monday 00:00 India time of an ISO week id (`2026-W44`), as a UTC instant. */
export function weekStart(weekId: string): Date {
  const [year, week] = weekId.split('-W').map(Number);
  const jan4 = Date.UTC(year, 0, 4);
  const monday1 = jan4 - ((new Date(jan4).getUTCDay() + 6) % 7) * 86_400_000;
  const monday = monday1 + (week - 1) * 7 * 86_400_000;
  return new Date(monday - 5.5 * 3_600_000); // 00:00 IST = 18:30 UTC the day before
}

export const weekEnd = (weekId: string) =>
  new Date(weekStart(weekId).getTime() + 7 * 86_400_000);

/** Share of the week gone, 0–1. */
export const weekProgress = (weekId: string, now: Date) =>
  Math.min(
    1,
    Math.max(
      0,
      (now.getTime() - weekStart(weekId).getTime()) / (7 * 86_400_000),
    ),
  );

/** What other learners see: first name and last initial ("Asha K."). */
export function publicName(displayName: string): string {
  const parts = displayName.trim().split(/\s+/).filter(Boolean);
  if (!parts.length) return 'Learner';
  const first = parts[0];
  return parts.length > 1
    ? `${first} ${parts.at(-1)![0].toUpperCase()}.`
    : first;
}

// ---------------------------------------------------------------- practice players

const FIRST = [
  'Aarav',
  'Ananya',
  'Vihaan',
  'Diya',
  'Arjun',
  'Meera',
  'Karthik',
  'Lakshmi',
  'Rohan',
  'Priya',
  'Sai',
  'Kavya',
  'Aditya',
  'Nandini',
  'Harish',
  'Fathima',
  'Vikram',
  'Sneha',
  'Rahul',
  'Divya',
  'Manoj',
  'Aishwarya',
  'Gurpreet',
  'Anjali',
  'Siddharth',
  'Revathi',
  'Imran',
  'Pooja',
  'Naveen',
  'Swathi',
  'Joseph',
  'Tanvi',
  'Deepak',
  'Keerthana',
  'Arun',
  'Shruti',
  'Varun',
  'Bhavana',
  'Suresh',
  'Nikhil',
];
const INITIAL = 'SKRINRMVGPDJ';

/** Small seeded generator, so a group always shows the same practice players. */
function seeded(seed: string) {
  let h = 2166136261;
  for (const c of seed) h = Math.imul(h ^ c.charCodeAt(0), 16777619);
  return () => {
    h = Math.imul(h ^ (h >>> 15), 2246822507);
    h = Math.imul(h ^ (h >>> 13), 3266489909);
    h ^= h >>> 16;
    return (h >>> 0) / 4294967296;
  };
}

export interface PracticePlayer {
  name: string;
  xp: number;
}

/**
 * Simulated players that top a small group up to 30. Worked out from the
 * group id and how far the week has gone, never stored. Higher tiers move
 * faster, and players progress unevenly through the week.
 */
export function practicePlayers(
  cohortId: string,
  tier: number,
  count: number,
  progress: number,
): PracticePlayer[] {
  const rnd = seeded(cohortId);
  const base = 140 + tier * 70;
  const used = new Set<string>();
  const out: PracticePlayer[] = [];
  for (let i = 0; i < COHORT_SIZE - 1 && out.length < count; i++) {
    let name: string;
    do {
      name = `${FIRST[Math.floor(rnd() * FIRST.length)]} ${INITIAL[Math.floor(rnd() * INITIAL.length)]}.`;
    } while (used.has(name));
    used.add(name);
    const pace = base * (0.15 + rnd() * 2.1);
    const curve = Math.pow(progress, 0.6 + rnd() * 0.9);
    out.push({ name, xp: Math.round(pace * curve) });
  }
  return out;
}
