import { createHash, randomBytes } from 'node:crypto';
import { HttpStatus, Inject, Injectable } from '@nestjs/common';
import { JwtService } from '@nestjs/jwt';
import { and, eq, inArray, isNull, or } from 'drizzle-orm';
import { AuditService } from '../core/audit.service.js';
import { APP_CONFIG, type AppConfig } from '../core/config.js';
import { DB, type Db, type Tx } from '../core/db.js';
import { ApiError, isUniqueViolation } from '../core/errors.js';
import { newId } from '../core/ids.js';
import { RateLimitStore } from '../core/rate-limits.js';
import {
  auditLog,
  contentReports,
  duelMatches,
  quizSessions,
  refreshTokens,
  users,
} from '../db/schema.js';
import type { MeDto, SessionDto } from './auth.dto.js';
import { DUMMY_HASH, hashPassword, verifyPassword } from './passwords.js';

type UserRow = typeof users.$inferSelect;

const REUSE_GRACE_MS = 30_000;
/** Window for the per-account password limit. */
const PASSWORD_WINDOW_MS = 15 * 60_000;

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
    private readonly limits: RateLimitStore,
  ) {}

  /**
   * Counts a password attempt for [email], from any address, and refuses once
   * there were too many in the window. Unknown emails count the same, so the
   * answer never shows which accounts exist. Returns the counter's key.
   */
  private async passwordAttempt(email: string): Promise<string> {
    const key = `password:${email.trim().toLowerCase()}`;
    const { hits, msLeft } = await this.limits.hit(key, PASSWORD_WINDOW_MS);
    if (hits > this.config.passwordAttemptsPerAccount) {
      const minutes = Math.max(1, Math.ceil(msLeft / 60_000));
      throw new ApiError(
        HttpStatus.TOO_MANY_REQUESTS,
        'rate_limited',
        `Too many wrong passwords for this account. Try again in ${minutes} ${minutes === 1 ? 'minute' : 'minutes'}.`,
      );
    }
    return key;
  }

  async signIn(
    email: string,
    password: string,
    requestId: string,
  ): Promise<SessionDto> {
    const attempts = await this.passwordAttempt(email);
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
    await this.limits.clear(attempts);
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

  /**
   * Deletes a learner's account and the personal data on it, after the
   * password is confirmed. Wallet, settings, bookmarks, league places, chat
   * counts and sign-in tokens go with the account row; quiz sessions and the
   * learner's own audit entries are removed here. Reports a learner sent stay
   * for the editors with the reason and question, but without the learner's
   * name or the free-text comment, which may hold personal details. Staff
   * accounts are managed by admins, not deleted by their owners.
   */
  async deleteAccount(userId: string, password: string): Promise<void> {
    const [user] = await this.db
      .select()
      .from(users)
      .where(eq(users.id, userId))
      .limit(1);
    if (!user) throw ApiError.notFound('Account');
    if (user.roles.some((r) => r !== 'learner'))
      throw new ApiError(
        HttpStatus.CONFLICT,
        'staff_account',
        'Staff accounts are removed by an admin',
      );
    // Wrong passwords here count towards the same limit as sign-in.
    await this.passwordAttempt(user.email);
    if (!(await verifyPassword(password, user.passwordHash)))
      throw new ApiError(
        HttpStatus.FORBIDDEN,
        'wrong_password',
        'The password is not right',
      );
    await this.db.transaction(async (tx) => {
      // Their name leaves the duels other learners raced against them.
      await tx
        .update(duelMatches)
        .set({ opponentName: 'Former learner' })
        .where(
          inArray(
            duelMatches.opponentSessionId,
            tx
              .select({ id: quizSessions.id })
              .from(quizSessions)
              .where(eq(quizSessions.userId, userId)),
          ),
        );
      await tx.delete(quizSessions).where(eq(quizSessions.userId, userId));
      // The row's user_id is set to null when the account goes; the comment is cleared first.
      await tx
        .update(contentReports)
        .set({ comment: null })
        .where(eq(contentReports.userId, userId));
      await tx
        .delete(auditLog)
        .where(
          or(
            eq(auditLog.actorId, userId),
            and(eq(auditLog.entityType, 'user'), eq(auditLog.entityId, userId)),
          ),
        );
      await tx.delete(users).where(eq(users.id, userId));
      // Nothing links this id to a person any more; the entry only shows it happened.
      await this.audit.record(tx, null, {
        action: 'account.deleted',
        entityType: 'user',
        entityId: userId,
      });
    });
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
