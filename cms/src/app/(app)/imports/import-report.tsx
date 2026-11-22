import Link from 'next/link';
import type { Schemas } from '@/lib/api';

type Report = Schemas['ImportReportDto'];
type Row = Schemas['ImportRowDto'];

const OUTCOME: Record<Row['outcome'], { done: string; planned: string; tone: string }> = {
  created: { done: 'Draft created', planned: 'Will be a draft', tone: 'bg-[var(--st-approved-bg)] text-[var(--st-approved-fg)]' },
  skipped: { done: 'Already in the bank', planned: 'Already in the bank', tone: 'bg-surface-2 text-muted' },
  failed: { done: 'Not imported', planned: 'Will not be imported', tone: 'bg-[var(--st-changes-bg)] text-[var(--st-changes-fg)]' },
  withdrawn: { done: 'Withdrawn position', planned: 'Will be a withdrawn position', tone: 'bg-surface-2 text-muted' },
};

/** Counts, then one line per row; rows with nothing to say are folded away. */
export function ImportReport({ report }: { report: Report }) {
  const t = report.totals;
  const notable = report.rows.filter((r) => r.outcome !== 'created' || r.problems.length > 0);
  const clean = report.rows.length - notable.length;
  const duplicates = report.rows.filter(
    (r) => r.outcome === 'skipped' || r.problems.some((p) => p.reason.startsWith('Same question as row')),
  ).length;
  const invalid = report.rows.filter((r) => r.outcome === 'failed').length - report.rows.filter(
    (r) => r.outcome === 'failed' && r.problems.some((p) => p.reason.startsWith('Same question as row')),
  ).length;
  const stat = (n: number, label: string) => (
    <div className="rounded-lg border border-border bg-surface px-4 py-3">
      <div className="font-serif text-2xl">{n}</div>
      <div className="text-xs text-muted">{label}</div>
    </div>
  );

  return (
    <div className="flex flex-col gap-4">
      <div className="grid grid-cols-2 gap-3 sm:grid-cols-3 lg:grid-cols-7">
        {stat(report.rows.length, 'rows in the file')}
        {stat(t.created, report.dry_run ? 'valid: ready to import as drafts' : 'drafts created')}
        {stat(invalid, 'invalid: have errors')}
        {stat(duplicates, 'duplicates (in the bank or the file)')}
        {stat(t.with_warnings, 'valid but need more before review')}
        {stat(t.failed + t.skipped, report.dry_run ? 'will not be imported' : 'not imported')}
        {t.withdrawn > 0 && stat(t.withdrawn, 'withdrawn (no question; kept as a paper position)')}
      </div>

      {notable.length > 0 && (
        <div className="overflow-x-auto rounded-xl border border-border bg-surface">
          <table className="w-full min-w-[640px] text-sm">
            <thead className="border-b border-border text-left text-xs tracking-wide text-muted uppercase">
              <tr>
                <th className="px-4 py-3 font-medium">Row</th>
                <th className="px-4 py-3 font-medium">Result</th>
                <th className="px-4 py-3 font-medium">What to know</th>
              </tr>
            </thead>
            <tbody className="divide-y divide-border">
              {notable.map((r) => {
                const o = OUTCOME[r.outcome];
                return (
                  <tr key={r.row} className="align-top">
                    <td className="px-4 py-3 whitespace-nowrap">
                      {r.row}
                      {r.external_ref && <div className="text-xs text-muted">{r.external_ref}</div>}
                    </td>
                    <td className="px-4 py-3">
                      <span className={`rounded-full px-2.5 py-0.5 text-xs font-medium whitespace-nowrap ${o.tone}`}>
                        {report.dry_run ? o.planned : o.done}
                      </span>
                      {r.question_id && !report.dry_run && (
                        <div className="mt-1 text-xs">
                          <Link href={`/questions/${r.question_id}`} className="text-primary hover:underline">Open question</Link>
                        </div>
                      )}
                      {r.question_id && report.dry_run && r.outcome === 'skipped' && (
                        <div className="mt-1 text-xs">
                          <Link href={`/questions/${r.question_id}`} className="text-primary hover:underline">See the existing one</Link>
                        </div>
                      )}
                    </td>
                    <td className="px-4 py-3">
                      <ul className="flex flex-col gap-1">
                        {r.problems.map((p, i) => (
                          <li key={i} className={p.level === 'error' ? 'text-danger' : 'text-muted'}>
                            {p.field && <span className="font-mono text-xs">{p.field}: </span>}
                            {p.reason}
                          </li>
                        ))}
                      </ul>
                    </td>
                  </tr>
                );
              })}
            </tbody>
          </table>
        </div>
      )}
      {clean > 0 && (
        <p className="text-sm text-muted">
          {clean === 1 ? '1 other row' : `${clean} other rows`} {report.dry_run ? 'will become' : 'became'}{' '}
          {clean === 1 ? 'a complete draft' : 'complete drafts'}, ready to submit for review.
        </p>
      )}
    </div>
  );
}
