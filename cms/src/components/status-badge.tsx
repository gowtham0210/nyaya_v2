import type { VersionStatus } from '@/lib/api';
import { STATUS_LABEL } from '@/lib/workflow';

const STYLE: Record<VersionStatus, string> = {
  draft: 'bg-[var(--st-draft-bg)] text-[var(--st-draft-fg)]',
  in_review: 'bg-[var(--st-review-bg)] text-[var(--st-review-fg)]',
  changes_requested: 'bg-[var(--st-changes-bg)] text-[var(--st-changes-fg)]',
  approved: 'bg-[var(--st-approved-bg)] text-[var(--st-approved-fg)]',
  published: 'bg-[var(--st-live-bg)] text-[var(--st-live-fg)]',
  superseded: 'bg-[var(--st-ended-bg)] text-[var(--st-ended-fg)]',
  retired: 'bg-[var(--st-retired-bg)] text-[var(--st-retired-fg)]',
};

export function StatusBadge({ status }: { status: VersionStatus }) {
  return (
    <span className={`inline-flex shrink-0 items-center rounded-full px-2.5 py-0.5 text-xs font-medium whitespace-nowrap ${STYLE[status]}`}>
      {STATUS_LABEL[status]}
    </span>
  );
}
