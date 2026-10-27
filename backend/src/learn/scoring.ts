import { randomInt } from 'node:crypto';

/**
 * Scoring policy recorded on every session, so a result can always be
 * explained by the rules in force when it was taken. Change the rules by
 * adding a new version, never by editing this one.
 *
 * standard-v1: +1 for a correct answer, 0 for wrong or unanswered.
 * A single-select answer is correct when it picks exactly the correct option.
 */
export const SCORING_VERSION = 'standard-v1';

export function isCorrect(
  selected: readonly string[],
  correct: readonly string[],
): boolean {
  if (selected.length !== correct.length) return false;
  const want = new Set(correct);
  return (
    selected.every((id) => want.has(id)) &&
    new Set(selected).size === selected.length
  );
}

export interface ScoredQuestion {
  selectedOptionIds: readonly string[] | null;
  correctOptionIds: readonly string[];
}

export function scoreSession(questions: readonly ScoredQuestion[]) {
  let correct = 0;
  let answered = 0;
  for (const q of questions) {
    if (!q.selectedOptionIds) continue;
    answered++;
    if (isCorrect(q.selectedOptionIds, q.correctOptionIds)) correct++;
  }
  return { score: correct, correctCount: correct, answeredCount: answered };
}

export const MAX_QUESTIONS = 20;
const SECONDS_PER_QUESTION = 120;
const MIN_SESSION_SECONDS = 10 * 60;

/** How long a learner has to answer; submitting is allowed after it. */
export function sessionDeadline(startedAt: Date, questionCount: number): Date {
  const seconds = Math.max(
    MIN_SESSION_SECONDS,
    questionCount * SECONDS_PER_QUESTION,
  );
  return new Date(startedAt.getTime() + seconds * 1000);
}

const INDIA_DATE = new Intl.DateTimeFormat('en-CA', {
  timeZone: 'Asia/Kolkata',
});

/** Today's date in India (YYYY-MM-DD), which decides whether content is in force. */
export const indiaToday = (now: Date): string => INDIA_DATE.format(now);

/** Fisher–Yates with a crypto RNG, so option order cannot be predicted. */
export function shuffled<T>(items: readonly T[]): T[] {
  const out = [...items];
  for (let i = out.length - 1; i > 0; i--) {
    const j = randomInt(i + 1);
    [out[i], out[j]] = [out[j], out[i]];
  }
  return out;
}
