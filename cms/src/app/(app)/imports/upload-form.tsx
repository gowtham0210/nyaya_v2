'use client';

import Link from 'next/link';
import { useState, useTransition } from 'react';
import { Alert, Button, inputClass } from '@/components/ui';
import { uploadImport, type UploadState } from './actions';
import { ImportReport } from './import-report';

/**
 * Two steps: check the file (nothing is saved), then import the rows the
 * check said will become drafts. Changing the file starts over.
 */
export function UploadForm() {
  const [file, setFile] = useState<File | null>(null);
  const [state, setState] = useState<UploadState>({});
  const [pending, startTransition] = useTransition();
  const [step, setStep] = useState<'check' | 'import' | null>(null);

  const send = (dryRun: boolean) => {
    if (!file) return;
    const form = new FormData();
    form.set('file', file);
    form.set('dry_run', String(dryRun));
    setStep(dryRun ? 'check' : 'import');
    startTransition(async () => setState(await uploadImport(form)));
  };
  const report = state.report;
  const toCreate = report?.totals.created ?? 0;

  return (
    <div className="flex flex-col gap-4">
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
              setState({});
            }}
            className={`${inputClass} file:mr-3 file:rounded-md file:border-0 file:bg-surface-2 file:px-3 file:py-1 file:text-text`}
          />
        </div>
        <Button type="submit" variant="secondary" disabled={!file || pending}>
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
            <Button type="button" disabled={pending || toCreate === 0} onClick={() => send(false)}>
              {pending && step === 'import' ? 'Importing…' : `Import ${toCreate} question${toCreate === 1 ? '' : 's'} as drafts`}
            </Button>
            <p className="text-sm text-muted">
              {toCreate === 0
                ? 'Nothing new to import. Fix the rows with errors and check the file again.'
                : 'Rows with errors are left out. Nothing is sent for review or published.'}
            </p>
          </div>
        </>
      )}
    </div>
  );
}
