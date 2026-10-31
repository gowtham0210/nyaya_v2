'use server';

import { cookies, headers } from 'next/headers';
import { redirect } from 'next/navigation';
import { API_URL, clientAddressHeaders } from '@/lib/config';
import { setSessionCookies, type SessionTokens } from '@/lib/session-cookies';

export interface SignInState {
  error?: string;
  email?: string;
}

/** Only same-site paths, so a crafted link cannot bounce users elsewhere. */
function safeNext(value: FormDataEntryValue | null): string {
  const next = typeof value === 'string' ? value : '';
  return next.startsWith('/') && !next.startsWith('//') && !next.startsWith('/\\') ? next : '/questions';
}

export async function signIn(_: SignInState, form: FormData): Promise<SignInState> {
  const email = String(form.get('email') ?? '').trim();
  const password = String(form.get('password') ?? '');
  if (!email || !password) return { error: 'Enter your email and password.', email };

  let res: Response;
  try {
    res = await fetch(`${API_URL}/v1/auth/session`, {
      method: 'POST',
      headers: { 'content-type': 'application/json', ...clientAddressHeaders((await headers()).get('x-real-ip')) },
      body: JSON.stringify({ email, password }),
    });
  } catch {
    return { error: 'Cannot reach the Nyaya API. Is the backend running?', email };
  }
  if (res.status === 429) {
    // The API says how long: a minute for one address, longer for one account.
    const body = (await res.json().catch(() => ({}))) as { message?: string };
    return { error: body.message ?? 'Too many attempts. Wait a minute and try again.', email };
  }
  if (res.status === 400) return { error: 'Enter a valid email address.', email };
  if (!res.ok) return { error: 'Email or password is incorrect.', email };

  setSessionCookies(await cookies(), (await res.json()) as SessionTokens);
  redirect(safeNext(form.get('next')));
}
