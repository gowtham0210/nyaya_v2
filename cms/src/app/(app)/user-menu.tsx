import Link from 'next/link';
import { getMe } from '@/lib/session';
import { ROLE_LABEL, hasRole } from '@/lib/workflow';
import { signOut } from './actions';

export async function UserMenu() {
  const me = await getMe();
  return (
    <div className="flex flex-col gap-1 border-t border-border pt-4 text-sm">
      <div className="px-3 pb-2">
        <div className="font-medium">{me.display_name}</div>
        <div className="text-xs text-muted">{me.roles.map((r) => ROLE_LABEL[r]).join(', ')}</div>
      </div>
      {hasRole(me, 'admin', 'analyst') && (
        <Link href="/analytics" className="rounded-lg px-3 py-2 text-muted hover:bg-surface-2 hover:text-text">
          Analytics
        </Link>
      )}
      {hasRole(me, 'admin') && (
        <Link href="/staff" className="rounded-lg px-3 py-2 text-muted hover:bg-surface-2 hover:text-text">
          Staff
        </Link>
      )}
      <form action={signOut} className="mt-1">
        <button
          type="submit"
          className="w-full rounded-lg border border-border px-3 py-2 text-left text-muted hover:bg-surface-2 hover:text-text"
        >
          Sign out
        </button>
      </form>
    </div>
  );
}
