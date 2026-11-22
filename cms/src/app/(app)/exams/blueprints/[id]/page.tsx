import type { Metadata } from 'next';
import Link from 'next/link';
import { Suspense } from 'react';
import { Card, Skeleton } from '@/components/ui';
import { api, must } from '@/lib/api';
import { getAllTaxonomy, getMe } from '@/lib/session';
import { hasRole } from '@/lib/workflow';
import { blueprintStep, saveSections } from '../../actions';
import { BlueprintSourceForm, JsonForm, StepButton } from '../../exam-forms';

export const metadata: Metadata = { title: 'Exam blueprint' };

export default function BlueprintPage({ params }: PageProps<'/exams/blueprints/[id]'>) {
  return (
    <div className="flex flex-col gap-6">
      <Link href="/exams" className="text-sm text-primary hover:underline">
        ← Exams
      </Link>
      <Suspense fallback={<Skeleton className="h-96" />}>
        <Blueprint params={params} />
      </Suspense>
    </div>
  );
}

async function Blueprint({ params }: { params: PageProps<'/exams/blueprints/[id]'>['params'] }) {
  const { id } = await params;
  const me = await getMe();
  const bp = await (await api()).GET('/v1/admin/exam-blueprints/{id}', { params: { path: { id } } }).then(must);
  const isAdmin = hasRole(me, 'admin');
  // Sections name topics by id; the id is not shown anywhere else in the CMS.
  const taxonomy = isAdmin ? await getAllTaxonomy() : null;
  const draft = bp.status === 'draft';
  const sectionsJson = JSON.stringify(
    bp.sections.map((s) => ({
      code: s.code,
      name: s.name,
      position: s.position,
      question_count: s.question_count,
      duration_seconds: s.duration_seconds ?? null,
      marks_correct: s.marks_correct ?? null,
      topics: s.topics.map((t) => ({ topic_id: t.topic_id, min_count: t.min_count, max_count: t.max_count, weight: t.weight })),
    })),
    null,
    2,
  );

  return (
    <>
      <div>
        <h1 className="font-serif text-4xl">
          Blueprint {bp.code} v{bp.version}
        </h1>
        <p className="mt-1 text-sm text-muted">
          {bp.status}
          {bp.is_current ? ' · current' : ''} · {bp.total_questions} questions · {Math.round(bp.duration_seconds / 60)} minutes · {bp.marks_correct} mark each,
          {` ${bp.negative_marks} negative`} · settings {bp.config_status.replace('_', ' ')}
        </p>
        <p className="mt-1 text-sm text-muted">{bp.timed_allowed ? 'Timed mocks are allowed.' : `Timed mocks are off: ${bp.timed_blocked_reason ?? 'settings are not official-confirmed'}`}</p>
      </div>

      <Card className="flex flex-wrap gap-3">
        {draft && hasRole(me, 'publisher', 'admin') && (
          <StepButton
            label="Publish"
            variant="primary"
            run={blueprintStep.bind(null, bp.id, 'publish')}
            confirm="Publish this blueprint? It becomes read-only. A publisher cannot publish a blueprint they created."
          />
        )}
        {isAdmin && bp.status === 'published' && !bp.is_current && (
          <StepButton label="Make current" variant="primary" run={blueprintStep.bind(null, bp.id, 'make-current')} confirm="Make this the blueprint the exam uses?" />
        )}
        {isAdmin && bp.is_current && <StepButton label="Stop being current" run={blueprintStep.bind(null, bp.id, 'clear-current')} confirm="This exam will have no current blueprint and cannot stay switched on." />}
        {isAdmin && bp.status === 'published' && <StepButton label="Retire" variant="danger" run={blueprintStep.bind(null, bp.id, 'retire')} confirm="Retire this blueprint?" />}
      </Card>

      {draft && isAdmin && (
        <Card className="flex flex-col gap-3">
          <h2 className="font-serif text-2xl">Settings status and source</h2>
          <p className="text-sm text-muted">Official-confirmed needs the official source named and the date it was checked. Timed mode needs it.</p>
          <BlueprintSourceForm id={bp.id} status={bp.config_status} source={bp.config_source ?? null} checkedOn={bp.config_checked_on ?? null} />
        </Card>
      )}

      <Card className="flex flex-col gap-3">
        <h2 className="font-serif text-2xl">Sections</h2>
        <ul className="flex flex-col gap-2 text-sm">
          {bp.sections.length === 0 && <li className="text-muted">No sections yet.</li>}
          {bp.sections.map((s) => (
            <li key={s.code}>
              <span className="font-medium">
                {s.position}. {s.name}
              </span>{' '}
              <span className="text-muted">
                ({s.code}) · {s.question_count} questions · {s.topics.length} topics
              </span>
            </li>
          ))}
        </ul>
      </Card>

      {draft && isAdmin && (
        <Card className="flex flex-col gap-3">
          <h2 className="font-serif text-2xl">Set sections</h2>
          {taxonomy && (
            <details className="text-sm">
              <summary className="cursor-pointer font-medium text-primary">Topic IDs to use as topic_id</summary>
              <p className="mt-2 text-muted">Copy the whole ID (the long code) into the section&apos;s topic_id. Do not type the topic name.</p>
              <ul className="mt-2 flex flex-col gap-1">
                {taxonomy.subjects.flatMap((subject) =>
                  subject.topics.map((t) => (
                    <li key={t.id} className="flex flex-col gap-0.5 sm:flex-row sm:items-baseline sm:gap-3">
                      <span className="min-w-[16rem] font-medium">{t.name}</span>
                      <code className="font-mono text-xs break-all select-all">{t.id}</code>
                    </li>
                  )),
                )}
              </ul>
            </details>
          )}
          <JsonForm
            save={saveSections.bind(null, bp.id)}
            name="sections"
            label="Sections (JSON)"
            hint="Each section has code, name, position, question_count and topics (topic_id, min_count, max_count, weight). The question counts must add up to the blueprint's total. Saving replaces all sections."
            initial={sectionsJson}
          />
        </Card>
      )}
    </>
  );
}
