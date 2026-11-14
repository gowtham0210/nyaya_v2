import Link from 'next/link';
import { Suspense } from 'react';
import { Skeleton } from '@/components/ui';
import { NavLinks } from './nav-links';
import { UserMenu } from './user-menu';

export default function AppLayout({ children }: LayoutProps<'/'>) {
  return (
    <div className="flex min-h-screen w-full flex-1 flex-col md:flex-row">
      <aside className="flex shrink-0 flex-col gap-6 border-b border-border bg-surface px-4 py-5 md:sticky md:top-0 md:h-screen md:w-64 md:overflow-y-auto md:border-r md:border-b-0">
        <Link href="/questions" className="font-serif text-2xl text-primary">
          Nyaya <span className="font-sans text-sm text-muted">CMS</span>
        </Link>
        <Suspense fallback={<div className="h-8 flex-1" />}>
          <div className="md:flex-1">
            <NavLinks />
          </div>
        </Suspense>
        <div className="border-t border-border pt-4">
          <Suspense fallback={<Skeleton className="h-8 w-40" />}>
            <UserMenu />
          </Suspense>
        </div>
      </aside>
      <main className="mx-auto w-full max-w-6xl min-w-0 flex-1 px-6 py-8">{children}</main>
    </div>
  );
}
