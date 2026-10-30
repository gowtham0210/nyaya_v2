import { createHash, randomBytes } from 'node:crypto';
import { HttpStatus, Inject, Injectable } from '@nestjs/common';
import {
  and,
  arrayContains,
  arrayOverlaps,
  asc,
  desc,
  eq,
  inArray,
  isNull,
  ne,
} from 'drizzle-orm';
import { hashPassword } from '../auth/passwords.js';
import { AuditService, type Actor } from '../core/audit.service.js';
import { DB, type Db, type Tx } from '../core/db.js';
import { ApiError, isUniqueViolation } from '../core/errors.js';
import { newId } from '../core/ids.js';
import {
  refreshTokens,
  STAFF_ROLES,
  staffSetupTokens,
  users,
} from '../db/schema.js';
import type {
  InviteStaffDto,
  SetupLinkDto,
  StaffListDto,
  StaffMemberDto,
  UpdateStaffDto,
} from './staff.dto.js';

const SETUP_LINK_DAYS = 7;
const sha256 = (s: string) => createHash('sha256').update(s).digest('hex');

type UserRow = typeof users.$inferSelect;
type TokenRow = typeof staffSetupTokens.$inferSelect;

const refused = (code: string, message: string) =>
  new ApiError(HttpStatus.CONFLICT, code, message);

const invalidLink = () =>
  new ApiError(
    HttpStatus.BAD_REQUEST,
    'invalid_link',
    'This link is not valid any more. Ask an admin for a new one.',
  );

function toMember(u: UserRow, pending: TokenRow | undefined): StaffMemberDto {
  return {
    id: u.id,
    email: u.email,
    display_name: u.displayName,
    roles: u.roles.filter((r) => r !== 'learner') as StaffMemberDto['roles'],
    is_active: u.isActive,
    setup: pending
      ? {
          expires_at: pending.expiresAt.toISOString(),
          expired: pending.expiresAt < new Date(),
        }
      : null,
    created_at: u.createdAt.toISOString(),
  };
}

/**
 * Staff accounts, managed by admins. Nobody but the person ever knows their
 * password: an invite or a reset gives a one-time link to choose one.
 */
@Injectable()
export class StaffService {
  constructor(
    @Inject(DB) private readonly db: Db,
    private readonly audit: AuditService,
  ) {}

  async list(): Promise<StaffListDto> {
    const rows = await this.db
      .select()
      .from(users)
      .where(arrayOverlaps(users.roles, STAFF_ROLES))
      .orderBy(desc(users.isActive), asc(users.displayName));
    const pending = await this.pendingLinks(
      this.db,
      rows.map((r) => r.id),
    );
    return { items: rows.map((u) => toMember(u, pending.get(u.id))) };
  }

  async invite(actor: Actor, dto: InviteStaffDto): Promise<SetupLinkDto> {
    const email = dto.email.toLowerCase();
    // Nobody can sign in until they use the link: the stored password is random.
    const unusable = await hashPassword(randomBytes(32).toString('base64url'));
    const id = newId();
    try {
      return await this.db.transaction(async (tx) => {
        const [user] = await tx
          .insert(users)
          .values({
            id,
            email,
            displayName: dto.display_name,
            passwordHash: unusable,
            roles: dto.roles,
          })
          .returning();
        const link = await this.newLink(tx, actor, user.id);
        await this.audit.record(tx, actor, {
          action: 'staff.invited',
          entityType: 'user',
          entityId: id,
          data: { email, roles: dto.roles },
        });
        return { staff: toMember(user, link.row), ...link.out };
      });
    } catch (e) {
      if (isUniqueViolation(e))
        throw refused('email_taken', 'This email already has an account');
      throw e;
    }
  }

  async update(
    actor: Actor,
    id: string,
    dto: UpdateStaffDto,
  ): Promise<StaffMemberDto> {
    return this.db.transaction(async (tx) => {
      const target = await this.lockStaff(tx, id);
      const roles = dto.roles ?? target.roles;
      const active = dto.is_active ?? target.isActive;
      const losesAdmin =
        target.roles.includes('admin') &&
        target.isActive &&
        (!roles.includes('admin') || !active);
      if (id === actor.id && losesAdmin)
        throw refused(
          'own_account',
          'You cannot remove your own admin role or disable yourself',
        );
      if (losesAdmin) {
        const others = await tx
          .select({ id: users.id })
          .from(users)
          .where(
            and(
              arrayContains(users.roles, ['admin']),
              eq(users.isActive, true),
              ne(users.id, id),
            ),
          )
          .for('update');
        if (others.length === 0)
          throw refused('last_admin', 'There must always be an active admin');
      }

      const patch = {
        ...(dto.display_name !== undefined && {
          displayName: dto.display_name,
        }),
        ...(dto.roles && { roles: dto.roles }),
        ...(dto.is_active !== undefined && { isActive: dto.is_active }),
      };
      const [updated] = Object.keys(patch).length
        ? await tx
            .update(users)
            .set({ ...patch, updatedAt: new Date() })
            .where(eq(users.id, id))
            .returning()
        : [target];
      if (target.isActive && !active) await this.signOutEverywhere(tx, id);
      if (Object.keys(patch).length)
        await this.audit.record(tx, actor, {
          action: 'staff.updated',
          entityType: 'user',
          entityId: id,
          data: {
            before: { roles: target.roles, is_active: target.isActive },
            ...patch,
          },
        });
      return toMember(updated, (await this.pendingLinks(tx, [id])).get(id));
    });
  }

  /**
   * A new setup link for a forgotten password or a lost invite. The old
   * password stops working and the person is signed out everywhere. Never
   * for yourself: losing the link would lock you out, maybe with no other admin.
   */
  async resetLink(actor: Actor, id: string): Promise<SetupLinkDto> {
    if (id === actor.id)
      throw refused(
        'own_account',
        'Another admin must make a new setup link for you',
      );
    const unusable = await hashPassword(randomBytes(32).toString('base64url'));
    return this.db.transaction(async (tx) => {
      const target = await this.lockStaff(tx, id);
      if (!target.isActive)
        throw refused('disabled', 'Enable the account before sending a link');
      const [user] = await tx
        .update(users)
        .set({ passwordHash: unusable, updatedAt: new Date() })
        .where(eq(users.id, id))
        .returning();
      await this.signOutEverywhere(tx, id);
      const link = await this.newLink(tx, actor, id);
      await this.audit.record(tx, actor, {
        action: 'staff.setup_link_created',
        entityType: 'user',
        entityId: id,
      });
      return { staff: toMember(user, link.row), ...link.out };
    });
  }

  /** The person behind a setup link chooses their password. Works once. */
  async setPassword(
    token: string,
    password: string,
    requestId: string,
  ): Promise<void> {
    const hash = await hashPassword(password);
    await this.db.transaction(async (tx) => {
      const [link] = await tx
        .select()
        .from(staffSetupTokens)
        .where(eq(staffSetupTokens.tokenHash, sha256(token)))
        .for('update');
      if (!link || link.usedAt || link.expiresAt < new Date())
        throw invalidLink();
      const [user] = await tx
        .select()
        .from(users)
        .where(eq(users.id, link.userId))
        .limit(1);
      if (!user?.isActive) throw invalidLink();
      const now = new Date();
      await tx
        .update(users)
        .set({ passwordHash: hash, updatedAt: now })
        .where(eq(users.id, user.id));
      await tx
        .update(staffSetupTokens)
        .set({ usedAt: now })
        .where(eq(staffSetupTokens.id, link.id));
      await this.signOutEverywhere(tx, user.id);
      await this.audit.record(
        tx,
        { id: user.id, requestId },
        { action: 'staff.password_set', entityType: 'user', entityId: user.id },
      );
    });
  }

  private async lockStaff(tx: Tx, id: string): Promise<UserRow> {
    const [user] = await tx
      .select()
      .from(users)
      .where(and(eq(users.id, id), arrayOverlaps(users.roles, STAFF_ROLES)))
      .for('update');
    if (!user) throw ApiError.notFound('Staff member');
    return user;
  }

  /** Replaces any unused link, so only the newest one works. */
  private async newLink(tx: Tx, actor: Actor, userId: string) {
    await tx
      .delete(staffSetupTokens)
      .where(
        and(
          eq(staffSetupTokens.userId, userId),
          isNull(staffSetupTokens.usedAt),
        ),
      );
    const token = randomBytes(32).toString('base64url');
    const [row] = await tx
      .insert(staffSetupTokens)
      .values({
        id: newId(),
        userId,
        tokenHash: sha256(token),
        createdBy: actor.id,
        expiresAt: new Date(Date.now() + SETUP_LINK_DAYS * 86_400_000),
      })
      .returning();
    return {
      row,
      out: { setup_token: token, expires_at: row.expiresAt.toISOString() },
    };
  }

  private async pendingLinks(db: Db | Tx, ids: string[]) {
    if (ids.length === 0) return new Map<string, TokenRow>();
    const rows = await db
      .select()
      .from(staffSetupTokens)
      .where(
        and(
          inArray(staffSetupTokens.userId, ids),
          isNull(staffSetupTokens.usedAt),
        ),
      );
    return new Map(rows.map((r) => [r.userId, r]));
  }

  private async signOutEverywhere(tx: Tx, userId: string) {
    await tx
      .update(refreshTokens)
      .set({ revokedAt: new Date() })
      .where(
        and(eq(refreshTokens.userId, userId), isNull(refreshTokens.revokedAt)),
      );
  }
}
