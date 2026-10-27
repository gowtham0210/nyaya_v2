'use server';

import { refresh } from 'next/cache';
import { redirect } from 'next/navigation';
import { api, asApiError, type ApiError } from '@/lib/api';
import type { WorkflowAction } from '@/lib/workflow';
import type { ActionState, QuestionInput } from './form-state';

/*
 * Every action calls the API as the signed-in user; the API decides whether
 * they may. Nothing here trusts what the browser says about roles.
 */

const NULLABLE = ['source_title', 'source_url', 'citation', 'provision_reference', 'valid_from', 'valid_to'] as const;

function toBody(v: QuestionInput) {
  const str = (x: unknown) => (typeof x === 'string' ? x : '');
  const options = (Array.isArray(v.options) ? v.options : [])
    .map((o) => ({ id: str(o?.id), text: str(o?.text).trim() }))
    .filter((o) => o.text);
  const nullable = Object.fromEntries(NULLABLE.map((k) => [k, str(v[k]).trim() || null]));
  return {
    topic_id: str(v.topic_id),
    difficulty: Number(v.difficulty) || 1,
    stem: str(v.stem).trim(),
    options,
    correct_option_ids: options.some((o) => o.id === v.correct) ? [v.correct] : [],
    explanation: str(v.explanation).trim(),
    ...(nullable as Record<(typeof NULLABLE)[number], string | null>),
  };
}

function toState(err: ApiError, status: number): ActionState {
  if (status === 401) redirect('/login');
  const fieldErrors: Record<string, string[]> = {};
  const otherErrors: string[] = [];
  for (const d of err.details ?? []) {
    // "options.0.text" → "options"
    const field = d.field?.split('.')[0];
    if (field) (fieldErrors[field] ??= []).push(d.reason);
    else otherErrors.push(d.reason);
  }
  return { error: err.message, fieldErrors, otherErrors };
}

export async function createQuestion(_: ActionState, input: QuestionInput): Promise<ActionState> {
  const client = await api();
  const { data, error, response } = await client.POST('/v1/editor/questions', { body: toBody(input) });
  if (!data) return toState(asApiError(error, response.status), response.status);
  redirect(`/questions/${data.id}`);
}

export async function saveQuestion(id: string, _: ActionState, input: QuestionInput): Promise<ActionState> {
  const client = await api();
  const { data, error, response } = await client.PATCH('/v1/editor/questions/{id}', {
    params: { path: { id } },
    body: toBody(input),
  });
  if (!data) return toState(asApiError(error, response.status), response.status);
  refresh();
  return { ok: true, message: 'Saved' };
}

const PATHS = {
  submit: '/v1/editor/questions/{id}/submit',
  request_changes: '/v1/editor/questions/{id}/request-changes',
  approve: '/v1/editor/questions/{id}/approve',
  publish: '/v1/editor/questions/{id}/publish',
  revise: '/v1/editor/questions/{id}/revise',
  retire: '/v1/editor/questions/{id}/retire',
} as const;

const DONE: Record<WorkflowAction, string> = {
  submit: 'Sent for review',
  request_changes: 'Sent back to the editor',
  approve: 'Approved',
  publish: 'Published',
  revise: 'New draft version started',
  retire: 'Retired',
};

/** Runs one lifecycle step. Reason, note and change note come from the form. */
export async function runAction(id: string, action: WorkflowAction, _: ActionState, form: FormData): Promise<ActionState> {
  if (!(action in PATHS)) return { error: 'Unknown action' };
  const text = (k: string) => String(form.get(k) ?? '').trim();
  const body =
    action === 'request_changes' || action === 'retire'
      ? { reason: text('reason') }
      : action === 'revise'
        ? { change_note: text('change_note') }
        : action === 'approve'
          ? text('note')
            ? { note: text('note') }
            : {}
          : undefined;

  const client = await api();
  // The paths share a shape; the union keeps openapi-fetch's typing happy.
  const { data, error, response } = await client.POST(PATHS[action] as '/v1/editor/questions/{id}/approve', {
    params: { path: { id } },
    body: body as { note?: string },
  });
  if (!data) return toState(asApiError(error, response.status), response.status);
  refresh();
  return { ok: true, message: DONE[action] };
}
