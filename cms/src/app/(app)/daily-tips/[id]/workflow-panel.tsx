'use client';

import { useActionState } from 'react';
import { Alert, Button, inputClass } from '@/components/ui';
import { TIP_WORKFLOW, type TipAction } from '@/lib/workflow';
import type { ActionState } from '../../questions/form-state';
import { runTipAction } from '../actions';

/** Actions that need a reason, and what to ask. */
const REASON: Partial<Record<TipAction, string>> = {
  request_changes: 'What needs to change?',
  revise: 'What needs correcting?',
  retire: 'Why retire it?',
};

const HELP: Record<TipAction, string> = {
  submit: 'Checks the tip is complete, then locks it for legal review.',
  request_changes: 'Sends it back to the editor with your reason.',
  approve: 'Records you as the legal reviewer. Only approve what you have checked against the official source.',
  publish: 'Learners see it on Home from its "Show on" day. Only one tip can be published per day and language.',
  revise: 'Takes it off the app and back to draft. It needs a new review before it is published again.',
  retire: 'Takes it off the app immediately.',
};

export function TipWorkflowPanel({
  tipId,
  actions,
  approveBlocked,
}: {
  tipId: string;
  actions: TipAction[];
  /** Set when the viewer wrote or last saved this tip and so cannot approve it. */
  approveBlocked: boolean;
}) {
  if (actions.length === 0) {
    return <p className="text-sm text-muted">Nothing for you to do on this tip right now.</p>;
  }
  return (
    <div className="flex flex-col gap-4">
      {actions.map((a) => (
        <ActionForm key={a} tipId={tipId} action={a} blocked={a === 'approve' && approveBlocked} />
      ))}
    </div>
  );
}

function ActionForm({ tipId, action, blocked }: { tipId: string; action: TipAction; blocked: boolean }) {
  const [state, dispatch, pending] = useActionState<ActionState, FormData>(runTipAction.bind(null, tipId, action), {});
  const reason = REASON[action];
  const danger = action === 'retire' || action === 'request_changes' || action === 'revise';
  const problems = [...Object.values(state.fieldErrors ?? {}).flat(), ...(state.otherErrors ?? [])];

  return (
    <form action={dispatch} className="flex flex-col gap-2 border-t border-border pt-4 first:border-t-0 first:pt-0">
      {state.error && (
        <Alert>
          {state.error}
          {problems.length > 0 && (
            <ul className="mt-1 list-disc pl-5">
              {problems.map((p) => <li key={p}>{p}</li>)}
            </ul>
          )}
        </Alert>
      )}
      {state.ok && <Alert tone="success">{state.message}</Alert>}
      {reason && (
        <>
          <label htmlFor={`${action}-reason`} className="text-sm font-medium">{reason}</label>
          <textarea id={`${action}-reason`} name="reason" rows={2} required minLength={3} className={inputClass} />
        </>
      )}
      <Button type="submit" variant={danger ? 'danger' : 'primary'} disabled={pending || blocked}>
        {pending ? 'Working…' : TIP_WORKFLOW[action].label}
      </Button>
      <p className="text-xs text-muted">
        {blocked ? 'You wrote or edited this tip, so another reviewer must approve it.' : HELP[action]}
      </p>
    </form>
  );
}
