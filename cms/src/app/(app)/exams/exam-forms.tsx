'use client';

import { useActionState, useState, useTransition } from 'react';
import { Alert, Button, Field, inputClass } from '@/components/ui';
import {
  createBlueprint,
  createContentSource,
  createPaper,
  saveBlueprintSource,
  setPracticeTimer,
  type ExamActionState,
} from './actions';

type Exam = { id: string; name: string };

/** A one-click action with a result line (publish, retire, switch on, …). */
export function StepButton({
  label,
  run,
  variant = 'secondary',
  confirm,
}: {
  label: string;
  run: () => Promise<ExamActionState>;
  variant?: 'primary' | 'secondary' | 'danger';
  confirm?: string;
}) {
  const [pending, start] = useTransition();
  const [state, setState] = useState<ExamActionState>({});
  return (
    <div className="flex flex-col gap-1">
      <Button
        type="button"
        variant={variant}
        disabled={pending}
        onClick={() => {
          if (confirm && !window.confirm(confirm)) return;
          start(async () => setState(await run()));
        }}
      >
        {pending ? 'Working…' : label}
      </Button>
      {state.error && <Alert>{state.error}</Alert>}
      {state.ok && state.message && <Alert tone="success">{state.message}</Alert>}
    </div>
  );
}

function Result({ state }: { state: ExamActionState }) {
  return (
    <>
      {state.error && <Alert>{state.error}</Alert>}
      {state.ok && state.message && <Alert tone="success">{state.message}</Alert>}
    </>
  );
}

function ExamSelect({ exams }: { exams: Exam[] }) {
  return (
    <Field label="Exam" htmlFor="exam_id">
      <select id="exam_id" name="exam_id" required className={inputClass}>
        {exams.map((e) => (
          <option key={e.id} value={e.id}>
            {e.name}
          </option>
        ))}
      </select>
    </Field>
  );
}

export function CreatePaperForm({ exams }: { exams: Exam[] }) {
  const [state, action, pending] = useActionState<ExamActionState, FormData>(createPaper, {});
  return (
    <form action={action} className="flex flex-col gap-3">
      <Result state={state} />
      <div className="grid gap-3 sm:grid-cols-2">
        <ExamSelect exams={exams} />
        <Field label="Code" htmlFor="paper-code" hint="Lower-case letters, digits and hyphens, e.g. aibe-18-set-a">
          <input id="paper-code" name="code" required className={inputClass} />
        </Field>
        <Field label="Title" htmlFor="paper-title">
          <input id="paper-title" name="title" required maxLength={200} className={inputClass} />
        </Field>
        <Field label="Edition" htmlFor="paper-edition">
          <input id="paper-edition" name="edition" maxLength={20} className={inputClass} />
        </Field>
        <Field label="Year" htmlFor="paper-year">
          <input id="paper-year" name="year" type="number" min={1990} max={2100} className={inputClass} />
        </Field>
        <Field label="Set" htmlFor="paper-set">
          <input id="paper-set" name="set_label" maxLength={20} className={inputClass} />
        </Field>
        <Field label="Total questions" htmlFor="paper-total">
          <input id="paper-total" name="total_questions" type="number" min={1} max={500} required className={inputClass} />
        </Field>
        <Field label="Duration (seconds)" htmlFor="paper-duration" hint="Leave empty until the duration is officially confirmed; timed mode stays off">
          <input id="paper-duration" name="duration_seconds" type="number" min={60} className={inputClass} />
        </Field>
        <Field label="Practice timer (seconds)" htmlFor="paper-practice-timer" hint="Optional. A clock for practising, shown to learners as practice timing not confirmed by BCI. It does not turn on the official timed mode.">
          <input id="paper-practice-timer" name="practice_timer_seconds" type="number" min={60} max={86400} className={inputClass} />
        </Field>
      </div>
      <Field label="Source note" htmlFor="paper-note" hint="Which official documents the paper was built from">
        <textarea id="paper-note" name="source_note" maxLength={2000} rows={2} className={inputClass} />
      </Field>
      <div>
        <Button type="submit" disabled={pending}>
          {pending ? 'Creating…' : 'Create draft paper'}
        </Button>
      </div>
    </form>
  );
}

export function CreateBlueprintForm({ exams }: { exams: Exam[] }) {
  const [state, action, pending] = useActionState<ExamActionState, FormData>(createBlueprint, {});
  const num = (name: string, label: string, props: Record<string, unknown> = {}) => (
    <Field label={label} htmlFor={`bp-${name}`}>
      <input id={`bp-${name}`} name={name} type="number" step="any" className={inputClass} {...props} />
    </Field>
  );
  return (
    <form action={action} className="flex flex-col gap-3">
      <Result state={state} />
      <div className="grid gap-3 sm:grid-cols-2">
        <ExamSelect exams={exams} />
        <Field label="Code" htmlFor="bp-code">
          <input id="bp-code" name="code" required className={inputClass} />
        </Field>
        {num('duration_seconds', 'Duration (seconds)', { required: true, min: 60 })}
        {num('total_questions', 'Total questions', { required: true, min: 1 })}
        {num('marks_correct', 'Marks per correct answer', { required: true, min: 0 })}
        {num('negative_marks', 'Negative marks per wrong answer', { min: 0 })}
        {num('marks_unanswered', 'Marks for unanswered', { min: 0 })}
        {num('pass_percent_general', 'Pass percentage, general', { min: 0, max: 100 })}
        {num('pass_percent_reserved', 'Pass percentage, reserved', { min: 0, max: 100 })}
        <Field label="Law regime filter" htmlFor="bp-regime" hint="Which questions a random mock may draw on">
          <select id="bp-regime" name="law_regime_filter" defaultValue="" className={inputClass}>
            <option value="">Default</option>
            <option value="any">Any (includes old-code questions)</option>
            <option value="new_codes">New codes only</option>
            <option value="old_codes">Old codes only</option>
          </select>
        </Field>
      </div>
      <p className="text-xs text-muted">A new blueprint is unverified. Mark it official-confirmed on its own page once the official source is named.</p>
      <div>
        <Button type="submit" disabled={pending}>
          {pending ? 'Creating…' : 'Create draft blueprint'}
        </Button>
      </div>
    </form>
  );
}

/** A JSON box for the parts too long for a form: paper positions, blueprint sections. */
export function JsonForm({
  save,
  name,
  label,
  hint,
  initial,
}: {
  save: (_: ExamActionState, form: FormData) => Promise<ExamActionState>;
  name: string;
  label: string;
  hint: string;
  initial: string;
}) {
  const [state, action, pending] = useActionState<ExamActionState, FormData>(save, {});
  return (
    <form action={action} className="flex flex-col gap-3">
      <Result state={state} />
      <Field label={label} htmlFor={`json-${name}`} hint={hint}>
        <textarea id={`json-${name}`} name={name} defaultValue={initial} rows={12} spellCheck={false} className={`${inputClass} font-mono text-xs`} />
      </Field>
      <div>
        <Button type="submit" disabled={pending}>
          {pending ? 'Saving…' : 'Save'}
        </Button>
      </div>
    </form>
  );
}

export function PracticeTimerForm({ id, seconds }: { id: string; seconds: number | null }) {
  const [state, action, pending] = useActionState<ExamActionState, FormData>(setPracticeTimer.bind(null, id), {});
  return (
    <form action={action} className="flex flex-col gap-3">
      <Result state={state} />
      <Field
        label="Practice timer (seconds)"
        htmlFor="practice-timer"
        hint="Learners see this as 'Practice timing — not officially confirmed by BCI'. Leave empty to remove it. It does not enable the official timed mode."
      >
        <input id="practice-timer" name="practice_timer_seconds" type="number" min={60} max={86400} defaultValue={seconds ?? ''} className={inputClass} />
      </Field>
      <div>
        <Button type="submit" variant="secondary" disabled={pending}>
          {pending ? 'Saving…' : 'Save practice timer'}
        </Button>
      </div>
    </form>
  );
}

export function BlueprintSourceForm({
  id,
  status,
  source,
  checkedOn,
}: {
  id: string;
  status: string;
  source: string | null;
  checkedOn: string | null;
}) {
  const [state, action, pending] = useActionState<ExamActionState, FormData>(saveBlueprintSource.bind(null, id), {});
  return (
    <form action={action} className="flex flex-col gap-3">
      <Result state={state} />
      <div className="grid gap-3 sm:grid-cols-3">
        <Field label="Settings are" htmlFor="cfg-status">
          <select id="cfg-status" name="config_status" defaultValue={status} className={inputClass}>
            <option value="unverified">Unverified</option>
            <option value="official_confirmed">Official-confirmed</option>
          </select>
        </Field>
        <Field label="Official source" htmlFor="cfg-source" hint="Needed for official-confirmed">
          <input id="cfg-source" name="config_source" defaultValue={source ?? ''} maxLength={500} className={inputClass} />
        </Field>
        <Field label="Checked on" htmlFor="cfg-checked">
          <input id="cfg-checked" name="config_checked_on" type="date" defaultValue={checkedOn ?? ''} className={inputClass} />
        </Field>
      </div>
      <div>
        <Button type="submit" variant="secondary" disabled={pending}>
          {pending ? 'Saving…' : 'Save settings status'}
        </Button>
      </div>
    </form>
  );
}

export function CreateSourceForm() {
  const [state, action, pending] = useActionState<ExamActionState, FormData>(createContentSource, {});
  return (
    <form action={action} className="flex flex-col gap-2">
      <Result state={state} />
      <div className="grid gap-2 sm:grid-cols-[10rem_1fr_1fr_1fr_auto]">
        <select name="kind" defaultValue="third_party" aria-label="Kind" className={inputClass}>
          <option value="third_party">Third party</option>
          <option value="official_bci">Official (BCI)</option>
          <option value="original">Original (in-house)</option>
        </select>
        <input name="title" required maxLength={300} placeholder="Title, e.g. CLAT 2026 UG Question Booklet (Set A)" aria-label="Title" className={inputClass} />
        <input name="publisher" maxLength={300} placeholder="Publisher (optional)" aria-label="Publisher" className={inputClass} />
        <input name="url" type="url" maxLength={2000} placeholder="https:// link (optional)" aria-label="Link" className={inputClass} />
        <Button type="submit" disabled={pending}>
          {pending ? 'Saving…' : 'Add'}
        </Button>
      </div>
    </form>
  );
}
