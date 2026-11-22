import { FilterForm } from '@/components/filter-form';
import type { Metadata } from 'next';
import Link from 'next/link';
import { Suspense } from 'react';
import { StatusBadge } from '@/components/status-badge';
import { Skeleton, buttonClass, inputClass } from '@/components/ui';
import { api, must, type DailyTipCategory, type DailyTipStatus } from '@/lib/api';
import { getMe } from '@/lib/session';
import { PublishAllApproved } from './publish-all';
import { STATUS_LABEL, TIP_CATEGORY_LABEL, TIP_LANGUAGE_LABEL, TIP_WORKFLOW, hasRole } from '@/lib/workflow';

export const metadata: Metadata = { title: 'Daily tips' };

const STATUSES: DailyTipStatus[] = ['draft', 'in_review', 'changes_requested', 'approved', 'published', 'retired'];
const CATEGORIES = Object.keys(TIP_CATEGORY_LABEL) as DailyTipCategory[];
const DATE = new Intl.DateTimeFormat('en-IN', { dateStyle: 'medium' });

export default function DailyTipsPage({ searchParams }: PageProps<'/daily-tips'>) {
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
        <TipList searchParams={searchParams} />
      </Suspense>
    </div>
  );
}

const first = (v: string | string[] | undefined) => (Array.isArray(v) ? v[0] : v) || undefined;

async function TipList({ searchParams }: { searchParams: PageProps<'/daily-tips'>['searchParams'] }) {
  const sp = await searchParams;
  const status = STATUSES.find((s) => s === first(sp.status));
  const category = CATEGORIES.find((c) => c === first(sp.category));
  const q = first(sp.q);
  const cursor = first(sp.cursor);

  const client = await api();
  const [me, page] = await Promise.all([
    getMe(),
    client.GET('/v1/editor/daily-tips', { params: { query: { status, category, q, cursor, limit: 25 } } }).then(must),
  ]);
  const canPublish = hasRole(me, 'publisher');
  // Up to 100 shown; the button publishes them all, however many.
  const approved = canPublish
    ? await client.GET('/v1/editor/daily-tips', { params: { query: { status: 'approved', limit: 100 } } }).then(must)
    : null;
  const href = (patch: Record<string, string | undefined>) => {
    const p = new URLSearchParams();
    for (const [k, v] of Object.entries({ status, category, q, ...patch })) if (v) p.set(k, v);
    const s = p.toString();
    return s ? `/daily-tips?${s}` : '/daily-tips';
  };

  return (
    <>
      <div className="flex flex-wrap items-end justify-between gap-4">
        <div>
          <h1 className="font-serif text-4xl">Daily tips</h1>
          <p className="mt-1 text-sm text-muted">
            The tip on the app&apos;s Home screen. Learners see the published tip whose day is today (India time).
          </p>
        </div>
        <div className="flex flex-wrap gap-2">
          <Link href="/daily-tips/verification" className={buttonClass('secondary')}>
            Tips to verify
          </Link>
          {hasRole(me, ...TIP_WORKFLOW.submit.roles) && (
            <Link href="/daily-tips/new" className={buttonClass()}>
              New tip
            </Link>
          )}
        </div>
      </div>

      {approved && <PublishAllApproved count={approved.items.length} />}

      <FilterForm method="get" action="/daily-tips" className="grid gap-3 sm:grid-cols-[1fr_12rem_14rem_auto]" role="search">
        <label className="sr-only" htmlFor="q">Search</label>
        <input id="q" name="q" defaultValue={q} placeholder="Search titles" className={inputClass} />
        <label className="sr-only" htmlFor="category">Category</label>
        <select id="category" name="category" defaultValue={category ?? ''} className={inputClass}>
          <option value="">Any category</option>
          {CATEGORIES.map((c) => (
            <option key={c} value={c}>{TIP_CATEGORY_LABEL[c]}</option>
          ))}
        </select>
        <label className="sr-only" htmlFor="status">Status</label>
        <select id="status" name="status" defaultValue={status ?? ''} className={inputClass}>
          <option value="">Any status</option>
          {STATUSES.map((s) => (
            <option key={s} value={s}>{STATUS_LABEL[s]}</option>
          ))}
        </select>
        <button type="submit" className={buttonClass('secondary')}>Filter</button>
      </FilterForm>

      {page.items.length === 0 ? (
        <div className="rounded-xl border border-dashed border-border px-6 py-16 text-center text-muted">No tips match these filters.</div>
      ) : (
        <div className="overflow-x-auto rounded-xl border border-border">
          <table className="w-full text-sm">
            <thead className="bg-surface-2 text-left text-xs text-muted">
              <tr>
                <th scope="col" className="px-4 py-2 font-medium">Title</th>
                <th scope="col" className="px-4 py-2 font-medium">Category</th>
                <th scope="col" className="px-4 py-2 font-medium">Language</th>
                <th scope="col" className="px-4 py-2 font-medium">Shown on</th>
                <th scope="col" className="px-4 py-2 font-medium">Status</th>
              </tr>
            </thead>
            <tbody>
              {page.items.map((t) => (
                <tr key={t.id} className="border-t border-border">
                  <td className="px-4 py-3">
                    <Link href={`/daily-tips/${t.id}`} className="font-medium hover:text-primary hover:underline">
                      {t.title || 'Untitled draft'}
                    </Link>
                  </td>
                  <td className="px-4 py-3 whitespace-nowrap text-muted">{TIP_CATEGORY_LABEL[t.category]}</td>
                  <td className="px-4 py-3 whitespace-nowrap text-muted">{TIP_LANGUAGE_LABEL[t.language] ?? t.language}</td>
                  <td className="px-4 py-3 whitespace-nowrap text-muted">{t.publish_date ? DATE.format(new Date(t.publish_date)) : '—'}</td>
                  <td className="px-4 py-3"><StatusBadge status={t.status} /></td>
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
