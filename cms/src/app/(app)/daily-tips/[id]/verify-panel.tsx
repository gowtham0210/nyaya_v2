'use client';

import { useActionState } from 'react';
import { Alert, Button } from '@/components/ui';
import type { ActionState } from '../../questions/form-state';
import { verifyTip } from '../actions';
import { isExactSourceLink } from '../source-link';

/**
 * "I checked this today": records today's date as the last check, under the
 * signed-in editor's name, once they confirm they opened the exact source.
 */
export function VerifyPanel({ tipId, sourceUrl }: { tipId: string; sourceUrl: string | null }) {
  const [state, dispatch, pending] = useActionState<ActionState, FormData>(verifyTip.bind(null, tipId), {});
  const exact = isExactSourceLink(sourceUrl);
  return (
    <form action={dispatch} className="flex flex-col gap-3 text-sm">
      <p className="text-muted">
        Open the official source, read the provision, and confirm the tip says what it says. This records today&apos;s
        date and your name. It does not send the tip for review.
      </p>
      {sourceUrl ? (
        <a href={sourceUrl} target="_blank" rel="noopener noreferrer" className="break-all text-primary hover:underline">
          {sourceUrl}
        </a>
      ) : (
        <p className="text-muted">No source link yet.</p>
      )}
      {!exact && <Alert>Save the exact link to the provision (not a website home page) before recording a check.</Alert>}
      <label className="flex items-start gap-2">
        <input type="checkbox" name="confirmed" disabled={!exact || pending} className="mt-1" />
        <span>I opened this exact source and checked the tip against it.</span>
      </label>
      {state.error && <Alert>{state.error}</Alert>}
      {state.otherErrors?.map((m) => <Alert key={m}>{m}</Alert>)}
      {state.fieldErrors?.source_url?.map((m) => <Alert key={m}>{m}</Alert>)}
      {state.ok && <Alert tone="success">{state.message}</Alert>}
      <Button type="submit" variant="secondary" disabled={!exact || pending}>
        {pending ? 'Recording…' : 'I checked this today'}
      </Button>
    </form>
  );
}
