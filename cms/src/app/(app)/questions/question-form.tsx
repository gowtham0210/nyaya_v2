'use client';

import { startTransition, useActionState, useState } from 'react';
import { Alert, Button, Card, Field, inputClass } from '@/components/ui';
import type { Taxonomy } from '@/lib/api';
import { OPTION_IDS, type ActionState, type QuestionInput } from './form-state';

const DIFFICULTY = [
  { value: '1', label: 'Easy' },
  { value: '2', label: 'Medium' },
  { value: '3', label: 'Hard' },
];

/**
 * Create or edit a question version. Fields are controlled so a failed save
 * keeps what was typed. Completeness is only enforced on submit for review.
 */
export function QuestionForm({
  initial,
  taxonomy,
  action,
  submitLabel,
}: {
  initial: QuestionInput;
  taxonomy: Taxonomy;
  action: (state: ActionState, input: QuestionInput) => Promise<ActionState>;
  submitLabel: string;
}) {
  const [values, setValues] = useState(initial);
  const [state, dispatch, pending] = useActionState(action, {});
  const errs = (f: string) => state.fieldErrors?.[f];
  const set = <K extends keyof QuestionInput>(k: K, v: QuestionInput[K]) => setValues((s) => ({ ...s, [k]: v }));

  const setOption = (i: number, text: string) =>
    set('options', values.options.map((o, j) => (j === i ? { ...o, text } : o)));
  const addOption = () => {
    const id = OPTION_IDS.find((x) => !values.options.some((o) => o.id === x));
    if (id) set('options', [...values.options, { id, text: '' }]);
  };
  const removeOption = (i: number) => {
    const removed = values.options[i];
    setValues((s) => ({
      ...s,
      options: s.options.filter((_, j) => j !== i),
      correct: s.correct === removed.id ? '' : s.correct,
    }));
  };

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
        <h2 className="font-serif text-xl">Question</h2>
        <div className="grid gap-4 sm:grid-cols-[1fr_10rem]">
          <Field label="Topic" htmlFor="topic_id" errors={errs('topic_id')}>
            <select id="topic_id" value={values.topic_id} onChange={(e) => set('topic_id', e.target.value)} className={inputClass} required>
              <option value="" disabled>Choose a topic</option>
              {taxonomy.subjects.map((s) => (
                <optgroup key={s.id} label={s.name}>
                  {s.topics.map((t) => <option key={t.id} value={t.id}>{t.name}</option>)}
                </optgroup>
              ))}
            </select>
          </Field>
          <Field label="Difficulty" htmlFor="difficulty" errors={errs('difficulty')}>
            <select id="difficulty" value={values.difficulty} onChange={(e) => set('difficulty', e.target.value)} className={inputClass}>
              {DIFFICULTY.map((d) => <option key={d.value} value={d.value}>{d.label}</option>)}
            </select>
          </Field>
        </div>
        <Field label="Question text" htmlFor="stem" errors={errs('stem')}>
          <textarea id="stem" rows={3} value={values.stem} onChange={(e) => set('stem', e.target.value)} aria-invalid={!!errs('stem')} className={inputClass} />
        </Field>

        <fieldset className="flex flex-col gap-2">
          <legend className="mb-1.5 text-sm font-medium">Options <span className="font-normal text-muted">— select the correct answer</span></legend>
          {values.options.map((o, i) => (
            <div key={o.id} className="flex items-center gap-3">
              <input
                type="radio"
                name="correct"
                aria-label={`Option ${o.id.toUpperCase()} is correct`}
                checked={values.correct === o.id}
                onChange={() => set('correct', o.id)}
                className="size-4 accent-[var(--primary)]"
              />
              <span className="w-4 text-sm font-medium text-muted uppercase">{o.id}</span>
              <input
                value={o.text}
                onChange={(e) => setOption(i, e.target.value)}
                aria-label={`Option ${o.id.toUpperCase()}`}
                className={inputClass}
              />
              <button
                type="button"
                onClick={() => removeOption(i)}
                disabled={values.options.length <= 2}
                className="rounded-lg px-2 py-1 text-sm text-muted hover:bg-surface-2 hover:text-danger disabled:invisible"
                aria-label={`Remove option ${o.id.toUpperCase()}`}
              >
                ✕
              </button>
            </div>
          ))}
          {[...(errs('options') ?? []), ...(errs('correct_option_ids') ?? [])].map((e) => (
            <p key={e} className="text-xs text-danger">{e}</p>
          ))}
          {values.options.length < OPTION_IDS.length && (
            <button type="button" onClick={addOption} className="self-start text-sm text-primary hover:underline">
              + Add option
            </button>
          )}
        </fieldset>

        <Field label="Explanation" htmlFor="explanation" hint="Why the answer is right, in plain language, citing the provision." errors={errs('explanation')}>
          <textarea id="explanation" rows={4} value={values.explanation} onChange={(e) => set('explanation', e.target.value)} aria-invalid={!!errs('explanation')} className={inputClass} />
        </Field>
      </Card>

      <Card className="flex flex-col gap-5">
        <h2 className="font-serif text-xl">Source and validity</h2>
        <div className="grid gap-4 sm:grid-cols-2">
          <Field label="Source title" htmlFor="source_title" hint="Official act, judgment or notification." errors={errs('source_title')}>
            <input id="source_title" value={values.source_title} onChange={(e) => set('source_title', e.target.value)} aria-invalid={!!errs('source_title')} className={inputClass} />
          </Field>
          <Field label="Source URL" htmlFor="source_url" hint="https only. Prefer indiacode.nic.in or the court's site." errors={errs('source_url')}>
            <input id="source_url" type="url" inputMode="url" value={values.source_url} onChange={(e) => set('source_url', e.target.value)} aria-invalid={!!errs('source_url')} className={inputClass} />
          </Field>
          <Field label="Provision" htmlFor="provision_reference" hint="e.g. Article 394, Section 103 BNS." errors={errs('provision_reference')}>
            <input id="provision_reference" value={values.provision_reference} onChange={(e) => set('provision_reference', e.target.value)} className={inputClass} />
          </Field>
          <Field label="Citation" htmlFor="citation" errors={errs('citation')}>
            <input id="citation" value={values.citation} onChange={(e) => set('citation', e.target.value)} className={inputClass} />
          </Field>
          <Field label="Valid from" htmlFor="valid_from" hint="When this content starts to apply." errors={errs('valid_from')}>
            <input id="valid_from" type="date" value={values.valid_from} onChange={(e) => set('valid_from', e.target.value)} aria-invalid={!!errs('valid_from')} className={inputClass} />
          </Field>
          <Field label="Valid to" htmlFor="valid_to" hint="Leave empty while the law is in force." errors={errs('valid_to')}>
            <input id="valid_to" type="date" value={values.valid_to} onChange={(e) => set('valid_to', e.target.value)} aria-invalid={!!errs('valid_to')} className={inputClass} />
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
