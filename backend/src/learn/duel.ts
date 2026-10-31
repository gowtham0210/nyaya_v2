/**
 * Moot Court Duel: you race another learner's recorded run of the same
 * questions (a "ghost"), or a labelled practice player when no run fits.
 * Points, the result and the hidden rating are worked out here, on the
 * server. Mirrors the app's GameRules / XpCalculator.duelPoints / Elo.
 */
export const DUEL = {
  seconds: 15,
  questions: 7,
  startingRating: 1000,
  /** Rating moves faster for a learner's first duels. */
  kProvisional: 32,
  kSettled: 16,
  provisionalDuels: 20,
  /** A recorded run is a fair match within this many rating points. */
  matchRange: 400,
  /** Opponents met in your last few duels are not picked again. */
  recentOpponents: 5,
  /** Fastest answer time counted; anything quicker is taken as this. */
  minAnswerMs: 500,
  winXp: 15,
  winCoins: 10,
} as const;

export type DuelOutcome = 'won' | 'lost' | 'draw';

export interface GhostAnswer {
  correct: boolean;
  elapsed_ms: number;
}

/** Points for one answer: 1000 for an instant right answer, 500 at the buzzer, 0 when wrong. */
export function duelPoints(correct: boolean, elapsedMs: number): number {
  if (!correct) return 0;
  const t = Math.min(Math.max(elapsedMs / 1000, 0), DUEL.seconds);
  return Math.round(1000 * (1 - t / (2 * DUEL.seconds)));
}

export function totalPoints(answers: GhostAnswer[]): number {
  return answers.reduce(
    (sum, a) => sum + duelPoints(a.correct, a.elapsed_ms),
    0,
  );
}

export function outcomeOf(player: number, opponent: number): DuelOutcome {
  return player > opponent ? 'won' : player < opponent ? 'lost' : 'draw';
}

/** Elo: the new rating after a duel against [opponent]. */
export function nextRating(opts: {
  rating: number;
  opponent: number;
  outcome: DuelOutcome;
  /** Duels finished before this one. */
  played: number;
}): number {
  const score = opts.outcome === 'won' ? 1 : opts.outcome === 'draw' ? 0.5 : 0;
  const expected = 1 / (1 + Math.pow(10, (opts.opponent - opts.rating) / 400));
  const k =
    opts.played < DUEL.provisionalDuels ? DUEL.kProvisional : DUEL.kSettled;
  return Math.round(opts.rating + k * (score - expected));
}

/**
 * A practice player's answers: right more often the higher its rating and
 * the easier the question, at a human pace. [rnd] gives 0..1.
 */
export function practiceAnswers(
  rating: number,
  difficulties: number[],
  rnd: () => number,
): GhostAnswer[] {
  const skill = Math.min(Math.max((rating - 600) / 1400, 0), 1);
  return difficulties.map((d) => {
    const p = Math.min(
      Math.max(0.4 + skill * 0.5 - (d - 1) * 0.08, 0.25),
      0.92,
    );
    return {
      correct: rnd() < p,
      elapsed_ms: 2500 + Math.floor(rnd() * 9000),
    };
  });
}
