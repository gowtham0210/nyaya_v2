import type { Metadata } from 'next';
import Link from 'next/link';
import { Suspense } from 'react';
import { StatusBadge } from '@/components/status-badge';
import { Card, Skeleton } from '@/components/ui';
import { api, must, type DailyTip } from '@/lib/api';
import { getMe } from '@/lib/session';
import { TIP_CATEGORY_LABEL, TIP_LANGUAGE_LABEL, canEditTip, tipActions } from '@/lib/workflow';
import { saveTip } from '../actions';
import { DailyTipForm } from '../daily-tip-form';
import type { TipInput } from '../form-state';
import { VerifyPanel } from './verify-panel';
import { TipWorkflowPanel } from './workflow-panel';

export const metadata: Metadata = { title: 'Daily tip' };

export default function TipPage({ params }: PageProps<'/daily-tips/[id]'>) {
  return (
    <div className="flex flex-col gap-6">
      <Link href="/daily-tips" className="text-sm text-muted hover:text-text">← Daily tips</Link>
      <Suspense fallback={<Skeleton className="h-[40rem]" />}>
        <TipDetail params={params} />
      </Suspense>
    </div>
  );
}

const DATE = new Intl.DateTimeFormat('en-IN', { dateStyle: 'medium' });
const DATE_TIME = new Intl.DateTimeFormat('en-IN', { dateStyle: 'medium', timeStyle: 'short' });
const fmt = (iso: string | null, withTime = false) => (iso ? (withTime ? DATE_TIME : DATE).format(new Date(iso)) : '—');

function toInput(t: DailyTip): TipInput {
  return {
    category: t.category,
    language: t.language as TipInput['language'],
    title: t.title,
    summary: t.summary,
    explanation: t.explanation,
    legal_reference: t.legal_reference,
    source_url: t.source_url ?? '',
    publish_date: t.publish_date ?? '',
    last_verified_on: t.last_verified_on ?? '',
  };
}

async function TipDetail({ params }: { params: PageProps<'/daily-tips/[id]'>['params'] }) {
  const { id } = await params;
  // Not a UUID: show not found instead of an API validation error.
  if (!/^[0-9a-f-]{36}$/i.test(id)) return <p className="text-muted">This tip does not exist.</p>;
  const client = await api();
  const [me, t] = await Promise.all([getMe(), client.GET('/v1/editor/daily-tips/{id}', { params: { path: { id } } }).then(must)]);

  return (
    <div className="grid gap-6 lg:grid-cols-[1fr_20rem]">
      <div className="flex min-w-0 flex-col gap-6">
        <div className="flex flex-col gap-2">
          <div className="flex flex-wrap items-center gap-2 text-sm text-muted">
            <StatusBadge status={t.status} />
            <span>{TIP_CATEGORY_LABEL[t.category]}</span>
            <span aria-hidden>·</span>
            <span>{TIP_LANGUAGE_LABEL[t.language] ?? t.language}</span>
          </div>
          <h1 className="font-serif text-3xl leading-tight">{t.title || 'Untitled draft'}</h1>
        </div>

        {t.changes_reason && (
          <div className="rounded-xl border border-[var(--st-changes-fg)]/30 bg-[var(--st-changes-bg)] p-4 text-sm text-[var(--st-changes-fg)]">
            <p className="font-medium">Changes requested</p>
            <p className="mt-1 whitespace-pre-wrap">{t.changes_reason}</p>
          </div>
        )}

        {canEditTip(me, t.status) ? (
          // Keyed by status: a save keeps the form (and its "Saved" message); a new step starts fresh.
          <DailyTipForm key={t.status} initial={toInput(t)} action={saveTip.bind(null, t.id)} submitLabel="Save changes" />
        ) : (
          <ReadOnlyTip tip={t} />
        )}
      </div>

      <aside className="flex flex-col gap-6">
        <Card>
          <h2 className="mb-4 font-serif text-xl">Actions</h2>
          <TipWorkflowPanel
            // Any change to the tip clears earlier action messages.
            key={`${t.status}:${t.updated_at}`}
            tipId={t.id}
            actions={tipActions(me, t.status)}
            // Admins may approve their own work; everyone else needs another reviewer.
            approveBlocked={!me.roles.includes('admin') && (t.created_by === me.id || t.updated_by === me.id)}
          />
        </Card>
        {canEditTip(me, t.status) && (
          <Card>
            <h2 className="mb-3 font-serif text-xl">Source check</h2>
            <VerifyPanel key={`${t.source_url}:${t.last_verified_on}`} tipId={t.id} sourceUrl={t.source_url} />
          </Card>
        )}
        <Card>
          <h2 className="mb-3 font-serif text-xl">Dates</h2>
          <dl className="grid gap-2 text-sm">
            {(
              [
                ['Shown on', fmt(t.publish_date)],
                ['Last verified', fmt(t.last_verified_on)],
                ['Created', fmt(t.created_at, true)],
                ['Approved', fmt(t.approved_at, true)],
                ['Published', fmt(t.published_at, true)],
                ['Retired', fmt(t.retired_at, true)],
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

/** The tip as learners read it in the app. */
function ReadOnlyTip({ tip: t }: { tip: DailyTip }) {
  return (
    <>
      <Card className="flex flex-col gap-4">
        <div>
          <h2 className="text-sm font-medium text-muted">Summary</h2>
          <p className="mt-1 text-sm whitespace-pre-wrap">{t.summary || '—'}</p>
        </div>
        <div>
          <h2 className="text-sm font-medium text-muted">Full explanation</h2>
          <p className="mt-1 text-sm whitespace-pre-wrap">{t.explanation || '—'}</p>
        </div>
      </Card>
      <Card>
        <dl className="grid gap-x-6 gap-y-3 text-sm sm:grid-cols-2">
          <div>
            <dt className="text-muted">Legal reference</dt>
            <dd className="mt-0.5 break-words">{t.legal_reference || '—'}</dd>
          </div>
          <div>
            <dt className="text-muted">Last verified</dt>
            <dd className="mt-0.5">{fmt(t.last_verified_on)}</dd>
          </div>
          <div className="sm:col-span-2">
            <dt className="text-muted">Official source link</dt>
            <dd className="mt-0.5 break-all">
              {t.source_url ? (
                <a href={t.source_url} target="_blank" rel="noopener noreferrer" className="text-primary hover:underline">
                  {t.source_url}
                </a>
              ) : '—'}
            </dd>
          </div>
        </dl>
      </Card>
    </>
  );
}
