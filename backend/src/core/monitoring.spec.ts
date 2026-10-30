import * as Sentry from '@sentry/node';
import { afterEach, describe, expect, it } from 'vitest';
import { loadConfig } from './config.js';
import { initMonitoring, reportError } from './monitoring.js';
import { ApiExceptionFilter } from './api-exception.filter.js';
import { HttpException, type ArgumentsHost } from '@nestjs/common';

const DSN = 'https://abc123@o1.ingest.us.sentry.io/42';

/** Runs the real reporting path but keeps what would be sent, instead of sending it. */
function capture(extra: Record<string, unknown> = {}) {
  const sent: any[] = [];
  const ok = initMonitoring(loadConfig({ SENTRY_DSN: DSN }), {
    ...extra,
    transport: () => ({
      send: async (envelope: any) => {
        for (const [header, payload] of envelope[1])
          sent.push({ ...payload, __type: header.type });
        return {};
      },
      flush: async () => true,
    }),
  });
  return { ok, sent };
}

describe('crash reports', () => {
  afterEach(async () => {
    await Sentry.close();
  });

  it('are off when there is no SENTRY_DSN', () => {
    expect(initMonitoring(loadConfig({}))).toBe(false);
  });

  it('send the error and the request id, and nothing about the person', async () => {
    const { ok, sent } = capture();
    expect(ok).toBe(true);
    // What the database layer throws: the query and its values in the message.
    // Built in pieces so the test's own source lines (which the SDK attaches) don't contain it.
    const email = ['asha', 'example.com'].join('@');
    const err = new Error(
      `Failed query: select * from users where email = $1\nparams: ${email}`,
    );
    reportError(err, 'req-123');
    await Sentry.flush(1000);

    expect(sent).toHaveLength(1);
    const event = sent[0];
    expect(event.exception.values[0].value).not.toContain(email);
    expect(event.exception.values[0].value).toContain('params: [removed]');
    expect(event.tags).toMatchObject({ request_id: 'req-123' });
    expect(event.environment).toBe('development');
    expect(event.user).toBeUndefined();
    expect(event.request).toBeUndefined();
    expect(event.breadcrumbs).toEqual([]);
    expect(JSON.stringify(event)).not.toContain(email);
  });

  it('are the only thing sent, even when a release name is known', async () => {
    // With a release, the SDK would also send release-health sessions (as CI does via GITHUB_SHA).
    const { sent } = capture({ release: 'nyaya-api@1' });
    reportError(new Error('boom'));
    await Sentry.close(1000);
    expect(sent.length).toBeGreaterThan(0);
    expect(new Set(sent.map((i) => i.__type))).toEqual(new Set(['event']));
  });

  it('come from the error filter for unexpected faults only', async () => {
    const { sent } = capture();
    const filter = new ApiExceptionFilter();
    const handle = (exception: unknown) => {
      const res = { status: () => ({ json: () => undefined }) };
      const host = {
        switchToHttp: () => ({
          getRequest: () => ({ method: 'GET', path: '/v1/x', id: 'req-9' }),
          getResponse: () => res,
        }),
      } as unknown as ArgumentsHost;
      filter.catch(exception, host);
    };
    handle(new HttpException('Not allowed', 403)); // the caller's mistake
    handle(new HttpException({ code: 'wrong_password' }, 409));
    // A 5xx thrown on purpose (like "AI chat is not configured") is a handled answer.
    handle(new HttpException({ code: 'chat_unavailable' }, 503));
    handle(new Error('boom')); // a real fault
    await Sentry.flush(1000);
    expect(sent).toHaveLength(1);
    expect(sent[0].exception.values[0].value).toBe('boom');
  });
});
