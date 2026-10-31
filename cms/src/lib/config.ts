/** Base URL of the Nyaya API (server-side only; the browser never calls it). */
export const API_URL = process.env.API_URL ?? 'http://localhost:3000';

/**
 * Headers telling the API which browser a sign-in, refresh or password setup
 * came from, so its limits count each person and not this server. The API
 * trusts them only with the shared PORTAL_PROXY_SECRET. The address is the
 * X-Real-IP header that nginx in front of the portal sets.
 */
export function clientAddressHeaders(realIp: string | null | undefined): Record<string, string> {
  const secret = process.env.PORTAL_PROXY_SECRET;
  if (!secret || !realIp) return {};
  return { 'x-nyaya-client-ip': realIp, 'x-nyaya-proxy-secret': secret };
}
