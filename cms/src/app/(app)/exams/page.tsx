import type { Metadata } from 'next';
import Link from 'next/link';
import { Suspense } from 'react';
import { Card, Skeleton } from '@/components/ui';
import { api, must } from '@/lib/api';
import { getMe } from '@/lib/session';
import { hasRole } from '@/lib/workflow';
import { setExamActive } from './actions';
import { CreateBlueprintForm, CreatePaperForm, CreateSourceForm, StepButton } from './exam-forms';

export const metadata: Metadata = { title: 'Exams' };

const PILL = 'rounded-full bg-surface-2 px-2 py-0.5 text-xs font-medium';

export default function ExamsPage() {
  return (
    <div className="flex flex-col gap-6">
      <div>
        <h1 className="font-serif text-4xl">Exams</h1>
        <p className="mt-1 max-w-3xl text-sm text-muted">
          Mock exam papers, blueprints, content sources and switching an exam on. Admins manage all of it; a publisher can publish a
          paper or blueprint an admin prepared. Every change is recorded in the audit log under your name.
        </p>
      </div>
      <Suspense fallback={<Skeleton className="h-96" />}>
        <Exams />
      </Suspense>
    </div>
  );
}

async function Exams() {
  const me = await getMe();
  const client = await api();
  const isAdmin = hasRole(me, 'admin');
  const { items: exams } = await client.GET('/v1/admin/exams').then(must);
  const details = await Promise.all(exams.map((e) => client.GET('/v1/admin/exams/{id}', { params: { path: { id: e.id } } }).then(must)));
  const { items: papers } = await client.GET('/v1/admin/exam-papers', { params: { query: { limit: 100 } } }).then(must);
  const { items: sources } = await client.GET('/v1/admin/content-sources', { params: { query: { limit: 100 } } }).then(must);
  const examName = new Map(exams.map((e) => [e.id, e.short_name]));

  return (
    <>
      <Card className="flex flex-col gap-4">
        <h2 className="font-serif text-2xl">Exams</h2>
        {exams.length === 0 && <p className="text-sm text-muted">No exam exists yet.</p>}
        {details.map((e) => (
          <div key={e.id} className="flex flex-col gap-3 border-t border-border pt-4 first:border-t-0 first:pt-0">
            <div className="flex flex-wrap items-center justify-between gap-3">
              <div className="flex flex-wrap items-center gap-2">
                <span className="font-medium">{e.name}</span>
                <span className={PILL}>{e.is_active ? 'On' : 'Off'}</span>
                <span className="text-xs text-muted">
                  {e.current_blueprint_id ? 'Has a current blueprint' : 'No current blueprint, so it cannot be switched on'}
                </span>
              </div>
              {isAdmin && (
                <StepButton
                  label={e.is_active ? 'Switch off' : 'Switch on'}
                  variant={e.is_active ? 'danger' : 'primary'}
                  run={setExamActive.bind(null, e.id, !e.is_active)}
                  confirm={e.is_active ? `Switch ${e.name} off? Learners will stop seeing it.` : `Switch ${e.name} on for learners?`}
                />
              )}
            </div>
            <ul className="flex flex-col gap-1 text-sm">
              {e.blueprints.length === 0 && <li className="text-muted">No blueprints.</li>}
              {e.blueprints.map((b) => (
                <li key={b.id} className="flex flex-wrap items-center gap-2">
                  <Link href={`/exams/blueprints/${b.id}`} className="font-medium text-primary hover:underline">
                    Blueprint {b.code} v{b.version}
                  </Link>
                  <span className={PILL}>{b.status}</span>
                  {b.is_current && <span className={PILL}>current</span>}
                  <span className="text-xs text-muted">{b.config_status.replace('_', ' ')}</span>
                </li>
              ))}
            </ul>
          </div>
        ))}
      </Card>

      <Card className="flex flex-col gap-3">
        <h2 className="font-serif text-2xl">Papers</h2>
        <ul className="flex flex-col divide-y divide-border text-sm">
          {papers.length === 0 && <li className="py-2 text-muted">No papers yet.</li>}
          {papers.map((p) => (
            <li key={p.id} className="flex flex-wrap items-center gap-2 py-2">
              <Link href={`/exams/papers/${p.id}`} className="font-medium text-primary hover:underline">
                {p.title}
              </Link>
              <span className={PILL}>{p.status}</span>
              <span className="text-xs text-muted">
                {examName.get(p.exam_id) ?? ''} · {p.code} rev {p.revision} · {p.total_questions} questions · {p.config_status.replace('_', ' ')}
              </span>
            </li>
          ))}
        </ul>
        {isAdmin && (
          <details>
            <summary className="cursor-pointer font-medium text-primary">Create a draft paper</summary>
            <div className="mt-4">
              <CreatePaperForm exams={exams.map((e) => ({ id: e.id, name: e.name }))} />
            </div>
          </details>
        )}
      </Card>

      {isAdmin && (
        <Card className="flex flex-col gap-3">
          <h2 className="font-serif text-2xl">New blueprint</h2>
          <details>
            <summary className="cursor-pointer font-medium text-primary">Create a draft blueprint</summary>
            <div className="mt-4">
              <CreateBlueprintForm exams={exams.map((e) => ({ id: e.id, name: e.name }))} />
            </div>
          </details>
        </Card>
      )}

      <Card className="flex flex-col gap-3">
        <h2 className="font-serif text-2xl">Content sources</h2>
        <p className="text-sm text-muted">
          Where imported content came from, kept for attribution. A source is optional when importing and never blocks an import or publishing.
        </p>
        <ul className="flex flex-col divide-y divide-border text-sm">
          {sources.length === 0 && <li className="py-2 text-muted">No content sources.</li>}
          {sources.map((s) => (
            <li key={s.id} className="flex flex-col gap-1 py-3">
              <div className="flex flex-wrap items-center gap-2">
                <span className="font-medium">{s.title}</span>
                <span className={PILL}>{s.kind.replace('_', ' ')}</span>
              </div>
              {(s.publisher || s.url) && (
                <p className="text-xs text-muted">
                  {s.publisher}
                  {s.publisher && s.url && ' · '}
                  {s.url && (
                    <a href={s.url} target="_blank" rel="noreferrer" className="text-primary hover:underline">
                      {s.url}
                    </a>
                  )}
                </p>
              )}
            </li>
          ))}
        </ul>
        {isAdmin && (
          <details>
            <summary className="cursor-pointer font-medium text-primary">Add a content source</summary>
            <div className="mt-4">
              <CreateSourceForm />
            </div>
          </details>
        )}
      </Card>
    </>
  );
}
