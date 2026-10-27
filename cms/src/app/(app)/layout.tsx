import Link from 'next/link';
import { Suspense } from 'react';
import { Skeleton } from '@/components/ui';
import { NavLinks } from './nav-links';
import { UserMenu } from './user-menu';

export default function AppLayout({ children }: LayoutProps<'/'>) {
  return (
    <>
      <header className="sticky top-0 z-10 border-b border-border bg-surface/95 backdrop-blur">
        <div className="mx-auto flex max-w-6xl flex-wrap items-center gap-x-6 gap-y-2 px-4 py-3">
          <Link href="/questions" className="font-serif text-2xl text-primary">
            Nyaya <span className="font-sans text-sm text-muted">CMS</span>
          </Link>
          <Suspense fallback={<div className="h-8 flex-1" />}>
            <div className="order-3 w-full sm:order-none sm:w-auto sm:flex-1">
              <NavLinks />
            </div>
          </Suspense>
          <div className="ml-auto">
            <Suspense fallback={<Skeleton className="h-8 w-40" />}>
              <UserMenu />
            </Suspense>
          </div>
        </div>
      </header>
      <main className="mx-auto w-full max-w-6xl flex-1 px-4 py-8">{children}</main>
    </>
  );
}
