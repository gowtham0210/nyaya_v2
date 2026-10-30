'use client';

import { useActionState } from 'react';
import { useSearchParams } from 'next/navigation';
import { Alert, Button, Field, inputClass } from '@/components/ui';
import { SESSION_ENDED_PARAM } from '@/lib/session-cookies';
import { signIn, type SignInState } from './actions';

export function LoginForm() {
  const params = useSearchParams();
  const next = params.get('next') ?? '';
  const ended = params.has(SESSION_ENDED_PARAM);
  const passwordSet = params.has('password_set');
  const [state, action, pending] = useActionState<SignInState, FormData>(signIn, {});
  return (
    <form action={action} className="flex flex-col gap-4">
      <input type="hidden" name="next" value={next} />
      {state.error ? (
        <Alert>{state.error}</Alert>
      ) : passwordSet ? (
        <Alert tone="success">Password saved. Sign in with it.</Alert>
      ) : (
        ended && <Alert>Your session ended. Sign in again.</Alert>
      )}
      <Field label="Email" htmlFor="email">
        <input
          id="email"
          name="email"
          type="email"
          autoComplete="username"
          required
          defaultValue={state.email}
          className={inputClass}
        />
      </Field>
      <Field label="Password" htmlFor="password">
        <input id="password" name="password" type="password" autoComplete="current-password" required className={inputClass} />
      </Field>
      <Button type="submit" disabled={pending} className="mt-2">
        {pending ? 'Signing in…' : 'Sign in'}
      </Button>
    </form>
  );
}
