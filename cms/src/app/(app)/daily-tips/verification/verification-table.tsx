'use client';

import Link from 'next/link';
import { useActionState, useState } from 'react';
import { StatusBadge } from '@/components/status-badge';
import { Alert, Button } from '@/components/ui';
import type { DailyTipStatus } from '@/lib/api';
import { verifyTipsAsAdmin, type BulkVerifyState } from '../actions';

export interface VerifyRow {
  id: string;
  title: string;
  category: string;
  legalReference: string;
  status: DailyTipStatus;
  showOn: string;
  placeholder: boolean;
  /** Why a check cannot be recorded yet; null when it can. */
  blocked: string | null;
}

/**
 * The to-verify list. An admin can tick the tips they have personally checked
 * against their official sources and record those checks in one step, under
 * their own name. Everyone else sees the list only.
 */
export function VerificationTable({ rows, isAdmin }: { rows: VerifyRow[]; isAdmin: boolean }) {
  const [state, dispatch, pending] = useActionState<BulkVerifyState, FormData>(verifyTipsAsAdmin, {});
  const [selected, setSelected] = useState<Set<string>>(new Set());
  const ready = rows.filter((r) => !r.blocked);
  const toggle = (id: string) =>
    setSelected((prev) => {
      const next = new Set(prev);
      if (!next.delete(id)) next.add(id);
      return next;
    });
  const failedTitle = (id: string) => rows.find((r) => r.id === id)?.title || 'Untitled draft';

  return (
    <form
      action={dispatch}
      className="flex flex-col gap-4"
      onSubmit={(e) => {
        if (!confirm(`Record today's date as the last check on ${selected.size} tips, under your name?`)) e.preventDefault();
      }}
    >
      {isAdmin && (
        <div className="flex flex-col gap-3 rounded-xl border border-border bg-surface p-4 text-sm">
          <p className="text-muted">
            Tick only the tips you have personally opened and checked against their official source. Each one gets
            today&apos;s date as its &ldquo;Last verified&rdquo; date and an audit entry with your name. This does not send
            anything for review or publish it.
          </p>
          <label className="flex items-start gap-2">
            <input type="checkbox" name="attest" className="mt-1" />
            <span>I personally checked each selected tip against its official source.</span>
          </label>
          <div className="flex flex-wrap items-center gap-3">
            <Button type="submit" disabled={pending || selected.size === 0}>
              {pending ? 'Recording…' : `Record my check on ${selected.size} selected`}
            </Button>
            <button
              type="button"
              className="text-primary hover:underline"
              onClick={() => setSelected(selected.size === ready.length ? new Set() : new Set(ready.map((r) => r.id)))}
            >
              {selected.size === ready.length && ready.length > 0 ? 'Clear selection' : `Select all ready (${ready.length})`}
            </button>
          </div>
          {state.error && <Alert>{state.error}</Alert>}
          {state.ok && (
            <Alert tone="success">
              Recorded {state.verified} {state.verified === 1 ? 'check' : 'checks'}.
              {state.failed && state.failed.length > 0 && ` ${state.failed.length} could not be recorded:`}
            </Alert>
          )}
          {state.failed && state.failed.length > 0 && (
            <ul className="list-disc pl-6 text-muted">
              {state.failed.map((f) => (
                <li key={f.id}>
                  <span className="font-medium text-text">{failedTitle(f.id)}</span>: {f.reason}
                </li>
              ))}
            </ul>
          )}
        </div>
      )}

      <div className="overflow-x-auto rounded-xl border border-border">
        <table className="w-full text-sm">
          <thead className="bg-surface-2 text-left text-xs text-muted">
            <tr>
              {isAdmin && <th scope="col" className="w-10 px-4 py-2 font-medium"><span className="sr-only">Select</span></th>}
              <th scope="col" className="px-4 py-2 font-medium">Title</th>
              <th scope="col" className="px-4 py-2 font-medium">Category</th>
              <th scope="col" className="px-4 py-2 font-medium">Legal reference</th>
              <th scope="col" className="px-4 py-2 font-medium">Can record a check?</th>
              <th scope="col" className="px-4 py-2 font-medium">Shown on</th>
              <th scope="col" className="px-4 py-2 font-medium">Status</th>
            </tr>
          </thead>
          <tbody>
            {rows.map((t) => (
              <tr key={t.id} className="border-t border-border align-top">
                {isAdmin && (
                  <td className="px-4 py-3">
                    <input
                      type="checkbox"
                      name="id"
                      value={t.id}
                      checked={selected.has(t.id)}
                      disabled={!!t.blocked || pending}
                      onChange={() => toggle(t.id)}
                      aria-label={`Select ${t.title || 'Untitled draft'}`}
                    />
                  </td>
                )}
                <td className="px-4 py-3">
                  <Link href={`/daily-tips/${t.id}`} className="font-medium hover:text-primary hover:underline">
                    {t.title || 'Untitled draft'}
                  </Link>
                  {t.placeholder && <p className="mt-1 text-xs text-danger">Test placeholder date: clear it and re-verify</p>}
                </td>
                <td className="px-4 py-3 whitespace-nowrap text-muted">{t.category}</td>
                <td className="px-4 py-3 text-muted">{t.legalReference || '—'}</td>
                <td className="px-4 py-3">{t.blocked ? <span className="text-danger">{t.blocked}</span> : 'Yes'}</td>
                <td className="px-4 py-3 whitespace-nowrap text-muted">{t.showOn}</td>
                <td className="px-4 py-3"><StatusBadge status={t.status} /></td>
              </tr>
            ))}
          </tbody>
        </table>
      </div>
    </form>
  );
}
