'use server';

import { cookies } from 'next/headers';
import { redirect } from 'next/navigation';
import { API_URL } from '@/lib/config';
import { REFRESH_COOKIE, clearSessionCookies } from '@/lib/session-cookies';

export async function signOut() {
  const store = await cookies();
  const refresh = store.get(REFRESH_COOKIE)?.value;
  if (refresh) {
    // Best effort: the cookies are cleared either way.
    await fetch(`${API_URL}/v1/auth/sign-out`, {
      method: 'POST',
      headers: { 'content-type': 'application/json' },
      body: JSON.stringify({ refresh_token: refresh }),
    }).catch(() => undefined);
  }
  clearSessionCookies(store);
  redirect('/login');
}
