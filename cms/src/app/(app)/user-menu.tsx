import { getMe } from '@/lib/session';
import { ROLE_LABEL } from '@/lib/workflow';
import { signOut } from './actions';

export async function UserMenu() {
  const me = await getMe();
  return (
    <div className="flex items-center gap-3 text-sm">
      <div className="hidden text-right sm:block">
        <div className="font-medium">{me.display_name}</div>
        <div className="text-xs text-muted">{me.roles.map((r) => ROLE_LABEL[r]).join(', ')}</div>
      </div>
      <form action={signOut}>
        <button type="submit" className="rounded-lg border border-border px-3 py-1.5 text-muted hover:bg-surface-2 hover:text-text">
          Sign out
        </button>
      </form>
    </div>
  );
}
