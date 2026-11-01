import {
  createHash,
  randomBytes,
  randomInt,
  timingSafeEqual,
} from 'node:crypto';
import { HttpStatus, Inject, Injectable, Logger } from '@nestjs/common';
import { JwtService } from '@nestjs/jwt';
import { and, eq, inArray, isNull, or } from 'drizzle-orm';
import { AuditService } from '../core/audit.service.js';
import { APP_CONFIG, type AppConfig } from '../core/config.js';
import { DB, type Db, type Tx } from '../core/db.js';
import { ApiError, isUniqueViolation } from '../core/errors.js';
import { newId } from '../core/ids.js';
import { Mailer } from '../core/mailer.js';
import { RateLimitStore } from '../core/rate-limits.js';
import {
  auditLog,
  contentReports,
  duelMatches,
  passwordResetCodes,
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
/** How long an emailed reset code works. */
const RESET_CODE_TTL_MS = 15 * 60_000;
/** Wrong tries before a reset code stops working. */
const RESET_CODE_MAX_WRONG = 5;
/** Reset emails per address in [RESET_CODE_TTL_MS]; more are quietly not sent. */
const RESET_MAILS_PER_WINDOW = 3;

const sha256 = (s: string) => createHash('sha256').update(s).digest('hex');
const invalidResetCode = () =>
  new ApiError(
    HttpStatus.BAD_REQUEST,
    'invalid_reset_code',
    'This code is wrong or has expired. Ask for a new one.',
  );
const sameHash = (a: string, b: string) =>
  a.length === b.length && timingSafeEqual(Buffer.from(a), Buffer.from(b));
const resetCodeHash = (userId: string, code: string) =>
  sha256(`${userId}:${code}`);
const isLearner = (u: UserRow) =>
  u.isActive && u.roles.every((r) => r === 'learner');

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
  private readonly logger = new Logger('Auth');

  constructor(
    @Inject(DB) private readonly db: Db,
    @Inject(APP_CONFIG) private readonly config: AppConfig,
    private readonly jwt: JwtService,
    private readonly audit: AuditService,
    private readonly limits: RateLimitStore,
    private readonly mailer: Mailer,
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

  /**
   * Emails a learner a code to choose a new password. Nothing tells the
   * caller whether the email has an account: unknown emails, staff accounts
   * (an admin resets those) and too many requests all end the same way.
   */
  async requestPasswordReset(email: string): Promise<void> {
    if (!this.mailer.available)
      throw new ApiError(
        HttpStatus.SERVICE_UNAVAILABLE,
        'password_reset_unavailable',
        'Password reset is not available right now',
      );
    const normalized = email.trim().toLowerCase();
    const { hits } = await this.limits.hit(
      `reset-mail:${normalized}`,
      RESET_CODE_TTL_MS,
    );
    if (hits > RESET_MAILS_PER_WINDOW) return;
    const [user] = await this.db
      .select()
      .from(users)
      .where(eq(users.email, normalized))
      .limit(1);
    if (!user || !isLearner(user)) return;
    const code = randomInt(0, 1_000_000).toString().padStart(6, '0');
    const row = {
      codeHash: resetCodeHash(user.id, code),
      wrongTries: 0,
      expiresAt: new Date(Date.now() + RESET_CODE_TTL_MS),
    };
    await this.db
      .insert(passwordResetCodes)
      .values({ userId: user.id, ...row })
      .onConflictDoUpdate({ target: passwordResetCodes.userId, set: row });
    try {
      await this.mailer.send({
        to: user.email,
        subject: 'Your Nyaya password reset code',
        text:
          `Your code is ${code}. It works for 15 minutes.\n\n` +
          "If you didn't ask to reset your Nyaya password, ignore this email. " +
          'Your password stays the same.',
      });
    } catch (e) {
      // Logged, not shown: an error here would tell the caller the account exists.
      this.logger.error(`Reset mail failed: ${(e as Error).message}`);
    }
  }

  /**
   * Sets a new password with the emailed code, signs the account out
   * everywhere and signs it in here.
   */
  async confirmPasswordReset(
    email: string,
    code: string,
    newPassword: string,
    requestId: string,
  ): Promise<SessionDto> {
    const normalized = email.trim().toLowerCase();
    const [found] = await this.db
      .select({ user: users, reset: passwordResetCodes })
      .from(passwordResetCodes)
      .innerJoin(users, eq(users.id, passwordResetCodes.userId))
      .where(eq(users.email, normalized))
      .limit(1);
    if (!found || !isLearner(found.user) || found.reset.expiresAt < new Date())
      throw invalidResetCode();
    const { user, reset } = found;
    if (!sameHash(resetCodeHash(user.id, code), reset.codeHash)) {
      if (reset.wrongTries + 1 >= RESET_CODE_MAX_WRONG)
        await this.db
          .delete(passwordResetCodes)
          .where(eq(passwordResetCodes.userId, user.id));
      else
        await this.db
          .update(passwordResetCodes)
          .set({ wrongTries: reset.wrongTries + 1 })
          .where(eq(passwordResetCodes.userId, user.id));
      throw invalidResetCode();
    }
    const passwordHash = await hashPassword(newPassword);
    const session = await this.db.transaction(async (tx) => {
      // Deleting first means two requests with the same code can't both win.
      const used = await tx
        .delete(passwordResetCodes)
        .where(eq(passwordResetCodes.userId, user.id))
        .returning({ userId: passwordResetCodes.userId });
      if (used.length === 0) return null;
      const [updated] = await tx
        .update(users)
        .set({ passwordHash, updatedAt: new Date() })
        .where(eq(users.id, user.id))
        .returning();
      await tx
        .update(refreshTokens)
        .set({ revokedAt: new Date() })
        .where(
          and(
            eq(refreshTokens.userId, user.id),
            isNull(refreshTokens.revokedAt),
          ),
        );
      await this.audit.record(
        tx,
        { id: user.id, requestId },
        {
          action: 'auth.password_reset',
          entityType: 'user',
          entityId: user.id,
        },
      );
      return this.issue(tx, updated);
    });
    if (!session) throw invalidResetCode();
    // Earlier wrong passwords no longer lock the new one out.
    await this.limits.clear(`password:${normalized}`);
    return session;
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
