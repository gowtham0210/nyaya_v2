'use client';

import * as Sentry from '@sentry/nextjs';
import { useEffect } from 'react';

/** The last safety net: a page that failed to draw at all. Reports the error and offers another try. */
export default function GlobalError({ error, retry }: { error: unknown; retry: () => void }) {
  useEffect(() => {
    Sentry.captureException(error);
  }, [error]);
  return (
    <html lang="en">
      <body style={{ fontFamily: 'system-ui, sans-serif', padding: '4rem 1rem', textAlign: 'center' }}>
        <h1 style={{ fontSize: '1.5rem' }}>Something went wrong</h1>
        <p>The problem has been reported. You can try again, or reload the page.</p>
        <button type="button" onClick={() => retry()} style={{ marginTop: '1rem', padding: '0.5rem 1rem' }}>
          Try again
        </button>
      </body>
    </html>
  );
}
