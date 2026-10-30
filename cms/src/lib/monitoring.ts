import type { BrowserOptions, ErrorEvent } from '@sentry/nextjs';

/**
 * Crash reports to Sentry: errors only. No user, no cookies or headers, no
 * form data, no breadcrumbs, no traces and no session replay. An error keeps
 * the page it happened on, without the query string or the part after `#`
 * (the staff setup link carries its one-time token there).
 */
export const monitoringOptions = (dsn: string | undefined): BrowserOptions => ({
  dsn: dsn || undefined,
  environment: process.env.NEXT_PUBLIC_SENTRY_ENV || (process.env.NODE_ENV === 'production' ? 'production' : 'development'),
  dataCollection: {
    userInfo: false,
    cookies: false,
    httpHeaders: false,
    httpBodies: [],
    urlQueryParams: false,
    databaseQueryData: false,
    queues: false,
    stackFrameVariables: false,
  },
  tracesSampleRate: 0,
  maxBreadcrumbs: 0,
  // No release-health "sessions" either: errors only.
  integrations: (defaults) => defaults.filter((i) => i.name !== 'BrowserSession' && i.name !== 'ProcessSession'),
  beforeSend: scrub,
});

/** The address without its query string and fragment. */
export function pageOnly(url: string): string {
  return url.split('#')[0].split('?')[0];
}

export function scrub(event: ErrorEvent): ErrorEvent {
  if (event.request?.url) event.request = { url: pageOnly(event.request.url) };
  else delete event.request;
  delete event.user;
  event.breadcrumbs = [];
  event.extra = undefined;
  if (event.transaction) event.transaction = pageOnly(event.transaction);
  return event;
}
