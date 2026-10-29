import type { QuizMode } from '../db/schema.js';

/**
 * Learning rewards, worked out on the server from answers it checked and
 * times it measured. Mirrors the app's GameRules / XpCalculator (keep both in
 * step; the tests here copy the app's cases).
 */
export const RULES = {
  xpPerCorrect: 10,
  maxSpeedBonus: 5,
  comboStart: 3,
  comboBonusStep: 2,
  maxComboBonus: 6,
  difficultyMultiplier: { 1: 1, 2: 1.25, 3: 1.5, 4: 2 } as Record<
    number,
    number
  >,
  xpCompletionBonus: 10,
  xpPerfectBonus: 10,
  dailyDocketMultiplier: 1.25,
  replayMultiplier: 0.5,
  oneStarAccuracy: 0.5,
  twoStarAccuracy: 0.8,
  /** Seconds for a full speed bonus to run out, per mode. */
  speedReferenceSeconds: {
    case_path: 30,
    daily_docket: 30,
    duel: 15,
    exam: 60,
    mistake_review: 30,
  } as Record<QuizMode, number>,
  streakMilestones: [3, 7, 14, 30, 50, 100, 365],
  freezeMilestones: [7, 30, 100],
  maxStreakFreezes: 2,
} as const;

/** Coins and energy (the app's GameRules economy). */
export const ECONOMY = {
  startingCoins: 60,
  coinsPerNewStar: 5,
  coinsPerChest: 30,
  coinsForDailyDocket: 10,
  coinsForDailyGoal: 15,
  /** Streak days reached → bonus coins. */
  streakMilestoneCoins: {
    3: 15,
    7: 30,
    14: 50,
    30: 100,
    50: 150,
    100: 300,
    365: 1000,
  } as Record<number, number>,
  streakFreezeCost: 100,
  energyRefillCost: 30,
  freeDailyEnergy: 5,
  /** Energy a quiz costs to start; the docket is always free. */
  /** Mistake practice is free, so learners fix weak spots. */
  energyCost: {
    case_path: 1,
    daily_docket: 0,
    duel: 1,
    exam: 2,
    mistake_review: 0,
  } as Record<QuizMode, number>,
  threeStarEnergyBonus: 1,
  defaultDailyGoal: 3,
} as const;

/** Streak multiplier: 0–2 days ×1.0, 3–6 ×1.1, 7–29 ×1.2, 30+ ×1.3. */
export function streakMultiplier(streak: number): number {
  if (streak >= 30) return 1.3;
  if (streak >= 7) return 1.2;
  if (streak >= 3) return 1.1;
  return 1;
}

/** qXP = (10 + speed bonus + combo bonus) × difficulty. */
export function questionXp(opts: {
  difficulty: number;
  elapsedMs: number;
  referenceSeconds: number;
  comboBefore: number;
}): number {
  const t = opts.elapsedMs / 1000;
  const speed = Math.round(
    RULES.maxSpeedBonus * Math.max(0, 1 - t / opts.referenceSeconds),
  );
  const combo =
    opts.comboBefore + 1 >= RULES.comboStart
      ? Math.min(
          RULES.maxComboBonus,
          (opts.comboBefore + 2 - RULES.comboStart) * RULES.comboBonusStep,
        )
      : 0;
  const d =
    RULES.difficultyMultiplier[Math.min(4, Math.max(1, opts.difficulty))];
  return (RULES.xpPerCorrect + speed + combo) * d;
}

export interface AnsweredQuestion {
  correct: boolean;
  difficulty: number;
  /** Time the learner took, as measured by the server. */
  elapsedMs: number;
}

export interface XpBreakdown {
  question_xp: number;
  completion_bonus: number;
  perfect_bonus: number;
  mode_multiplier: number;
  streak_multiplier: number;
  total: number;
}

/**
 * XP for a finished session. Never negative: exam minus marks change the
 * score, not XP. Duels earn XP for correct answers only (the opponent is
 * simulated on the phone, so the server can't confirm a win).
 */
export function sessionXp(opts: {
  mode: QuizMode;
  questions: AnsweredQuestion[];
  /** Streak before this session counted. */
  streak: number;
  isReplayOfMastered: boolean;
}): XpBreakdown {
  let sum = 0;
  let combo = 0;
  for (const q of opts.questions) {
    if (q.correct) {
      sum += questionXp({
        difficulty: q.difficulty,
        elapsedMs: q.elapsedMs,
        referenceSeconds: RULES.speedReferenceSeconds[opts.mode],
        comboBefore: combo,
      });
      combo++;
    } else {
      combo = 0;
    }
  }
  const total = opts.questions.length;
  const completion = total > 0 ? RULES.xpCompletionBonus : 0;
  const perfect =
    total > 0 && opts.questions.every((q) => q.correct)
      ? RULES.xpPerfectBonus
      : 0;
  const modeMul =
    opts.mode === 'daily_docket'
      ? RULES.dailyDocketMultiplier
      : opts.isReplayOfMastered
        ? RULES.replayMultiplier
        : 1;
  const streakMul = streakMultiplier(opts.streak);
  return {
    question_xp: Math.round(sum),
    completion_bonus: completion,
    perfect_bonus: perfect,
    mode_multiplier: modeMul,
    streak_multiplier: streakMul,
    total: Math.round((sum + completion + perfect) * modeMul * streakMul),
  };
}

/** Case Path stars from the share correct: 50 % → 1, 80 % → 2, 100 % → 3. */
export function stars(correct: number, total: number): number {
  if (total === 0) return 0;
  const accuracy = correct / total;
  if (accuracy >= 1) return 3;
  if (accuracy >= RULES.twoStarAccuracy) return 2;
  if (accuracy >= RULES.oneStarAccuracy) return 1;
  return 0;
}
