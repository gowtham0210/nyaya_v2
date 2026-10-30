import type { Metadata } from 'next';
import { SetupForm } from './setup-form';

export const metadata: Metadata = { title: 'Choose your password' };

/** Opened from the one-time link an admin sends to a new or returning staff member. */
export default function SetupPage() {
  return (
    <main className="flex flex-1 items-center justify-center px-4 py-12">
      <div className="w-full max-w-sm">
        <div className="mb-8 text-center">
          <h1 className="font-serif text-4xl text-primary">Nyaya</h1>
          <p className="mt-1 text-sm text-muted">Choose your password for the Content Management Portal</p>
        </div>
        <div className="rounded-xl border border-border bg-surface p-6 shadow-sm">
          <SetupForm />
        </div>
        <p className="mt-6 text-center text-xs text-muted">The link works once. Nobody else, including the admin, sees your password.</p>
      </div>
    </main>
  );
}
