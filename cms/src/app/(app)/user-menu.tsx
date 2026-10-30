import Link from 'next/link';
import { getMe } from '@/lib/session';
import { ROLE_LABEL, hasRole } from '@/lib/workflow';
import { signOut } from './actions';

export async function UserMenu() {
  const me = await getMe();
  return (
    <div className="flex items-center gap-3 text-sm">
      <div className="hidden text-right sm:block">
        <div className="font-medium">{me.display_name}</div>
        <div className="text-xs text-muted">{me.roles.map((r) => ROLE_LABEL[r]).join(', ')}</div>
      </div>
      {hasRole(me, 'admin') && (
        <Link href="/staff" className="rounded-lg px-3 py-1.5 text-muted hover:bg-surface-2 hover:text-text">
          Staff
        </Link>
      )}
      <form action={signOut}>
        <button type="submit" className="rounded-lg border border-border px-3 py-1.5 text-muted hover:bg-surface-2 hover:text-text">
          Sign out
        </button>
      </form>
    </div>
  );
}
