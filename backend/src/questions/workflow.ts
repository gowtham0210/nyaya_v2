import type { ErrorDetail } from '../core/errors.js';
import type {
  QuestionOption,
  QuestionType,
  Role,
  VersionStatus,
} from '../db/schema.js';

export const SUPPORTED_JURISDICTIONS = ['IN'] as const;
export const SUPPORTED_LANGUAGES = [
  'en',
  'hi',
  'ta',
  'te',
  'kn',
  'ml',
] as const;

export const READ_ROLES: Role[] = [
  'content_editor',
  'legal_reviewer',
  'publisher',
  'admin',
  'analyst',
];

/**
 * The question lifecycle (contract sheet "Workflow & Roles"). Every action
 * applies to the question's latest version, which must be in one of [from].
 */
export const ACTIONS = {
  edit: { from: ['draft', 'changes_requested'], roles: ['content_editor'] },
  submit: {
    from: ['draft', 'changes_requested'],
    to: 'in_review',
    roles: ['content_editor'],
  },
  request_changes: {
    from: ['in_review'],
    to: 'changes_requested',
    roles: ['legal_reviewer'],
  },
  approve: { from: ['in_review'], to: 'approved', roles: ['legal_reviewer'] },
  publish: {
    from: ['approved'],
    to: 'published',
    roles: ['publisher', 'admin'],
  },
  // A revision is a new draft version; a published one stays live meanwhile.
  revise: { from: ['published', 'retired'], roles: ['content_editor'] },
} as const satisfies Record<
  string,
  { from: readonly VersionStatus[]; to?: VersionStatus; roles: readonly Role[] }
>;

export type Action = keyof typeof ACTIONS;

/** Content fields checked before review and again before publishing. */
export interface VersionContent {
  questionType: QuestionType;
  stem: string;
  options: QuestionOption[];
  correctOptionIds: string[];
  explanation: string;
  sourceTitle: string | null;
  sourceUrl: string | null;
  jurisdiction: string;
  language: string;
  validFrom: string | null;
  validTo: string | null;
}

/** What stops this version going to review; empty when it is complete. */
export function contentProblems(
  v: VersionContent,
  topicActive: boolean,
): ErrorDetail[] {
  const problems: ErrorDetail[] = [];
  const add = (field: string, reason: string) =>
    problems.push({ field, reason });

  if (!v.stem.trim()) add('stem', 'Question text is required');
  if (v.options.length < 2 || v.options.length > 6)
    add('options', 'Give between 2 and 6 options');
  const ids = v.options.map((o) => o.id);
  if (new Set(ids).size !== ids.length)
    add('options', 'Option ids must be unique');
  if (v.options.some((o) => !o.text.trim()))
    add('options', 'Options cannot be empty');
  const texts = v.options.map((o) => o.text.trim().toLowerCase());
  if (new Set(texts).size !== texts.length)
    add('options', 'Options must be different from each other');
  if (v.correctOptionIds.some((id) => !ids.includes(id)))
    add('correct_option_ids', 'Correct answers must be listed options');
  if (v.questionType === 'single_select' && v.correctOptionIds.length !== 1) {
    add(
      'correct_option_ids',
      'A single-select question needs exactly one correct answer',
    );
  }
  if (!v.explanation.trim()) add('explanation', 'An explanation is required');
  if (!v.sourceTitle?.trim())
    add('source_title', 'An attributable source is required');
  if (v.sourceUrl && !/^https:\/\/\S+$/.test(v.sourceUrl))
    add('source_url', 'The source URL must use https');
  if (!(SUPPORTED_JURISDICTIONS as readonly string[]).includes(v.jurisdiction))
    add('jurisdiction', 'Unsupported jurisdiction');
  if (!(SUPPORTED_LANGUAGES as readonly string[]).includes(v.language))
    add('language', 'Unsupported language');
  if (!v.validFrom)
    add('valid_from', 'The date the content applies from is required');
  if (v.validFrom && v.validTo && v.validTo <= v.validFrom)
    add('valid_to', 'Must be after valid_from');
  if (!topicActive) add('topic_id', 'The topic is inactive');
  return problems;
}
