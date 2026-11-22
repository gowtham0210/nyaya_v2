import type { ErrorDetail } from '../core/errors.js';
import type { DailyTipStatus, Role } from '../db/schema.js';

export const TIP_READ_ROLES: Role[] = [
  'content_editor',
  'legal_reviewer',
  'publisher',
  'admin',
  'analyst',
];

/**
 * The tip lifecycle: the same steps and roles as a news article's.
 * Every action needs the tip to be in one of [from].
 */
export const TIP_ACTIONS = {
  edit: { from: ['draft', 'changes_requested'], roles: ['content_editor'] },
  // Records that the editor checked the tip against its exact official
  // source today. It only sets the verification date; it never moves the tip
  // through review, and it counts as editing for the "no self-approval" rule.
  verify: { from: ['draft', 'changes_requested'], roles: ['content_editor'] },
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
  // A correction takes the tip off the app until it is approved again.
  revise: {
    from: ['published', 'retired'],
    to: 'draft',
    roles: ['content_editor'],
  },
  retire: { from: ['published'], to: 'retired', roles: ['publisher', 'admin'] },
} as const satisfies Record<
  string,
  {
    from: readonly DailyTipStatus[];
    to?: DailyTipStatus;
    roles: readonly Role[];
  }
>;

export type TipAction = keyof typeof TIP_ACTIONS;

/** Content fields checked before review and again before publishing. */
export interface TipContent {
  title: string;
  summary: string;
  explanation: string;
  legalReference: string;
  sourceUrl: string | null;
  publishDate: string | null;
  lastVerifiedOn: string | null;
}

/** What stops this tip going to review; empty when it is complete. */
export function tipProblems(t: TipContent): ErrorDetail[] {
  const problems: ErrorDetail[] = [];
  const add = (field: string, reason: string) =>
    problems.push({ field, reason });

  if (!t.title.trim()) add('title', 'A title is required');
  if (!t.summary.trim()) add('summary', 'A short summary is required');
  if (!t.explanation.trim())
    add('explanation', 'The full explanation is required');
  if (!t.legalReference.trim())
    add('legal_reference', 'Give the Act and section the tip rests on');
  if (!t.sourceUrl) add('source_url', 'An official source link is required');
  else if (!/^https:\/\/\S+$/.test(t.sourceUrl))
    add('source_url', 'The source link must use https');
  if (!t.publishDate) add('publish_date', 'Choose the day the tip is shown');
  // lastVerifiedOn is optional: an unverified tip can still be reviewed and
  // published; the verification page lists tips that have not been checked.
  return problems;
}

/**
 * Whether [url] points at the exact page the tip rests on. A bare site address
 * (https://www.indiacode.nic.in/) names a website, not a provision, so it
 * cannot stand in for checking the tip against its source.
 */
export function isExactSourceLink(url: string | null): boolean {
  if (!url || !/^https:\/\/\S+$/.test(url)) return false;
  try {
    const u = new URL(url);
    return u.pathname.replace(/\/+$/, '') !== '' || u.search !== '';
  } catch {
    return false;
  }
}
