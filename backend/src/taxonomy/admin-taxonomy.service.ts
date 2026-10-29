import { HttpStatus, Inject, Injectable } from '@nestjs/common';
import { and, asc, count, eq, isNull, max } from 'drizzle-orm';
import { AuditService, type Actor } from '../core/audit.service.js';
import { DB, type Db, type Tx } from '../core/db.js';
import { ApiError, isUniqueViolation } from '../core/errors.js';
import { newId } from '../core/ids.js';
import {
  acts,
  questions,
  questionVersions,
  subjects,
  topics,
} from '../db/schema.js';
import type {
  AdminTaxonomyDto,
  CreateActDto,
  CreateSubjectDto,
  CreateTopicDto,
  UpdateActDto,
  UpdateSubjectDto,
  UpdateTopicDto,
} from './admin-taxonomy.dto.js';

type Table = typeof subjects | typeof topics | typeof acts;

const slugTaken = (slug: string) =>
  new ApiError(HttpStatus.CONFLICT, 'slug_taken', `"${slug}" is already used`, [
    { field: 'slug', reason: 'Choose another slug' },
  ]);

/** Only the fields that were sent with a usable value (null clears where allowed). */
function pick<T extends object>(
  dto: T,
  map: Record<string, { col: string; nullable?: boolean }>,
) {
  const patch: Record<string, unknown> = {};
  for (const [key, { col, nullable }] of Object.entries(map)) {
    const v = (dto as Record<string, unknown>)[key];
    if (v === undefined || (v === null && !nullable)) continue;
    patch[col] = v;
  }
  return patch;
}

const NAMED = {
  name: { col: 'name' },
  description: { col: 'description', nullable: true },
  sort_order: { col: 'sortOrder' },
  is_active: { col: 'isActive' },
};

/**
 * Staff editing of subjects, topics and acts. Slugs never change, topics
 * never move between subjects, and new subjects start hidden, because the
 * learner app and stored progress refer to them.
 */
@Injectable()
export class AdminTaxonomyService {
  constructor(
    @Inject(DB) private readonly db: Db,
    private readonly audit: AuditService,
  ) {}

  async overview(): Promise<AdminTaxonomyDto> {
    const latestNo = this.db
      .select({
        questionId: questionVersions.questionId,
        maxNo: max(questionVersions.versionNo).as('max_no'),
      })
      .from(questionVersions)
      .groupBy(questionVersions.questionId)
      .as('latest_no');
    const [subjectRows, topicRows, actRows, latest, live, actUse] =
      await Promise.all([
        this.db
          .select()
          .from(subjects)
          .orderBy(asc(subjects.sortOrder), asc(subjects.name)),
        this.db
          .select()
          .from(topics)
          .orderBy(asc(topics.sortOrder), asc(topics.name)),
        this.db.select().from(acts).orderBy(asc(acts.name)),
        this.db
          .select({ topicId: questionVersions.topicId, n: count() })
          .from(questionVersions)
          .innerJoin(
            latestNo,
            and(
              eq(latestNo.questionId, questionVersions.questionId),
              eq(latestNo.maxNo, questionVersions.versionNo),
            ),
          )
          .groupBy(questionVersions.topicId),
        this.db
          .select({ topicId: questionVersions.topicId, n: count() })
          .from(questions)
          .innerJoin(
            questionVersions,
            eq(questionVersions.id, questions.liveVersionId),
          )
          .where(isNull(questions.retiredAt))
          .groupBy(questionVersions.topicId),
        this.db
          .select({ actId: topics.actId, n: count() })
          .from(topics)
          .groupBy(topics.actId),
      ]);
    const n = (rows: { topicId: string; n: number }[], id: string) =>
      rows.find((r) => r.topicId === id)?.n ?? 0;
    return {
      subjects: subjectRows.map((s) => ({
        id: s.id,
        slug: s.slug,
        name: s.name,
        description: s.description,
        sort_order: s.sortOrder,
        is_active: s.isActive,
        topics: topicRows
          .filter((t) => t.subjectId === s.id)
          .map((t) => ({
            id: t.id,
            subject_id: t.subjectId,
            slug: t.slug,
            name: t.name,
            description: t.description,
            act_id: t.actId,
            sort_order: t.sortOrder,
            is_active: t.isActive,
            question_count: n(latest, t.id),
            live_count: n(live, t.id),
          })),
      })),
      acts: actRows.map((a) => ({
        id: a.id,
        slug: a.slug,
        name: a.name,
        short_name: a.shortName,
        year: a.year,
        jurisdiction: a.jurisdiction,
        is_active: a.isActive,
        topic_count: actUse.find((u) => u.actId === a.id)?.n ?? 0,
      })),
    };
  }

  createSubject(actor: Actor, dto: CreateSubjectDto) {
    return this.create(actor, subjects, 'subject', dto.slug, {
      ...pick(dto, NAMED),
      isActive: false,
    });
  }

  updateSubject(actor: Actor, id: string, dto: UpdateSubjectDto) {
    return this.update(actor, subjects, 'subject', id, pick(dto, NAMED));
  }

  async createTopic(actor: Actor, dto: CreateTopicDto) {
    await this.mustExist(subjects, dto.subject_id, 'subject_id', 'subject');
    if (dto.act_id) await this.mustExist(acts, dto.act_id, 'act_id', 'act');
    return this.create(actor, topics, 'topic', dto.slug, {
      ...pick(dto, { ...NAMED, act_id: { col: 'actId', nullable: true } }),
      subjectId: dto.subject_id,
    });
  }

  async updateTopic(actor: Actor, id: string, dto: UpdateTopicDto) {
    if (dto.act_id) await this.mustExist(acts, dto.act_id, 'act_id', 'act');
    return this.update(
      actor,
      topics,
      'topic',
      id,
      pick(dto, { ...NAMED, act_id: { col: 'actId', nullable: true } }),
    );
  }

  createAct(actor: Actor, dto: CreateActDto) {
    return this.create(actor, acts, 'act', dto.slug, {
      ...pick(dto, ACT_FIELDS),
      jurisdiction: 'IN',
    });
  }

  updateAct(actor: Actor, id: string, dto: UpdateActDto) {
    return this.update(actor, acts, 'act', id, pick(dto, ACT_FIELDS));
  }

  private async create(
    actor: Actor,
    table: Table,
    kind: string,
    slug: string,
    values: Record<string, unknown>,
  ): Promise<AdminTaxonomyDto> {
    const id = newId();
    try {
      await this.db.transaction(async (tx) => {
        await tx.insert(table).values({ id, slug, ...values } as never);
        await this.audit.record(tx, actor, {
          action: `taxonomy.${kind}_created`,
          entityType: kind,
          entityId: id,
          data: { slug, ...values },
        });
      });
    } catch (e) {
      if (isUniqueViolation(e)) throw slugTaken(slug);
      throw e;
    }
    return this.overview();
  }

  private async update(
    actor: Actor,
    table: Table,
    kind: string,
    id: string,
    patch: Record<string, unknown>,
  ): Promise<AdminTaxonomyDto> {
    await this.db.transaction(async (tx: Tx) => {
      const [row] = await tx
        .select({ id: table.id })
        .from(table as typeof subjects)
        .where(eq(table.id, id))
        .for('update');
      if (!row) throw ApiError.notFound(kind[0].toUpperCase() + kind.slice(1));
      if (Object.keys(patch).length === 0) return;
      await tx
        .update(table)
        .set({ ...patch, updatedAt: new Date() } as never)
        .where(eq(table.id, id));
      await this.audit.record(tx, actor, {
        action: `taxonomy.${kind}_updated`,
        entityType: kind,
        entityId: id,
        data: patch,
      });
    });
    return this.overview();
  }

  private async mustExist(
    table: Table,
    id: string,
    field: string,
    what: string,
  ) {
    const [row] = await this.db
      .select({ id: table.id })
      .from(table as typeof subjects)
      .where(eq(table.id, id))
      .limit(1);
    if (!row)
      throw new ApiError(
        HttpStatus.UNPROCESSABLE_ENTITY,
        'validation_failed',
        `Unknown ${what}`,
        [{ field, reason: `No ${what} has this id` }],
      );
  }
}

const ACT_FIELDS = {
  name: { col: 'name' },
  short_name: { col: 'shortName', nullable: true },
  year: { col: 'year', nullable: true },
  is_active: { col: 'isActive' },
};
