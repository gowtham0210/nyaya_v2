'use server';

import { refresh } from 'next/cache';
import { redirect } from 'next/navigation';
import { api, asApiError, type ApiError } from '@/lib/api';
import { SESSION_ENDED_URL } from '@/lib/session-cookies';
import type { NewsAction } from '@/lib/workflow';
import type { ActionState } from '../questions/form-state';
import type { NewsInput } from './form-state';

/*
 * Every action calls the API as the signed-in user; the API decides whether
 * they may. Nothing here trusts what the browser says about roles.
 */

function toBody(v: NewsInput) {
  const str = (x: unknown) => (typeof x === 'string' ? x.trim() : '');
  return {
    category: v.category,
    title: str(v.title),
    summary: str(v.summary),
    key_points: (Array.isArray(v.key_points) ? v.key_points : []).map(str).filter(Boolean),
    why_it_matters: str(v.why_it_matters),
    source: str(v.source),
    source_url: str(v.source_url) || null,
    event_date: str(v.event_date) || null,
    read_minutes: Number(v.read_minutes) || 3,
  };
}

function toState(err: ApiError, status: number): ActionState {
  if (status === 401) redirect(SESSION_ENDED_URL);
  const fieldErrors: Record<string, string[]> = {};
  const otherErrors: string[] = [];
  for (const d of err.details ?? []) {
    // "key_points.0" → "key_points"
    const field = d.field?.split('.')[0];
    if (field) (fieldErrors[field] ??= []).push(d.reason);
    else otherErrors.push(d.reason);
  }
  return { error: err.message, fieldErrors, otherErrors };
}

export async function createNews(_: ActionState, input: NewsInput): Promise<ActionState> {
  const client = await api();
  const { data, error, response } = await client.POST('/v1/editor/news', { body: toBody(input) });
  if (!data) return toState(asApiError(error, response.status), response.status);
  redirect(`/news/${data.id}`);
}

export async function saveNews(id: string, _: ActionState, input: NewsInput): Promise<ActionState> {
  const client = await api();
  const { data, error, response } = await client.PATCH('/v1/editor/news/{id}', {
    params: { path: { id } },
    body: toBody(input),
  });
  if (!data) return toState(asApiError(error, response.status), response.status);
  refresh();
  return { ok: true, message: 'Saved' };
}

const PATHS = {
  submit: '/v1/editor/news/{id}/submit',
  request_changes: '/v1/editor/news/{id}/request-changes',
  approve: '/v1/editor/news/{id}/approve',
  publish: '/v1/editor/news/{id}/publish',
  revise: '/v1/editor/news/{id}/revise',
  retire: '/v1/editor/news/{id}/retire',
} as const;

const DONE: Record<NewsAction, string> = {
  submit: 'Sent for review',
  request_changes: 'Sent back to the editor',
  approve: 'Approved',
  publish: 'Published: learners see it now',
  revise: 'Back to draft and off the app',
  retire: 'Retired: no longer in the app',
};

const NEEDS_REASON: NewsAction[] = ['request_changes', 'revise', 'retire'];

/** Runs one lifecycle step. The reason comes from the form. */
export async function runNewsAction(id: string, action: NewsAction, _: ActionState, form: FormData): Promise<ActionState> {
  if (!(action in PATHS)) return { error: 'Unknown action' };
  const body = NEEDS_REASON.includes(action) ? { reason: String(form.get('reason') ?? '').trim() } : undefined;
  const client = await api();
  // The paths share a shape; the cast keeps openapi-fetch's typing happy.
  const { data, error, response } = await client.POST(PATHS[action] as '/v1/editor/news/{id}/retire', {
    params: { path: { id } },
    body: body as { reason: string },
  });
  if (!data) return toState(asApiError(error, response.status), response.status);
  refresh();
  return { ok: true, message: DONE[action] };
}
