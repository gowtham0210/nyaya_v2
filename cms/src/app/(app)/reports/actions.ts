'use server';

import { refresh } from 'next/cache';
import { redirect } from 'next/navigation';
import { api, asApiError } from '@/lib/api';
import { SESSION_ENDED_URL } from '@/lib/session-cookies';
import type { ActionState } from '../questions/form-state';

const OUTCOMES = ['fixed', 'retired', 'no_change'] as const;

/** Closes a report. Fix or retire the question first; this only records the outcome. */
export async function resolveReport(id: string, _: ActionState, form: FormData): Promise<ActionState> {
  const outcome = OUTCOMES.find((o) => o === form.get('outcome'));
  const note = String(form.get('note') ?? '').trim();
  if (!outcome) return { error: 'Choose what was done' };
  const client = await api();
  const { data, error, response } = await client.PATCH('/v1/admin/content-reports/{id}', {
    params: { path: { id } },
    body: { outcome, note },
  });
  if (!data) {
    if (response.status === 401) redirect(SESSION_ENDED_URL);
    return { error: asApiError(error, response.status).message };
  }
  refresh();
  return { ok: true, message: 'Report closed' };
}
