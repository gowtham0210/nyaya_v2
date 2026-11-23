'use client';

import type { ComponentProps } from 'react';

/**
 * A GET filter form that applies a dropdown choice as soon as it changes.
 * Text search still submits on Enter or with the Filter button, which also
 * keeps the form working without JavaScript.
 */
export function FilterForm({ children, ...props }: Omit<ComponentProps<'form'>, 'onChange'>) {
  return (
    <form
      {...props}
      onChange={(e) => {
        if (e.target instanceof HTMLSelectElement) e.currentTarget.requestSubmit();
      }}
    >
      {children}
    </form>
  );
}
