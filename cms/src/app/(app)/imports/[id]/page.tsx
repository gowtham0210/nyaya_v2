import type { Metadata } from 'next';
import Link from 'next/link';
import { Suspense } from 'react';
import { Skeleton } from '@/components/ui';
import { api, must } from '@/lib/api';
import { ImportReport } from '../import-report';

export const metadata: Metadata = { title: 'Import report' };

const DATE_TIME = new Intl.DateTimeFormat('en-IN', { dateStyle: 'medium', timeStyle: 'short' });

export default function ImportReportPage({ params }: PageProps<'/imports/[id]'>) {
  return (
    <div className="flex flex-col gap-6">
      <Suspense fallback={<Skeleton className="h-96" />}>
        <Report params={params} />
      </Suspense>
    </div>
  );
}

async function Report({ params }: { params: PageProps<'/imports/[id]'>['params'] }) {
  const { id } = await params;
  if (!/^[0-9a-f-]{36}$/i.test(id)) return <p className="text-muted">No such import.</p>;
  const client = await api();
  const report = await client.GET('/v1/admin/import-jobs/{id}', { params: { path: { id } } }).then(must);
  return (
    <>
      <div>
        <Link href="/imports" className="text-sm text-primary hover:underline">← Imports</Link>
        <h1 className="mt-2 font-serif text-4xl break-all">{report.file_name}</h1>
        <p className="mt-1 text-sm text-muted">
          Imported {report.created_at && DATE_TIME.format(new Date(report.created_at))}. New questions are drafts: find them under{' '}
          <Link href="/questions?status=draft" className="text-primary hover:underline">Draft</Link> to finish and submit them.
        </p>
      </div>
      <ImportReport report={report} />
    </>
  );
}
