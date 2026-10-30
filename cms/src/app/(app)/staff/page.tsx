import type { Metadata } from 'next';
import { Suspense } from 'react';
import { Card, Skeleton } from '@/components/ui';
import { api, must } from '@/lib/api';
import { getMe } from '@/lib/session';
import { ROLE_LABEL, hasRole } from '@/lib/workflow';
import { ItemRow } from '../topics/taxonomy-forms';
import { EditStaffForm, InviteForm, StaffActions } from './staff-forms';

export const metadata: Metadata = { title: 'Staff' };

const DATE = new Intl.DateTimeFormat('en-IN', { dateStyle: 'medium' });

export default function StaffPage() {
  return (
    <div className="flex flex-col gap-6">
      <div>
        <h1 className="font-serif text-4xl">Staff</h1>
        <p className="mt-1 max-w-3xl text-sm text-muted">
          Who can use this portal and what they may do. New people get a one-time link to choose their own password; nobody
          else ever sees it. Role changes and disabling take effect at once.
        </p>
      </div>
      <Suspense fallback={<Skeleton className="h-96" />}>
        <Staff />
      </Suspense>
    </div>
  );
}

async function Staff() {
  const me = await getMe();
  if (!hasRole(me, 'admin')) return <p className="text-muted">Only admins manage staff accounts.</p>;
  const { items } = await (await api()).GET('/v1/admin/staff').then(must);

  return (
    <>
      <Card>
        <details>
          <summary className="cursor-pointer font-medium text-primary">Add a staff member</summary>
          <div className="mt-4">
            <InviteForm />
          </div>
        </details>
      </Card>

      <Card className="flex flex-col divide-y divide-border py-0">
        {items.map((m) => {
          const self = m.id === me.id;
          const status = !m.is_active
            ? { text: 'Disabled', tone: 'bg-[var(--st-changes-bg)] text-[var(--st-changes-fg)]' }
            : m.setup
              ? m.setup.expired
                ? { text: 'Setup link expired', tone: 'bg-surface-2 text-muted' }
                : { text: `Waiting to set a password (link until ${DATE.format(new Date(m.setup.expires_at))})`, tone: 'bg-[var(--st-review-bg)] text-[var(--st-review-fg)]' }
              : { text: 'Active', tone: 'bg-[var(--st-live-bg)] text-[var(--st-live-fg)]' };
          return (
            <ItemRow
              key={m.id}
              info={
                <>
                  <div className="flex flex-wrap items-center gap-2">
                    <span className="font-medium">
                      {m.display_name}
                      {self && <span className="text-muted"> (you)</span>}
                    </span>
                    <span className={`rounded-full px-2 py-0.5 text-xs font-medium ${status.tone}`}>{status.text}</span>
                  </div>
                  <p className="mt-0.5 text-xs text-muted">
                    {m.email} · {m.roles.map((r) => ROLE_LABEL[r]).join(', ')}
                  </p>
                </>
              }
              actions={<StaffActions id={m.id} name={m.display_name} active={m.is_active} self={self} />}
              editForm={<EditStaffForm id={m.id} name={m.display_name} roles={m.roles} />}
            />
          );
        })}
      </Card>
    </>
  );
}
