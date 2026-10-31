import 'server-only';
import createClient from 'openapi-fetch';
import { cookies } from 'next/headers';
import { notFound, redirect } from 'next/navigation';
import { API_URL } from './config';
import type { components, paths } from './api-schema';
import { ACCESS_COOKIE, SESSION_ENDED_URL } from './session-cookies';

export type Schemas = components['schemas'];
export type Me = Schemas['MeDto'];
export type Question = Schemas['QuestionDetailDto'];
export type Version = Schemas['VersionDto'];
export type Taxonomy = Schemas['TaxonomyDto'];
export type VersionStatus = Version['status'];
export type News = Schemas['NewsDetailDto'];
export type NewsStatus = News['status'];
export type NewsCategory = News['category'];

/** The API's standard error body. */
export interface ApiError {
  code: string;
  message: string;
  details: { field?: string; reason: string }[] | null;
  request_id?: string;
}

/** An API client acting as the signed-in user. */
export async function api() {
  const token = (await cookies()).get(ACCESS_COOKIE)?.value;
  return createClient<paths>({
    baseUrl: API_URL,
    headers: token ? { Authorization: `Bearer ${token}` } : {},
  });
}

/**
 * Unwraps a read: signed-out users go to sign-in, missing things 404, and
 * anything else throws to the nearest error boundary.
 */
export function must<T>(res: { data?: T; error?: unknown; response: Response }): T {
  if (res.data !== undefined) return res.data;
  const status = res.response.status;
  if (status === 401) redirect(SESSION_ENDED_URL);
  if (status === 404) notFound();
  const err = res.error as ApiError | undefined;
  throw new Error(err?.message ?? `The API returned ${status}`);
}

export function asApiError(error: unknown, status: number): ApiError {
  if (error && typeof error === 'object' && 'code' in error) return error as ApiError;
  return { code: 'error', message: `The API returned ${status}`, details: null };
}
