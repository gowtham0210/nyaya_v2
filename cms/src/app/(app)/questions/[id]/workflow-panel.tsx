'use client';

import { useActionState } from 'react';
import { Alert, Button, inputClass } from '@/components/ui';
import { WORKFLOW, type WorkflowAction } from '@/lib/workflow';
import { runAction } from '../actions';
import type { ActionState } from '../form-state';

/** Extra input each action asks for, if any. */
const INPUT: Partial<Record<WorkflowAction, { name: string; label: string; required: boolean }>> = {
  request_changes: { name: 'reason', label: 'What needs to change?', required: true },
  approve: { name: 'note', label: 'Note (optional)', required: false },
  revise: { name: 'change_note', label: 'Why is this changing?', required: true },
  retire: { name: 'reason', label: 'Why retire it?', required: true },
};

const HELP: Partial<Record<WorkflowAction, string>> = {
  submit: 'Checks the question is complete, then locks it for legal review.',
  approve: 'Records you as the reviewer and today as the verified date.',
  publish: 'Learners will see this version. Any earlier live version is replaced.',
  revise: 'Creates a new draft. The live version stays up until the new one is published.',
  retire: 'Takes the live version down immediately.',
};

export function WorkflowPanel({
  questionId,
  actions,
  approveBlocked,
}: {
  questionId: string;
  actions: WorkflowAction[];
  /** Set when the viewer wrote or edited this version and so cannot approve it. */
  approveBlocked: boolean;
}) {
  if (actions.length === 0) {
    return <p className="text-sm text-muted">Nothing for you to do on this question right now.</p>;
  }
  return (
    <div className="flex flex-col gap-4">
      {actions.map((a) => (
        <ActionForm key={a} questionId={questionId} action={a} blocked={a === 'approve' && approveBlocked} />
      ))}
    </div>
  );
}

function ActionForm({ questionId, action, blocked }: { questionId: string; action: WorkflowAction; blocked: boolean }) {
  const [state, dispatch, pending] = useActionState<ActionState, FormData>(runAction.bind(null, questionId, action), {});
  const input = INPUT[action];
  const danger = action === 'retire' || action === 'request_changes';
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
      {input && (
        <>
          <label htmlFor={`${action}-${input.name}`} className="text-sm font-medium">{input.label}</label>
          <textarea id={`${action}-${input.name}`} name={input.name} rows={2} required={input.required} minLength={input.required ? 3 : undefined} className={inputClass} disabled={blocked} />
        </>
      )}
      <Button type="submit" variant={danger ? 'danger' : action === 'approve' || action === 'publish' || action === 'submit' ? 'primary' : 'secondary'} disabled={pending || blocked}>
        {pending ? 'Working…' : WORKFLOW[action].label}
      </Button>
      <p className="text-xs text-muted">
        {blocked ? 'You wrote or edited this version, so another reviewer must approve it.' : HELP[action]}
      </p>
    </form>
  );
}
