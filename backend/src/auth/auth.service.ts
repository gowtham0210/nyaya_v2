import { createHash, randomBytes } from 'node:crypto';
import { HttpStatus, Inject, Injectable } from '@nestjs/common';
import { JwtService } from '@nestjs/jwt';
import { and, eq, isNull } from 'drizzle-orm';
import { AuditService } from '../core/audit.service.js';
import { APP_CONFIG, type AppConfig } from '../core/config.js';
import { DB, type Db, type Tx } from '../core/db.js';
import { ApiError } from '../core/errors.js';
import { newId } from '../core/ids.js';
import { refreshTokens, users } from '../db/schema.js';
import type { MeDto, SessionDto } from './auth.dto.js';
import { DUMMY_HASH, hashPassword, verifyPassword } from './passwords.js';

type UserRow = typeof users.$inferSelect;

const REUSE_GRACE_MS = 30_000;

/** Postgres unique_violation, possibly wrapped by the query builder. */
const isUniqueViolation = (e: unknown): boolean => {
  for (let x: any = e; x; x = x.cause) if (x.code === '23505') return true;
  return false;
};

const sha256 = (s: string) => createHash('sha256').update(s).digest('hex');
const invalidRefresh = () =>
  new ApiError(
    HttpStatus.UNAUTHORIZED,
    'invalid_refresh_token',
    'Sign in again to continue',
  );

export const toMe = (u: UserRow): MeDto => ({
  id: u.id,
  email: u.email,
  display_name: u.displayName,
  roles: u.roles,
});

@Injectable()
export class AuthService {
  constructor(
    @Inject(DB) private readonly db: Db,
    @Inject(APP_CONFIG) private readonly config: AppConfig,
    private readonly jwt: JwtService,
    private readonly audit: AuditService,
  ) {}

  async signIn(
    email: string,
    password: string,
    requestId: string,
  ): Promise<SessionDto> {
    const [user] = await this.db
      .select()
      .from(users)
      .where(eq(users.email, email.toLowerCase()))
      .limit(1);
    // Always run the hash so response time does not reveal which emails exist.
    const ok = await verifyPassword(password, user?.passwordHash ?? DUMMY_HASH);
    if (!user || !ok || !user.isActive) {
      throw new ApiError(
        HttpStatus.UNAUTHORIZED,
        'invalid_credentials',
        'Email or password is incorrect',
      );
    }
    return this.db.transaction(async (tx) => {
      await this.audit.record(
        tx,
        { id: user.id, requestId },
        { action: 'auth.signed_in', entityType: 'user', entityId: user.id },
      );
      return this.issue(tx, user);
    });
  }

  /** Creates a learner account and signs it in. */
  async register(
    email: string,
    password: string,
    displayName: string,
    requestId: string,
  ): Promise<SessionDto> {
    const passwordHash = await hashPassword(password);
    const normalized = email.trim().toLowerCase();
    try {
      return await this.db.transaction(async (tx) => {
        const [user] = await tx
          .insert(users)
          .values({
            id: newId(),
            email: normalized,
            displayName: displayName.trim(),
            passwordHash,
            roles: ['learner'],
          })
          .returning();
        await this.audit.record(
          tx,
          { id: user.id, requestId },
          { action: 'auth.registered', entityType: 'user', entityId: user.id },
        );
        return this.issue(tx, user);
      });
    } catch (e) {
      if (isUniqueViolation(e)) {
        throw new ApiError(
          HttpStatus.CONFLICT,
          'email_taken',
          'An account with this email already exists',
        );
      }
      throw e;
    }
  }

  /** Rotates the refresh token. Presenting a used token revokes all of that user's sessions. */
  async refresh(token: string, requestId: string): Promise<SessionDto> {
    return this.db
      .transaction(async (tx) => {
        const [row] = await tx
          .select()
          .from(refreshTokens)
          .where(eq(refreshTokens.tokenHash, sha256(token)))
          .for('update')
          .limit(1);
        if (!row) throw invalidRefresh();
        // Two requests refreshing at once (e.g. parallel page loads) is a
        // race, not theft: reject the loser without ending every session.
        if (
          row.revokedAt &&
          Date.now() - row.revokedAt.getTime() < REUSE_GRACE_MS
        ) {
          throw invalidRefresh();
        }
        if (row.revokedAt) {
          await tx
            .update(refreshTokens)
            .set({ revokedAt: new Date() })
            .where(
              and(
                eq(refreshTokens.userId, row.userId),
                isNull(refreshTokens.revokedAt),
              ),
            );
          await this.audit.record(
            tx,
            { id: row.userId, requestId },
            {
              action: 'auth.refresh_token_reused',
              entityType: 'user',
              entityId: row.userId,
            },
          );
          return null;
        }
        const [user] = await tx
          .select()
          .from(users)
          .where(eq(users.id, row.userId))
          .limit(1);
        if (row.expiresAt < new Date() || !user?.isActive)
          throw invalidRefresh();
        await tx
          .update(refreshTokens)
          .set({ revokedAt: new Date() })
          .where(eq(refreshTokens.id, row.id));
        return this.issue(tx, user);
      })
      .then((session) => {
        // Thrown after the transaction so the revocations above are committed.
        if (!session) throw invalidRefresh();
        return session;
      });
  }

  async signOut(token: string) {
    await this.db
      .update(refreshTokens)
      .set({ revokedAt: new Date() })
      .where(
        and(
          eq(refreshTokens.tokenHash, sha256(token)),
          isNull(refreshTokens.revokedAt),
        ),
      );
  }

  async me(userId: string): Promise<MeDto> {
    const [user] = await this.db
      .select()
      .from(users)
      .where(eq(users.id, userId))
      .limit(1);
    return toMe(user);
  }

  private async issue(tx: Tx, user: UserRow): Promise<SessionDto> {
    const refresh = randomBytes(32).toString('base64url');
    await tx.insert(refreshTokens).values({
      id: newId(),
      userId: user.id,
      tokenHash: sha256(refresh),
      expiresAt: new Date(
        Date.now() + this.config.refreshTokenTtlDays * 86_400_000,
      ),
    });
    return {
      access_token: await this.jwt.signAsync({ sub: user.id }),
      expires_in: this.config.accessTokenTtlSec,
      refresh_token: refresh,
      user: toMe(user),
    };
  }
}
