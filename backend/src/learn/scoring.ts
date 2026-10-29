import { randomInt } from 'node:crypto';
import type { FeedbackMode, QuizMode } from '../db/schema.js';

/**
 * Scoring policy recorded on every session, so a result can always be
 * explained by the rules in force when it was taken. Change the rules by
 * adding a new version, never by editing this one.
 *
 * standard-v1: +1 for a correct answer, 0 for wrong or unanswered.
 * A single-select answer is correct when it picks exactly the correct option.
 */
export const SCORING_VERSION = 'standard-v1';

/** exam-negative-v1: +1 correct, −0.25 wrong, 0 unanswered (the app's Exam Chamber). */
export const EXAM_NEGATIVE_VERSION = 'exam-negative-v1';
const NEGATIVE_MARKS = 0.25;

/** The score under a session's scoring version, from its counts. */
export function scoreFor(
  version: string,
  correct: number,
  answered: number,
): number {
  if (version === EXAM_NEGATIVE_VERSION)
    return correct - NEGATIVE_MARKS * (answered - correct);
  return correct;
}

/** Exams reveal answers at the end; every other mode explains each answer. */
export const feedbackModeFor = (mode: QuizMode): FeedbackMode =>
  mode === 'exam' ? 'end' : 'immediate';

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
  return { correctCount: correct, answeredCount: answered };
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

/** The docket's question set is fixed per India date: the date it was started. */
export const dailySetDate = (mode: QuizMode, startedAt: Date): string | null =>
  mode === 'daily_docket' ? indiaToday(startedAt) : null;

/** ISO week id (`2026-W44`, weeks start Monday) of a YYYY-MM-DD date. */
export function isoWeek(day: string): string {
  const d = new Date(`${day}T00:00:00Z`);
  const weekday = (d.getUTCDay() + 6) % 7; // Monday = 0
  d.setUTCDate(d.getUTCDate() - weekday + 3); // Thursday of this week
  const year = d.getUTCFullYear();
  const jan4 = new Date(Date.UTC(year, 0, 4));
  const firstThursday = new Date(jan4);
  firstThursday.setUTCDate(
    jan4.getUTCDate() - ((jan4.getUTCDay() + 6) % 7) + 3,
  );
  const week =
    1 + Math.round((d.getTime() - firstThursday.getTime()) / 604_800_000);
  return `${year}-W${String(week).padStart(2, '0')}`;
}

/** Fisher–Yates with a crypto RNG, so option order cannot be predicted. */
export function shuffled<T>(items: readonly T[]): T[] {
  const out = [...items];
  for (let i = out.length - 1; i > 0; i--) {
    const j = randomInt(i + 1);
    [out[i], out[j]] = [out[j], out[i]];
  }
  return out;
}
