import { HttpStatus, Inject, Injectable } from '@nestjs/common';
import { and, desc, eq, gte, ilike, inArray, lt, ne, type SQL } from 'drizzle-orm';
import { AuditService, type Actor } from '../core/audit.service.js';
import { DB, type Db, type Tx } from '../core/db.js';
import { ApiError, isUniqueViolation } from '../core/errors.js';
import { newId } from '../core/ids.js';
import { decodeCursor, toPage, type Page } from '../core/pagination.js';
import { auditLog, dailyTips } from '../db/schema.js';
import { indiaToday } from '../learn/scoring.js';
import type {
  CreateDailyTipDto,
  DailyTipDetailDto,
  DailyTipListItemDto,
  ListTipsQuery,
  PublicDailyTipDto,
  TodayTipDto,
  UpdateDailyTipDto,
} from './daily-tips.dto.js';
import { TIP_ACTIONS, tipProblems, type TipAction } from './workflow.js';

type TipRow = typeof dailyTips.$inferSelect;
type TipPatch = Partial<typeof dailyTips.$inferInsert>;

const iso = (d: Date | null) => (d ? d.toISOString() : null);

const AUDIT_ACTIONS: Record<TipAction, string> = {
  edit: 'daily_tip.updated',
  submit: 'daily_tip.submitted',
  request_changes: 'daily_tip.changes_requested',
  approve: 'daily_tip.approved',
  publish: 'daily_tip.published',
  revise: 'daily_tip.revised',
  retire: 'daily_tip.retired',
};

/** Request field → column, and whether the column may be cleared with null. */
const FIELDS: [keyof UpdateDailyTipDto, keyof TipPatch, boolean][] = [
  ['category', 'category', false],
  ['language', 'language', false],
  ['title', 'title', false],
  ['summary', 'summary', false],
  ['explanation', 'explanation', false],
  ['legal_reference', 'legalReference', false],
  ['source_url', 'sourceUrl', true],
  ['publish_date', 'publishDate', true],
  ['last_verified_on', 'lastVerifiedOn', true],
];

function toPatch(dto: UpdateDailyTipDto): TipPatch {
  const patch: Record<string, unknown> = {};
  const bad: { field: string; reason: string }[] = [];
  for (const [field, column, nullable] of FIELDS) {
    const value = dto[field];
    if (value === undefined) continue;
    if (value === null && !nullable)
      bad.push({ field, reason: 'Cannot be null' });
    else if (typeof value === 'string') patch[column] = value.trim() || null;
    else patch[column] = value;
  }
  // Required text columns hold '' rather than null.
  for (const column of [
    'title',
    'summary',
    'explanation',
    'legalReference',
    'language',
  ])
    if (patch[column] === null) patch[column] = column === 'language' ? 'en' : '';
  if (bad.length)
    throw new ApiError(
      HttpStatus.BAD_REQUEST,
      'validation_failed',
      'Request body is invalid',
      bad,
    );
  return patch as TipPatch;
}

const toListItem = (t: TipRow): DailyTipListItemDto => ({
  id: t.id,
  status: t.status,
  category: t.category,
  language: t.language,
  title: t.title,
  publish_date: t.publishDate,
  updated_at: t.updatedAt.toISOString(),
});

/** A published tip always passed the completeness check, so these are set. */
const toPublic = (t: TipRow): PublicDailyTipDto => ({
  id: t.id,
  category: t.category,
  language: t.language,
  title: t.title,
  summary: t.summary,
  explanation: t.explanation,
  legal_reference: t.legalReference,
  source_url: t.sourceUrl!,
  publish_date: t.publishDate!,
  last_verified_on: t.lastVerifiedOn!,
});

/**
 * Daily legal tips for the app's Home screen. Like news, every step is checked
 * here, runs in one transaction with the tip locked, and is written to the
 * audit log. Which tip is "today's" is a query on its publish date (India), so
 * no scheduled job is needed.
 */
@Injectable()
export class DailyTipsService {
  constructor(
    @Inject(DB) private readonly db: Db,
    private readonly audit: AuditService,
  ) {}

  /** The tip published for today in India; null when there is none. */
  async today(language = 'en', now = new Date()): Promise<TodayTipDto> {
    const [t] = await this.db
      .select()
      .from(dailyTips)
      .where(
        and(
          eq(dailyTips.status, 'published'),
          eq(dailyTips.publishDate, indiaToday(now)),
          eq(dailyTips.language, language),
        ),
      )
      .limit(1);
    return { tip: t ? toPublic(t) : null };
  }

  /**
   * One published tip whose day has come. Drafts, tips under review, retired
   * tips and ones scheduled for a later day are all "not found" to the app.
   */
  async published(id: string, now = new Date()): Promise<PublicDailyTipDto> {
    const [t] = await this.db
      .select()
      .from(dailyTips)
      .where(eq(dailyTips.id, id))
      .limit(1);
    if (!t || t.status !== 'published' || t.publishDate! > indiaToday(now))
      throw ApiError.notFound('Tip');
    return toPublic(t);
  }

  async list(query: ListTipsQuery): Promise<Page<DailyTipListItemDto>> {
    const limit = query.limit ?? 20;
    const where: SQL[] = [];
    const after = decodeCursor(query.cursor);
    if (after) where.push(lt(dailyTips.id, after));
    if (query.status) where.push(eq(dailyTips.status, query.status));
    if (query.category) where.push(eq(dailyTips.category, query.category));
    if (query.q)
      where.push(
        ilike(dailyTips.title, `%${query.q.replace(/[\\%_]/g, '\\$&')}%`),
      );
    const rows = await this.db
      .select()
      .from(dailyTips)
      .where(and(...where))
      .orderBy(desc(dailyTips.id))
      .limit(limit + 1);
    return toPage(rows, limit, toListItem);
  }

  async get(id: string, tx: Tx = this.db): Promise<DailyTipDetailDto> {
    const [t] = await tx
      .select()
      .from(dailyTips)
      .where(eq(dailyTips.id, id))
      .limit(1);
    if (!t) throw ApiError.notFound('Tip');
    let changesReason: string | null = null;
    if (t.status === 'changes_requested') {
      const [last] = await tx
        .select({ data: auditLog.data })
        .from(auditLog)
        .where(
          and(
            eq(auditLog.entityType, 'daily_tip'),
            eq(auditLog.entityId, id),
            eq(auditLog.action, AUDIT_ACTIONS.request_changes),
          ),
        )
        .orderBy(desc(auditLog.createdAt))
        .limit(1);
      changesReason = (last?.data?.reason as string | undefined) ?? null;
    }
    return {
      ...toListItem(t),
      summary: t.summary,
      explanation: t.explanation,
      legal_reference: t.legalReference,
      source_url: t.sourceUrl,
      last_verified_on: t.lastVerifiedOn,
      created_by: t.createdBy,
      updated_by: t.updatedBy,
      reviewer_id: t.reviewerId,
      approved_at: iso(t.approvedAt),
      published_at: iso(t.publishedAt),
      retired_at: iso(t.retiredAt),
      created_at: t.createdAt.toISOString(),
      changes_reason: changesReason,
    };
  }

  async create(
    actor: Actor,
    dto: CreateDailyTipDto,
  ): Promise<DailyTipDetailDto> {
    const patch = toPatch(dto);
    return this.db.transaction(async (tx) => {
      const id = newId();
      await tx.insert(dailyTips).values({
        ...patch,
        id,
        category: dto.category,
        status: 'draft',
        createdBy: actor.id,
        updatedBy: actor.id,
      });
      await this.audit.record(tx, actor, {
        action: 'daily_tip.created',
        entityType: 'daily_tip',
        entityId: id,
      });
      return this.get(id, tx);
    });
  }

  update(actor: Actor, id: string, dto: UpdateDailyTipDto) {
    const patch = toPatch(dto);
    return this.act(actor, id, 'edit', async (tx) => {
      await tx
        .update(dailyTips)
        .set({ ...patch, updatedBy: actor.id, updatedAt: new Date() })
        .where(eq(dailyTips.id, id));
      return { fields: Object.keys(dto) };
    });
  }

  submit(actor: Actor, id: string) {
    return this.act(actor, id, 'submit', async (tx, t) => {
      requireComplete(t);
      await this.setStatus(tx, t, 'submit');
      return {};
    });
  }

  requestChanges(actor: Actor, id: string, reason: string) {
    return this.act(actor, id, 'request_changes', async (tx, t) => {
      await this.setStatus(tx, t, 'request_changes');
      return { reason };
    });
  }

  /**
   * Approves the tip under review. Nobody approves what they wrote or edited,
   * except an admin, who may do every step. The admin is still recorded as the
   * approver, so the trail shows it.
   */
  approve(actor: Actor, id: string, isAdmin = false) {
    return this.act(actor, id, 'approve', async (tx, t) => {
      if (
        !isAdmin &&
        (t.createdBy === actor.id ||
          t.updatedBy === actor.id ||
          (await this.hasEdited(tx, actor, id)))
      )
        throw ApiError.forbidden(
          'A reviewer cannot approve a tip they wrote or edited',
        );
      await this.setStatus(tx, t, 'approve', {
        reviewerId: actor.id,
        approvedAt: new Date(),
      });
      return {};
    });
  }

  publish(actor: Actor, id: string, now = new Date()) {
    return this.act(actor, id, 'publish', async (tx, t) => {
      requireComplete(t);
      if (!t.reviewerId || !t.approvedAt)
        throw ApiError.incomplete([{ reason: 'The tip has no recorded review' }]);
      // A day that has gone would never show the tip.
      if (t.publishDate! < indiaToday(now))
        throw ApiError.incomplete([
          {
            field: 'publish_date',
            reason: 'The day has passed; choose today or a later day',
          },
        ]);
      const [taken] = await tx
        .select({ id: dailyTips.id })
        .from(dailyTips)
        .where(
          and(
            eq(dailyTips.status, 'published'),
            eq(dailyTips.publishDate, t.publishDate!),
            eq(dailyTips.language, t.language),
            ne(dailyTips.id, id),
          ),
        )
        .limit(1);
      if (taken) throw dayTaken();
      try {
        await this.setStatus(tx, t, 'publish', {
          publishedAt: new Date(),
          publishedBy: actor.id,
          retiredAt: null,
        });
      } catch (e) {
        if (isUniqueViolation(e)) throw dayTaken();
        throw e;
      }
      return {};
    });
  }

  revise(actor: Actor, id: string, reason: string) {
    return this.act(actor, id, 'revise', async (tx, t) => {
      // A new review is needed, so the old one no longer counts.
      await this.setStatus(tx, t, 'revise', {
        reviewerId: null,
        approvedAt: null,
        updatedBy: actor.id,
      });
      return { reason };
    });
  }

  retire(actor: Actor, id: string, reason: string) {
    return this.act(actor, id, 'retire', async (tx, t) => {
      await this.setStatus(tx, t, 'retire', { retiredAt: new Date() });
      return { reason };
    });
  }

  // ---------------------------------------------------------------- helpers

  /** Locks the tip, checks it may take [action], runs [fn] and audits it. */
  private act(
    actor: Actor,
    id: string,
    action: TipAction,
    fn: (tx: Tx, t: TipRow) => Promise<Record<string, unknown>>,
  ): Promise<DailyTipDetailDto> {
    return this.db.transaction(async (tx) => {
      const [t] = await tx
        .select()
        .from(dailyTips)
        .where(eq(dailyTips.id, id))
        .for('update')
        .limit(1);
      if (!t) throw ApiError.notFound('Tip');
      const allowed: readonly string[] = TIP_ACTIONS[action].from;
      if (!allowed.includes(t.status))
        throw ApiError.invalidTransition(
          `Cannot ${action.replace('_', ' ')} a tip that is ${t.status.replace('_', ' ')}`,
        );
      const data = await fn(tx, t);
      await this.audit.record(tx, actor, {
        action: AUDIT_ACTIONS[action],
        entityType: 'daily_tip',
        entityId: id,
        data,
      });
      return this.get(id, tx);
    });
  }

  /** Whether [actor] edited the tip since it last went back to draft. */
  private async hasEdited(tx: Tx, actor: Actor, id: string): Promise<boolean> {
    const [lastRevise] = await tx
      .select({ at: auditLog.createdAt })
      .from(auditLog)
      .where(
        and(
          eq(auditLog.entityType, 'daily_tip'),
          eq(auditLog.entityId, id),
          eq(auditLog.action, AUDIT_ACTIONS.revise),
        ),
      )
      .orderBy(desc(auditLog.createdAt))
      .limit(1);
    const [edit] = await tx
      .select({ id: auditLog.id })
      .from(auditLog)
      .where(
        and(
          eq(auditLog.entityType, 'daily_tip'),
          eq(auditLog.entityId, id),
          eq(auditLog.actorId, actor.id),
          inArray(auditLog.action, [
            AUDIT_ACTIONS.edit,
            'daily_tip.created',
          ]),
          lastRevise ? gte(auditLog.createdAt, lastRevise.at) : undefined,
        ),
      )
      .limit(1);
    return edit !== undefined;
  }

  private async setStatus(
    tx: Tx,
    t: TipRow,
    action: TipAction,
    extra: TipPatch = {},
  ) {
    const to = (TIP_ACTIONS[action] as { to?: TipRow['status'] }).to!;
    await tx
      .update(dailyTips)
      .set({ ...extra, status: to, updatedAt: new Date() })
      .where(eq(dailyTips.id, t.id));
  }
}

function requireComplete(t: TipRow) {
  const problems = tipProblems(t);
  if (problems.length) throw ApiError.incomplete(problems);
}

const dayTaken = () =>
  new ApiError(
    HttpStatus.CONFLICT,
    'day_taken',
    'Another tip is already published for that day and language',
  );
