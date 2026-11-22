'use client';

import { useActionState } from 'react';
import { Alert, Button } from '@/components/ui';
import { publishAllApprovedTips, type PublishAllState } from './actions';

/** Publishes every tip that has already passed legal review and approval; never touches drafts. */
export function PublishAllApproved({ count }: { count: number }) {
  const [state, dispatch, pending] = useActionState<PublishAllState, FormData>(publishAllApprovedTips, {});
  const shown = state;
  return (
    <div className="flex flex-col gap-3">
      {count > 0 && (
        <form
          action={dispatch}
          onSubmit={(e) => {
            if (!confirm(`Publish all ${count} approved tips? Each goes live on its own "Shown on" day.`)) e.preventDefault();
          }}
        >
          <Button type="submit" variant="secondary" disabled={pending}>
            {pending ? 'Publishing…' : `Publish all approved (${count})`}
          </Button>
        </form>
      )}
      {shown.error && <Alert>{shown.error}</Alert>}
      {shown.ok && (
        <Alert tone="success">
          Published {shown.published} {shown.published === 1 ? 'tip' : 'tips'}.
          {shown.skipped && shown.skipped.length > 0 && ` ${shown.skipped.length} could not be published:`}
        </Alert>
      )}
      {shown.skipped && shown.skipped.length > 0 && (
        <ul className="list-disc pl-6 text-sm text-muted">
          {shown.skipped.map((s, i) => (
            <li key={i}>
              <span className="font-medium text-text">{s.title}</span>: {s.reason}
            </li>
          ))}
        </ul>
      )}
    </div>
  );
}
