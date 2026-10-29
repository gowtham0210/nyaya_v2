import type { Metadata } from 'next';
import Link from 'next/link';
import { Suspense } from 'react';
import { Skeleton } from '@/components/ui';
import { api, must } from '@/lib/api';
import { getMe } from '@/lib/session';
import { TRIAGE_ROLES, hasRole } from '@/lib/workflow';
import { ReportList } from './report-list';

export const metadata: Metadata = { title: 'Reports' };

export default function ReportsPage({ searchParams }: PageProps<'/reports'>) {
  return (
    <div className="flex flex-col gap-6">
      <Suspense fallback={<Skeleton className="h-96" />}>
        <Reports searchParams={searchParams} />
      </Suspense>
    </div>
  );
}

async function Reports({ searchParams }: { searchParams: PageProps<'/reports'>['searchParams'] }) {
  const sp = await searchParams;
  const closed = sp.status === 'closed';
  const me = await getMe();
  if (!hasRole(me, ...TRIAGE_ROLES)) {
    return <p className="text-muted">Only editors, reviewers and publishers handle reports.</p>;
  }
  const client = await api();
  const page = await client
    .GET('/v1/admin/content-reports', { params: { query: { status: closed ? 'closed' : 'open', limit: 100 } } })
    .then(must);
  const tab = (active: boolean) =>
    `rounded-lg px-3 py-1.5 text-sm ${active ? 'bg-surface-2 font-medium text-text' : 'text-muted hover:text-text'}`;

  return (
    <>
      <div>
        <h1 className="font-serif text-4xl">Reports</h1>
        <p className="mt-1 text-sm text-muted">
          Problems learners reported. Fix or retire the question from its page, then close the report here. Wrong answers and
          outdated law come first.
        </p>
      </div>
      <nav className="flex gap-1" aria-label="Report status">
        <Link href="/reports" className={tab(!closed)} aria-current={!closed ? 'page' : undefined}>Open</Link>
        <Link href="/reports?status=closed" className={tab(closed)} aria-current={closed ? 'page' : undefined}>Closed</Link>
      </nav>
      {page.items.length === 0 ? (
        <div className="rounded-xl border border-dashed border-border px-6 py-16 text-center text-muted">
          {closed ? 'No closed reports yet.' : 'No open reports. Nice.'}
        </div>
      ) : (
        <ReportList reports={page.items} />
      )}
    </>
  );
}
