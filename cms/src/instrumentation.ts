import * as Sentry from '@sentry/nextjs';
import { monitoringOptions } from './lib/monitoring';

/** Reports errors from the portal's own server (pages, server actions, the proxy). Off without SENTRY_DSN. */
export function register() {
  const dsn = process.env.SENTRY_DSN;
  if (dsn) Sentry.init(monitoringOptions(dsn));
}

export const onRequestError = Sentry.captureRequestError;
