import type { Metadata } from 'next';
import { Suspense } from 'react';
import { Skeleton } from '@/components/ui';
import { LoginForm } from './login-form';

export const metadata: Metadata = { title: 'Sign in' };

export default function LoginPage() {
  return (
    <main className="flex flex-1 items-center justify-center px-4 py-12">
      <div className="w-full max-w-sm">
        <div className="mb-8 text-center">
          <h1 className="font-serif text-4xl text-primary">Nyaya</h1>
          <p className="mt-1 text-sm text-muted">Content Management Portal</p>
        </div>
        <div className="rounded-xl border border-border bg-surface p-6 shadow-sm">
          <Suspense fallback={<Skeleton className="h-56" />}>
            <LoginForm />
          </Suspense>
        </div>
        <p className="mt-6 text-center text-xs text-muted">For editors, legal reviewers and publishers.</p>
      </div>
    </main>
  );
}
