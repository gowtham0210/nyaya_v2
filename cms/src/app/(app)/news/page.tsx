import type { Metadata } from 'next';
import Link from 'next/link';
import { Suspense } from 'react';
import { StatusBadge } from '@/components/status-badge';
import { Skeleton, buttonClass, inputClass } from '@/components/ui';
import { api, must, type NewsStatus } from '@/lib/api';
import { getMe } from '@/lib/session';
import { NEWS_CATEGORY_LABEL, NEWS_WORKFLOW, STATUS_LABEL, hasRole } from '@/lib/workflow';

export const metadata: Metadata = { title: 'News' };

const STATUSES: NewsStatus[] = ['draft', 'in_review', 'changes_requested', 'approved', 'published', 'retired'];
const DATE = new Intl.DateTimeFormat('en-IN', { dateStyle: 'medium' });

export default function NewsPage({ searchParams }: PageProps<'/news'>) {
  return (
    <div className="flex flex-col gap-6">
      <Suspense
        fallback={
          <>
            <Skeleton className="h-12 w-64" />
            <Skeleton className="h-96" />
          </>
        }
      >
        <NewsList searchParams={searchParams} />
      </Suspense>
    </div>
  );
}

const first = (v: string | string[] | undefined) => (Array.isArray(v) ? v[0] : v) || undefined;

async function NewsList({ searchParams }: { searchParams: PageProps<'/news'>['searchParams'] }) {
  const sp = await searchParams;
  const status = STATUSES.find((s) => s === first(sp.status));
  const q = first(sp.q);
  const cursor = first(sp.cursor);

  const client = await api();
  const [me, page] = await Promise.all([
    getMe(),
    client.GET('/v1/editor/news', { params: { query: { status, q, cursor, limit: 25 } } }).then(must),
  ]);
  const href = (patch: Record<string, string | undefined>) => {
    const p = new URLSearchParams();
    for (const [k, v] of Object.entries({ status, q, ...patch })) if (v) p.set(k, v);
    const s = p.toString();
    return s ? `/news?${s}` : '/news';
  };

  return (
    <>
      <div className="flex flex-wrap items-end justify-between gap-4">
        <div>
          <h1 className="font-serif text-4xl">News</h1>
          <p className="mt-1 text-sm text-muted">
            Legal updates for the app&apos;s Updates tab, in English. Learners see published articles only, newest date first.
          </p>
        </div>
        {hasRole(me, ...NEWS_WORKFLOW.submit.roles) && (
          <Link href="/news/new" className={buttonClass()}>
            New article
          </Link>
        )}
      </div>

      <form method="get" action="/news" className="grid gap-3 sm:grid-cols-[1fr_14rem_auto]" role="search">
        <label className="sr-only" htmlFor="q">Search</label>
        <input id="q" name="q" defaultValue={q} placeholder="Search titles" className={inputClass} />
        <label className="sr-only" htmlFor="status">Status</label>
        <select id="status" name="status" defaultValue={status ?? ''} className={inputClass}>
          <option value="">Any status</option>
          {STATUSES.map((s) => (
            <option key={s} value={s}>{STATUS_LABEL[s]}</option>
          ))}
        </select>
        <button type="submit" className={buttonClass('secondary')}>Filter</button>
      </form>

      {page.items.length === 0 ? (
        <div className="rounded-xl border border-dashed border-border px-6 py-16 text-center text-muted">No articles match these filters.</div>
      ) : (
        <div className="overflow-x-auto rounded-xl border border-border">
          <table className="w-full text-sm">
            <thead className="bg-surface-2 text-left text-xs text-muted">
              <tr>
                <th scope="col" className="px-4 py-2 font-medium">Title</th>
                <th scope="col" className="px-4 py-2 font-medium">Category</th>
                <th scope="col" className="px-4 py-2 font-medium">Date</th>
                <th scope="col" className="px-4 py-2 font-medium">Status</th>
              </tr>
            </thead>
            <tbody>
              {page.items.map((a) => (
                <tr key={a.id} className="border-t border-border">
                  <td className="px-4 py-3">
                    <Link href={`/news/${a.id}`} className="font-medium hover:text-primary hover:underline">
                      {a.title || 'Untitled draft'}
                    </Link>
                  </td>
                  <td className="px-4 py-3 whitespace-nowrap text-muted">{NEWS_CATEGORY_LABEL[a.category]}</td>
                  <td className="px-4 py-3 whitespace-nowrap text-muted">{a.event_date ? DATE.format(new Date(a.event_date)) : '—'}</td>
                  <td className="px-4 py-3"><StatusBadge status={a.status} /></td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      )}

      <div className="flex justify-between text-sm">
        {cursor ? <Link href={href({ cursor: undefined })} className="text-primary hover:underline">← First page</Link> : <span />}
        {page.next_cursor && (
          <Link href={href({ cursor: page.next_cursor })} className="text-primary hover:underline">Next page →</Link>
        )}
      </div>
    </>
  );
}
