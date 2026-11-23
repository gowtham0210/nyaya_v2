import type { PaperAnswerStatus, WithdrawnPolicy } from '../db/schema.js';
import { scorePosition, type PositionOutcome } from './paper-rules.js';

/*
 * Scoring of a finished exam attempt, free of the database so it can be
 * tested exhaustively. It applies the paper rule `scorePosition` to every
 * position and adds the totals, the section breakdown and the pass check.
 *
 * It never invents rules: marks are reported only when the correct,
 * negative and unanswered marks were all configured; a pass is reported only
 * when the rules were verified, the result is not provisional and a
 * threshold exists.
 */

export interface AttemptRules {
  marksCorrect: number | null;
  negativeMarks: number | null;
  marksUnanswered: number | null;
  withdrawnPolicy: WithdrawnPolicy;
  withdrawnPolicyConfirmed: boolean;
  /** The rules come from a source marked official_confirmed. */
  rulesVerified: boolean;
  passPercentGeneral: number | null;
  passPercentReserved: number | null;
}

export interface ScoredPositionInput {
  position: number;
  sectionCode: string | null;
  sectionPosition: number | null;
  answerStatus: PaperAnswerStatus;
  questionType: string;
  accepted: string[];
  /** Marks for a correct answer here; falls back to the attempt's rules. */
  marksCorrect: number | null;
  selected: string[] | null;
}

export interface Tally {
  total_positions: number;
  /** Positions that count towards the maximum (withdrawn ones may not). */
  scorable_positions: number;
  correct: number;
  incorrect: number;
  unanswered: number;
  withdrawn: number;
  marks_obtained: number | null;
  max_marks: number | null;
  percentage: number | null;
}

export interface SectionTally extends Tally {
  code: string | null;
  position: number | null;
}

export interface PassCheck {
  /** True only when a pass could be judged; false means no claim is made. */
  available: boolean;
  reason: string | null;
  percentage: number | null;
  /** Whether the percentage reaches each category's threshold. */
  general: { threshold: number; met: boolean } | null;
  reserved: { threshold: number; met: boolean } | null;
}

export interface AttemptResult {
  marks_available: boolean;
  rules_verified: boolean;
  /** True while a withdrawn question's scoring rule is unconfirmed. */
  provisional: boolean;
  provisional_reasons: string[];
  withdrawn_policy: WithdrawnPolicy;
  overall: Tally;
  sections: SectionTally[];
  pass: PassCheck;
  positions: {
    position: number;
    outcome: PositionOutcome;
    marks: number | null;
  }[];
}

const round2 = (n: number) => Math.round(n * 100) / 100;

export function computeResult(
  rules: AttemptRules,
  inputs: ScoredPositionInput[],
): AttemptResult {
  const marksAvailable =
    rules.marksCorrect !== null &&
    rules.negativeMarks !== null &&
    rules.marksUnanswered !== null;

  const scored = [...inputs]
    .sort((a, b) => a.position - b.position)
    .map((p) => {
      const perCorrect = p.marksCorrect ?? rules.marksCorrect ?? 0;
      const s = scorePosition(
        {
          marksCorrect: perCorrect,
          negativeMarks: rules.negativeMarks ?? 0,
          marksUnanswered: rules.marksUnanswered ?? 0,
          withdrawnPolicy: rules.withdrawnPolicy,
        },
        p,
        p.selected,
      );
      return { p, s, perCorrect };
    });

  const tally = (rows: typeof scored): Tally => {
    const count = (o: PositionOutcome) =>
      rows.filter((r) => r.s.outcome === o).length;
    const counted = rows.filter((r) => r.s.counted);
    const obtained = counted.reduce((a, r) => a + r.s.marks, 0);
    const max = counted.reduce((a, r) => a + r.perCorrect, 0);
    return {
      total_positions: rows.length,
      scorable_positions: counted.length,
      correct: count('correct'),
      incorrect: count('incorrect'),
      unanswered: count('unanswered'),
      withdrawn: count('withdrawn_unscored') + count('withdrawn_awarded'),
      marks_obtained: marksAvailable ? round2(obtained) : null,
      max_marks: marksAvailable ? round2(max) : null,
      percentage:
        marksAvailable && max > 0 ? round2((obtained / max) * 100) : null,
    };
  };

  const overall = tally(scored);
  const sectionKeys = [
    ...new Map(
      scored
        .filter((r) => r.p.sectionCode !== null)
        .map((r) => [
          r.p.sectionCode,
          { code: r.p.sectionCode, position: r.p.sectionPosition },
        ]),
    ).values(),
  ].sort((a, b) => (a.position ?? 0) - (b.position ?? 0));
  const sections: SectionTally[] = sectionKeys.map((k) => ({
    code: k.code,
    position: k.position,
    ...tally(scored.filter((r) => r.p.sectionCode === k.code)),
  }));

  const hasWithdrawn = overall.withdrawn > 0;
  const provisionalReasons: string[] = [];
  if (hasWithdrawn && !rules.withdrawnPolicyConfirmed)
    provisionalReasons.push(
      rules.withdrawnPolicy === 'unscored'
        ? 'Withdrawn questions are left out of the marks until the exam body’s rule is confirmed'
        : 'The marks for withdrawn questions are not confirmed',
    );
  const provisional = provisionalReasons.length > 0;

  return {
    marks_available: marksAvailable,
    rules_verified: rules.rulesVerified,
    provisional,
    provisional_reasons: provisionalReasons,
    withdrawn_policy: rules.withdrawnPolicy,
    overall,
    sections,
    pass: passCheck(rules, overall, marksAvailable, provisional),
    positions: scored.map(({ p, s }) => ({
      position: p.position,
      outcome: s.outcome,
      marks: marksAvailable ? s.marks : null,
    })),
  };
}

function passCheck(
  rules: AttemptRules,
  overall: Tally,
  marksAvailable: boolean,
  provisional: boolean,
): PassCheck {
  const none = (reason: string): PassCheck => ({
    available: false,
    reason,
    percentage: overall.percentage,
    general: null,
    reserved: null,
  });
  if (!marksAvailable)
    return none('The marking rules for this exam are not configured');
  if (!rules.rulesVerified)
    return none(
      'The exam rules have not been verified against an official source',
    );
  if (rules.passPercentGeneral === null && rules.passPercentReserved === null)
    return none('No pass criteria are configured for this exam');
  if (provisional)
    return none('The result is provisional, so no pass decision is made');
  if (overall.percentage === null)
    return none('There are no scorable questions');
  const pct = overall.percentage;
  const check = (threshold: number | null) =>
    threshold === null ? null : { threshold, met: pct >= threshold };
  return {
    available: true,
    reason: null,
    percentage: pct,
    general: check(rules.passPercentGeneral),
    reserved: check(rules.passPercentReserved),
  };
}

/** Seconds left until [deadline], never negative; null when there is no deadline. */
export function remainingSeconds(
  deadline: Date | null,
  now: Date,
): number | null {
  if (!deadline) return null;
  return Math.max(0, Math.ceil((deadline.getTime() - now.getTime()) / 1000));
}

export type AnswerSaveVerdict =
  | { apply: true }
  | { apply: false; reason: 'duplicate' | 'stale' | 'conflict' };

/**
 * Decides whether a save may overwrite what the server holds. A higher
 * counter wins; an older one is stale and ignored; the same counter with the
 * same answer is a harmless repeat; the same counter with a different answer
 * is a conflict and is also ignored.
 */
export function answerSaveVerdict(
  stored: { seq: number; selected: string[] | null },
  incoming: { seq: number; selected: string[] | null },
): AnswerSaveVerdict {
  if (incoming.seq > stored.seq) return { apply: true };
  if (incoming.seq < stored.seq) return { apply: false, reason: 'stale' };
  const a = [...(stored.selected ?? [])].sort().join('|');
  const b = [...(incoming.selected ?? [])].sort().join('|');
  return { apply: false, reason: a === b ? 'duplicate' : 'conflict' };
}
