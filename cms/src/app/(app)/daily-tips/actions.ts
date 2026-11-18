'use server';

import { refresh } from 'next/cache';
import { redirect } from 'next/navigation';
import { api, asApiError, type ApiError } from '@/lib/api';
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
