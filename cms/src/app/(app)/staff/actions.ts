'use server';

import { refresh } from 'next/cache';
import { redirect } from 'next/navigation';
import { api, asApiError, type ApiError } from '@/lib/api';
import { SESSION_ENDED_URL } from '@/lib/session-cookies';
import { STAFF_ROLES } from '@/lib/workflow';

/*
 * Staff account changes as the signed-in admin; the API checks the role and
 * the rules (never your own admin role, never the last admin).
 */

export interface StaffState {
  ok?: boolean;
  message?: string;
  error?: string;
  /** A fresh one-time link token, shown once. */
  setup?: { token: string; expiresAt: string; name: string };
}

type Role = (typeof STAFF_ROLES)[number];
const rolesOf = (form: FormData) => form.getAll('roles').filter((r): r is Role => STAFF_ROLES.includes(r as Role));

function failed(err: ApiError | undefined, status: number): StaffState {
  if (status === 401) redirect(SESSION_ENDED_URL);
  const e = err ?? asApiError(undefined, status);
  const reasons = (e.details ?? []).map((d) => d.reason).join('; ');
  return { error: reasons && e.code === 'validation_failed' ? `${e.message}: ${reasons}` : e.message };
}

export async function inviteStaff(_: StaffState, form: FormData): Promise<StaffState> {
  const client = await api();
  const { data, error, response } = await client.POST('/v1/admin/staff', {
    body: {
      email: String(form.get('email') ?? '').trim(),
      display_name: String(form.get('display_name') ?? '').trim(),
      roles: rolesOf(form),
    },
  });
  if (!data) return failed(asApiError(error, response.status), response.status);
  refresh();
  return { ok: true, setup: { token: data.setup_token, expiresAt: data.expires_at, name: data.staff.display_name } };
}

export async function updateStaff(id: string, _: StaffState, form: FormData): Promise<StaffState> {
  const client = await api();
  const { data, error, response } = await client.PATCH('/v1/admin/staff/{id}', {
    params: { path: { id } },
    body: { display_name: String(form.get('display_name') ?? '').trim(), roles: rolesOf(form) },
  });
  if (!data) return failed(asApiError(error, response.status), response.status);
  refresh();
  return { ok: true, message: 'Saved' };
}

export async function setStaffActive(id: string, active: boolean): Promise<StaffState> {
  const client = await api();
  const { data, error, response } = await client.PATCH('/v1/admin/staff/{id}', {
    params: { path: { id } },
    body: { is_active: active },
  });
  if (!data) return failed(asApiError(error, response.status), response.status);
  refresh();
  return { ok: true };
}

export async function newSetupLink(id: string): Promise<StaffState> {
  const client = await api();
  const { data, error, response } = await client.POST('/v1/admin/staff/{id}/setup-link', {
    params: { path: { id } },
  });
  if (!data) return failed(asApiError(error, response.status), response.status);
  refresh();
  return { ok: true, setup: { token: data.setup_token, expiresAt: data.expires_at, name: data.staff.display_name } };
}
