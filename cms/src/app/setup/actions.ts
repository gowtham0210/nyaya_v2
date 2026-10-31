'use server';

import { headers } from 'next/headers';
import { redirect } from 'next/navigation';
import { API_URL, clientAddressHeaders } from '@/lib/config';

export interface SetupState {
  error?: string;
}

/** Sends the link's token and the chosen password; the API checks both. */
export async function choosePassword(token: string, _: SetupState, form: FormData): Promise<SetupState> {
  const password = String(form.get('password') ?? '');
  if (password !== String(form.get('repeat') ?? '')) return { error: 'The two passwords are different.' };
  if (password.length < 12) return { error: 'Use at least 12 characters.' };
  if (!token) return { error: 'This page needs the full link you were sent.' };

  let res: Response;
  try {
    res = await fetch(`${API_URL}/v1/auth/setup-password`, {
      method: 'POST',
      headers: { 'content-type': 'application/json', ...clientAddressHeaders((await headers()).get('x-real-ip')) },
      body: JSON.stringify({ token, password }),
    });
  } catch {
    return { error: 'Cannot reach the Nyaya API. Try again in a moment.' };
  }
  if (res.status === 429) return { error: 'Too many attempts. Wait a minute and try again.' };
  if (!res.ok) {
    const body = (await res.json().catch(() => ({}))) as { code?: string; message?: string };
    return {
      error:
        body.code === 'invalid_link'
          ? 'This link is not valid any more. Ask an admin for a new one.'
          : (body.message ?? 'The password could not be saved.'),
    };
  }
  redirect('/login?password_set=1');
}
