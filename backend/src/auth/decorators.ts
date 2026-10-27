import {
  createParamDecorator,
  ExecutionContext,
  SetMetadata,
} from '@nestjs/common';
import type { Request } from 'express';
import type { Actor } from '../core/audit.service.js';
import type { Role } from '../db/schema.js';
import type { AuthUser } from './auth-user.js';

export const IS_PUBLIC = 'isPublic';
export const ROLES = 'roles';

/** Skips authentication. */
export const Public = () => SetMetadata(IS_PUBLIC, true);

/** The caller needs at least one of these roles. */
export const Roles = (...roles: Role[]) => SetMetadata(ROLES, roles);

export const CurrentUser = createParamDecorator(
  (_: unknown, ctx: ExecutionContext): AuthUser =>
    ctx.switchToHttp().getRequest<Request>().user!,
);

/** The signed-in user plus the request id, for the audit log. */
export const CurrentActor = createParamDecorator(
  (_: unknown, ctx: ExecutionContext): Actor => {
    const req = ctx.switchToHttp().getRequest<Request>();
    return { id: req.user!.id, requestId: req.id };
  },
);
