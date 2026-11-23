import type { Metadata } from 'next';
import Link from 'next/link';
import { Suspense } from 'react';
import { Skeleton } from '@/components/ui';
import { getMe } from '@/lib/session';
import { hasRole } from '@/lib/workflow';
import { createTip } from '../actions';
import { DailyTipForm } from '../daily-tip-form';
import { EMPTY_TIP } from '../form-state';

export const metadata: Metadata = { title: 'New tip' };

export default function NewTipPage() {
  return (
    <div className="mx-auto flex max-w-3xl flex-col gap-6">
      <div>
        <Link href="/daily-tips" className="text-sm text-muted hover:text-text">← Daily tips</Link>
        <h1 className="mt-2 font-serif text-4xl">New tip</h1>
      </div>
      <Suspense fallback={<Skeleton className="h-[40rem]" />}>
        <NewTip />
      </Suspense>
    </div>
  );
}

async function NewTip() {
  const me = await getMe();
  if (!hasRole(me, 'content_editor')) {
    return <p className="text-muted">Only content editors can write daily tips.</p>;
  }
  return <DailyTipForm initial={EMPTY_TIP} action={createTip} submitLabel="Create draft" />;
}
