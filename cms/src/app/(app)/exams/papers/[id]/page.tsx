import type { Metadata } from 'next';
import Link from 'next/link';
import { Suspense } from 'react';
import { Alert, Card, Skeleton } from '@/components/ui';
import { api, must } from '@/lib/api';
import { getMe } from '@/lib/session';
import { hasRole } from '@/lib/workflow';
import { publishPaper, retirePaper, revisePaper, savePositions } from '../../actions';
import { JsonForm, PracticeTimerForm, StepButton } from '../../exam-forms';

export const metadata: Metadata = { title: 'Exam paper' };

export default function PaperPage({ params }: PageProps<'/exams/papers/[id]'>) {
  return (
    <div className="flex flex-col gap-6">
      <Link href="/exams" className="text-sm text-primary hover:underline">
        ← Exams
      </Link>
      <Suspense fallback={<Skeleton className="h-96" />}>
        <Paper params={params} />
      </Suspense>
    </div>
  );
}

async function Paper({ params }: { params: PageProps<'/exams/papers/[id]'>['params'] }) {
  const { id } = await params;
  const me = await getMe();
  const client = await api();
  const paper = await client.GET('/v1/admin/exam-papers/{id}', { params: { path: { id } } }).then(must);
  const readiness = paper.status === 'draft' ? await client.GET('/v1/admin/exam-papers/{id}/readiness', { params: { path: { id } } }).then(must) : null;
  const isAdmin = hasRole(me, 'admin');
  const canPublish = hasRole(me, 'publisher', 'admin');
  const draft = paper.status === 'draft';
  const positionsJson = JSON.stringify(
    paper.positions.map((p) => ({
      position: p.position,
      question_version_id: p.question_version_id,
      original_ref: p.original_ref,
      official_key_text: p.official_key_text,
      source_ref: p.source_ref,
      withdrawn_note: p.withdrawn_note,
    })),
    null,
    2,
  );

  return (
    <>
      <div>
        <h1 className="font-serif text-4xl">{paper.title}</h1>
        <p className="mt-1 text-sm text-muted">
          {paper.code} revision {paper.revision} · {paper.status} · {paper.total_questions} questions · settings {paper.config_status.replace('_', ' ')}
          {paper.duration_seconds ? ` · ${Math.round(paper.duration_seconds / 60)} minutes` : ' · no duration, so timed mode is off'}
        </p>
        <p className="mt-1 text-sm text-muted">
          {paper.practice_timer_seconds
            ? `Practice timer: ${Math.round(paper.practice_timer_seconds / 60)} minutes (practice timing, not officially confirmed by BCI)`
            : 'No practice timer.'}
        </p>
      </div>

      {draft && readiness && (
        <Card className="flex flex-col gap-3">
          <h2 className="font-serif text-2xl">Ready to publish?</h2>
          {readiness.ready ? (
            <Alert tone="success">Every check passes.</Alert>
          ) : (
            <ul className="list-disc pl-5 text-sm">
              {readiness.problems.map((p, i) => (
                <li key={i}>
                  {(p as { field?: string }).field ? `${(p as { field?: string }).field}: ` : ''}
                  {(p as { reason?: string }).reason}
                </li>
              ))}
            </ul>
          )}
          {canPublish && (
            <div className="max-w-xs">
              <StepButton
                label="Publish and freeze"
                variant="primary"
                run={publishPaper.bind(null, paper.id)}
                confirm="Publish this paper? It is frozen and learners can sit it once the exam is on."
              />
            </div>
          )}
          <p className="text-xs text-muted">A publisher cannot publish a paper they created. Every publish is audited.</p>
        </Card>
      )}

      {paper.status === 'published' && isAdmin && (
        <Card className="max-w-xs">
          <StepButton label="Retire this paper" variant="danger" run={retirePaper.bind(null, paper.id)} confirm="Retire this paper? Learners will no longer see it." />
        </Card>
      )}

      {(paper.status === 'published' || paper.status === 'retired') && isAdmin && (
        <Card className="max-w-md">
          <StepButton
            label="Revise (make a new draft copy)"
            run={revisePaper.bind(null, paper.id)}
            confirm="Create a new draft revision with the same questions? Publish it to bring the paper back for learners."
          />
        </Card>
      )}

      <Card className="flex flex-col gap-3">
        <h2 className="font-serif text-2xl">Positions ({paper.positions.length} of {paper.total_questions})</h2>
        <div className="overflow-x-auto">
          <table className="w-full text-left text-sm">
            <thead className="text-xs text-muted">
              <tr>
                <th className="py-1 pr-3">No.</th>
                <th className="py-1 pr-3">Original ref</th>
                <th className="py-1 pr-3">Answer</th>
                <th className="py-1">Question version</th>
              </tr>
            </thead>
            <tbody className="divide-y divide-border">
              {paper.positions.map((p) => (
                <tr key={p.id}>
                  <td className="py-1 pr-3">{p.position}</td>
                  <td className="py-1 pr-3">{p.original_ref ?? ''}</td>
                  <td className="py-1 pr-3">{p.answer_status.replace('_', ' ')}</td>
                  <td className="py-1 font-mono text-xs">{p.question_version_id ?? '(withdrawn)'}</td>
                </tr>
              ))}
              {paper.positions.length === 0 && (
                <tr>
                  <td colSpan={4} className="py-2 text-muted">
                    No positions yet.
                  </td>
                </tr>
              )}
            </tbody>
          </table>
        </div>
      </Card>

      {draft && isAdmin && (
        <Card className="flex flex-col gap-3">
          <h2 className="font-serif text-2xl">Practice timer</h2>
          <PracticeTimerForm id={paper.id} seconds={paper.practice_timer_seconds ?? null} />
        </Card>
      )}

      {draft && isAdmin && (
        <Card className="flex flex-col gap-3">
          <h2 className="font-serif text-2xl">Set positions</h2>
          <JsonForm
            save={savePositions.bind(null, paper.id)}
            name="positions"
            label="Positions (JSON)"
            hint="A list with position, question_version_id (published; empty for a withdrawn question), original_ref, official_key_text, source_ref and withdrawn_note. Saving replaces all positions."
            initial={positionsJson}
          />
        </Card>
      )}
    </>
  );
}
