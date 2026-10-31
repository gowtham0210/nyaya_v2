import type { Metadata } from 'next';
import Link from 'next/link';
import { Suspense } from 'react';
import { StatusBadge } from '@/components/status-badge';
import { Card, Skeleton } from '@/components/ui';
import { api, must, type News } from '@/lib/api';
import { getMe } from '@/lib/session';
import { NEWS_CATEGORY_LABEL, canEditNews, newsActions } from '@/lib/workflow';
import { saveNews } from '../actions';
import type { NewsInput } from '../form-state';
import { NewsForm } from '../news-form';
import { NewsWorkflowPanel } from './workflow-panel';

export const metadata: Metadata = { title: 'Article' };

export default function ArticlePage({ params }: PageProps<'/news/[id]'>) {
  return (
    <div className="flex flex-col gap-6">
      <Link href="/news" className="text-sm text-muted hover:text-text">← News</Link>
      <Suspense fallback={<Skeleton className="h-[40rem]" />}>
        <ArticleDetail params={params} />
      </Suspense>
    </div>
  );
}

const DATE = new Intl.DateTimeFormat('en-IN', { dateStyle: 'medium' });
const DATE_TIME = new Intl.DateTimeFormat('en-IN', { dateStyle: 'medium', timeStyle: 'short' });
const fmt = (iso: string | null, withTime = false) => (iso ? (withTime ? DATE_TIME : DATE).format(new Date(iso)) : '—');

function toInput(a: News): NewsInput {
  return {
    category: a.category,
    title: a.title,
    summary: a.summary,
    key_points: a.key_points.length ? a.key_points : [''],
    why_it_matters: a.why_it_matters,
    source: a.source,
    source_url: a.source_url ?? '',
    event_date: a.event_date ?? '',
    read_minutes: String(a.read_minutes),
  };
}

async function ArticleDetail({ params }: { params: PageProps<'/news/[id]'>['params'] }) {
  const { id } = await params;
  // Not a UUID: show not found instead of an API validation error.
  if (!/^[0-9a-f-]{36}$/i.test(id)) return <p className="text-muted">This article does not exist.</p>;
  const client = await api();
  const [me, a] = await Promise.all([getMe(), client.GET('/v1/editor/news/{id}', { params: { path: { id } } }).then(must)]);

  return (
    <div className="grid gap-6 lg:grid-cols-[1fr_20rem]">
      <div className="flex min-w-0 flex-col gap-6">
        <div className="flex flex-col gap-2">
          <div className="flex flex-wrap items-center gap-2 text-sm text-muted">
            <StatusBadge status={a.status} />
            <span>{NEWS_CATEGORY_LABEL[a.category]}</span>
            {a.external_ref && (
              <>
                <span aria-hidden>·</span>
                <span className="font-mono text-xs">{a.external_ref}</span>
              </>
            )}
          </div>
          <h1 className="font-serif text-3xl leading-tight">{a.title || 'Untitled draft'}</h1>
        </div>

        {a.changes_reason && (
          <div className="rounded-xl border border-[var(--st-changes-fg)]/30 bg-[var(--st-changes-bg)] p-4 text-sm text-[var(--st-changes-fg)]">
            <p className="font-medium">Changes requested</p>
            <p className="mt-1 whitespace-pre-wrap">{a.changes_reason}</p>
          </div>
        )}

        {canEditNews(me, a.status) ? (
          // Keyed by status: a save keeps the form (and its "Saved" message); a new step starts fresh.
          <NewsForm key={a.status} initial={toInput(a)} action={saveNews.bind(null, a.id)} submitLabel="Save changes" />
        ) : (
          <ReadOnlyArticle article={a} />
        )}
      </div>

      <aside className="flex flex-col gap-6">
        <Card>
          <h2 className="mb-4 font-serif text-xl">Actions</h2>
          <NewsWorkflowPanel
            // Any change to the article clears earlier action messages.
            key={`${a.status}:${a.updated_at}`}
            articleId={a.id}
            actions={newsActions(me, a.status)}
            approveBlocked={a.created_by === me.id || a.updated_by === me.id}
          />
        </Card>
        <Card>
          <h2 className="mb-3 font-serif text-xl">Dates</h2>
          <dl className="grid gap-2 text-sm">
            {(
              [
                ['Created', fmt(a.created_at, true)],
                ['Approved', fmt(a.approved_at, true)],
                ['Published', fmt(a.published_at, true)],
                ['Retired', fmt(a.retired_at, true)],
              ] as const
            ).map(([k, v]) => (
              <div key={k} className="flex justify-between gap-2">
                <dt className="text-muted">{k}</dt>
                <dd>{v}</dd>
              </div>
            ))}
          </dl>
        </Card>
      </aside>
    </div>
  );
}

/** The article as learners read it in the app. */
function ReadOnlyArticle({ article: a }: { article: News }) {
  return (
    <>
      <Card className="flex flex-col gap-4">
        <p className="text-sm whitespace-pre-wrap">{a.summary || '—'}</p>
        <div>
          <h2 className="text-sm font-medium text-muted">Key points</h2>
          <ul className="mt-1 list-disc pl-5 text-sm">
            {a.key_points.map((p) => <li key={p}>{p}</li>)}
          </ul>
        </div>
        <div>
          <h2 className="text-sm font-medium text-muted">Why it matters</h2>
          <p className="mt-1 text-sm whitespace-pre-wrap">{a.why_it_matters || '—'}</p>
        </div>
      </Card>
      <Card>
        <dl className="grid gap-x-6 gap-y-3 text-sm sm:grid-cols-2">
          <div>
            <dt className="text-muted">Source</dt>
            <dd className="mt-0.5 break-words">{a.source || '—'}</dd>
          </div>
          <div>
            <dt className="text-muted">Date</dt>
            <dd className="mt-0.5">{fmt(a.event_date)} · {a.read_minutes} min read</dd>
          </div>
          <div className="sm:col-span-2">
            <dt className="text-muted">Source link</dt>
            <dd className="mt-0.5 break-all">
              {a.source_url ? (
                <a href={a.source_url} target="_blank" rel="noopener noreferrer" className="text-primary hover:underline">
                  {a.source_url}
                </a>
              ) : '—'}
            </dd>
          </div>
        </dl>
      </Card>
    </>
  );
}
