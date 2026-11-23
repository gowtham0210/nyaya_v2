import { redirect } from 'next/navigation';
import { api } from '@/lib/api';
import { SESSION_ENDED_URL } from '@/lib/session-cookies';

/** Downloads a blank import template as the signed-in user; the API decides who may. */
export async function GET(request: Request) {
  const sp = new URL(request.url).searchParams;
  const kind = sp.get('kind') === 'exam' ? 'exam' : 'general';
  const format = sp.get('format') === 'csv' ? 'csv' : 'xlsx';
  const exam = sp.get('exam');
  const client = await api();
  const { response } = await client.GET('/v1/admin/import-templates', {
    params: {
      query: { kind, format, exam: kind === 'exam' && exam && /^[a-z0-9][a-z0-9-]{0,40}$/.test(exam) ? exam : undefined },
    },
    parseAs: 'stream',
  });
  if (response.status === 401) redirect(SESSION_ENDED_URL);
  if (!response.ok) return new Response('The template could not be made.', { status: response.status });
  return new Response(response.body, {
    headers: {
      'content-type': response.headers.get('content-type') ?? 'application/octet-stream',
      'content-disposition': response.headers.get('content-disposition') ?? 'attachment',
      'cache-control': 'no-store',
    },
  });
}
