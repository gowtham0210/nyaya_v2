import { redirect } from 'next/navigation';
import { api } from '@/lib/api';
import { SESSION_ENDED_URL } from '@/lib/session-cookies';

const STATUSES = ['draft', 'in_review', 'changes_requested', 'approved', 'published', 'superseded', 'retired'] as const;

/** Downloads the question bank as the signed-in user; the API decides who may. */
export async function GET(request: Request) {
  const sp = new URL(request.url).searchParams;
  const format = sp.get('format') === 'xlsx' ? 'xlsx' : 'csv';
  const status = STATUSES.find((s) => s === sp.get('status'));
  const topic = sp.get('topic');
  const client = await api();
  const { response } = await client.GET('/v1/admin/question-export', {
    params: {
      query: { format, status, topic_id: topic && /^[0-9a-f-]{36}$/i.test(topic) ? topic : undefined },
    },
    parseAs: 'stream',
  });
  if (response.status === 401) redirect(SESSION_ENDED_URL);
  if (!response.ok) return new Response('The export could not be made.', { status: response.status });
  return new Response(response.body, {
    headers: {
      'content-type': response.headers.get('content-type') ?? 'application/octet-stream',
      'content-disposition': response.headers.get('content-disposition') ?? 'attachment',
      'cache-control': 'no-store',
    },
  });
}
