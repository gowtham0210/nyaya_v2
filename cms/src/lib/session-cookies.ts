/**
 * The API tokens live in httpOnly cookies, so browser scripts never see them.
 * Shared by the sign-in action and the proxy, which both speak this
 * cookie-store shape.
 */

export const ACCESS_COOKIE = 'nyaya_at';
export const REFRESH_COOKIE = 'nyaya_rt';

/**
 * Where to send someone whose access cookie the API rejected (a restarted dev
 * API, a disabled account). The proxy clears the session on this URL instead
 * of bouncing a still-present access cookie back into the app.
 */
export const SESSION_ENDED_PARAM = 'ended';
export const SESSION_ENDED_URL = `/login?${SESSION_ENDED_PARAM}=1`;

const REFRESH_MAX_AGE = 30 * 24 * 60 * 60;
/** Drop the access cookie a little early so the proxy refreshes before the API rejects it. */
const EXPIRY_MARGIN_SEC = 30;

export interface SessionTokens {
  access_token: string;
  expires_in: number;
  refresh_token: string;
}

interface CookieWriter {
  set(name: string, value: string, options: Record<string, unknown>): unknown;
  delete(name: string): unknown;
}

const base = () => ({
  httpOnly: true,
  secure: process.env.NODE_ENV === 'production',
  sameSite: 'lax' as const,
  path: '/',
});

export function setSessionCookies(store: CookieWriter, s: SessionTokens) {
  store.set(ACCESS_COOKIE, s.access_token, { ...base(), maxAge: Math.max(s.expires_in - EXPIRY_MARGIN_SEC, 1) });
  store.set(REFRESH_COOKIE, s.refresh_token, { ...base(), maxAge: REFRESH_MAX_AGE });
}

export function clearSessionCookies(store: CookieWriter) {
  store.delete(ACCESS_COOKIE);
  store.delete(REFRESH_COOKIE);
}
