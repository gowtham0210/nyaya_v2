import type { Metadata } from 'next';
import Link from 'next/link';
import { Suspense } from 'react';
import { Skeleton, buttonClass, inputClass } from '@/components/ui';
import { api, must, type VersionStatus } from '@/lib/api';
import { getAllTaxonomy, getMe, getTopicNames } from '@/lib/session';
import { BULK_ACTIONS, STATUS_LABEL, WORKFLOW, hasRole } from '@/lib/workflow';
import { QuestionTable } from './question-table';

export const metadata: Metadata = { title: 'Questions' };

const STATUSES = Object.keys(STATUS_LABEL) as VersionStatus[];
const PAGE_SIZES = ['25', '50', '100'];

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
  const per = PAGE_SIZES.find((n) => n === first(sp.per));

  const client = await api();
  const [me, taxonomy, topicNames, page] = await Promise.all([
    getMe(),
    getAllTaxonomy(),
    getTopicNames(),
    client
      .GET('/v1/editor/questions', {
        params: { query: { status, topic_id: topic, q, cursor, limit: Number(per ?? 25) } },
      })
      .then(must),
  ]);

  const href = (patch: Record<string, string | undefined>) => {
    const p = new URLSearchParams();
    for (const [k, v] of Object.entries({ status, topic, q, per, ...patch })) if (v) p.set(k, v);
    const s = p.toString();
    return s ? `/questions?${s}` : '/questions';
  };
  // The export follows the status and topic filters (not search or paging).
  const exportQuery = (format: 'csv' | 'xlsx') =>
    new URLSearchParams(Object.entries({ format, status, topic }).filter((e): e is [string, string] => !!e[1])).toString();
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
        <div className="flex flex-wrap gap-2">
          {/* Plain links: these are file downloads, not pages. */}
          <a href={`/questions/export?${exportQuery('csv')}`} download className={buttonClass('secondary')}>
            Export CSV
          </a>
          <a href={`/questions/export?${exportQuery('xlsx')}`} download className={buttonClass('secondary')}>
            Export Excel
          </a>
          {hasRole(me, 'content_editor') && (
            <Link href="/questions/new" className={buttonClass()}>
              New question
            </Link>
          )}
        </div>
      </div>

      <form method="get" action="/questions" className="grid gap-3 sm:grid-cols-[1fr_12rem_14rem_7rem_auto]" role="search">
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
                <option key={t.id} value={t.id}>
                  {t.name}
                  {s.is_active && t.is_active ? '' : ' (hidden)'}
                </option>
              ))}
            </optgroup>
          ))}
        </select>
        <label className="sr-only" htmlFor="per">Questions per page</label>
        <select id="per" name="per" defaultValue={per ?? '25'} className={inputClass}>
          {PAGE_SIZES.map((n) => (
            <option key={n} value={n}>{n} a page</option>
          ))}
        </select>
        <button type="submit" className={buttonClass('secondary')}>Filter</button>
      </form>

      {page.items.length === 0 ? (
        <div className="rounded-xl border border-dashed border-border px-6 py-16 text-center text-muted">
          No questions match these filters.
        </div>
      ) : (
        <QuestionTable
          // A new page or filter starts with nothing selected.
          key={href({ cursor })}
          actions={BULK_ACTIONS.filter((a) => hasRole(me, ...WORKFLOW[a].roles))}
          rows={page.items.map((item) => ({
            id: item.id,
            stem: item.latest.stem,
            versionNo: item.latest.version_no,
            status: item.latest.status,
            topic: topicNames.get(item.latest.topic_id) ?? '—',
            live: item.live_version_id ? 'Yes' : item.retired_at ? 'Retired' : '—',
          }))}
        />
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
