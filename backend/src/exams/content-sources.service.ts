import { Inject, Injectable } from '@nestjs/common';
import { and, desc, eq, lt, type SQL } from 'drizzle-orm';
import { AuditService, type Actor } from '../core/audit.service.js';
import { DB, type Db, type Tx } from '../core/db.js';
import { ApiError } from '../core/errors.js';
import { newId } from '../core/ids.js';
import { decodeCursor, toPage } from '../core/pagination.js';
import { contentSources } from '../db/schema.js';
import type {
  ContentSourceDto,
  ContentSourcePageDto,
  CreateContentSourceDto,
  ListContentSourcesQuery,
  UpdateContentSourceDto,
} from './content-sources.dto.js';

type Row = typeof contentSources.$inferSelect;

const toDto = (r: Row): ContentSourceDto => ({
  id: r.id,
  kind: r.kind,
  title: r.title,
  publisher: r.publisher,
  url: r.url,
  retrieved_on: r.retrievedOn,
  sha256: r.sha256,
  allowed_uses: r.allowedUses,
  created_by: r.createdBy,
  created_at: r.createdAt.toISOString(),
  updated_at: r.updatedAt.toISOString(),
});

@Injectable()
export class ContentSourcesService {
  constructor(
    @Inject(DB) private readonly db: Db,
    private readonly audit: AuditService,
  ) {}

  async list(query: ListContentSourcesQuery): Promise<ContentSourcePageDto> {
    const limit = query.limit ?? 50;
    const cursor = decodeCursor(query.cursor);
    const where: SQL[] = [];
    if (query.kind) where.push(eq(contentSources.kind, query.kind));
    if (cursor) where.push(lt(contentSources.id, cursor));
    const rows = await this.db
      .select()
      .from(contentSources)
      .where(and(...where))
      .orderBy(desc(contentSources.id))
      .limit(limit + 1);
    return toPage(rows, limit, toDto);
  }

  async get(id: string): Promise<ContentSourceDto> {
    return toDto(await this.load(this.db, id));
  }

  /** A content source records where content came from: attribution only. */
  async create(
    actor: Actor,
    dto: CreateContentSourceDto,
  ): Promise<ContentSourceDto> {
    return this.db.transaction(async (tx) => {
      const id = newId();
      const [row] = await tx
        .insert(contentSources)
        .values({
          id,
          kind: dto.kind,
          title: dto.title.trim(),
          publisher: dto.publisher?.trim() || null,
          url: dto.url ?? null,
          retrievedOn: dto.retrieved_on ?? null,
          sha256: dto.sha256 ?? null,
          allowedUses: dto.allowed_uses ?? [],
          createdBy: actor.id,
        })
        .returning();
      await this.audit.record(tx, actor, {
        action: 'content_source.created',
        entityType: 'content_source',
        entityId: id,
        data: { kind: dto.kind, title: row.title },
      });
      return toDto(row);
    });
  }

  async update(
    actor: Actor,
    id: string,
    dto: UpdateContentSourceDto,
  ): Promise<ContentSourceDto> {
    return this.db.transaction(async (tx) => {
      await this.lock(tx, id);
      const patch: Partial<typeof contentSources.$inferInsert> = {};
      if (dto.title !== undefined) patch.title = dto.title.trim();
      if (dto.publisher !== undefined)
        patch.publisher = dto.publisher?.trim() || null;
      if (dto.url !== undefined) patch.url = dto.url;
      if (dto.retrieved_on !== undefined) patch.retrievedOn = dto.retrieved_on;
      if (dto.sha256 !== undefined) patch.sha256 = dto.sha256;
      if (dto.allowed_uses !== undefined) patch.allowedUses = dto.allowed_uses;
      const [row] = await tx
        .update(contentSources)
        .set({ ...patch, updatedAt: new Date() })
        .where(eq(contentSources.id, id))
        .returning();
      await this.audit.record(tx, actor, {
        action: 'content_source.updated',
        entityType: 'content_source',
        entityId: id,
        data: { fields: Object.keys(dto) },
      });
      return toDto(row);
    });
  }

  private async load(tx: Tx, id: string): Promise<Row> {
    const [row] = await tx
      .select()
      .from(contentSources)
      .where(eq(contentSources.id, id))
      .limit(1);
    if (!row) throw ApiError.notFound('Content source');
    return row;
  }

  private async lock(tx: Tx, id: string): Promise<Row> {
    const [row] = await tx
      .select()
      .from(contentSources)
      .where(eq(contentSources.id, id))
      .for('update')
      .limit(1);
    if (!row) throw ApiError.notFound('Content source');
    return row;
  }
}
