'use client';

import Link from 'next/link';
import { useState, useTransition } from 'react';
import { StatusBadge } from '@/components/status-badge';
import { Alert, Button, inputClass } from '@/components/ui';
import type { VersionStatus } from '@/lib/api';
import { WORKFLOW, type BulkAction } from '@/lib/workflow';
import { runBulk } from './actions';
import type { BulkState } from './form-state';

export interface QuestionRow {
  id: string;
  stem: string;
  versionNo: number;
  status: VersionStatus;
  topic: string;
  live: string;
}

const DONE: Record<BulkAction, string> = {
  submit: 'Sent for review',
  approve: 'Approved',
  publish: 'Published',
};

/** Asked before steps that change what learners see or record a legal check. */
const CONFIRM: Partial<Record<BulkAction, (n: number) => string>> = {
  approve: (n) =>
    `Approve ${n} question${n === 1 ? '' : 's'}? You will be recorded as the legal reviewer of each, so only approve questions you have checked against their source.`,
  publish: (n) => `Publish ${n} question${n === 1 ? '' : 's'}? Learners will see ${n === 1 ? 'it' : 'them'} straight away.`,
};

const fits = (action: BulkAction, status: VersionStatus) => (WORKFLOW[action].from as readonly string[]).includes(status);

/**
 * The question list. When the viewer may run a step on many questions, rows
 * get checkboxes and the step buttons act on the selected rows it applies to.
 */
export function QuestionTable({ rows, actions }: { rows: QuestionRow[]; actions: BulkAction[] }) {
  const [selected, setSelected] = useState<ReadonlySet<string>>(new Set());
  const [note, setNote] = useState('');
  const [result, setResult] = useState<(BulkState & { action: BulkAction }) | null>(null);
  const [pending, startTransition] = useTransition();
  const selectable = actions.length > 0;
  const allSelected = rows.length > 0 && rows.every((r) => selected.has(r.id));
  const stemOf = new Map(rows.map((r) => [r.id, r.stem]));

  const toggle = (id: string) =>
    setSelected((prev) => {
      const next = new Set(prev);
      if (!next.delete(id)) next.add(id);
      return next;
    });

  const run = (action: BulkAction) => {
    const ids = rows.filter((r) => selected.has(r.id) && fits(action, r.status)).map((r) => r.id);
    const ask = CONFIRM[action];
    if (ids.length === 0 || (ask && !window.confirm(ask(ids.length)))) return;
    startTransition(async () => {
      const res = await runBulk(action, ids, note);
      setResult({ ...res, action });
      if (!res.error) {
        const failed = new Set(res.failures?.map((f) => f.questionId));
        setSelected((prev) => new Set([...prev].filter((id) => failed.has(id))));
        if (action === 'approve') setNote('');
      }
    });
  };

  return (
    <div className="flex flex-col gap-3">
      {selectable && (
        <div className="flex flex-col gap-3 rounded-xl border border-border bg-surface p-4">
          <div className="flex flex-wrap items-center gap-3">
            <span className="text-sm text-muted" aria-live="polite">
              {selected.size === 0 ? 'Select questions to act on several at once.' : `${selected.size} selected`}
            </span>
            <div className="ml-auto flex flex-wrap gap-2">
              {actions.map((a) => {
                const n = rows.filter((r) => selected.has(r.id) && fits(a, r.status)).length;
                return (
                  <Button key={a} type="button" variant={a === 'submit' ? 'secondary' : 'primary'} disabled={pending || n === 0} onClick={() => run(a)}>
                    {pending ? 'Working…' : `${WORKFLOW[a].label}${n ? ` (${n})` : ''}`}
                  </Button>
                );
              })}
            </div>
          </div>
          {actions.includes('approve') && rows.some((r) => selected.has(r.id) && fits('approve', r.status)) && (
            <div className="flex flex-col gap-1.5">
              <label htmlFor="bulk-note" className="text-sm font-medium">Approval note (optional, saved on each)</label>
              <input id="bulk-note" value={note} onChange={(e) => setNote(e.target.value)} maxLength={2000} className={inputClass} />
            </div>
          )}
          {result?.error && <Alert>{result.error}</Alert>}
          {result && !result.error && (
            <Alert tone={result.failures?.length ? 'danger' : 'success'}>
              {DONE[result.action]}: {result.succeeded}.
              {!!result.failures?.length && (
                <>
                  {' '}
                  {result.failures.length} could not be done:
                  <ul className="mt-1 list-disc pl-5">
                    {result.failures.map((f) => (
                      <li key={f.questionId}>
                        <Link href={`/questions/${f.questionId}`} className="underline">
                          {stemOf.get(f.questionId) || 'Question'}
                        </Link>
                        : {f.message}
                        {f.reasons.length > 0 && ` (${f.reasons.join('; ')})`}
                      </li>
                    ))}
                  </ul>
                </>
              )}
            </Alert>
          )}
        </div>
      )}

      <div className="overflow-x-auto rounded-xl border border-border bg-surface">
        <table className="w-full min-w-[640px] text-sm">
          <thead className="border-b border-border text-left text-xs tracking-wide text-muted uppercase">
            <tr>
              {selectable && (
                <th className="w-10 px-4 py-3">
                  <input
                    type="checkbox"
                    aria-label="Select all on this page"
                    checked={allSelected}
                    onChange={() => setSelected(allSelected ? new Set() : new Set(rows.map((r) => r.id)))}
                    className="size-4 accent-[var(--primary)]"
                  />
                </th>
              )}
              <th className="px-4 py-3 font-medium">Question</th>
              <th className="px-4 py-3 font-medium">Topic</th>
              <th className="px-4 py-3 font-medium">Status</th>
              <th className="px-4 py-3 font-medium">Live</th>
            </tr>
          </thead>
          <tbody className="divide-y divide-border">
            {rows.map((r) => (
              <tr key={r.id} className={selected.has(r.id) ? 'bg-surface-2' : 'hover:bg-surface-2/60'}>
                {selectable && (
                  <td className="px-4 py-3">
                    <input
                      type="checkbox"
                      aria-label={`Select: ${r.stem || 'Untitled draft'}`}
                      checked={selected.has(r.id)}
                      onChange={() => toggle(r.id)}
                      className="size-4 accent-[var(--primary)]"
                    />
                  </td>
                )}
                <td className="max-w-md px-4 py-3">
                  <Link href={`/questions/${r.id}`} className="line-clamp-2 font-medium hover:text-primary">
                    {r.stem || <span className="text-muted italic">Untitled draft</span>}
                  </Link>
                  <span className="text-xs text-muted">v{r.versionNo}</span>
                </td>
                <td className="px-4 py-3 text-muted">{r.topic}</td>
                <td className="px-4 py-3"><StatusBadge status={r.status} /></td>
                <td className="px-4 py-3 text-muted">{r.live}</td>
              </tr>
            ))}
          </tbody>
        </table>
      </div>
    </div>
  );
}
