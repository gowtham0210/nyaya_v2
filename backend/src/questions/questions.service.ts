import { HttpStatus, Inject, Injectable } from '@nestjs/common';
import {
  and,
  asc,
  desc,
  eq,
  ilike,
  inArray,
  lt,
  max,
  type SQL,
} from 'drizzle-orm';
import { AuditService, type Actor } from '../core/audit.service.js';
import { DB, type Db, type Tx } from '../core/db.js';
import { ApiError } from '../core/errors.js';
import { newId } from '../core/ids.js';
import { decodeCursor, toPage, type Page } from '../core/pagination.js';
import {
  questions,
  questionVersions,
  reviewDecisions,
  topics,
} from '../db/schema.js';
import type {
  CreateQuestionDto,
  QuestionDetailDto,
  QuestionListItemDto,
  ListQuestionsQuery,
  UpdateQuestionDto,
  VersionDto,
  VersionSummaryDto,
} from './questions.dto.js';
import { ACTIONS, contentProblems, type Action } from './workflow.js';

type QuestionRow = typeof questions.$inferSelect;
type VersionRow = typeof questionVersions.$inferSelect;
type VersionPatch = Partial<typeof questionVersions.$inferInsert>;

const iso = (d: Date | null) => (d ? d.toISOString() : null);

const AUDIT_ACTIONS: Record<Action, string> = {
  edit: 'question.updated',
  submit: 'question.submitted',
  request_changes: 'question.changes_requested',
  approve: 'question.approved',
  publish: 'question.published',
  revise: 'question.revised',
};

/** Request field → column, and whether the column may be cleared with null. */
const FIELDS: [keyof UpdateQuestionDto, keyof VersionPatch, boolean][] = [
  ['topic_id', 'topicId', false],
  ['question_type', 'questionType', false],
  ['difficulty', 'difficulty', false],
  ['jurisdiction', 'jurisdiction', false],
  ['language', 'language', false],
  ['stem', 'stem', false],
  ['options', 'options', false],
  ['correct_option_ids', 'correctOptionIds', false],
  ['explanation', 'explanation', false],
  ['source_title', 'sourceTitle', true],
  ['source_url', 'sourceUrl', true],
  ['citation', 'citation', true],
  ['provision_reference', 'provisionReference', true],
  ['valid_from', 'validFrom', true],
  ['valid_to', 'validTo', true],
];

function toPatch(dto: UpdateQuestionDto): VersionPatch {
  const patch: Record<string, unknown> = {};
  const bad: { field: string; reason: string }[] = [];
  for (const [field, column, nullable] of FIELDS) {
    const value = dto[field];
    if (value === undefined) continue;
    if (value === null && !nullable)
      bad.push({ field, reason: 'Cannot be null' });
    else
      patch[column] =
        typeof value === 'string' &&
        column !== 'stem' &&
        column !== 'explanation'
          ? value.trim()
          : value;
  }
  if (bad.length)
    throw new ApiError(
      HttpStatus.BAD_REQUEST,
      'validation_failed',
      'Request body is invalid',
      bad,
    );
  return patch as VersionPatch;
}

export function toVersionDto(v: VersionRow): VersionDto {
  return {
    id: v.id,
    version_no: v.versionNo,
    status: v.status,
    topic_id: v.topicId,
    jurisdiction: v.jurisdiction,
    language: v.language,
    question_type: v.questionType,
    difficulty: v.difficulty,
    stem: v.stem,
    options: v.options,
    correct_option_ids: v.correctOptionIds,
    explanation: v.explanation,
    source_title: v.sourceTitle,
    source_url: v.sourceUrl,
    citation: v.citation,
    provision_reference: v.provisionReference,
    valid_from: v.validFrom,
    valid_to: v.validTo,
    verified_at: iso(v.verifiedAt),
    reviewer_id: v.reviewerId,
    change_note: v.changeNote,
    created_by: v.createdBy,
    updated_by: v.updatedBy,
    submitted_at: iso(v.submittedAt),
    approved_at: iso(v.approvedAt),
    published_at: iso(v.publishedAt),
    published_by: v.publishedBy,
    ended_at: iso(v.endedAt),
    created_at: v.createdAt.toISOString(),
    updated_at: v.updatedAt.toISOString(),
  };
}

const toSummary = (v: VersionRow): VersionSummaryDto => ({
  id: v.id,
  version_no: v.versionNo,
  status: v.status,
  change_note: v.changeNote,
  created_at: v.createdAt.toISOString(),
});

/**
 * Editorial side of the question bank. The backend owns the lifecycle: every
 * transition is checked here, runs in one transaction with the question row
 * locked, and is written to the audit log.
 */
@Injectable()
export class QuestionsService {
  constructor(
    @Inject(DB) private readonly db: Db,
    private readonly audit: AuditService,
  ) {}

  async list(query: ListQuestionsQuery): Promise<Page<QuestionListItemDto>> {
    const limit = query.limit ?? 20;
    const latestNo = this.db
      .select({
        questionId: questionVersions.questionId,
        maxNo: max(questionVersions.versionNo).as('max_no'),
      })
      .from(questionVersions)
      .groupBy(questionVersions.questionId)
      .as('latest_no');

    const where: SQL[] = [];
    const after = decodeCursor(query.cursor);
    if (after) where.push(lt(questions.id, after));
    if (query.status) where.push(eq(questionVersions.status, query.status));
    if (query.topic_id)
      where.push(eq(questionVersions.topicId, query.topic_id));
    if (query.q)
      where.push(
        ilike(questionVersions.stem, `%${query.q.replace(/[\\%_]/g, '\\$&')}%`),
      );

    const rows = await this.db
      .select({ q: questions, v: questionVersions })
      .from(questions)
      .innerJoin(latestNo, eq(latestNo.questionId, questions.id))
      .innerJoin(
        questionVersions,
        and(
          eq(questionVersions.questionId, questions.id),
          eq(questionVersions.versionNo, latestNo.maxNo),
        ),
      )
      .where(and(...where))
      .orderBy(desc(questions.id))
      .limit(limit + 1);

    return toPage(
      rows.map((r) => ({ id: r.q.id, ...r })),
      limit,
      ({ q, v }) => ({
        id: q.id,
        external_ref: q.externalRef,
        live_version_id: q.liveVersionId,
        retired_at: iso(q.retiredAt),
        latest: { ...toSummary(v), stem: v.stem, topic_id: v.topicId },
      }),
    );
  }

  async get(id: string, tx: Tx = this.db): Promise<QuestionDetailDto> {
    const [q] = await tx
      .select()
      .from(questions)
      .where(eq(questions.id, id))
      .limit(1);
    if (!q) throw ApiError.notFound('Question');
    const versions = await tx
      .select()
      .from(questionVersions)
      .where(eq(questionVersions.questionId, id))
      .orderBy(asc(questionVersions.versionNo));
    const reviews = await tx
      .select()
      .from(reviewDecisions)
      .where(
        inArray(
          reviewDecisions.versionId,
          versions.map((v) => v.id),
        ),
      )
      .orderBy(asc(reviewDecisions.createdAt));
    return {
      id: q.id,
      external_ref: q.externalRef,
      live_version_id: q.liveVersionId,
      retired_at: iso(q.retiredAt),
      created_at: q.createdAt.toISOString(),
      latest: toVersionDto(versions[versions.length - 1]),
      versions: versions.map(toSummary),
      reviews: reviews.map((r) => ({
        version_id: r.versionId,
        reviewer_id: r.reviewerId,
        decision: r.decision,
        reason: r.reason,
        created_at: r.createdAt.toISOString(),
      })),
    };
  }

  async create(
    actor: Actor,
    dto: CreateQuestionDto,
  ): Promise<QuestionDetailDto> {
    const patch = toPatch(dto);
    return this.db.transaction(async (tx) => {
      await this.requireTopic(tx, dto.topic_id);
      const questionId = newId();
      const versionId = newId();
      await tx
        .insert(questions)
        .values({ id: questionId, createdBy: actor.id });
      await tx.insert(questionVersions).values({
        ...patch,
        id: versionId,
        questionId,
        versionNo: 1,
        topicId: dto.topic_id,
        status: 'draft',
        createdBy: actor.id,
        updatedBy: actor.id,
      });
      await this.audit.record(tx, actor, {
        action: 'question.created',
        entityType: 'question',
        entityId: questionId,
        data: { version_id: versionId },
      });
      return this.get(questionId, tx);
    });
  }

  update(actor: Actor, id: string, dto: UpdateQuestionDto) {
    const patch = toPatch(dto);
    return this.act(actor, id, 'edit', async (tx, _q, v) => {
      if (patch.topicId) await this.requireTopic(tx, patch.topicId);
      await tx
        .update(questionVersions)
        .set({ ...patch, updatedBy: actor.id, updatedAt: new Date() })
        .where(eq(questionVersions.id, v.id));
      return { version_id: v.id, fields: Object.keys(dto) };
    });
  }

  submit(actor: Actor, id: string) {
    return this.act(actor, id, 'submit', async (tx, _q, v) => {
      await this.requireComplete(tx, v);
      await this.setStatus(tx, v, 'submit', { submittedAt: new Date() });
      return { version_id: v.id };
    });
  }

  requestChanges(actor: Actor, id: string, reason: string) {
    return this.act(actor, id, 'request_changes', async (tx, _q, v) => {
      await this.setStatus(tx, v, 'request_changes');
      await this.recordDecision(tx, actor, v, 'changes_requested', reason);
      return { version_id: v.id, reason };
    });
  }

  approve(actor: Actor, id: string, note?: string) {
    return this.act(actor, id, 'approve', async (tx, _q, v) => {
      if (v.createdBy === actor.id || v.updatedBy === actor.id) {
        throw ApiError.forbidden(
          'A reviewer cannot approve a version they wrote or edited',
        );
      }
      const now = new Date();
      await this.setStatus(tx, v, 'approve', {
        approvedAt: now,
        verifiedAt: now,
        reviewerId: actor.id,
      });
      await this.recordDecision(tx, actor, v, 'approved', note ?? null);
      return { version_id: v.id };
    });
  }

  publish(actor: Actor, id: string) {
    return this.act(actor, id, 'publish', async (tx, q, v) => {
      await this.requireComplete(tx, v);
      if (!v.reviewerId || !v.verifiedAt)
        throw ApiError.incomplete([
          { reason: 'The version has no recorded review' },
        ]);
      const now = new Date();
      if (q.liveVersionId) {
        await tx
          .update(questionVersions)
          .set({ status: 'superseded', endedAt: now, updatedAt: now })
          .where(eq(questionVersions.id, q.liveVersionId));
      }
      await this.setStatus(tx, v, 'publish', {
        publishedAt: now,
        publishedBy: actor.id,
      });
      await tx
        .update(questions)
        .set({ liveVersionId: v.id, retiredAt: null, updatedAt: now })
        .where(eq(questions.id, q.id));
      return { version_id: v.id, superseded_version_id: q.liveVersionId };
    });
  }

  revise(actor: Actor, id: string, changeNote: string) {
    return this.act(actor, id, 'revise', async (tx, _q, v) => {
      const versionId = newId();
      const {
        id: _id,
        versionNo,
        status: _s,
        verifiedAt: _va,
        reviewerId: _r,
        submittedAt: _sa,
        approvedAt: _aa,
        publishedAt: _pa,
        publishedBy: _pb,
        endedAt: _e,
        createdAt: _c,
        updatedAt: _u,
        ...content
      } = v;
      await tx.insert(questionVersions).values({
        ...content,
        id: versionId,
        versionNo: versionNo + 1,
        status: 'draft',
        changeNote,
        createdBy: actor.id,
        updatedBy: actor.id,
      });
      return {
        version_id: versionId,
        from_version_id: v.id,
        change_note: changeNote,
      };
    });
  }

  /** Takes the live version down. Any revision in progress is left as it is. */
  async retire(
    actor: Actor,
    id: string,
    reason: string,
  ): Promise<QuestionDetailDto> {
    return this.db.transaction(async (tx) => {
      const q = await this.lockQuestion(tx, id);
      if (!q.liveVersionId)
        throw ApiError.invalidTransition(
          'This question has no published version to retire',
        );
      const now = new Date();
      await tx
        .update(questionVersions)
        .set({ status: 'retired', endedAt: now, updatedAt: now })
        .where(eq(questionVersions.id, q.liveVersionId));
      await tx
        .update(questions)
        .set({ liveVersionId: null, retiredAt: now, updatedAt: now })
        .where(eq(questions.id, id));
      await this.audit.record(tx, actor, {
        action: 'question.retired',
        entityType: 'question',
        entityId: id,
        data: { version_id: q.liveVersionId, reason },
      });
      return this.get(id, tx);
    });
  }

  // ---------------------------------------------------------------- helpers

  /** Locks the question, checks its latest version may take [action], runs [fn] and audits it. */
  private act(
    actor: Actor,
    id: string,
    action: Action,
    fn: (
      tx: Tx,
      q: QuestionRow,
      latest: VersionRow,
    ) => Promise<Record<string, unknown>>,
  ): Promise<QuestionDetailDto> {
    return this.db.transaction(async (tx) => {
      const q = await this.lockQuestion(tx, id);
      const [latest] = await tx
        .select()
        .from(questionVersions)
        .where(eq(questionVersions.questionId, id))
        .orderBy(desc(questionVersions.versionNo))
        .limit(1);
      const allowed: readonly string[] = ACTIONS[action].from;
      if (!allowed.includes(latest.status)) {
        throw ApiError.invalidTransition(
          `Cannot ${action.replace('_', ' ')} a question whose latest version is ${latest.status.replace('_', ' ')}`,
        );
      }
      const data = await fn(tx, q, latest);
      await this.audit.record(tx, actor, {
        action: AUDIT_ACTIONS[action],
        entityType: 'question',
        entityId: id,
        data,
      });
      return this.get(id, tx);
    });
  }

  private async lockQuestion(tx: Tx, id: string): Promise<QuestionRow> {
    const [q] = await tx
      .select()
      .from(questions)
      .where(eq(questions.id, id))
      .for('update')
      .limit(1);
    if (!q) throw ApiError.notFound('Question');
    return q;
  }

  private async setStatus(
    tx: Tx,
    v: VersionRow,
    action: Action,
    extra: VersionPatch = {},
  ) {
    const to = (ACTIONS[action] as { to?: VersionRow['status'] }).to!;
    await tx
      .update(questionVersions)
      .set({ ...extra, status: to, updatedAt: new Date() })
      .where(eq(questionVersions.id, v.id));
  }

  private async recordDecision(
    tx: Tx,
    actor: Actor,
    v: VersionRow,
    decision: 'approved' | 'changes_requested',
    reason: string | null,
  ) {
    await tx
      .insert(reviewDecisions)
      .values({
        id: newId(),
        versionId: v.id,
        reviewerId: actor.id,
        decision,
        reason,
      });
  }

  private async requireTopic(tx: Tx, topicId: string) {
    const [t] = await tx
      .select({ id: topics.id })
      .from(topics)
      .where(eq(topics.id, topicId))
      .limit(1);
    if (!t) {
      throw new ApiError(
        HttpStatus.UNPROCESSABLE_ENTITY,
        'validation_failed',
        'Unknown topic',
        [{ field: 'topic_id', reason: 'No topic has this id' }],
      );
    }
  }

  private async requireComplete(tx: Tx, v: VersionRow) {
    const [t] = await tx
      .select({ isActive: topics.isActive })
      .from(topics)
      .where(eq(topics.id, v.topicId))
      .limit(1);
    const problems = contentProblems(v, t?.isActive ?? false);
    if (problems.length) throw ApiError.incomplete(problems);
  }
}
