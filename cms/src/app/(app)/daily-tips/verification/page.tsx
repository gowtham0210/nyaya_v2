import type { Metadata } from 'next';
import Link from 'next/link';
import { Suspense } from 'react';
import { Skeleton } from '@/components/ui';
import { api, asApiError, type DailyTipStatus } from '@/lib/api';
import { getMe } from '@/lib/session';
import { TIP_CATEGORY_LABEL } from '@/lib/workflow';
import { isExactSourceLink } from '../source-link';
import { VerificationTable } from './verification-table';

export const metadata: Metadata = { title: 'Tips to verify' };

/**
 * The date used when 7 tips were published on a test database. No reviewer
 * checked them; see docs/daily-tips-draft/test_published_NOT_LEGALLY_VERIFIED.json.
 */
const PLACEHOLDER_VERIFIED_ON = '2026-11-17';
const STATUSES: DailyTipStatus[] = ['draft', 'changes_requested', 'in_review', 'retired'];
const DATE = new Intl.DateTimeFormat('en-IN', { dateStyle: 'medium' });

export default function VerificationPage() {
  return (
    <div className="flex flex-col gap-6">
      <Link href="/daily-tips" className="text-sm text-muted hover:text-text">← Daily tips</Link>
      <Suspense fallback={<Skeleton className="h-96" />}>
        <Worklist />
      </Suspense>
    </div>
  );
}

async function Worklist() {
  const client = await api();
  const me = await getMe();
  const tips = [];
  for (const status of STATUSES) {
    let cursor: string | undefined;
    do {
      const { data, error, response } = await client.GET('/v1/editor/daily-tips', {
        params: { query: { status, cursor, limit: 100 } },
      });
      if (!data) throw asApiError(error, response.status);
      tips.push(...data.items);
      cursor = data.next_cursor ?? undefined;
    } while (cursor);
  }
  const rows = tips
    .filter((t) => !t.last_verified_on || t.last_verified_on === PLACEHOLDER_VERIFIED_ON)
    .sort((a, b) => (a.publish_date ?? '9999').localeCompare(b.publish_date ?? '9999'));
  const noLink = rows.filter((t) => !isExactSourceLink(t.source_url)).length;

  return (
    <>
      <div>
        <h1 className="font-serif text-4xl">Tips to verify</h1>
        <p className="mt-1 text-sm text-muted">
          Tips with no real source check on record. Open each one, check it against its exact official source, then use
          &ldquo;I checked this today&rdquo;. Dates are never filled in for you, and nothing here sends a tip for review
          or publishes it.
        </p>
        <p className="mt-2 text-sm">
          <strong>{rows.length}</strong> to verify · <strong>{noLink}</strong> still need an exact source link
        </p>
      </div>

      {rows.length === 0 ? (
        <div className="rounded-xl border border-dashed border-border px-6 py-16 text-center text-muted">
          Every tip in draft, review or retired has a recorded check.
        </div>
      ) : (
        <VerificationTable
          isAdmin={me.roles.includes('admin')}
          rows={rows.map((t) => ({
            id: t.id,
            title: t.title,
            category: TIP_CATEGORY_LABEL[t.category],
            legalReference: t.legal_reference,
            status: t.status,
            showOn: t.publish_date ? DATE.format(new Date(t.publish_date)) : '—',
            placeholder: t.last_verified_on === PLACEHOLDER_VERIFIED_ON,
            blocked: !['draft', 'changes_requested'].includes(t.status)
              ? 'Only drafts can be checked'
              : !isExactSourceLink(t.source_url)
                ? 'Needs an exact source link'
                : null,
          }))}
        />
      )}
    </>
  );
}
