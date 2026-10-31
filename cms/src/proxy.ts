import { NextResponse, type NextRequest } from 'next/server';
import { API_URL, clientAddressHeaders } from './lib/config';
import {
  ACCESS_COOKIE,
  REFRESH_COOKIE,
  SESSION_ENDED_PARAM,
  clearSessionCookies,
  setSessionCookies,
  type SessionTokens,
} from './lib/session-cookies';

/**
 * Keeps the session alive: when the short-lived access cookie has expired
 * but a refresh token remains, swap it for a new pair before the page renders.
 * Pages without a session go to /login.
 */

// Parallel requests carrying the same refresh token share one refresh, since
// each refresh token is single-use. Kept briefly so stragglers reuse the result.
const inflight = new Map<string, { at: number; result: Promise<SessionTokens | null> }>();
const SHARE_MS = 20_000;

function refreshOnce(token: string, realIp: string | null): Promise<SessionTokens | null> {
  const now = Date.now();
  for (const [k, v] of inflight) if (now - v.at > SHARE_MS) inflight.delete(k);
  const hit = inflight.get(token);
  if (hit) return hit.result;
  const result = fetch(`${API_URL}/v1/auth/refresh`, {
    method: 'POST',
    headers: { 'content-type': 'application/json', ...clientAddressHeaders(realIp) },
    body: JSON.stringify({ refresh_token: token }),
  })
    .then((r) => (r.ok ? (r.json() as Promise<SessionTokens>) : null))
    .catch(() => null);
  inflight.set(token, { at: now, result });
  return result;
}

export async function proxy(req: NextRequest) {
  const { pathname, search } = req.nextUrl;
  // Choosing a password from a setup link needs no session.
  if (pathname === '/setup') return NextResponse.next();
  const onLogin = pathname === '/login';
  const access = req.cookies.get(ACCESS_COOKIE)?.value;
  const refresh = req.cookies.get(REFRESH_COOKIE)?.value;

  if (onLogin && req.nextUrl.searchParams.has(SESSION_ENDED_PARAM)) {
    const res = NextResponse.next();
    clearSessionCookies(res.cookies);
    return res;
  }

  if (access) return onLogin ? NextResponse.redirect(new URL('/questions', req.url)) : NextResponse.next();

  if (refresh) {
    const session = await refreshOnce(refresh, req.headers.get('x-real-ip'));
    if (session) {
      // Forward the new tokens to this render as well as to the browser.
      req.cookies.set(ACCESS_COOKIE, session.access_token);
      req.cookies.set(REFRESH_COOKIE, session.refresh_token);
      const res = onLogin
        ? NextResponse.redirect(new URL('/questions', req.url))
        : NextResponse.next({ request: { headers: req.headers } });
      setSessionCookies(res.cookies, session);
      return res;
    }
  }

  if (onLogin) {
    const res = NextResponse.next();
    if (refresh) clearSessionCookies(res.cookies);
    return res;
  }
  const login = new URL('/login', req.url);
  if (pathname !== '/') login.searchParams.set('next', pathname + search);
  const res = NextResponse.redirect(login);
  clearSessionCookies(res.cookies);
  return res;
}

export const config = {
  matcher: ['/((?!_next/static|_next/image|favicon.ico|.*\\.(?:svg|png|jpg|jpeg|webp|ico)$).*)'],
};
