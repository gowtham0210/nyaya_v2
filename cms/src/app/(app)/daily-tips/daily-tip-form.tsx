'use client';

import { startTransition, useActionState, useState } from 'react';
import { Alert, Button, Card, Field, inputClass } from '@/components/ui';
import type { DailyTipCategory, DailyTipLanguage } from '@/lib/api';
import { TIP_CATEGORY_LABEL, TIP_LANGUAGE_LABEL } from '@/lib/workflow';
import type { ActionState } from '../questions/form-state';
import type { TipInput } from './form-state';

const CATEGORIES = Object.keys(TIP_CATEGORY_LABEL) as DailyTipCategory[];
const LANGUAGES = Object.keys(TIP_LANGUAGE_LABEL) as DailyTipLanguage[];

/**
 * Create or edit a daily tip. Fields are controlled so a failed save keeps
 * what was typed. Completeness is only enforced on submit for review.
 */
export function DailyTipForm({
  initial,
  action,
  submitLabel,
}: {
  initial: TipInput;
  action: (state: ActionState, input: TipInput) => Promise<ActionState>;
  submitLabel: string;
}) {
  const [values, setValues] = useState(initial);
  const [state, dispatch, pending] = useActionState(action, {});
  const errs = (f: string) => state.fieldErrors?.[f];
  const set = <K extends keyof TipInput>(k: K, v: TipInput[K]) => setValues((s) => ({ ...s, [k]: v }));

  return (
    <form
      className="flex flex-col gap-6"
      onSubmit={(e) => {
        e.preventDefault();
        startTransition(() => dispatch(values));
      }}
    >
      {state.error && (
        <Alert>
          {state.error}
          {state.otherErrors?.map((m) => <span key={m} className="block">{m}</span>)}
        </Alert>
      )}

      <Card className="flex flex-col gap-5">
        <h2 className="font-serif text-xl">Tip</h2>
        <div className="grid gap-4 sm:grid-cols-[1fr_12rem_9rem]">
          <Field label="Title" htmlFor="title" errors={errs('title')}>
            <input id="title" maxLength={150} value={values.title} onChange={(e) => set('title', e.target.value)} aria-invalid={!!errs('title')} className={inputClass} />
          </Field>
          <Field label="Category" htmlFor="category" errors={errs('category')}>
            <select id="category" value={values.category} onChange={(e) => set('category', e.target.value as DailyTipCategory)} className={inputClass}>
              {CATEGORIES.map((c) => <option key={c} value={c}>{TIP_CATEGORY_LABEL[c]}</option>)}
            </select>
          </Field>
          <Field label="Language" htmlFor="language" errors={errs('language')}>
            <select id="language" value={values.language} onChange={(e) => set('language', e.target.value as DailyTipLanguage)} className={inputClass}>
              {LANGUAGES.map((l) => <option key={l} value={l}>{TIP_LANGUAGE_LABEL[l]}</option>)}
            </select>
          </Field>
        </div>
        <Field label="Short summary" htmlFor="summary" hint="One or two plain sentences, shown on the Home card (300 characters at most)." errors={errs('summary')}>
          <textarea id="summary" rows={3} maxLength={300} value={values.summary} onChange={(e) => set('summary', e.target.value)} aria-invalid={!!errs('summary')} className={inputClass} />
        </Field>
        <Field label="Full explanation" htmlFor="explanation" hint="What the law says and what a person can do. Plain language." errors={errs('explanation')}>
          <textarea id="explanation" rows={8} maxLength={4000} value={values.explanation} onChange={(e) => set('explanation', e.target.value)} aria-invalid={!!errs('explanation')} className={inputClass} />
        </Field>
      </Card>

      <Card className="flex flex-col gap-5">
        <h2 className="font-serif text-xl">Source and dates</h2>
        <div className="grid gap-4 sm:grid-cols-2">
          <Field label="Legal reference" htmlFor="legal_reference" hint="Act and section, e.g. Consumer Protection Act, 2019, Section 35." errors={errs('legal_reference')}>
            <input id="legal_reference" value={values.legal_reference} onChange={(e) => set('legal_reference', e.target.value)} aria-invalid={!!errs('legal_reference')} className={inputClass} />
          </Field>
          <Field label="Official source link" htmlFor="source_url" hint="https only: the India Code page, gazette or ministry site." errors={errs('source_url')}>
            <input id="source_url" type="url" inputMode="url" value={values.source_url} onChange={(e) => set('source_url', e.target.value)} aria-invalid={!!errs('source_url')} className={inputClass} />
          </Field>
          <Field label="Show on" htmlFor="publish_date" hint="The India day the app shows it on Home. One published tip per day and language." errors={errs('publish_date')}>
            <input id="publish_date" type="date" value={values.publish_date} onChange={(e) => set('publish_date', e.target.value)} aria-invalid={!!errs('publish_date')} className={inputClass} />
          </Field>
          <Field label="Last verified (optional)" htmlFor="last_verified_on" hint="Optional. The day you last checked the tip against the source; leave empty if not checked yet." errors={errs('last_verified_on')}>
            <input id="last_verified_on" type="date" value={values.last_verified_on} onChange={(e) => set('last_verified_on', e.target.value)} aria-invalid={!!errs('last_verified_on')} className={inputClass} />
          </Field>
        </div>
      </Card>

      <div className="flex flex-wrap items-center gap-3">
        <Button type="submit" disabled={pending}>{pending ? 'Saving…' : submitLabel}</Button>
        <span role="status" className={`text-sm ${state.error ? 'text-danger' : state.ok ? 'text-success' : 'text-muted'}`}>
          {pending
            ? ''
            : state.error
              ? 'Not saved — see the messages above.'
              : state.ok
                ? `${state.message ?? 'Saved'}.`
                : 'Drafts can be saved incomplete. Everything is checked when you submit for review.'}
        </span>
      </div>
    </form>
  );
}
