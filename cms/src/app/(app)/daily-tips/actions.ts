'use server';

import { refresh } from 'next/cache';
import { redirect } from 'next/navigation';
import { api, asApiError, type ApiError } from '@/lib/api';
import { getMe } from '@/lib/session';
import { SESSION_ENDED_URL } from '@/lib/session-cookies';
import type { TipAction } from '@/lib/workflow';
import type { ActionState } from '../questions/form-state';
import type { TipInput } from './form-state';

/*
 * Every action calls the API as the signed-in user; the API decides whether
 * they may. Nothing here trusts what the browser says about roles.
 */

function toBody(v: TipInput) {
  const str = (x: unknown) => (typeof x === 'string' ? x.trim() : '');
  return {
    category: v.category,
    language: v.language,
    title: str(v.title),
    summary: str(v.summary),
    explanation: str(v.explanation),
    legal_reference: str(v.legal_reference),
    source_url: str(v.source_url) || null,
    publish_date: str(v.publish_date) || null,
    last_verified_on: str(v.last_verified_on) || null,
  };
}

function toState(err: ApiError, status: number): ActionState {
  if (status === 401) redirect(SESSION_ENDED_URL);
  const fieldErrors: Record<string, string[]> = {};
  const otherErrors: string[] = [];
  for (const d of err.details ?? []) {
    if (d.field) (fieldErrors[d.field] ??= []).push(d.reason);
    else otherErrors.push(d.reason);
  }
  return { error: err.message, fieldErrors, otherErrors };
}

export async function createTip(_: ActionState, input: TipInput): Promise<ActionState> {
  const client = await api();
  const { data, error, response } = await client.POST('/v1/editor/daily-tips', { body: toBody(input) });
  if (!data) return toState(asApiError(error, response.status), response.status);
  redirect(`/daily-tips/${data.id}`);
}

export async function saveTip(id: string, _: ActionState, input: TipInput): Promise<ActionState> {
  const client = await api();
  const { data, error, response } = await client.PATCH('/v1/editor/daily-tips/{id}', {
    params: { path: { id } },
    body: toBody(input),
  });
  if (!data) return toState(asApiError(error, response.status), response.status);
  refresh();
  return { ok: true, message: 'Saved' };
}

const PATHS = {
  submit: '/v1/editor/daily-tips/{id}/submit',
  request_changes: '/v1/editor/daily-tips/{id}/request-changes',
  approve: '/v1/editor/daily-tips/{id}/approve',
  publish: '/v1/editor/daily-tips/{id}/publish',
  revise: '/v1/editor/daily-tips/{id}/revise',
  retire: '/v1/editor/daily-tips/{id}/retire',
} as const;

const DONE: Record<TipAction, string> = {
  submit: 'Sent for review',
  request_changes: 'Sent back to the editor',
  approve: 'Approved',
  publish: 'Published: learners see it on its day',
  revise: 'Back to draft and off the app',
  retire: 'Retired: no longer in the app',
};

const NEEDS_REASON: TipAction[] = ['request_changes', 'revise', 'retire'];

/** Runs one lifecycle step. The reason comes from the form. */
export async function runTipAction(id: string, action: TipAction, _: ActionState, form: FormData): Promise<ActionState> {
  if (!(action in PATHS)) return { error: 'Unknown action' };
  const body = NEEDS_REASON.includes(action) ? { reason: String(form.get('reason') ?? '').trim() } : undefined;
  const client = await api();
  // The paths share a shape; the cast keeps openapi-fetch's typing happy.
  const { data, error, response } = await client.POST(PATHS[action] as '/v1/editor/daily-tips/{id}/retire', {
    params: { path: { id } },
    body: body as { reason: string },
  });
  if (!data) return toState(asApiError(error, response.status), response.status);
  refresh();
  return { ok: true, message: DONE[action] };
}

export interface PublishAllState {
  ok?: boolean;
  error?: string;
  published?: number;
  /** Tips left approved, with the reason the API gave. */
  skipped?: { title: string; reason: string }[];
}

/**
 * Publishes every approved tip on its own "Show on" day, one by one through the
 * same publish step as the tip's page, so the API still checks the review, the
 * day and the one-tip-per-day rule and writes the audit entry. A tip that
 * cannot go out is left approved and reported; the rest are not held up.
 */
export async function publishAllApprovedTips(_: PublishAllState): Promise<PublishAllState> {
  const client = await api();
  const tips: { id: string; title: string; publish_date: string | null }[] = [];
  let cursor: string | undefined;
  do {
    const { data, error, response } = await client.GET('/v1/editor/daily-tips', {
      params: { query: { status: 'approved', cursor, limit: 100 } },
    });
    if (!data) {
      if (response.status === 401) redirect(SESSION_ENDED_URL);
      return { error: asApiError(error, response.status).message };
    }
    tips.push(...data.items);
    cursor = data.next_cursor ?? undefined;
  } while (cursor);

  // Earliest day first, so a clash is reported against the later tip.
  tips.sort((a, b) => (a.publish_date ?? '').localeCompare(b.publish_date ?? ''));
  let published = 0;
  const skipped: { title: string; reason: string }[] = [];
  for (const t of tips) {
    const { data, error, response } = await client.POST('/v1/editor/daily-tips/{id}/publish', {
      params: { path: { id: t.id } },
    });
    if (data) {
      published++;
      continue;
    }
    if (response.status === 401) redirect(SESSION_ENDED_URL);
    const err = asApiError(error, response.status);
    skipped.push({ title: t.title || 'Untitled draft', reason: err.details?.[0]?.reason ?? err.message });
  }
  refresh();
  return { ok: true, published, skipped };
}

/**
 * Records that the signed-in editor checked this tip against its exact
 * official source today. The API sets only the date, refuses a home-page link,
 * and writes who checked, and which link, to the audit log.
 */
export async function verifyTip(id: string, _: ActionState, form: FormData): Promise<ActionState> {
  if (form.get('confirmed') !== 'on') return { error: 'Tick the box to confirm you checked the source' };
  const client = await api();
  const { data, error, response } = await client.POST('/v1/editor/daily-tips/{id}/verify', {
    params: { path: { id } },
    body: { confirmed_against_source: true },
  });
  if (!data) return toState(asApiError(error, response.status), response.status);
  refresh();
  return { ok: true, message: `Recorded: checked against its source on ${data.last_verified_on}` };
}

export interface BulkVerifyState {
  ok?: boolean;
  error?: string;
  verified?: number;
  failed?: { id: string; reason: string }[];
}

/**
 * An admin's own statement that they checked each ticked tip against its
 * official source. Every tip goes through the same verify step as the single
 * "I checked this today" button, so the API refuses a tip with no exact source
 * link or that is not a draft, and writes one audit entry per tip naming the
 * signed-in admin. It does not submit, approve or publish anything.
 */
export async function verifyTipsAsAdmin(_: BulkVerifyState, form: FormData): Promise<BulkVerifyState> {
  const me = await getMe();
  if (!me.roles.includes('admin')) return { error: 'Only an admin can record checks in bulk' };
  if (form.get('attest') !== 'on') return { error: 'Tick the box to confirm you checked each selected tip yourself' };
  const ids = form.getAll('id').filter((v): v is string => typeof v === 'string');
  if (ids.length === 0) return { error: 'Select at least one tip' };

  const client = await api();
  let verified = 0;
  const failed: { id: string; reason: string }[] = [];
  for (const id of ids) {
    const { data, error, response } = await client.POST('/v1/editor/daily-tips/{id}/verify', {
      params: { path: { id } },
      body: { confirmed_against_source: true },
    });
    if (data) {
      verified++;
      continue;
    }
    if (response.status === 401) redirect(SESSION_ENDED_URL);
    const err = asApiError(error, response.status);
    failed.push({ id, reason: err.details?.[0]?.reason ?? err.message });
  }
  refresh();
  return { ok: true, verified, failed };
}
