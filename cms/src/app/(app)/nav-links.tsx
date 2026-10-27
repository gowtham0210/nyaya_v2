'use client';

import Link from 'next/link';
import { usePathname, useSearchParams } from 'next/navigation';

const LINKS = [
  { label: 'All questions', href: '/questions', status: null },
  { label: 'Review queue', href: '/questions?status=in_review', status: 'in_review' },
  { label: 'Ready to publish', href: '/questions?status=approved', status: 'approved' },
];

export function NavLinks() {
  const pathname = usePathname();
  const status = useSearchParams().get('status');
  return (
    <nav className="flex gap-1 overflow-x-auto text-sm" aria-label="Main">
      {LINKS.map((l) => {
        const active = pathname === '/questions' && (status ?? null) === l.status;
        return (
          <Link
            key={l.href}
            href={l.href}
            aria-current={active ? 'page' : undefined}
            className={`rounded-lg px-3 py-1.5 whitespace-nowrap ${active ? 'bg-surface-2 font-medium text-text' : 'text-muted hover:text-text'}`}
          >
            {l.label}
          </Link>
        );
      })}
    </nav>
  );
}
