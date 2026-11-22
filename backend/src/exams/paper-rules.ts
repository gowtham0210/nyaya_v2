import type {
  KeyHistoryKind,
  PaperAnswerStatus,
  WithdrawnPolicy,
} from '../db/schema.js';
import type { ErrorDetail } from '../core/errors.js';

/*
 * Rules for fixed papers, kept apart from the database so they can be tested.
 * Nothing here records an attempt; `scorePosition` is the rule a later stage
 * will apply to a submitted answer.
 */

export interface PositionKeyInput {
  answerStatus: PaperAnswerStatus;
  /** The pinned version's own key. */
  versionCorrect: string[];
  versionAlternates: string[];
  /** The newest key-history row for the position, if any. */
  latestKey: { kind: KeyHistoryKind; acceptedOptionIds: string[] } | null;
}

/**
 * Every option accepted for a position. A key-history row wins over the
 * version's own key; a withdrawn position accepts nothing.
 */
export function acceptedOptions(p: PositionKeyInput): string[] {
  if (p.answerStatus === 'withdrawn') return [];
  if (p.latestKey && p.latestKey.kind !== 'withdrawn')
    return [...new Set(p.latestKey.acceptedOptionIds)];
  return [...new Set([...p.versionCorrect, ...p.versionAlternates])];
}

/** keyed or multi_accepted, from how many options the pinned version accepts. */
export function answerStatusFor(
  versionId: string | null,
  correct: string[],
  alternates: string[],
): PaperAnswerStatus {
  if (!versionId) return 'withdrawn';
  return alternates.length > 0 || correct.length > 1
    ? 'multi_accepted'
    : 'keyed';
}

/** Whether [order] lists exactly the option ids, once each. */
export function isPermutation(order: string[], optionIds: string[]): boolean {
  return (
    order.length === optionIds.length &&
    new Set(order).size === order.length &&
    order.every((id) => optionIds.includes(id))
  );
}

export interface ScoringPolicy {
  marksCorrect: number;
  negativeMarks: number;
  marksUnanswered: number;
  withdrawnPolicy: WithdrawnPolicy;
}

export type PositionOutcome =
  | 'correct'
  | 'incorrect'
  | 'unanswered'
  | 'withdrawn_unscored'
  | 'withdrawn_awarded';

export interface PositionScore {
  outcome: PositionOutcome;
  marks: number;
  /** False when the position is left out of the maximum marks and percentage. */
  counted: boolean;
}

/**
 * Scores one position. A single-select position is right when the chosen
 * option is any accepted one. A multi-select question needs exactly its
 * accepted set. A withdrawn position follows the paper's withdrawn policy:
 * unscored (the default) leaves it out entirely; award_all gives full marks
 * to everyone.
 */
export function scorePosition(
  policy: ScoringPolicy,
  p: {
    answerStatus: PaperAnswerStatus;
    questionType: string;
    accepted: string[];
  },
  selected: string[] | null,
): PositionScore {
  if (p.answerStatus === 'withdrawn') {
    return policy.withdrawnPolicy === 'award_all'
      ? {
          outcome: 'withdrawn_awarded',
          marks: policy.marksCorrect,
          counted: true,
        }
      : { outcome: 'withdrawn_unscored', marks: 0, counted: false };
  }
  if (!selected || selected.length === 0)
    return {
      outcome: 'unanswered',
      marks: policy.marksUnanswered,
      counted: true,
    };
  const right =
    p.questionType === 'single_select'
      ? selected.length === 1 && p.accepted.includes(selected[0])
      : selected.length === p.accepted.length &&
        selected.every((s) => p.accepted.includes(s));
  return right
    ? { outcome: 'correct', marks: policy.marksCorrect, counted: true }
    : { outcome: 'incorrect', marks: -policy.negativeMarks, counted: true };
}

export interface PaperDraftState {
  totalQuestions: number;
  positions: {
    position: number;
    answerStatus: PaperAnswerStatus;
    /** Set when the pinned version is missing or not published. */
    versionProblem: string | null;
  }[];
  withdrawnPolicy: WithdrawnPolicy;
  withdrawnPolicyConfirmed: boolean;
  marksCorrect: number | null;
  hasWithdrawn: boolean;
}

/** What stops a draft paper being published (and so frozen); empty when it is ready. */
export function publishProblems(s: PaperDraftState): ErrorDetail[] {
  const out: ErrorDetail[] = [];
  const add = (field: string, reason: string) => out.push({ field, reason });
  const have = new Set(s.positions.map((p) => p.position));
  if (s.positions.length !== s.totalQuestions)
    add(
      'positions',
      `The paper has ${s.positions.length} positions but total_questions is ${s.totalQuestions}`,
    );
  const missing: number[] = [];
  for (let i = 1; i <= s.totalQuestions; i++) if (!have.has(i)) missing.push(i);
  if (missing.length)
    add(
      'positions',
      `Positions ${missing.slice(0, 10).join(', ')}${missing.length > 10 ? '…' : ''} are missing`,
    );
  for (const p of s.positions)
    if (p.versionProblem) add(`positions[${p.position}]`, p.versionProblem);
  if (s.withdrawnPolicy === 'award_all' && !s.withdrawnPolicyConfirmed)
    add(
      'withdrawn_policy',
      'Awarding marks for withdrawn questions needs the rule confirmed from the exam body',
    );
  // A withdrawn question with the interim unscored policy is allowed.
  return out;
}
