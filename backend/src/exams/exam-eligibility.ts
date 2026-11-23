import { and, eq, inArray, isNull, lte, sql, type SQL } from 'drizzle-orm';
import { liveVersions } from '../learn/eligibility.js';
import { indiaToday } from '../learn/scoring.js';
import type { Db, Tx } from '../core/db.js';
import {
  examQuestionTags,
  questions,
  questionVersions,
  subjects,
  topics,
  type LawRegime,
  type LawRegimeFilter,
} from '../db/schema.js';

/*
 * Which questions a randomised mock may draw from. This is separate from the
 * game modes' `eligible()`: a mock needs an exam tag,
 * ignores when a question stops being in force (an old-code question is still
 * fair in an exam that tests it), and applies the blueprint's law-regime rule.
 */

export type ExamIneligibleCode =
  | 'question_not_found'
  | 'no_exam_tag'
  | 'not_published'
  | 'retired'
  | 'language_mismatch'
  | 'jurisdiction_mismatch'
  | 'not_yet_valid'
  | 'topic_inactive'
  | 'law_regime_excluded';

export const INELIGIBLE_MESSAGES: Record<ExamIneligibleCode, string> = {
  question_not_found: 'There is no question with this id',
  no_exam_tag: 'The question is not tagged for this exam',
  not_published: 'The question has no published live version',
  retired: 'The question is retired',
  language_mismatch: 'The question is not in the requested language',
  jurisdiction_mismatch: 'The question is not for the Indian jurisdiction',
  not_yet_valid: 'The question does not apply yet, or has no start date',
  topic_inactive: 'The question belongs to an inactive topic or subject',
  law_regime_excluded:
    "A randomised mock tests current law, so questions only about the old codes (IPC, CrPC, Evidence Act) are left out unless the blueprint's law-regime rule is include_all",
};

export interface ExamEligibilityOptions {
  language: string;
  now: Date;
  lawRegimeFilter: LawRegimeFilter;
}

/** Where a question is used: a randomised mock tests current law; a fixed paper is history. */
export type LawRegimeContext = 'random_mock' | 'fixed_paper';

/**
 * How an exam treats a question's law regime.
 *
 * - In a randomised mock, a question that is only about the old codes
 *   (IPC, CrPC, Evidence Act) is left out under `any` (the default),
 *   `exclude_old` and `prefer_new`. Only `include_all` lets it in;
 *   `prefer_new` is not a permission to include old-code questions.
 * - In a fixed historical paper nothing is filtered: the paper keeps the
 *   questions it was set with.
 *
 * Questions that are not purely about the old codes always pass.
 */
export function lawRegimeVerdict(
  filter: LawRegimeFilter,
  regime: LawRegime,
  context: LawRegimeContext = 'random_mock',
): { allowed: true } | { allowed: false; code: 'law_regime_excluded' } {
  if (context === 'fixed_paper') return { allowed: true };
  if (regime !== 'old_codes') return { allowed: true };
  if (filter === 'include_all') return { allowed: true };
  return { allowed: false, code: 'law_regime_excluded' };
}

/** The law regimes a pool may hold under [filter]. */
export function allowedRegimes(filter: LawRegimeFilter): LawRegime[] {
  const all: LawRegime[] = ['new_codes', 'both', 'neutral', 'old_codes'];
  return all.filter((r) => lawRegimeVerdict(filter, r).allowed);
}

/**
 * The SQL condition for a randomised mock's pool, over `liveVersions`:
 * tagged for the exam, published and live, in an active topic, and
 * allowed by the law-regime rule.
 */
export function examEligible(
  examId: string,
  options: ExamEligibilityOptions,
): SQL {
  const today = indiaToday(options.now);
  return and(
    eq(questionVersions.status, 'published'),
    isNull(questions.retiredAt),
    eq(questionVersions.language, options.language),
    eq(questionVersions.jurisdiction, 'IN'),
    lte(questionVersions.validFrom, today),
    eq(topics.isActive, true),
    eq(subjects.isActive, true),
    sql`exists (
      select 1 from ${examQuestionTags}
      where ${examQuestionTags.questionId} = ${questions.id}
        and ${examQuestionTags.examId} = ${examId}
    )`,
    inArray(
      questionVersions.lawRegime,
      allowedRegimes(options.lawRegimeFilter),
    ),
  )!;
}

/** question_versions joined to the live pointer, topic and subject (as for the games). */
export function examPool(tx: Tx, fields: Parameters<Db['select']>[0]) {
  return liveVersions(tx, fields);
}
