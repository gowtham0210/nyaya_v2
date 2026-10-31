import type { Metadata } from 'next';
import Link from 'next/link';
import { Suspense } from 'react';
import { Skeleton } from '@/components/ui';
import { getMe } from '@/lib/session';
import { hasRole } from '@/lib/workflow';
import { createNews } from '../actions';
import { EMPTY_NEWS } from '../form-state';
import { NewsForm } from '../news-form';

export const metadata: Metadata = { title: 'New article' };

export default function NewArticlePage() {
  return (
    <div className="mx-auto flex max-w-3xl flex-col gap-6">
      <div>
        <Link href="/news" className="text-sm text-muted hover:text-text">← News</Link>
        <h1 className="mt-2 font-serif text-4xl">New article</h1>
      </div>
      <Suspense fallback={<Skeleton className="h-[40rem]" />}>
        <NewArticle />
      </Suspense>
    </div>
  );
}

async function NewArticle() {
  const me = await getMe();
  if (!hasRole(me, 'content_editor')) {
    return <p className="text-muted">Only content editors can write news articles.</p>;
  }
  return <NewsForm initial={EMPTY_NEWS} action={createNews} submitLabel="Create draft" />;
}
