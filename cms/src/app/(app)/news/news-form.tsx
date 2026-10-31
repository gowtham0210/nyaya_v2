'use client';

import { startTransition, useActionState, useState } from 'react';
import { Alert, Button, Card, Field, inputClass } from '@/components/ui';
import type { NewsCategory } from '@/lib/api';
import { NEWS_CATEGORY_LABEL } from '@/lib/workflow';
import type { ActionState } from '../questions/form-state';
import { MAX_KEY_POINTS, type NewsInput } from './form-state';

const CATEGORIES = Object.keys(NEWS_CATEGORY_LABEL) as NewsCategory[];

/**
 * Create or edit a news article. Fields are controlled so a failed save
 * keeps what was typed. Completeness is only enforced on submit for review.
 */
export function NewsForm({
  initial,
  action,
  submitLabel,
}: {
  initial: NewsInput;
  action: (state: ActionState, input: NewsInput) => Promise<ActionState>;
  submitLabel: string;
}) {
  const [values, setValues] = useState(initial);
  const [state, dispatch, pending] = useActionState(action, {});
  const errs = (f: string) => state.fieldErrors?.[f];
  const set = <K extends keyof NewsInput>(k: K, v: NewsInput[K]) => setValues((s) => ({ ...s, [k]: v }));
  const setPoint = (i: number, text: string) => set('key_points', values.key_points.map((p, j) => (j === i ? text : p)));

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
        <h2 className="font-serif text-xl">Article</h2>
        <div className="grid gap-4 sm:grid-cols-[1fr_12rem]">
          <Field label="Title" htmlFor="title" errors={errs('title')}>
            <input id="title" value={values.title} onChange={(e) => set('title', e.target.value)} aria-invalid={!!errs('title')} className={inputClass} />
          </Field>
          <Field label="Category" htmlFor="category" errors={errs('category')}>
            <select id="category" value={values.category} onChange={(e) => set('category', e.target.value as NewsCategory)} className={inputClass}>
              {CATEGORIES.map((c) => <option key={c} value={c}>{NEWS_CATEGORY_LABEL[c]}</option>)}
            </select>
          </Field>
        </div>
        <Field label="Summary" htmlFor="summary" hint="Two or three plain sentences: what happened and what was decided." errors={errs('summary')}>
          <textarea id="summary" rows={4} value={values.summary} onChange={(e) => set('summary', e.target.value)} aria-invalid={!!errs('summary')} className={inputClass} />
        </Field>

        <fieldset className="flex flex-col gap-2">
          <legend className="mb-1.5 text-sm font-medium">Key points <span className="font-normal text-muted">— one short line each</span></legend>
          {values.key_points.map((p, i) => (
            <div key={i} className="flex items-center gap-3">
              <span className="w-4 text-sm text-muted">{i + 1}.</span>
              <input value={p} onChange={(e) => setPoint(i, e.target.value)} aria-label={`Key point ${i + 1}`} className={inputClass} />
              <button
                type="button"
                onClick={() => set('key_points', values.key_points.filter((_, j) => j !== i))}
                disabled={values.key_points.length <= 1}
                className="rounded-lg px-2 py-1 text-sm text-muted hover:bg-surface-2 hover:text-danger disabled:invisible"
                aria-label={`Remove key point ${i + 1}`}
              >
                ✕
              </button>
            </div>
          ))}
          {errs('key_points')?.map((e) => <p key={e} className="text-xs text-danger">{e}</p>)}
          {values.key_points.length < MAX_KEY_POINTS && (
            <button type="button" onClick={() => set('key_points', [...values.key_points, ''])} className="self-start text-sm text-primary hover:underline">
              + Add key point
            </button>
          )}
        </fieldset>

        <Field label="Why it matters" htmlFor="why_it_matters" hint="What it changes for an ordinary person." errors={errs('why_it_matters')}>
          <textarea id="why_it_matters" rows={2} value={values.why_it_matters} onChange={(e) => set('why_it_matters', e.target.value)} aria-invalid={!!errs('why_it_matters')} className={inputClass} />
        </Field>
      </Card>

      <Card className="flex flex-col gap-5">
        <h2 className="font-serif text-xl">Source</h2>
        <div className="grid gap-4 sm:grid-cols-2">
          <Field label="Source" htmlFor="source" hint="Who decided or passed it, and when. e.g. Supreme Court of India, 8 April 2025." errors={errs('source')}>
            <input id="source" value={values.source} onChange={(e) => set('source', e.target.value)} aria-invalid={!!errs('source')} className={inputClass} />
          </Field>
          <Field label="Source link" htmlFor="source_url" hint="Optional. https only: the judgment, gazette or official page." errors={errs('source_url')}>
            <input id="source_url" type="url" inputMode="url" value={values.source_url} onChange={(e) => set('source_url', e.target.value)} aria-invalid={!!errs('source_url')} className={inputClass} />
          </Field>
          <Field label="Date" htmlFor="event_date" hint="The day of the judgment, Act or event. The app sorts by it." errors={errs('event_date')}>
            <input id="event_date" type="date" value={values.event_date} onChange={(e) => set('event_date', e.target.value)} aria-invalid={!!errs('event_date')} className={inputClass} />
          </Field>
          <Field label="Reading time (minutes)" htmlFor="read_minutes" errors={errs('read_minutes')}>
            <input id="read_minutes" type="number" min={1} max={30} value={values.read_minutes} onChange={(e) => set('read_minutes', e.target.value)} className={inputClass} />
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
