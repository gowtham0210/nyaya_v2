import { createHash, timingSafeEqual } from 'node:crypto';
import { isIP } from 'node:net';
import { Inject, Injectable } from '@nestjs/common';
import { Reflector } from '@nestjs/core';
import {
  InjectThrottlerOptions,
  InjectThrottlerStorage,
  ThrottlerGuard,
  type ThrottlerModuleOptions,
  type ThrottlerStorage,
} from '@nestjs/throttler';
import type { Request } from 'express';
import { APP_CONFIG, type AppConfig } from '../core/config.js';

/** Browser address the content portal passes on, and the secret proving it is the portal. */
export const CLIENT_IP_HEADER = 'x-nyaya-client-ip';
export const PROXY_SECRET_HEADER = 'x-nyaya-proxy-secret';

/**
 * The sign-in rate limit, per client address. The content portal calls the
 * API from its own server, so on its own every staff member would share one
 * address; with the shared secret, the portal's word for the browser's
 * address is used instead.
 */
@Injectable()
export class AuthThrottlerGuard extends ThrottlerGuard {
  constructor(
    @InjectThrottlerOptions() options: ThrottlerModuleOptions,
    @InjectThrottlerStorage() storage: ThrottlerStorage,
    reflector: Reflector,
    @Inject(APP_CONFIG) private readonly config: AppConfig,
  ) {
    super(options, storage, reflector);
  }

  protected override async getTracker(req: Request): Promise<string> {
    const forwarded = req.header(CLIENT_IP_HEADER);
    if (
      forwarded &&
      isIP(forwarded) &&
      sameSecret(req.header(PROXY_SECRET_HEADER), this.config.portalProxySecret)
    )
      return super.getTracker({ ip: forwarded });
    return super.getTracker(req);
  }
}

/** Constant-time compare; false when either side is missing. */
function sameSecret(given: string | undefined, expected: string | undefined) {
  if (!given || !expected) return false;
  const digest = (s: string) => createHash('sha256').update(s).digest();
  return timingSafeEqual(digest(given), digest(expected));
}
