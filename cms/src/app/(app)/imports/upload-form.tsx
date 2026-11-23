'use client';

import Link from 'next/link';
import { useState, useTransition } from 'react';
import { Alert, Button, inputClass } from '@/components/ui';
import { uploadImport, type UploadState } from './actions';
import { ImportReport } from './import-report';

export interface SourceOption {
  id: string;
  title: string;
}

const EXAMS = [
  { slug: 'aibe', name: 'AIBE' },
  { slug: 'ailet', name: 'AILET' },
  { slug: 'clat', name: 'CLAT' },
];

/**
 * Two steps: check the file (nothing is saved), then import the rows the
 * check said will become drafts. Changing the file, type or exam starts over.
 * An examination import also needs the exam and a content source.
 */
export function UploadForm({ sources }: { sources: SourceOption[] }) {
  const [kind, setKind] = useState<'general' | 'exam'>('general');
  const [exam, setExam] = useState('');
  const [source, setSource] = useState('');
  const [file, setFile] = useState<File | null>(null);
  const [state, setState] = useState<UploadState>({});
  const [pending, startTransition] = useTransition();
  const [step, setStep] = useState<'check' | 'import' | null>(null);

  const isExam = kind === 'exam';
  const reset = () => setState({});
  const send = (dryRun: boolean) => {
    if (!file) return;
    const form = new FormData();
    form.set('file', file);
    form.set('dry_run', String(dryRun));
    form.set('kind', kind);
    form.set('exam', exam);
    form.set('content_source_id', source);
    setStep(dryRun ? 'check' : 'import');
    startTransition(async () => setState(await uploadImport(form)));
  };
  const report = state.report;
  const toCreate = report?.totals.created ?? 0;
  const ready = !!file && (!isExam || !!exam);
  const canImport = toCreate > 0 && !pending;
  const templateHref = (format: 'xlsx' | 'csv') =>
    `/imports/template?kind=${kind}&format=${format}${isExam && exam ? `&exam=${exam}` : ''}`;

  return (
    <div className="flex flex-col gap-4">
      <fieldset className="flex flex-col gap-2">
        <legend className="text-sm font-medium">What are you importing?</legend>
        <div className="flex flex-wrap gap-4 text-sm">
          {(
            [
              ['general', 'General question import'],
              ['exam', 'Examination paper import'],
            ] as const
          ).map(([value, label]) => (
            <label key={value} className="flex items-center gap-2">
              <input
                type="radio"
                name="kind"
                value={value}
                checked={kind === value}
                onChange={() => {
                  setKind(value);
                  reset();
                }}
              />
              {label}
            </label>
          ))}
        </div>
        <p className="text-xs text-muted">
          {isExam
            ? 'Questions are kept out of the games and tagged for the chosen exam.'
            : 'Questions for the learning games and quizzes.'}{' '}
          Template:{' '}
          <a href={templateHref('xlsx')} download className="text-primary hover:underline">Excel (.xlsx)</a>
          {' · '}
          <a href={templateHref('csv')} download className="text-primary hover:underline">CSV</a>
        </p>
      </fieldset>

      {isExam && (
        <div className="grid gap-3 sm:grid-cols-2">
          <div className="flex flex-col gap-1.5">
            <label htmlFor="import-exam" className="text-sm font-medium">Examination</label>
            <select
              id="import-exam"
              value={exam}
              onChange={(e) => {
                setExam(e.target.value);
                reset();
              }}
              className={inputClass}
            >
              <option value="">Choose…</option>
              {EXAMS.map((e) => (
                <option key={e.slug} value={e.slug}>{e.name}</option>
              ))}
            </select>
          </div>
          <div className="flex flex-col gap-1.5">
            <label htmlFor="import-source" className="text-sm font-medium">Content source (optional, for attribution)</label>
            <select
              id="import-source"
              value={source}
              onChange={(e) => {
                setSource(e.target.value);
                reset();
              }}
              className={inputClass}
            >
              <option value="">None</option>
              {sources.map((s) => (
                <option key={s.id} value={s.id}>
                  {s.title}
                </option>
              ))}
            </select>
            {sources.length === 0 && (
              <p className="text-xs text-muted">
                None recorded yet. An admin can add one under <Link href="/exams" className="text-primary hover:underline">Exams</Link> if you want the questions attributed.
              </p>
            )}
          </div>
        </div>
      )}

      <form
        className="flex flex-col gap-3 sm:flex-row sm:items-end"
        onSubmit={(e) => {
          e.preventDefault();
          send(true);
        }}
      >
        <div className="flex flex-1 flex-col gap-1.5">
          <label htmlFor="import-file" className="text-sm font-medium">Question file (.csv or .xlsx, up to 500 questions)</label>
          <input
            id="import-file"
            type="file"
            accept=".csv,.xlsx,text/csv,application/vnd.openxmlformats-officedocument.spreadsheetml.sheet"
            onChange={(e) => {
              setFile(e.target.files?.[0] ?? null);
              reset();
            }}
            className={`${inputClass} file:mr-3 file:rounded-md file:border-0 file:bg-surface-2 file:px-3 file:py-1 file:text-text`}
          />
        </div>
        <Button type="submit" variant="secondary" disabled={!ready || pending}>
          {pending && step === 'check' ? 'Checking…' : 'Check file'}
        </Button>
      </form>

      {state.error && (
        <Alert>
          {state.error}
          {state.previousImportId && (
            <>
              {' '}
              <Link href={`/imports/${state.previousImportId}`} className="underline">See that import</Link>.
            </>
          )}
          {!!state.reasons?.length && (
            <ul className="mt-1 list-disc pl-5">
              {state.reasons.map((r) => <li key={r}>{r}</li>)}
            </ul>
          )}
        </Alert>
      )}

      {report && (
        <>
          <ImportReport report={report} />
          <div className="flex flex-wrap items-center gap-3 border-t border-border pt-4">
            <Button type="button" disabled={!canImport} onClick={() => send(false)}>
              {pending && step === 'import' ? 'Importing…' : `Import ${toCreate} question${toCreate === 1 ? '' : 's'} as drafts`}
            </Button>
            <p className="text-sm text-muted">
              {toCreate === 0
                ? 'Nothing new to import. Fix the rows with errors and check the file again.'
                : 'Rows with errors are left out. Nothing is sent for review, published or switched on.'}
            </p>
          </div>
        </>
      )}
    </div>
  );
}
