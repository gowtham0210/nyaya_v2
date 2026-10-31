import type { Me, NewsCategory, NewsStatus, VersionStatus } from './api';

/**
 * Mirrors the API's lifecycle rules so the UI only offers allowed actions.
 * The API still enforces them; this is for display only.
 */
type Role = Me['roles'][number];

export const WORKFLOW = {
  submit: { label: 'Submit for review', from: ['draft', 'changes_requested'], roles: ['content_editor'] },
  request_changes: { label: 'Request changes', from: ['in_review'], roles: ['legal_reviewer'] },
  approve: { label: 'Approve', from: ['in_review'], roles: ['legal_reviewer'] },
  publish: { label: 'Publish', from: ['approved'], roles: ['publisher', 'admin'] },
  revise: { label: 'Start a revision', from: ['published', 'retired'], roles: ['content_editor'] },
  retire: { label: 'Retire', from: [], roles: ['publisher', 'admin'] },
} as const satisfies Record<string, { label: string; from: readonly VersionStatus[]; roles: readonly Role[] }>;

export type WorkflowAction = keyof typeof WORKFLOW;

/** Steps the question list can run on many questions at once (the others need a reason each). */
export const BULK_ACTIONS = ['submit', 'approve', 'publish'] as const satisfies readonly WorkflowAction[];
export type BulkAction = (typeof BULK_ACTIONS)[number];

export const hasRole = (me: Me, ...roles: readonly Role[]) => roles.some((r) => me.roles.includes(r));

/** Staff who handle learner reports (the API checks this too). */
export const TRIAGE_ROLES = ['content_editor', 'legal_reviewer', 'publisher', 'admin'] as const satisfies readonly Role[];

/** Roles an admin can give on the Staff page (everything but learner). */
export const STAFF_ROLES = ['admin', 'content_editor', 'legal_reviewer', 'publisher', 'analyst'] as const satisfies readonly Role[];

/** Staff who may import question files (the API checks this too). */
export const IMPORT_ROLES = ['content_editor', 'admin'] as const satisfies readonly Role[];

export const canEdit = (me: Me, status: VersionStatus) =>
  hasRole(me, 'content_editor') && (status === 'draft' || status === 'changes_requested');

/** Actions this user may take now. Retire depends on a live version, not the latest status. */
export function availableActions(me: Me, status: VersionStatus, hasLive: boolean): WorkflowAction[] {
  return (Object.keys(WORKFLOW) as WorkflowAction[]).filter((a) => {
    const rule = WORKFLOW[a];
    if (!hasRole(me, ...rule.roles)) return false;
    return a === 'retire' ? hasLive : (rule.from as readonly string[]).includes(status);
  });
}

export const STATUS_LABEL: Record<VersionStatus, string> = {
  draft: 'Draft',
  in_review: 'In review',
  changes_requested: 'Changes requested',
  approved: 'Approved',
  published: 'Published',
  superseded: 'Superseded',
  retired: 'Retired',
};

export const ROLE_LABEL: Record<Role, string> = {
  learner: 'Learner',
  admin: 'Admin',
  content_editor: 'Editor',
  legal_reviewer: 'Legal reviewer',
  publisher: 'Publisher',
  analyst: 'Analyst',
};

/** The news article lifecycle, mirroring the API (which enforces it). */
export const NEWS_WORKFLOW = {
  submit: { label: 'Submit for review', from: ['draft', 'changes_requested'], roles: ['content_editor'] },
  request_changes: { label: 'Request changes', from: ['in_review'], roles: ['legal_reviewer'] },
  approve: { label: 'Approve', from: ['in_review'], roles: ['legal_reviewer'] },
  publish: { label: 'Publish', from: ['approved'], roles: ['publisher', 'admin'] },
  revise: { label: 'Correct this article', from: ['published', 'retired'], roles: ['content_editor'] },
  retire: { label: 'Retire', from: ['published'], roles: ['publisher', 'admin'] },
} as const satisfies Record<string, { label: string; from: readonly NewsStatus[]; roles: readonly Role[] }>;

export type NewsAction = keyof typeof NEWS_WORKFLOW;

export const canEditNews = (me: Me, status: NewsStatus) =>
  hasRole(me, 'content_editor') && (status === 'draft' || status === 'changes_requested');

export const newsActions = (me: Me, status: NewsStatus): NewsAction[] =>
  (Object.keys(NEWS_WORKFLOW) as NewsAction[]).filter(
    (a) => hasRole(me, ...NEWS_WORKFLOW[a].roles) && (NEWS_WORKFLOW[a].from as readonly string[]).includes(status),
  );

export const NEWS_CATEGORY_LABEL: Record<NewsCategory, string> = {
  supreme_court: 'Supreme Court',
  high_courts: 'High Courts',
  legislation: 'Legislation',
  explainer: 'Explainer',
};
