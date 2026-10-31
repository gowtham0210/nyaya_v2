import type { ErrorDetail } from '../core/errors.js';
import type { NewsStatus, Role } from '../db/schema.js';

export const NEWS_READ_ROLES: Role[] = [
  'content_editor',
  'legal_reviewer',
  'publisher',
  'admin',
  'analyst',
];

/**
 * The news article lifecycle, the same steps and roles as a question's.
 * Every action needs the article to be in one of [from].
 */
export const NEWS_ACTIONS = {
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
  // A correction takes the article off the app until it is approved again.
  revise: {
    from: ['published', 'retired'],
    to: 'draft',
    roles: ['content_editor'],
  },
  retire: { from: ['published'], to: 'retired', roles: ['publisher', 'admin'] },
} as const satisfies Record<
  string,
  { from: readonly NewsStatus[]; to?: NewsStatus; roles: readonly Role[] }
>;

export type NewsAction = keyof typeof NEWS_ACTIONS;

export const MAX_KEY_POINTS = 6;

/** Content fields checked before review and again before publishing. */
export interface NewsContent {
  title: string;
  summary: string;
  keyPoints: string[];
  whyItMatters: string;
  source: string;
  sourceUrl: string | null;
  eventDate: string | null;
}

/** What stops this article going to review; empty when it is complete. */
export function newsProblems(a: NewsContent): ErrorDetail[] {
  const problems: ErrorDetail[] = [];
  const add = (field: string, reason: string) =>
    problems.push({ field, reason });

  if (!a.title.trim()) add('title', 'A title is required');
  if (!a.summary.trim()) add('summary', 'A summary is required');
  if (a.keyPoints.length < 1 || a.keyPoints.length > MAX_KEY_POINTS)
    add('key_points', `Give between 1 and ${MAX_KEY_POINTS} key points`);
  if (a.keyPoints.some((p) => !p.trim()))
    add('key_points', 'Key points cannot be empty');
  if (!a.whyItMatters.trim())
    add('why_it_matters', 'Say why it matters to the reader');
  if (!a.source.trim()) add('source', 'Say who decided or passed it, and when');
  if (a.sourceUrl && !/^https:\/\/\S+$/.test(a.sourceUrl))
    add('source_url', 'The source link must use https');
  if (!a.eventDate)
    add('event_date', 'The date of the judgment or law is required');
  return problems;
}
