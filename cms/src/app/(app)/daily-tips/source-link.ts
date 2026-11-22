/**
 * Whether [url] points at the exact page a tip rests on. A bare site address
 * (https://www.indiacode.nic.in/) names a website, not a provision. The API
 * applies the same rule before it records a check.
 */
export function isExactSourceLink(url: string | null): boolean {
  if (!url || !/^https:\/\/\S+$/.test(url)) return false;
  try {
    const u = new URL(url);
    return u.pathname.replace(/\/+$/, '') !== '' || u.search !== '';
  } catch {
    return false;
  }
}
