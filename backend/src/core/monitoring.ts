import * as Sentry from '@sentry/node';
import type { AppConfig } from './config.js';

/**
 * Crash reports to Sentry: errors only. No request data, no user, no
 * breadcrumbs, no traces. The only thing sent is the error, its stack, the
 * environment and the request id, which lets us find the matching log line.
 */
export function initMonitoring(
  config: AppConfig,
  extra: Partial<Sentry.NodeOptions> = {},
): boolean {
  if (!config.sentryDsn) return false;
  Sentry.init({
    dsn: config.sentryDsn,
    environment: config.isStaging
      ? 'staging'
      : config.isProduction
        ? 'production'
        : 'development',
    // Every kind of data the SDK could add on its own is switched off.
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
    integrations: (defaults) =>
      defaults.filter((i) => i.name !== 'ProcessSession'),
    beforeSend: scrub,
    ...extra,
  });
  return true;
}

/**
 * Database errors quote the query and its values ("params: ..."), which can
 * hold an email address or a name. Everything from there on is dropped, and
 * anything that could identify a person or a request is removed.
 */
export function scrub(event: Sentry.ErrorEvent): Sentry.ErrorEvent {
  const clean = (text: string) =>
    text.replace(/\bparams:[\s\S]*$/i, 'params: [removed]');
  for (const e of event.exception?.values ?? [])
    if (e.value) e.value = clean(e.value);
  if (event.message) event.message = clean(event.message);
  delete event.request;
  delete event.user;
  delete event.contexts?.runtime;
  event.breadcrumbs = [];
  event.extra = undefined;
  return event;
}

/** Sends one server error (a 5xx or a crash) to Sentry. Safe to call when reporting is off. */
export function reportError(exception: unknown, requestId?: string) {
  Sentry.captureException(exception, {
    tags: requestId ? { request_id: requestId } : undefined,
  });
}
