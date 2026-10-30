'use client';

import { useActionState, useState, useTransition } from 'react';
import { Alert, Button, Field, inputClass } from '@/components/ui';
import { ROLE_LABEL, STAFF_ROLES } from '@/lib/workflow';
import { inviteStaff, newSetupLink, setStaffActive, updateStaff, type StaffState } from './actions';

const DATE = new Intl.DateTimeFormat('en-IN', { dateStyle: 'medium', timeStyle: 'short' });

const ROLE_HELP: Record<(typeof STAFF_ROLES)[number], string> = {
  admin: 'staff accounts, subjects, publishing',
  content_editor: 'writes and imports questions',
  legal_reviewer: 'approves or sends back questions',
  publisher: 'puts approved questions live',
  analyst: 'read-only',
};

function RoleChoices({ checked = [], idPrefix }: { checked?: readonly string[]; idPrefix: string }) {
  return (
    <fieldset className="flex flex-col gap-1.5">
      <legend className="mb-1 text-sm font-medium">Roles</legend>
      {STAFF_ROLES.map((r) => (
        <label key={r} htmlFor={`${idPrefix}-${r}`} className="flex items-start gap-2 text-sm">
          <input id={`${idPrefix}-${r}`} type="checkbox" name="roles" value={r} defaultChecked={checked.includes(r)} className="mt-0.5 size-4 accent-[var(--primary)]" />
          <span>
            {ROLE_LABEL[r]} <span className="text-muted">— {ROLE_HELP[r]}</span>
          </span>
        </label>
      ))}
    </fieldset>
  );
}

/** The one-time link, shown once with a copy button. */
export function SetupLinkBox({ setup }: { setup: NonNullable<StaffState['setup']> }) {
  const [copied, setCopied] = useState(false);
  const link = `${window.location.origin}/setup#token=${setup.token}`;
  return (
    <div className="flex flex-col gap-2 rounded-lg border border-success/30 bg-success-bg p-4 text-sm">
      <p className="font-medium text-success">Setup link for {setup.name}</p>
      <p className="text-muted">
        Copy it now and send it to them yourself; it is not shown again. It works once, until {DATE.format(new Date(setup.expiresAt))}.
      </p>
      <div className="flex flex-col gap-2 sm:flex-row">
        <input readOnly value={link} aria-label="Setup link" onFocus={(e) => e.target.select()} className={`${inputClass} font-mono text-xs`} />
        <Button
          type="button"
          variant="secondary"
          onClick={async () => {
            await navigator.clipboard.writeText(link);
            setCopied(true);
          }}
        >
          {copied ? 'Copied' : 'Copy link'}
        </Button>
      </div>
    </div>
  );
}

export function InviteForm() {
  const [state, action, pending] = useActionState<StaffState, FormData>(inviteStaff, {});
  return (
    <div className="flex flex-col gap-4">
      <form action={action} className="flex flex-col gap-4">
        {state.error && <Alert>{state.error}</Alert>}
        <div className="grid gap-3 sm:grid-cols-2">
          <Field label="Name" htmlFor="invite-name">
            <input id="invite-name" name="display_name" required maxLength={80} className={inputClass} />
          </Field>
          <Field label="Email" htmlFor="invite-email">
            <input id="invite-email" name="email" type="email" required maxLength={254} className={inputClass} />
          </Field>
        </div>
        <RoleChoices idPrefix="invite" />
        <div>
          <Button type="submit" disabled={pending}>{pending ? 'Adding…' : 'Add and make a setup link'}</Button>
        </div>
      </form>
      {state.setup && <SetupLinkBox setup={state.setup} />}
    </div>
  );
}

export function EditStaffForm({ id, name, roles }: { id: string; name: string; roles: readonly string[] }) {
  const [state, action, pending] = useActionState<StaffState, FormData>(updateStaff.bind(null, id), {});
  return (
    <form action={action} className="flex flex-col gap-4">
      {state.error && <Alert>{state.error}</Alert>}
      {state.ok && <Alert tone="success">{state.message}</Alert>}
      <Field label="Name" htmlFor={`name-${id}`}>
        <input id={`name-${id}`} name="display_name" required maxLength={80} defaultValue={name} className={inputClass} />
      </Field>
      <RoleChoices idPrefix={`roles-${id}`} checked={roles} />
      <div>
        <Button type="submit" disabled={pending}>{pending ? 'Saving…' : 'Save'}</Button>
      </div>
    </form>
  );
}

/** Disable / enable and a new setup link, each after a confirmation; neither for yourself. */
export function StaffActions({ id, name, active, self }: { id: string; name: string; active: boolean; self: boolean }) {
  const [pending, startTransition] = useTransition();
  const [result, setResult] = useState<StaffState>({});
  const run = (question: string, step: () => Promise<StaffState>) => {
    if (!window.confirm(question)) return;
    startTransition(async () => setResult(await step()));
  };
  return (
    <>
      {active && !self && (
        <Button
          type="button"
          variant="secondary"
          disabled={pending}
          onClick={() =>
            run(
              `Make a new setup link for ${name}? Their current password stops working and they are signed out until they use the link.`,
              () => newSetupLink(id),
            )
          }
        >
          New setup link
        </Button>
      )}
      {!self && (
        <Button
          type="button"
          variant={active ? 'danger' : 'secondary'}
          disabled={pending}
          onClick={() =>
            run(
              active
                ? `Disable ${name}? They are signed out at once and cannot sign in until enabled again.`
                : `Enable ${name} again? They can sign in with their password.`,
              () => setStaffActive(id, !active),
            )
          }
        >
          {active ? 'Disable' : 'Enable'}
        </Button>
      )}
      {result.error && <Alert>{result.error}</Alert>}
      {result.setup && (
        <div className="w-full">
          <SetupLinkBox setup={result.setup} />
        </div>
      )}
    </>
  );
}
