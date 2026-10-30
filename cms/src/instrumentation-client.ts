import * as Sentry from '@sentry/nextjs';
import { monitoringOptions } from './lib/monitoring';

// Reports errors from staff's browsers. The key is read when the portal is built; without it nothing is sent.
const dsn = process.env.NEXT_PUBLIC_SENTRY_DSN;
if (dsn) Sentry.init(monitoringOptions(dsn));
