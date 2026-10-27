'use client';

import { Button } from '@/components/ui';

export default function AppError({ error, reset }: { error: Error & { digest?: string }; reset: () => void }) {
  return (
    <div className="mx-auto max-w-md py-16 text-center">
      <h1 className="font-serif text-3xl">Something went wrong</h1>
      <p className="mt-2 text-sm text-muted">{error.message || 'The page could not be loaded.'}</p>
      <Button className="mt-6" onClick={reset}>Try again</Button>
    </div>
  );
}
