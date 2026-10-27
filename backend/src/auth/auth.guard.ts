import {
  CanActivate,
  ExecutionContext,
  HttpStatus,
  Inject,
  Injectable,
} from '@nestjs/common';
import { Reflector } from '@nestjs/core';
import { JwtService } from '@nestjs/jwt';
import { eq } from 'drizzle-orm';
import type { Request } from 'express';
import { DB, type Db } from '../core/db.js';
import { ApiError } from '../core/errors.js';
import { users, type Role } from '../db/schema.js';
import { IS_PUBLIC, ROLES } from './decorators.js';

const unauthenticated = (message: string) =>
  new ApiError(HttpStatus.UNAUTHORIZED, 'unauthenticated', message);

/**
 * Global guard: every route needs a valid access token unless marked
 * @Public(). Roles come from the database, not the token, so a role change
 * or deactivation takes effect on the next request.
 */
@Injectable()
export class AuthGuard implements CanActivate {
  constructor(
    private readonly reflector: Reflector,
    private readonly jwt: JwtService,
    @Inject(DB) private readonly db: Db,
  ) {}

  async canActivate(ctx: ExecutionContext): Promise<boolean> {
    const targets = [ctx.getHandler(), ctx.getClass()];
    if (this.reflector.getAllAndOverride<boolean>(IS_PUBLIC, targets))
      return true;

    const req = ctx.switchToHttp().getRequest<Request>();
    const [scheme, token] = (req.header('authorization') ?? '').split(' ');
    if (scheme !== 'Bearer' || !token)
      throw unauthenticated('Sign in to continue');

    let sub: string;
    try {
      ({ sub } = await this.jwt.verifyAsync<{ sub: string }>(token));
    } catch {
      throw new ApiError(
        HttpStatus.UNAUTHORIZED,
        'token_expired',
        'Your session has expired',
      );
    }
    const [user] = await this.db
      .select()
      .from(users)
      .where(eq(users.id, sub))
      .limit(1);
    if (!user?.isActive) throw unauthenticated('Sign in to continue');
    req.user = {
      id: user.id,
      email: user.email,
      displayName: user.displayName,
      roles: user.roles,
    };

    const needed = this.reflector.getAllAndOverride<Role[] | undefined>(
      ROLES,
      targets,
    );
    if (needed && !needed.some((r) => user.roles.includes(r)))
      throw ApiError.forbidden();
    return true;
  }
}
