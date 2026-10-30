'use client';

import { useActionState, useSyncExternalStore } from 'react';
import { Alert, Button, Field, inputClass } from '@/components/ui';
import { choosePassword, type SetupState } from './actions';

// The token travels after "#", so it never reaches the server in the page request or its logs.
const readToken = () => new URLSearchParams(window.location.hash.slice(1)).get('token') ?? '';
const subscribe = (onChange: () => void) => {
  window.addEventListener('hashchange', onChange);
  return () => window.removeEventListener('hashchange', onChange);
};

export function SetupForm() {
  const token = useSyncExternalStore(subscribe, readToken, () => '');
  const [state, action, pending] = useActionState<SetupState, FormData>(choosePassword.bind(null, token), {});
  return (
    <form action={action} className="flex flex-col gap-4">
      {state.error && <Alert>{state.error}</Alert>}
      <Field label="New password" htmlFor="password" hint="At least 12 characters. A short sentence is easy to remember.">
        <input id="password" name="password" type="password" autoComplete="new-password" required minLength={12} maxLength={200} className={inputClass} />
      </Field>
      <Field label="The same password again" htmlFor="repeat">
        <input id="repeat" name="repeat" type="password" autoComplete="new-password" required minLength={12} maxLength={200} className={inputClass} />
      </Field>
      <Button type="submit" disabled={pending} className="mt-2">
        {pending ? 'Saving…' : 'Save password'}
      </Button>
    </form>
  );
}
