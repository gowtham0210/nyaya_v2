import Link from 'next/link';
import type { Schemas } from '@/lib/api';
import { ResolveForm } from './resolve-form';

type Report = Schemas['ReportDto'];

export const REASON_LABEL: Record<Report['reason'], string> = {
  wrong_answer: 'Wrong answer',
  unclear: 'Unclear',
  outdated_law: 'Outdated law',
  typo: 'Typo or wording',
  other: 'Other',
};

const OUTCOME_LABEL: Record<NonNullable<Report['outcome']>, string> = {
  fixed: 'Fixed',
  retired: 'Retired',
  no_change: 'No change needed',
};

const DATE_TIME = new Intl.DateTimeFormat('en-IN', { dateStyle: 'medium', timeStyle: 'short' });

/** How long a report has waited, in plain words. */
function age(iso: string) {
  const hours = Math.floor((Date.now() - new Date(iso).getTime()) / 3_600_000);
  if (hours < 1) return 'just now';
  if (hours < 24) return `${hours} h ago`;
  const days = Math.floor(hours / 24);
  return days === 1 ? '1 day ago' : `${days} days ago`;
}

/** Report cards; open ones carry the form to close them. */
export function ReportList({ reports, showQuestion = true }: { reports: Report[]; showQuestion?: boolean }) {
  return (
    <ul className="flex flex-col gap-3">
      {reports.map((r) => (
        <li key={r.id} className="flex flex-col gap-3 rounded-xl border border-border bg-surface p-4">
          <div className="flex flex-wrap items-center gap-2 text-xs">
            <span
              className={`rounded-full px-2.5 py-0.5 font-medium ${r.urgent ? 'bg-[var(--st-changes-bg)] text-[var(--st-changes-fg)]' : 'bg-surface-2 text-muted'}`}
            >
              {r.urgent ? 'Urgent · ' : ''}
              {REASON_LABEL[r.reason]}
            </span>
            <span className="text-muted">v{r.version_no} · reported {age(r.created_at)}</span>
          </div>
          {showQuestion && (
            <Link href={`/questions/${r.question_id}`} className="font-medium hover:text-primary">
              {r.stem}
            </Link>
          )}
          {r.comment && <p className="text-sm whitespace-pre-line">“{r.comment}”</p>}
          {r.outcome ? (
            <p className="text-sm text-muted">
              {OUTCOME_LABEL[r.outcome]} by {r.resolved_by ?? 'staff'}
              {r.resolved_at && ` on ${DATE_TIME.format(new Date(r.resolved_at))}`}: {r.resolution_note}
            </p>
          ) : (
            // Beside a question the panel is narrow, so the form stacks.
            <ResolveForm reportId={r.id} stacked={!showQuestion} />
          )}
        </li>
      ))}
    </ul>
  );
}
