import { cookies } from 'next/headers';
import { API_URL } from '@/lib/config';
import { ACCESS_COOKIE } from '@/lib/session-cookies';

/**
 * The article's card picture for the portal, fetched from the API as the
 * signed-in user (drafts' pictures are staff-only, so the browser can't load
 * them from the API directly).
 */
export async function GET(_: Request, { params }: { params: Promise<{ id: string }> }) {
  const { id } = await params;
  if (!/^[0-9a-f-]{36}$/i.test(id)) return new Response(null, { status: 404 });
  const token = (await cookies()).get(ACCESS_COOKIE)?.value;
  if (!token) return new Response(null, { status: 401 });
  const res = await fetch(`${API_URL}/v1/editor/news/${id}/image`, {
    headers: { Authorization: `Bearer ${token}` },
    cache: 'no-store',
  });
  if (!res.ok) return new Response(null, { status: res.status === 404 ? 404 : 502 });
  return new Response(res.body, {
    headers: {
      'content-type': 'image/webp',
      // Staff only; the address carries the picture's version.
      'cache-control': 'private, max-age=3600',
    },
  });
}
