import type { Metadata } from 'next';
import Link from 'next/link';
import { Suspense } from 'react';
import { StatusBadge } from '@/components/status-badge';
import { Skeleton, buttonClass, inputClass } from '@/components/ui';
import { api, must, type VersionStatus } from '@/lib/api';
import { getMe, getTaxonomy, getTopicNames } from '@/lib/session';
import { STATUS_LABEL, hasRole } from '@/lib/workflow';

export const metadata: Metadata = { title: 'Questions' };

const STATUSES = Object.keys(STATUS_LABEL) as VersionStatus[];

export default function QuestionsPage({ searchParams }: PageProps<'/questions'>) {
  return (
    <div className="flex flex-col gap-6">
      <Suspense fallback={<ListSkeleton />}>
        <QuestionList searchParams={searchParams} />
      </Suspense>
    </div>
  );
}

const first = (v: string | string[] | undefined) => (Array.isArray(v) ? v[0] : v) || undefined;

async function QuestionList({ searchParams }: { searchParams: PageProps<'/questions'>['searchParams'] }) {
  const sp = await searchParams;
  const status = STATUSES.find((s) => s === first(sp.status));
  const topic = first(sp.topic);
  const q = first(sp.q);
  const cursor = first(sp.cursor);

  const client = await api();
  const [me, taxonomy, topicNames, page] = await Promise.all([
    getMe(),
    getTaxonomy(),
    getTopicNames(),
    client
      .GET('/v1/editor/questions', {
        params: { query: { status, topic_id: topic, q, cursor, limit: 25 } },
      })
      .then(must),
  ]);

  const href = (patch: Record<string, string | undefined>) => {
    const p = new URLSearchParams();
    for (const [k, v] of Object.entries({ status, topic, q, ...patch })) if (v) p.set(k, v);
    const s = p.toString();
    return s ? `/questions?${s}` : '/questions';
  };
  const title = status === 'in_review' ? 'Review queue' : status === 'approved' ? 'Ready to publish' : 'Questions';

  return (
    <>
      <div className="flex flex-wrap items-end justify-between gap-4">
        <div>
          <h1 className="font-serif text-4xl">{title}</h1>
          <p className="mt-1 text-sm text-muted">
            {status ? `Questions whose latest version is ${STATUS_LABEL[status].toLowerCase()}.` : 'Every question and its latest version.'}
          </p>
        </div>
        {hasRole(me, 'content_editor') && (
          <Link href="/questions/new" className={buttonClass()}>
            New question
          </Link>
        )}
      </div>

      <form method="get" action="/questions" className="grid gap-3 sm:grid-cols-[1fr_12rem_14rem_auto]" role="search">
        <label className="sr-only" htmlFor="q">Search</label>
        <input id="q" name="q" defaultValue={q} placeholder="Search question text" className={inputClass} />
        <label className="sr-only" htmlFor="status">Status</label>
        <select id="status" name="status" defaultValue={status ?? ''} className={inputClass}>
          <option value="">Any status</option>
          {STATUSES.map((s) => (
            <option key={s} value={s}>{STATUS_LABEL[s]}</option>
          ))}
        </select>
        <label className="sr-only" htmlFor="topic">Topic</label>
        <select id="topic" name="topic" defaultValue={topic ?? ''} className={inputClass}>
          <option value="">Any topic</option>
          {taxonomy.subjects.map((s) => (
            <optgroup key={s.id} label={s.name}>
              {s.topics.map((t) => (
                <option key={t.id} value={t.id}>{t.name}</option>
              ))}
            </optgroup>
          ))}
        </select>
        <button type="submit" className={buttonClass('secondary')}>Filter</button>
      </form>

      {page.items.length === 0 ? (
        <div className="rounded-xl border border-dashed border-border px-6 py-16 text-center text-muted">
          No questions match these filters.
        </div>
      ) : (
        <div className="overflow-x-auto rounded-xl border border-border bg-surface">
          <table className="w-full min-w-[640px] text-sm">
            <thead className="border-b border-border text-left text-xs tracking-wide text-muted uppercase">
              <tr>
                <th className="px-4 py-3 font-medium">Question</th>
                <th className="px-4 py-3 font-medium">Topic</th>
                <th className="px-4 py-3 font-medium">Status</th>
                <th className="px-4 py-3 font-medium">Live</th>
              </tr>
            </thead>
            <tbody className="divide-y divide-border">
              {page.items.map((item) => (
                <tr key={item.id} className="hover:bg-surface-2/60">
                  <td className="max-w-md px-4 py-3">
                    <Link href={`/questions/${item.id}`} className="line-clamp-2 font-medium hover:text-primary">
                      {item.latest.stem || <span className="text-muted italic">Untitled draft</span>}
                    </Link>
                    <span className="text-xs text-muted">v{item.latest.version_no}</span>
                  </td>
                  <td className="px-4 py-3 text-muted">{topicNames.get(item.latest.topic_id) ?? '—'}</td>
                  <td className="px-4 py-3"><StatusBadge status={item.latest.status} /></td>
                  <td className="px-4 py-3 text-muted">
                    {item.live_version_id ? 'Yes' : item.retired_at ? 'Retired' : '—'}
                  </td>
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

function ListSkeleton() {
  return (
    <>
      <Skeleton className="h-12 w-64" />
      <Skeleton className="h-10" />
      <Skeleton className="h-96" />
    </>
  );
}
