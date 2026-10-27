import type { Metadata } from 'next';
import Link from 'next/link';
import { Suspense } from 'react';
import { StatusBadge } from '@/components/status-badge';
import { Card, Skeleton } from '@/components/ui';
import { api, must, type Question, type Version } from '@/lib/api';
import { getMe, getTaxonomy, getTopicNames } from '@/lib/session';
import { STATUS_LABEL, availableActions, canEdit } from '@/lib/workflow';
import { saveQuestion } from '../actions';
import type { QuestionInput } from '../form-state';
import { QuestionForm } from '../question-form';
import { WorkflowPanel } from './workflow-panel';

export const metadata: Metadata = { title: 'Question' };

export default function QuestionPage({ params }: PageProps<'/questions/[id]'>) {
  return (
    <div className="flex flex-col gap-6">
      <Link href="/questions" className="text-sm text-muted hover:text-text">← Questions</Link>
      <Suspense fallback={<Skeleton className="h-[40rem]" />}>
        <QuestionDetail params={params} />
      </Suspense>
    </div>
  );
}

const DATE = new Intl.DateTimeFormat('en-IN', { dateStyle: 'medium' });
const DATE_TIME = new Intl.DateTimeFormat('en-IN', { dateStyle: 'medium', timeStyle: 'short' });
const fmt = (iso: string | null, withTime = false) => (iso ? (withTime ? DATE_TIME : DATE).format(new Date(iso)) : '—');

function toInput(v: Version): QuestionInput {
  return {
    topic_id: v.topic_id,
    difficulty: String(v.difficulty),
    stem: v.stem,
    options: v.options,
    correct: v.correct_option_ids[0] ?? '',
    explanation: v.explanation,
    source_title: v.source_title ?? '',
    source_url: v.source_url ?? '',
    citation: v.citation ?? '',
    provision_reference: v.provision_reference ?? '',
    valid_from: v.valid_from ?? '',
    valid_to: v.valid_to ?? '',
  };
}

async function QuestionDetail({ params }: { params: PageProps<'/questions/[id]'>['params'] }) {
  const { id } = await params;
  // Not a UUID: show not found instead of an API validation error.
  if (!/^[0-9a-f-]{36}$/i.test(id)) return <NotFound />;
  const client = await api();
  const [me, taxonomy, topicNames, q] = await Promise.all([
    getMe(),
    getTaxonomy(),
    getTopicNames(),
    client.GET('/v1/editor/questions/{id}', { params: { path: { id } } }).then(must),
  ]);
  const v = q.latest;
  const editable = canEdit(me, v.status);
  const actions = availableActions(me, v.status, !!q.live_version_id);
  const lastRequest = [...q.reviews].reverse().find((r) => r.version_id === v.id && r.decision === 'changes_requested');

  return (
    <div className="grid gap-6 lg:grid-cols-[1fr_20rem]">
      <div className="flex min-w-0 flex-col gap-6">
        <div className="flex flex-col gap-2">
          <div className="flex flex-wrap items-center gap-2 text-sm text-muted">
            <StatusBadge status={v.status} />
            <span>Version {v.version_no}</span>
            <span aria-hidden>·</span>
            <span>{topicNames.get(v.topic_id) ?? 'Unknown topic'}</span>
            {q.external_ref && (
              <>
                <span aria-hidden>·</span>
                <span className="font-mono text-xs">{q.external_ref}</span>
              </>
            )}
          </div>
          <h1 className="font-serif text-3xl leading-tight">{v.stem || 'Untitled draft'}</h1>
          {q.live_version_id && q.live_version_id !== v.id && (
            <p className="text-sm text-muted">An earlier version is live while this one is being worked on.</p>
          )}
        </div>

        {v.status === 'changes_requested' && lastRequest?.reason && (
          <div className="rounded-xl border border-[var(--st-changes-fg)]/30 bg-[var(--st-changes-bg)] p-4 text-sm text-[var(--st-changes-fg)]">
            <p className="font-medium">Changes requested</p>
            <p className="mt-1 whitespace-pre-wrap">{lastRequest.reason}</p>
          </div>
        )}

        {editable ? (
          // Keyed by version: a save keeps the form (and its "Saved" message); a new version starts fresh.
          <QuestionForm key={v.id} initial={toInput(v)} taxonomy={taxonomy} action={saveQuestion.bind(null, q.id)} submitLabel="Save changes" />
        ) : (
          <ReadOnlyVersion version={v} />
        )}
      </div>

      <aside className="flex flex-col gap-6">
        <Card>
          <h2 className="mb-4 font-serif text-xl">Actions</h2>
          <WorkflowPanel
            // Any change to the version clears earlier action messages.
            key={`${v.id}:${v.status}:${v.updated_at}`}
            questionId={q.id}
            actions={actions}
            approveBlocked={v.created_by === me.id || v.updated_by === me.id}
          />
        </Card>
        <History question={q} />
      </aside>
    </div>
  );
}

function ReadOnlyVersion({ version: v }: { version: Version }) {
  const rows: [string, string | null][] = [
    ['Source', v.source_title],
    ['Provision', v.provision_reference],
    ['Citation', v.citation],
    ['Valid from', v.valid_from && fmt(v.valid_from)],
    ['Valid to', v.valid_to && fmt(v.valid_to)],
    ['Verified', v.verified_at && fmt(v.verified_at, true)],
  ];
  return (
    <>
      <Card className="flex flex-col gap-4">
        <ol className="flex flex-col gap-2">
          {v.options.map((o) => {
            const correct = v.correct_option_ids.includes(o.id);
            return (
              <li
                key={o.id}
                className={`flex gap-3 rounded-lg border px-3 py-2 text-sm ${correct ? 'border-success/40 bg-success-bg' : 'border-border'}`}
              >
                <span className="font-medium text-muted uppercase">{o.id}</span>
                <span className="flex-1">{o.text}</span>
                {correct && <span className="text-xs font-medium text-success">Correct</span>}
              </li>
            );
          })}
        </ol>
        <div>
          <h2 className="text-sm font-medium text-muted">Explanation</h2>
          <p className="mt-1 text-sm whitespace-pre-wrap">{v.explanation || '—'}</p>
        </div>
      </Card>
      <Card>
        <dl className="grid gap-x-6 gap-y-3 text-sm sm:grid-cols-2">
          {rows.map(([k, val]) => (
            <div key={k}>
              <dt className="text-muted">{k}</dt>
              <dd className="mt-0.5 break-words">{val || '—'}</dd>
            </div>
          ))}
          <div className="sm:col-span-2">
            <dt className="text-muted">Source URL</dt>
            <dd className="mt-0.5 break-all">
              {v.source_url ? (
                <a href={v.source_url} target="_blank" rel="noopener noreferrer" className="text-primary hover:underline">
                  {v.source_url}
                </a>
              ) : '—'}
            </dd>
          </div>
        </dl>
      </Card>
    </>
  );
}

function History({ question: q }: { question: Question }) {
  const reviewsByVersion = new Map(q.versions.map((v) => [v.id, v.version_no]));
  return (
    <Card>
      <h2 className="mb-3 font-serif text-xl">History</h2>
      <ol className="flex flex-col gap-3 text-sm">
        {[...q.versions].reverse().map((v) => (
          <li key={v.id} className="flex flex-col gap-1">
            <div className="flex items-center justify-between gap-2">
              <span className="font-medium">Version {v.version_no}</span>
              <span className="text-xs text-muted">{STATUS_LABEL[v.status]}</span>
            </div>
            {v.change_note && <p className="text-xs text-muted">{v.change_note}</p>}
            <p className="text-xs text-muted">Created {fmt(v.created_at, true)}</p>
          </li>
        ))}
      </ol>
      {q.reviews.length > 0 && (
        <>
          <h3 className="mt-5 mb-2 text-sm font-medium">Reviews</h3>
          <ol className="flex flex-col gap-2 text-xs">
            {[...q.reviews].reverse().map((r) => (
              <li key={`${r.version_id}${r.created_at}`} className="rounded-lg bg-surface-2 px-3 py-2">
                <span className="font-medium">{r.decision === 'approved' ? 'Approved' : 'Changes requested'}</span>
                <span className="text-muted"> · v{reviewsByVersion.get(r.version_id)} · {fmt(r.created_at, true)}</span>
                {r.reason && <p className="mt-1 whitespace-pre-wrap">{r.reason}</p>}
              </li>
            ))}
          </ol>
        </>
      )}
    </Card>
  );
}

function NotFound() {
  return <p className="text-muted">This question does not exist.</p>;
}
