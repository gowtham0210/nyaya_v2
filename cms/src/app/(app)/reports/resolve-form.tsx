'use client';

import { useActionState } from 'react';
import { Alert, Button, inputClass } from '@/components/ui';
import type { ActionState } from '../questions/form-state';
import { resolveReport } from './actions';

/** Records what was done about a report. */
export function ResolveForm({ reportId, stacked = false }: { reportId: string; stacked?: boolean }) {
  const [state, dispatch, pending] = useActionState<ActionState, FormData>(resolveReport.bind(null, reportId), {});
  return (
    <form action={dispatch} className="flex flex-col gap-2">
      {state.error && <Alert>{state.error}</Alert>}
      {state.ok && <Alert tone="success">{state.message}</Alert>}
      <div className={`grid gap-2 ${stacked ? '' : 'sm:grid-cols-[12rem_1fr_auto]'}`}>
        <label className="sr-only" htmlFor={`outcome-${reportId}`}>Outcome</label>
        <select id={`outcome-${reportId}`} name="outcome" required defaultValue="" className={inputClass}>
          <option value="" disabled>What was done?</option>
          <option value="fixed">Fixed (question revised)</option>
          <option value="retired">Question retired</option>
          <option value="no_change">No change needed</option>
        </select>
        <label className="sr-only" htmlFor={`note-${reportId}`}>Note</label>
        <input id={`note-${reportId}`} name="note" required minLength={3} maxLength={1000} placeholder="Note for the record" className={inputClass} />
        <Button type="submit" variant="secondary" disabled={pending}>
          {pending ? 'Saving…' : 'Close report'}
        </Button>
      </div>
    </form>
  );
}
