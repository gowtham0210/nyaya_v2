import type { Metadata } from 'next';
import Link from 'next/link';
import { Suspense } from 'react';
import { Card, Skeleton } from '@/components/ui';
import { api, must } from '@/lib/api';
import { getMe } from '@/lib/session';
import { IMPORT_ROLES, hasRole } from '@/lib/workflow';
import { UploadForm } from './upload-form';

export const metadata: Metadata = { title: 'Imports' };

const COLUMNS: [string, string][] = [
  ['topic', 'Required. The topic slug, e.g. constitution-basics (see an export for the slugs).'],
  ['stem', 'Required. The question text.'],
  ['option_a … option_f', 'At least option_a and option_b, filled in order.'],
  ['correct', 'Required. The letter of the right option, e.g. b.'],
  ['explanation, source_title, valid_from', 'Needed before review; a row without them still becomes a draft.'],
  ['source_url, citation, provision_reference, valid_to', 'Optional. Links must start with https://. Dates are YYYY-MM-DD.'],
  ['difficulty, jurisdiction, language', 'Optional: 1–3 (default 1), IN, en.'],
  ['external_ref', 'Optional. Your own id for the row; a row whose id is already in the bank is skipped.'],
];

const DATE_TIME = new Intl.DateTimeFormat('en-IN', { dateStyle: 'medium', timeStyle: 'short' });

export default function ImportsPage() {
  return (
    <div className="flex flex-col gap-6">
      <div>
        <h1 className="font-serif text-4xl">Imports</h1>
        <p className="mt-1 text-sm text-muted">
          Add many questions from a spreadsheet. Every new question arrives as a draft and goes through review like any other.
        </p>
      </div>
      <Suspense fallback={<Skeleton className="h-96" />}>
        <Imports />
      </Suspense>
    </div>
  );
}

async function Imports() {
  const client = await api();
  const [me, jobs] = await Promise.all([getMe(), client.GET('/v1/admin/import-jobs').then(must)]);
  const canImport = hasRole(me, ...IMPORT_ROLES);

  return (
    <>
      {canImport && (
        <Card className="flex flex-col gap-4">
          <UploadForm />
          <details className="text-sm">
            <summary className="cursor-pointer font-medium">File format</summary>
            <p className="mt-2 text-muted">
              One question per row, column names in the first row. Start from the{' '}
              <a href="/question-import-template.csv" download className="text-primary hover:underline">template</a>, or edit an{' '}
              <Link href="/questions" className="text-primary hover:underline">export</Link> of the bank. Save CSV files as
              &ldquo;CSV UTF-8&rdquo; so Indian-language text survives.
            </p>
            <dl className="mt-3 grid gap-x-4 gap-y-2 sm:grid-cols-[14rem_1fr]">
              {COLUMNS.map(([col, help]) => (
                <div key={col} className="contents">
                  <dt className="font-mono text-xs">{col}</dt>
                  <dd className="text-muted">{help}</dd>
                </div>
              ))}
            </dl>
          </details>
        </Card>
      )}

      <section className="flex flex-col gap-3">
        <h2 className="font-serif text-2xl">Past imports</h2>
        {jobs.items.length === 0 ? (
          <div className="rounded-xl border border-dashed border-border px-6 py-12 text-center text-muted">No imports yet.</div>
        ) : (
          <div className="overflow-x-auto rounded-xl border border-border bg-surface">
            <table className="w-full min-w-[640px] text-sm">
              <thead className="border-b border-border text-left text-xs tracking-wide text-muted uppercase">
                <tr>
                  <th className="px-4 py-3 font-medium">File</th>
                  <th className="px-4 py-3 font-medium">By</th>
                  <th className="px-4 py-3 font-medium">Drafts</th>
                  <th className="px-4 py-3 font-medium">Skipped</th>
                  <th className="px-4 py-3 font-medium">Errors</th>
                </tr>
              </thead>
              <tbody className="divide-y divide-border">
                {jobs.items.map((j) => (
                  <tr key={j.id} className="hover:bg-surface-2/60">
                    <td className="px-4 py-3">
                      <Link href={`/imports/${j.id}`} className="font-medium hover:text-primary">{j.file_name}</Link>
                      <div className="text-xs text-muted">{DATE_TIME.format(new Date(j.created_at))}</div>
                    </td>
                    <td className="px-4 py-3 text-muted">{j.created_by_name}</td>
                    <td className="px-4 py-3">
                      {j.totals.created}
                      {j.totals.with_warnings > 0 && <span className="text-xs text-muted"> ({j.totals.with_warnings} unfinished)</span>}
                    </td>
                    <td className="px-4 py-3 text-muted">{j.totals.skipped}</td>
                    <td className="px-4 py-3 text-muted">{j.totals.failed}</td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        )}
      </section>
    </>
  );
}
