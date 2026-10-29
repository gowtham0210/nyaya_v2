'use client';

import { useActionState, useState, useTransition, type ReactNode } from 'react';
import { Alert, Button, Field, inputClass } from '@/components/ui';
import type { ActionState } from '../questions/form-state';
import { saveTaxonomy, setActive, type TaxonomyKind } from './actions';

export interface FormDefaults {
  name?: string;
  description?: string | null;
  sort_order?: number;
  act_id?: string | null;
  short_name?: string | null;
  year?: number | null;
}

const SLUG_HINT = 'Lower-case letters, digits and hyphens, e.g. family-law. It cannot be changed later.';

/** Adds (no id) or edits one subject, topic or act. */
export function TaxonomyForm({
  kind,
  id,
  subjectId,
  defaults = {},
  acts = [],
}: {
  kind: TaxonomyKind;
  id?: string;
  subjectId?: string;
  defaults?: FormDefaults;
  acts?: { id: string; name: string }[];
}) {
  const [state, dispatch, pending] = useActionState<ActionState, FormData>(
    saveTaxonomy.bind(null, kind, id ?? null),
    {},
  );
  const errs = (f: string) => state.fieldErrors?.[f];
  const creating = !id;
  const fid = (f: string) => `${kind}-${id ?? 'new'}-${subjectId ?? ''}-${f}`;

  return (
    <form action={dispatch} className="flex flex-col gap-3">
      {state.error && (
        <Alert>
          {state.error}
          {!!state.otherErrors?.length && (
            <ul className="mt-1 list-disc pl-5">
              {state.otherErrors.map((e) => <li key={e}>{e}</li>)}
            </ul>
          )}
        </Alert>
      )}
      {state.ok && <Alert tone="success">{state.message}</Alert>}
      {subjectId && <input type="hidden" name="subject_id" value={subjectId} />}
      <div className="grid gap-3 sm:grid-cols-2">
        <Field label="Name" htmlFor={fid('name')} errors={errs('name')}>
          <input id={fid('name')} name="name" required minLength={2} maxLength={kind === 'acts' ? 200 : 120} defaultValue={defaults.name} className={inputClass} />
        </Field>
        {creating && (
          <Field label="Slug" htmlFor={fid('slug')} hint={SLUG_HINT} errors={errs('slug')}>
            <input id={fid('slug')} name="slug" required maxLength={60} pattern="[a-z0-9]+(-[a-z0-9]+)*" className={`${inputClass} font-mono`} />
          </Field>
        )}
        {kind === 'acts' ? (
          <>
            <Field label="Short name (optional)" htmlFor={fid('short_name')} errors={errs('short_name')}>
              <input id={fid('short_name')} name="short_name" maxLength={60} defaultValue={defaults.short_name ?? ''} className={inputClass} />
            </Field>
            <Field label="Year (optional)" htmlFor={fid('year')} errors={errs('year')}>
              <input id={fid('year')} name="year" type="number" min={1800} max={2100} defaultValue={defaults.year ?? ''} className={inputClass} />
            </Field>
          </>
        ) : (
          <>
            <Field label="Order" htmlFor={fid('sort_order')} hint="Lower numbers come first." errors={errs('sort_order')}>
              <input id={fid('sort_order')} name="sort_order" type="number" min={0} max={10000} defaultValue={defaults.sort_order ?? 0} className={inputClass} />
            </Field>
            {kind === 'topics' && (
              <Field label="Act (optional)" htmlFor={fid('act_id')} errors={errs('act_id')}>
                <select id={fid('act_id')} name="act_id" defaultValue={defaults.act_id ?? ''} className={inputClass}>
                  <option value="">None</option>
                  {acts.map((a) => (
                    <option key={a.id} value={a.id}>{a.name}</option>
                  ))}
                </select>
              </Field>
            )}
            <div className="sm:col-span-2">
              <Field label="Description (optional)" htmlFor={fid('description')} errors={errs('description')}>
                <textarea id={fid('description')} name="description" rows={2} maxLength={1000} defaultValue={defaults.description ?? ''} className={inputClass} />
              </Field>
            </div>
          </>
        )}
      </div>
      <div>
        <Button type="submit" disabled={pending}>{pending ? 'Saving…' : creating ? 'Add' : 'Save'}</Button>
      </div>
    </form>
  );
}

/** Show or hide, after a confirmation that says what changes for learners. */
export function ActiveToggle({
  kind,
  id,
  active,
  confirmText,
}: {
  kind: TaxonomyKind;
  id: string;
  active: boolean;
  confirmText: string;
}) {
  const [pending, startTransition] = useTransition();
  const [error, setError] = useState<string>();
  return (
    <>
      <Button
        type="button"
        variant={active ? 'danger' : 'secondary'}
        disabled={pending}
        onClick={() => {
          if (!window.confirm(confirmText)) return;
          startTransition(async () => setError((await setActive(kind, id, !active)).error));
        }}
      >
        {pending ? 'Working…' : active ? 'Hide' : 'Show'}
      </Button>
      {error && <Alert>{error}</Alert>}
    </>
  );
}

/** A subject, topic or act line, with its edit form opening underneath. */
export function ItemRow({ info, actions, editForm }: { info: ReactNode; actions?: ReactNode; editForm?: ReactNode }) {
  const [editing, setEditing] = useState(false);
  return (
    <div className="flex flex-col gap-3 py-3">
      <div className="flex flex-wrap items-start gap-3">
        <div className="min-w-0 flex-1">{info}</div>
        {(editForm || actions) && (
          <div className="flex flex-wrap items-center gap-2">
            {editForm && (
              <Button type="button" variant="secondary" aria-expanded={editing} onClick={() => setEditing((e) => !e)}>
                {editing ? 'Close' : 'Edit'}
              </Button>
            )}
            {actions}
          </div>
        )}
      </div>
      {editing && <div className="rounded-lg border border-border bg-surface-2/40 p-4">{editForm}</div>}
    </div>
  );
}
