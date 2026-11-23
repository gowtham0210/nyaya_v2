import type { ErrorDetail } from '../core/errors.js';
import type { BlueprintStatus, ConfigStatus } from '../db/schema.js';

/**
 * Whether an exam blueprint may be used for a timed mock. Only a published
 * blueprint whose rules are official-confirmed qualifies; an inferred or
 * unverified one is practice-only until a person confirms it.
 */
export type TimedModeVerdict =
  | { allowed: true }
  | {
      allowed: false;
      code: 'blueprint_not_published' | 'config_not_official_confirmed';
      reason: string;
    };

export function timedModeVerdict(bp: {
  status: BlueprintStatus;
  configStatus: ConfigStatus;
}): TimedModeVerdict {
  if (bp.status !== 'published')
    return {
      allowed: false,
      code: 'blueprint_not_published',
      reason: 'The blueprint is not published',
    };
  if (bp.configStatus !== 'official_confirmed')
    return {
      allowed: false,
      code: 'config_not_official_confirmed',
      reason: `The exam rules are ${bp.configStatus.replace('_', ' ')}, not official-confirmed, so only practice mode is allowed`,
    };
  return { allowed: true };
}

/** "Official-confirmed" must say which document confirms it, and when it was checked. */
export function configEvidenceProblems(c: {
  configStatus: ConfigStatus;
  configSource: string | null;
  configCheckedOn: string | null;
}): ErrorDetail[] {
  if (c.configStatus !== 'official_confirmed') return [];
  const problems: ErrorDetail[] = [];
  if (!c.configSource?.trim())
    problems.push({
      field: 'config_source',
      reason: 'Name the official document that confirms these rules',
    });
  if (!c.configCheckedOn)
    problems.push({
      field: 'config_checked_on',
      reason: 'Give the date the rules were checked against that document',
    });
  return problems;
}

export interface SectionDraft {
  code: string;
  position: number;
  questionCount: number;
  durationSeconds: number | null;
  topics: { topicId: string; minCount: number; maxCount: number | null }[];
}

/**
 * Repeated section codes or positions, or a topic listed twice in a section.
 * Checked whenever sections are saved, even in a draft.
 */
export function structureProblems(
  sections: readonly SectionDraft[],
): ErrorDetail[] {
  const problems: ErrorDetail[] = [];
  const codes = sections.map((s) => s.code);
  if (new Set(codes).size !== codes.length)
    problems.push({
      field: 'sections',
      reason: 'Section codes must be different from each other',
    });
  const positions = sections.map((s) => s.position);
  if (new Set(positions).size !== positions.length)
    problems.push({
      field: 'sections',
      reason: 'Section positions must be different from each other',
    });
  for (const s of sections) {
    const ids = s.topics.map((t) => t.topicId);
    if (new Set(ids).size !== ids.length)
      problems.push({
        field: `sections.${s.code}`,
        reason: 'A topic appears twice in the section',
      });
  }
  return problems;
}

/** What stops a blueprint's sections from being published; empty when they are sound. */
export function sectionProblems(
  bp: { totalQuestions: number; durationSeconds: number },
  sections: readonly SectionDraft[],
): ErrorDetail[] {
  const problems: ErrorDetail[] = [...structureProblems(sections)];
  const add = (field: string, reason: string) =>
    problems.push({ field, reason });
  if (sections.length === 0) {
    add('sections', 'A blueprint needs at least one section');
    return problems;
  }

  const total = sections.reduce((n, s) => n + s.questionCount, 0);
  if (total !== bp.totalQuestions)
    add(
      'sections',
      `The sections add up to ${total} questions but the blueprint has ${bp.totalQuestions}`,
    );

  for (const s of sections) {
    const field = `sections.${s.code}`;
    if (s.topics.length === 0) add(field, 'The section has no topics');
    const minTotal = s.topics.reduce((n, t) => n + t.minCount, 0);
    if (minTotal > s.questionCount)
      add(
        field,
        `The topic minimums add up to ${minTotal}, more than the section's ${s.questionCount} questions`,
      );
    if (s.topics.length > 0 && s.topics.every((t) => t.maxCount !== null)) {
      const maxTotal = s.topics.reduce((n, t) => n + (t.maxCount ?? 0), 0);
      if (maxTotal < s.questionCount)
        add(
          field,
          `The topic maximums add up to ${maxTotal}, fewer than the section's ${s.questionCount} questions`,
        );
    }
    if (s.durationSeconds !== null && s.durationSeconds > bp.durationSeconds)
      add(field, "The section's time is longer than the whole exam");
  }
  return problems;
}
