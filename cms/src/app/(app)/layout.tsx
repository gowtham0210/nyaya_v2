import Link from 'next/link';
import { Suspense } from 'react';
import { Skeleton } from '@/components/ui';
import { NavLinks } from './nav-links';
import { UserMenu } from './user-menu';

export default function AppLayout({ children }: LayoutProps<'/'>) {
  return (
    <div className="flex flex-1 flex-col md:flex-row">
      {/* Fixed sidebar from md up; on small screens it stacks above the page. */}
      <aside className="z-10 flex flex-col gap-6 border-b border-border bg-surface px-4 py-4 md:fixed md:inset-y-0 md:left-0 md:w-64 md:overflow-y-auto md:border-r md:border-b-0 md:py-6">
        <Link href="/questions" className="font-serif text-2xl text-primary">
          Nyaya <span className="font-sans text-sm text-muted">CMS</span>
        </Link>
        <Suspense fallback={<div className="h-8" />}>
          <NavLinks />
        </Suspense>
        <div className="md:mt-auto">
          <Suspense fallback={<Skeleton className="h-8 w-40" />}>
            <UserMenu />
          </Suspense>
        </div>
      </aside>
      <main className="mx-auto w-full max-w-6xl flex-1 px-4 py-8 md:ml-64 md:w-[calc(100%-16rem)]">{children}</main>
    </div>
  );
}
