'use server';

import { refresh } from 'next/cache';
import { redirect } from 'next/navigation';
import { api, asApiError } from '@/lib/api';
import { SESSION_ENDED_URL } from '@/lib/session-cookies';
import type { ActionState } from '../questions/form-state';

export type TaxonomyKind = 'subjects' | 'topics' | 'acts';

// Server actions take any arguments a caller sends; only these become API paths.
const KINDS: readonly string[] = ['subjects', 'topics', 'acts'] satisfies TaxonomyKind[];

/*
 * Adds (no id) or changes (id) a subject, topic or act as the signed-in user;
 * the API decides who may. Form values arrive as text and are typed here.
 */

const text = (form: FormData, k: string) => {
  const v = form.get(k);
  return typeof v === 'string' ? v.trim() : undefined;
};

function toBody(kind: TaxonomyKind, form: FormData, creating: boolean) {
  const body: Record<string, unknown> = {};
  const set = (k: string, v: unknown) => {
    if (v !== undefined) body[k] = v;
  };
  set('name', text(form, 'name'));
  if (creating) set('slug', text(form, 'slug'));
  if (kind === 'acts') {
    const short = text(form, 'short_name');
    set('short_name', short === undefined ? undefined : short || null);
    const year = text(form, 'year');
    set('year', year === undefined ? undefined : year ? Number(year) : null);
  } else {
    const description = text(form, 'description');
    set('description', description === undefined ? undefined : description || null);
    const order = text(form, 'sort_order');
    if (order) set('sort_order', Number(order));
  }
  if (kind === 'topics') {
    if (creating) set('subject_id', text(form, 'subject_id'));
    const act = text(form, 'act_id');
    set('act_id', act === undefined ? undefined : act || null);
  }
  return body;
}

async function send(kind: TaxonomyKind, id: string | null, body: Record<string, unknown>): Promise<ActionState> {
  if (!KINDS.includes(kind)) return { error: 'Unknown kind' };
  const client = await api();
  const res = id
    ? await client.PATCH(`/v1/admin/${kind}/{id}` as '/v1/admin/topics/{id}', {
        params: { path: { id } },
        body: body as never,
      })
    : await client.POST(`/v1/admin/${kind}` as '/v1/admin/topics', { body: body as never });
  if (!res.data) {
    if (res.response.status === 401) redirect(SESSION_ENDED_URL);
    const err = asApiError(res.error, res.response.status);
    const fieldErrors: Record<string, string[]> = {};
    const otherErrors: string[] = [];
    for (const d of err.details ?? []) {
      if (d.field) (fieldErrors[d.field] ??= []).push(d.reason);
      else otherErrors.push(d.reason);
    }
    return { error: err.message, fieldErrors, otherErrors };
  }
  refresh();
  return { ok: true, message: id ? 'Saved' : 'Added' };
}

export async function saveTaxonomy(
  kind: TaxonomyKind,
  id: string | null,
  _: ActionState,
  form: FormData,
): Promise<ActionState> {
  return send(kind, id, toBody(kind, form, id === null));
}

/** Shows or hides one subject, topic or act. */
export async function setActive(kind: TaxonomyKind, id: string, active: boolean): Promise<ActionState> {
  return send(kind, id, { is_active: active });
}
