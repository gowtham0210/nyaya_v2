import { HttpStatus, Inject, Injectable } from '@nestjs/common';
import { and, desc, eq, gte, ilike, inArray, lt, type SQL } from 'drizzle-orm';
import { AuditService, type Actor } from '../core/audit.service.js';
import { DB, type Db, type Tx } from '../core/db.js';
import { ApiError } from '../core/errors.js';
import { newId } from '../core/ids.js';
import { decodeCursor, toPage, type Page } from '../core/pagination.js';
import { auditLog, newsArticles } from '../db/schema.js';
import type {
  CreateNewsDto,
  ListNewsQuery,
  NewsDetailDto,
  NewsListItemDto,
  PublicNewsListDto,
  UpdateNewsDto,
} from './news.dto.js';
import { NEWS_ACTIONS, newsProblems, type NewsAction } from './workflow.js';

type ArticleRow = typeof newsArticles.$inferSelect;
type ArticlePatch = Partial<typeof newsArticles.$inferInsert>;

const iso = (d: Date | null) => (d ? d.toISOString() : null);

const AUDIT_ACTIONS: Record<NewsAction, string> = {
  edit: 'news.updated',
  submit: 'news.submitted',
  request_changes: 'news.changes_requested',
  approve: 'news.approved',
  publish: 'news.published',
  revise: 'news.revised',
  retire: 'news.retired',
};

/** How many articles the app gets; older ones stay in the portal. */
const PUBLIC_LIMIT = 50;

/** Request field → column, and whether the column may be cleared with null. */
const FIELDS: [keyof UpdateNewsDto, keyof ArticlePatch, boolean][] = [
  ['category', 'category', false],
  ['title', 'title', false],
  ['summary', 'summary', false],
  ['key_points', 'keyPoints', false],
  ['why_it_matters', 'whyItMatters', false],
  ['source', 'source', false],
  ['source_url', 'sourceUrl', true],
  ['event_date', 'eventDate', true],
  ['read_minutes', 'readMinutes', false],
];

function toPatch(dto: UpdateNewsDto): ArticlePatch {
  const patch: Record<string, unknown> = {};
  const bad: { field: string; reason: string }[] = [];
  for (const [field, column, nullable] of FIELDS) {
    const value = dto[field];
    if (value === undefined) continue;
    if (value === null && !nullable)
      bad.push({ field, reason: 'Cannot be null' });
    else if (typeof value === 'string') patch[column] = value.trim() || null;
    else if (Array.isArray(value))
      patch[column] = value.map((p) => p.trim()).filter(Boolean);
    else patch[column] = value;
  }
  // Required text columns hold '' rather than null.
  for (const column of ['title', 'summary', 'whyItMatters', 'source'])
    if (patch[column] === null) patch[column] = '';
  if (bad.length)
    throw new ApiError(
      HttpStatus.BAD_REQUEST,
      'validation_failed',
      'Request body is invalid',
      bad,
    );
  return patch as ArticlePatch;
}

const toListItem = (a: ArticleRow): NewsListItemDto => ({
  id: a.id,
  status: a.status,
  category: a.category,
  title: a.title,
  event_date: a.eventDate,
  updated_at: a.updatedAt.toISOString(),
});

/**
 * Legal news for the app's Updates tab. Like questions, every step is checked
 * here, runs in one transaction with the article locked, and is written to
 * the audit log.
 */
@Injectable()
export class NewsService {
  constructor(
    @Inject(DB) private readonly db: Db,
    private readonly audit: AuditService,
  ) {}

  /** Published articles, newest first, for the app. */
  async published(): Promise<PublicNewsListDto> {
    const rows = await this.db
      .select()
      .from(newsArticles)
      .where(eq(newsArticles.status, 'published'))
      .orderBy(desc(newsArticles.eventDate), desc(newsArticles.publishedAt))
      .limit(PUBLIC_LIMIT);
    return {
      items: rows.map((a) => ({
        id: a.id,
        category: a.category,
        title: a.title,
        summary: a.summary,
        key_points: a.keyPoints,
        why_it_matters: a.whyItMatters,
        source: a.source,
        source_url: a.sourceUrl,
        date: a.eventDate!,
        read_minutes: a.readMinutes,
      })),
    };
  }

  async list(query: ListNewsQuery): Promise<Page<NewsListItemDto>> {
    const limit = query.limit ?? 20;
    const where: SQL[] = [];
    const after = decodeCursor(query.cursor);
    if (after) where.push(lt(newsArticles.id, after));
    if (query.status) where.push(eq(newsArticles.status, query.status));
    if (query.q)
      where.push(
        ilike(newsArticles.title, `%${query.q.replace(/[\\%_]/g, '\\$&')}%`),
      );
    const rows = await this.db
      .select()
      .from(newsArticles)
      .where(and(...where))
      .orderBy(desc(newsArticles.id))
      .limit(limit + 1);
    return toPage(rows, limit, toListItem);
  }

  async get(id: string, tx: Tx = this.db): Promise<NewsDetailDto> {
    const [a] = await tx
      .select()
      .from(newsArticles)
      .where(eq(newsArticles.id, id))
      .limit(1);
    if (!a) throw ApiError.notFound('Article');
    let changesReason: string | null = null;
    if (a.status === 'changes_requested') {
      const [last] = await tx
        .select({ data: auditLog.data })
        .from(auditLog)
        .where(
          and(
            eq(auditLog.entityType, 'news'),
            eq(auditLog.entityId, id),
            eq(auditLog.action, AUDIT_ACTIONS.request_changes),
          ),
        )
        .orderBy(desc(auditLog.createdAt))
        .limit(1);
      changesReason = (last?.data?.reason as string | undefined) ?? null;
    }
    return {
      ...toListItem(a),
      external_ref: a.externalRef,
      summary: a.summary,
      key_points: a.keyPoints,
      why_it_matters: a.whyItMatters,
      source: a.source,
      source_url: a.sourceUrl,
      read_minutes: a.readMinutes,
      created_by: a.createdBy,
      updated_by: a.updatedBy,
      reviewer_id: a.reviewerId,
      approved_at: iso(a.approvedAt),
      published_at: iso(a.publishedAt),
      retired_at: iso(a.retiredAt),
      created_at: a.createdAt.toISOString(),
      changes_reason: changesReason,
    };
  }

  async create(actor: Actor, dto: CreateNewsDto): Promise<NewsDetailDto> {
    const patch = toPatch(dto);
    return this.db.transaction(async (tx) => {
      const id = newId();
      await tx.insert(newsArticles).values({
        ...patch,
        id,
        category: dto.category,
        status: 'draft',
        createdBy: actor.id,
        updatedBy: actor.id,
      });
      await this.audit.record(tx, actor, {
        action: 'news.created',
        entityType: 'news',
        entityId: id,
      });
      return this.get(id, tx);
    });
  }

  update(actor: Actor, id: string, dto: UpdateNewsDto) {
    const patch = toPatch(dto);
    return this.act(actor, id, 'edit', async (tx) => {
      await tx
        .update(newsArticles)
        .set({ ...patch, updatedBy: actor.id, updatedAt: new Date() })
        .where(eq(newsArticles.id, id));
      return { fields: Object.keys(dto) };
    });
  }

  submit(actor: Actor, id: string) {
    return this.act(actor, id, 'submit', async (tx, a) => {
      requireComplete(a);
      await this.setStatus(tx, a, 'submit');
      return {};
    });
  }

  requestChanges(actor: Actor, id: string, reason: string) {
    return this.act(actor, id, 'request_changes', async (tx, a) => {
      await this.setStatus(tx, a, 'request_changes');
      return { reason };
    });
  }

  approve(actor: Actor, id: string) {
    return this.act(actor, id, 'approve', async (tx, a) => {
      if (
        a.createdBy === actor.id ||
        a.updatedBy === actor.id ||
        (await this.hasEdited(tx, actor, id))
      )
        throw ApiError.forbidden(
          'A reviewer cannot approve an article they wrote or edited',
        );
      await this.setStatus(tx, a, 'approve', {
        reviewerId: actor.id,
        approvedAt: new Date(),
      });
      return {};
    });
  }

  publish(actor: Actor, id: string) {
    return this.act(actor, id, 'publish', async (tx, a) => {
      requireComplete(a);
      if (!a.reviewerId || !a.approvedAt)
        throw ApiError.incomplete([
          { reason: 'The article has no recorded review' },
        ]);
      await this.setStatus(tx, a, 'publish', {
        publishedAt: new Date(),
        publishedBy: actor.id,
        retiredAt: null,
      });
      return {};
    });
  }

  revise(actor: Actor, id: string, reason: string) {
    return this.act(actor, id, 'revise', async (tx, a) => {
      // A new review is needed, so the old one no longer counts.
      await this.setStatus(tx, a, 'revise', {
        reviewerId: null,
        approvedAt: null,
        updatedBy: actor.id,
      });
      return { reason };
    });
  }

  retire(actor: Actor, id: string, reason: string) {
    return this.act(actor, id, 'retire', async (tx, a) => {
      await this.setStatus(tx, a, 'retire', { retiredAt: new Date() });
      return { reason };
    });
  }

  // ---------------------------------------------------------------- helpers

  /** Locks the article, checks it may take [action], runs [fn] and audits it. */
  private act(
    actor: Actor,
    id: string,
    action: NewsAction,
    fn: (tx: Tx, a: ArticleRow) => Promise<Record<string, unknown>>,
  ): Promise<NewsDetailDto> {
    return this.db.transaction(async (tx) => {
      const [a] = await tx
        .select()
        .from(newsArticles)
        .where(eq(newsArticles.id, id))
        .for('update')
        .limit(1);
      if (!a) throw ApiError.notFound('Article');
      const allowed: readonly string[] = NEWS_ACTIONS[action].from;
      if (!allowed.includes(a.status))
        throw ApiError.invalidTransition(
          `Cannot ${action.replace('_', ' ')} an article that is ${a.status.replace('_', ' ')}`,
        );
      const data = await fn(tx, a);
      await this.audit.record(tx, actor, {
        action: AUDIT_ACTIONS[action],
        entityType: 'news',
        entityId: id,
        data,
      });
      return this.get(id, tx);
    });
  }

  /** Whether [actor] edited the article since it last went back to draft. */
  private async hasEdited(tx: Tx, actor: Actor, id: string): Promise<boolean> {
    const [lastRevise] = await tx
      .select({ at: auditLog.createdAt })
      .from(auditLog)
      .where(
        and(
          eq(auditLog.entityType, 'news'),
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
          eq(auditLog.entityType, 'news'),
          eq(auditLog.entityId, id),
          eq(auditLog.actorId, actor.id),
          inArray(auditLog.action, [AUDIT_ACTIONS.edit, 'news.created']),
          lastRevise ? gte(auditLog.createdAt, lastRevise.at) : undefined,
        ),
      )
      .limit(1);
    return edit !== undefined;
  }

  private async setStatus(
    tx: Tx,
    a: ArticleRow,
    action: NewsAction,
    extra: ArticlePatch = {},
  ) {
    const to = (NEWS_ACTIONS[action] as { to?: ArticleRow['status'] }).to!;
    await tx
      .update(newsArticles)
      .set({ ...extra, status: to, updatedAt: new Date() })
      .where(eq(newsArticles.id, a.id));
  }
}

function requireComplete(a: ArticleRow) {
  const problems = newsProblems(a);
  if (problems.length) throw ApiError.incomplete(problems);
}
