import { HttpStatus, Inject, Injectable } from '@nestjs/common';
import { and, asc, desc, eq, inArray, max, lt } from 'drizzle-orm';
import { AuditService, isAdmin, type Actor } from '../core/audit.service.js';
import { DB, type Db, type Tx } from '../core/db.js';
import {
  ApiError,
  isUniqueViolation,
  type ErrorDetail,
} from '../core/errors.js';
import { newId } from '../core/ids.js';
import { decodeCursor, toPage } from '../core/pagination.js';
import {
  contentSources,
  examBlueprints,
  examPaperKeyHistory,
  examPaperQuestions,
  examPapers,
  exams,
  questionVersions,
  type PaperAnswerStatus,
} from '../db/schema.js';
import {
  acceptedOptions,
  answerStatusFor,
  isPermutation,
  publishProblems,
} from './paper-rules.js';
import type {
  AddKeyHistoryDto,
  CreatePaperDto,
  KeyHistoryEntryDto,
  LearnerListPapersQuery,
  LearnerPaperDetailDto,
  LearnerPaperPageDto,
  ListPapersQuery,
  PaperDetailDto,
  PaperDto,
  PaperPageDto,
  PaperReadinessDto,
  PositionInputDto,
  StaffPositionDto,
  UpdatePaperDto,
} from './papers.dto.js';

type PaperRow = typeof examPapers.$inferSelect;
type KeyRow = typeof examPaperKeyHistory.$inferSelect;
type VersionRow = typeof questionVersions.$inferSelect;

const num = (v: string | null): number | null =>
  v === null ? null : Number(v);
const fixed2 = (v: number | undefined): string | undefined =>
  v === undefined ? undefined : v.toFixed(2);
const iso = (d: Date | null) => (d ? d.toISOString() : null);

const toPaperDto = (p: PaperRow): PaperDto => ({
  id: p.id,
  exam_id: p.examId,
  code: p.code,
  revision: p.revision,
  supersedes_id: p.supersedesId,
  title: p.title,
  edition: p.edition,
  year: p.year,
  set_label: p.setLabel,
  status: p.status,
  frozen_at: iso(p.frozenAt),
  blueprint_id: p.blueprintId,
  total_questions: p.totalQuestions,
  duration_seconds: p.durationSeconds,
  practice_timer_seconds: p.practiceTimerSeconds,
  marks_correct: num(p.marksCorrect),
  negative_marks: num(p.negativeMarks),
  marks_unanswered: num(p.marksUnanswered),
  withdrawn_policy: p.withdrawnPolicy,
  withdrawn_policy_confirmed: p.withdrawnPolicyConfirmed,
  config_status: p.configStatus,
  source_note: p.sourceNote,
  created_at: p.createdAt.toISOString(),
  updated_at: p.updatedAt.toISOString(),
});

const toKeyDto = (k: KeyRow): KeyHistoryEntryDto => ({
  id: k.id,
  kind: k.kind,
  accepted_option_ids: k.acceptedOptionIds,
  content_source_id: k.contentSourceId,
  source_document_ref: k.sourceDocumentRef,
  retrieved_on: k.retrievedOn,
  source_sha256: k.sourceSha256,
  note: k.note,
  recorded_by: k.recordedBy,
  created_at: k.createdAt.toISOString(),
});

const paperFrozen = (p: PaperRow) =>
  new ApiError(
    HttpStatus.CONFLICT,
    'paper_frozen',
    `A ${p.status} paper is frozen and cannot be changed; make a new revision instead`,
  );

@Injectable()
export class PapersService {
  constructor(
    @Inject(DB) private readonly db: Db,
    private readonly audit: AuditService,
  ) {}

  // ---------------------------------------------------------------- staff: read

  async list(query: ListPapersQuery): Promise<PaperPageDto> {
    const limit = query.limit ?? 50;
    const after = decodeCursor(query.cursor);
    const rows = await this.db
      .select()
      .from(examPapers)
      .where(
        and(
          query.status ? eq(examPapers.status, query.status) : undefined,
          query.exam_id ? eq(examPapers.examId, query.exam_id) : undefined,
          after ? lt(examPapers.id, after) : undefined,
        ),
      )
      .orderBy(desc(examPapers.id))
      .limit(limit + 1);
    return toPage(rows, limit, toPaperDto);
  }

  async get(id: string): Promise<PaperDetailDto> {
    const paper = await this.load(this.db, id);
    return {
      ...toPaperDto(paper),
      positions: await this.staffPositions(this.db, paper),
    };
  }

  /** What would stop this paper being published, without changing anything. */
  async readiness(id: string): Promise<PaperReadinessDto> {
    const paper = await this.load(this.db, id);
    const problems = await this.problemsFor(this.db, paper);
    return { ready: problems.length === 0, problems };
  }

  // ---------------------------------------------------------------- staff: write

  async create(actor: Actor, dto: CreatePaperDto): Promise<PaperDto> {
    try {
      return await this.db.transaction(async (tx) => {
        const [exam] = await tx
          .select({ id: exams.id })
          .from(exams)
          .where(eq(exams.id, dto.exam_id))
          .limit(1);
        if (!exam) throw ApiError.notFound('Exam');
        if (dto.blueprint_id)
          await this.requireBlueprintOf(tx, dto.blueprint_id, dto.exam_id);
        if (
          dto.withdrawn_policy === 'award_all' &&
          !dto.withdrawn_policy_confirmed
        )
          throw this.awardAllNeedsConfirmation();
        const id = newId();
        const [row] = await tx
          .insert(examPapers)
          .values({
            id,
            examId: dto.exam_id,
            code: dto.code,
            title: dto.title,
            edition: dto.edition,
            year: dto.year,
            setLabel: dto.set_label,
            blueprintId: dto.blueprint_id,
            totalQuestions: dto.total_questions,
            durationSeconds: dto.duration_seconds,
            practiceTimerSeconds: dto.practice_timer_seconds,
            marksCorrect: fixed2(dto.marks_correct),
            negativeMarks: fixed2(dto.negative_marks),
            marksUnanswered: fixed2(dto.marks_unanswered),
            withdrawnPolicy: dto.withdrawn_policy,
            withdrawnPolicyConfirmed: dto.withdrawn_policy_confirmed,
            configStatus: dto.config_status,
            sourceNote: dto.source_note,
            createdBy: actor.id,
          })
          .returning();
        await this.audit.record(tx, actor, {
          action: 'exam_paper.created',
          entityType: 'exam_paper',
          entityId: id,
          data: { code: dto.code, revision: 1 },
        });
        return toPaperDto(row);
      });
    } catch (e) {
      if (isUniqueViolation(e))
        throw new ApiError(
          HttpStatus.CONFLICT,
          'paper_exists',
          'A paper with this code already exists for the exam',
        );
      throw e;
    }
  }

  async update(
    actor: Actor,
    id: string,
    dto: UpdatePaperDto,
  ): Promise<PaperDto> {
    return this.db.transaction(async (tx) => {
      const paper = await this.lockDraft(tx, id);
      if (dto.blueprint_id)
        await this.requireBlueprintOf(tx, dto.blueprint_id, paper.examId);
      const policy = dto.withdrawn_policy ?? paper.withdrawnPolicy;
      const confirmed =
        dto.withdrawn_policy_confirmed ?? paper.withdrawnPolicyConfirmed;
      if (policy === 'award_all' && !confirmed)
        throw this.awardAllNeedsConfirmation();
      if (dto.total_questions !== undefined) {
        const [top] = await tx
          .select({ n: max(examPaperQuestions.position) })
          .from(examPaperQuestions)
          .where(eq(examPaperQuestions.paperId, id));
        if ((top?.n ?? 0) > dto.total_questions)
          throw new ApiError(
            HttpStatus.UNPROCESSABLE_ENTITY,
            'positions_exceed_total',
            `The paper already has a position ${top?.n}`,
            [
              {
                field: 'total_questions',
                reason: 'Below the highest position',
              },
            ],
          );
      }
      const [row] = await tx
        .update(examPapers)
        .set({
          title: dto.title,
          edition: dto.edition,
          year: dto.year,
          setLabel: dto.set_label,
          blueprintId: dto.blueprint_id,
          totalQuestions: dto.total_questions,
          durationSeconds: dto.duration_seconds,
          practiceTimerSeconds: dto.practice_timer_seconds,
          marksCorrect: fixed2(dto.marks_correct),
          negativeMarks: fixed2(dto.negative_marks),
          marksUnanswered: fixed2(dto.marks_unanswered),
          withdrawnPolicy: dto.withdrawn_policy,
          withdrawnPolicyConfirmed: dto.withdrawn_policy_confirmed,
          configStatus: dto.config_status,
          sourceNote: dto.source_note,
          updatedAt: new Date(),
        })
        .where(eq(examPapers.id, id))
        .returning();
      await this.audit.record(tx, actor, {
        action: 'exam_paper.updated',
        entityType: 'exam_paper',
        entityId: id,
        data: { fields: Object.keys(dto) },
      });
      return toPaperDto(row);
    });
  }

  /**
   * Sets the paper's positions. A position is updated in place when it exists
   * (keeping its key history while the pinned version is unchanged), added
   * when new, and removed when left out. Draft papers only.
   */
  async replacePositions(
    actor: Actor,
    id: string,
    positions: PositionInputDto[],
  ): Promise<PaperDetailDto> {
    await this.db.transaction(async (tx) => {
      const paper = await this.lockDraft(tx, id);
      const problems: ErrorDetail[] = [];
      const seenPositions = new Set<number>();
      for (const p of positions) {
        if (p.position > paper.totalQuestions)
          problems.push({
            field: `positions[${p.position}]`,
            reason: `Beyond total_questions (${paper.totalQuestions})`,
          });
        if (seenPositions.has(p.position))
          problems.push({
            field: `positions[${p.position}]`,
            reason: 'Listed more than once',
          });
        seenPositions.add(p.position);
      }
      const versionIds = positions
        .map((p) => p.question_version_id)
        .filter((v): v is string => !!v);
      const versions = await this.versionsById(tx, versionIds);
      const prepared: {
        input: PositionInputDto;
        version: VersionRow | null;
        status: PaperAnswerStatus;
      }[] = [];
      for (const p of positions) {
        const field = `positions[${p.position}]`;
        if (!p.question_version_id) {
          if (p.option_order)
            problems.push({
              field,
              reason: 'A withdrawn position has no options',
            });
          prepared.push({ input: p, version: null, status: 'withdrawn' });
          continue;
        }
        const v = versions.get(p.question_version_id);
        if (!v) {
          problems.push({
            field,
            reason: 'The question version does not exist',
          });
          continue;
        }
        if (
          v.version.status !== 'published' &&
          v.version.status !== 'superseded'
        )
          problems.push({
            field,
            reason: `Only a published (or since superseded) version can be pinned; this one is ${v.version.status}`,
          });
        const optionIds = v.version.options.map((o) => o.id);
        if (p.option_order && !isPermutation(p.option_order, optionIds))
          problems.push({
            field: `${field}.option_order`,
            reason: 'Must list each of the version’s option ids exactly once',
          });
        prepared.push({
          input: p,
          version: v.version,
          status: answerStatusFor(
            v.version.id,
            v.version.correctOptionIds,
            v.version.alternateCorrectOptionIds,
          ),
        });
      }
      if (problems.length)
        throw new ApiError(
          HttpStatus.UNPROCESSABLE_ENTITY,
          'invalid_positions',
          'The positions cannot be saved',
          problems,
        );

      const existing = await tx
        .select()
        .from(examPaperQuestions)
        .where(eq(examPaperQuestions.paperId, id));
      const byPosition = new Map(existing.map((e) => [e.position, e]));
      let clearedHistory = 0;
      for (const p of prepared) {
        const values = {
          questionId: p.version?.questionId ?? null,
          questionVersionId: p.version?.id ?? null,
          answerStatus: p.status,
          originalRef: p.input.original_ref ?? null,
          optionOrder: p.input.option_order ?? null,
          originalLabelScheme: p.input.original_label_scheme ?? null,
          officialKeyText: p.input.official_key_text ?? null,
          sourceRef: p.input.source_ref ?? null,
          withdrawnNote: p.input.withdrawn_note ?? null,
        };
        const old = byPosition.get(p.input.position);
        if (old) {
          if (old.questionVersionId !== values.questionVersionId)
            clearedHistory += await this.dropHistory(tx, old.id);
          await tx
            .update(examPaperQuestions)
            .set(values)
            .where(eq(examPaperQuestions.id, old.id));
        } else {
          await tx.insert(examPaperQuestions).values({
            id: newId(),
            paperId: id,
            position: p.input.position,
            ...values,
          });
        }
      }
      const keep = new Set(positions.map((p) => p.position));
      const gone = existing.filter((e) => !keep.has(e.position));
      for (const g of gone) {
        clearedHistory += await this.dropHistory(tx, g.id);
        await tx
          .delete(examPaperQuestions)
          .where(eq(examPaperQuestions.id, g.id));
      }
      await tx
        .update(examPapers)
        .set({ updatedAt: new Date() })
        .where(eq(examPapers.id, id));
      await this.audit.record(tx, actor, {
        action: 'exam_paper.positions_replaced',
        entityType: 'exam_paper',
        entityId: id,
        data: {
          positions: positions.length,
          removed: gone.length,
          key_history_rows_cleared: clearedHistory,
        },
      });
    });
    return this.get(id);
  }

  async addKeyHistory(
    actor: Actor,
    paperId: string,
    position: number,
    dto: AddKeyHistoryDto,
  ): Promise<KeyHistoryEntryDto> {
    return this.db.transaction(async (tx) => {
      await this.lockDraft(tx, paperId);
      const [pq] = await tx
        .select()
        .from(examPaperQuestions)
        .where(
          and(
            eq(examPaperQuestions.paperId, paperId),
            eq(examPaperQuestions.position, position),
          ),
        )
        .limit(1);
      if (!pq) throw ApiError.notFound('Position');
      const problems: ErrorDetail[] = [];
      const add = (field: string, reason: string) =>
        problems.push({ field, reason });

      if (pq.answerStatus === 'withdrawn') {
        if (dto.kind !== 'withdrawn')
          add('kind', 'A withdrawn position only takes withdrawn key entries');
        if (dto.accepted_option_ids.length)
          add(
            'accepted_option_ids',
            'A withdrawn question has no accepted options',
          );
      } else {
        if (dto.kind === 'withdrawn')
          add(
            'kind',
            'This position holds a question; withdraw it by replacing it with a placeholder',
          );
        if (dto.accepted_option_ids.length === 0)
          add('accepted_option_ids', 'List at least one accepted option');
        const [v] = await tx
          .select({ options: questionVersions.options })
          .from(questionVersions)
          .where(eq(questionVersions.id, pq.questionVersionId!))
          .limit(1);
        const ids = v?.options.map((o) => o.id) ?? [];
        if (dto.accepted_option_ids.some((o) => !ids.includes(o)))
          add(
            'accepted_option_ids',
            'Every accepted option must be an option of the pinned question',
          );
        if (
          new Set(dto.accepted_option_ids).size !==
          dto.accepted_option_ids.length
        )
          add('accepted_option_ids', 'Options are listed more than once');
      }
      if (
        (dto.kind === 'final' ||
          dto.kind === 'revised' ||
          dto.kind === 'withdrawn') &&
        !dto.content_source_id &&
        !dto.source_document_ref
      )
        add('source_document_ref', 'Say which document this key comes from');
      if (dto.content_source_id) {
        const [s] = await tx
          .select({ id: contentSources.id })
          .from(contentSources)
          .where(eq(contentSources.id, dto.content_source_id))
          .limit(1);
        if (!s) add('content_source_id', 'The content source does not exist');
      }
      if (problems.length)
        throw new ApiError(
          HttpStatus.UNPROCESSABLE_ENTITY,
          'invalid_key_entry',
          'The key entry cannot be saved',
          problems,
        );
      const [row] = await tx
        .insert(examPaperKeyHistory)
        .values({
          id: newId(),
          paperId,
          paperQuestionId: pq.id,
          kind: dto.kind,
          acceptedOptionIds: dto.accepted_option_ids,
          contentSourceId: dto.content_source_id,
          sourceDocumentRef: dto.source_document_ref,
          retrievedOn: dto.retrieved_on,
          sourceSha256: dto.source_sha256,
          note: dto.note,
          recordedBy: actor.id,
        })
        .returning();
      await this.audit.record(tx, actor, {
        action: 'exam_paper.key_recorded',
        entityType: 'exam_paper',
        entityId: paperId,
        data: { position, kind: dto.kind },
      });
      return toKeyDto(row);
    });
  }

  /** Freezes a draft: it is complete, its pinned questions are published, and it never changes again. */
  async publish(actor: Actor, id: string): Promise<PaperDto> {
    return this.db.transaction(async (tx) => {
      const paper = await this.lockDraft(tx, id);
      if (!isAdmin(actor) && paper.createdBy === actor.id)
        throw ApiError.forbidden('You cannot publish a paper you created');
      const problems = await this.problemsFor(tx, paper);
      if (problems.length)
        throw new ApiError(
          HttpStatus.UNPROCESSABLE_ENTITY,
          'paper_not_ready',
          'The paper cannot be published yet',
          problems,
        );
      const now = new Date();
      // A paper has one live revision: the one it replaces is retired.
      await tx
        .update(examPapers)
        .set({ status: 'retired', updatedAt: now })
        .where(
          and(
            eq(examPapers.examId, paper.examId),
            eq(examPapers.code, paper.code),
            eq(examPapers.status, 'published'),
          ),
        );
      const [row] = await tx
        .update(examPapers)
        .set({ status: 'published', frozenAt: now, updatedAt: now })
        .where(eq(examPapers.id, id))
        .returning();
      await this.audit.record(tx, actor, {
        action: 'exam_paper.published',
        entityType: 'exam_paper',
        entityId: id,
        data: { code: paper.code, revision: paper.revision },
      });
      return toPaperDto(row);
    });
  }

  async retire(actor: Actor, id: string): Promise<PaperDto> {
    return this.db.transaction(async (tx) => {
      const paper = await this.load(tx, id, true);
      if (paper.status !== 'published')
        throw ApiError.invalidTransition(
          'Only a published paper can be retired',
        );
      const [row] = await tx
        .update(examPapers)
        .set({ status: 'retired', updatedAt: new Date() })
        .where(eq(examPapers.id, id))
        .returning();
      await this.audit.record(tx, actor, {
        action: 'exam_paper.retired',
        entityType: 'exam_paper',
        entityId: id,
      });
      return toPaperDto(row);
    });
  }

  /** Starts a new draft revision from a frozen paper, copying positions and key history. */
  async revise(actor: Actor, id: string): Promise<PaperDetailDto> {
    const newPaperId = await this.db.transaction(async (tx) => {
      const src = await this.load(tx, id, true);
      if (src.status === 'draft')
        throw ApiError.invalidTransition('A draft can be edited directly');
      const [latest] = await tx
        .select({ n: max(examPapers.revision) })
        .from(examPapers)
        .where(
          and(eq(examPapers.examId, src.examId), eq(examPapers.code, src.code)),
        );
      const [openDraft] = await tx
        .select({ id: examPapers.id })
        .from(examPapers)
        .where(
          and(
            eq(examPapers.examId, src.examId),
            eq(examPapers.code, src.code),
            eq(examPapers.status, 'draft'),
          ),
        )
        .limit(1);
      if (openDraft)
        throw new ApiError(
          HttpStatus.CONFLICT,
          'revision_in_progress',
          'This paper already has a draft revision',
        );
      const newId_ = newId();
      await tx.insert(examPapers).values({
        id: newId_,
        examId: src.examId,
        code: src.code,
        revision: (latest?.n ?? src.revision) + 1,
        supersedesId: src.id,
        title: src.title,
        edition: src.edition,
        year: src.year,
        setLabel: src.setLabel,
        blueprintId: src.blueprintId,
        totalQuestions: src.totalQuestions,
        durationSeconds: src.durationSeconds,
        practiceTimerSeconds: src.practiceTimerSeconds,
        marksCorrect: src.marksCorrect,
        negativeMarks: src.negativeMarks,
        marksUnanswered: src.marksUnanswered,
        withdrawnPolicy: src.withdrawnPolicy,
        withdrawnPolicyConfirmed: src.withdrawnPolicyConfirmed,
        configStatus: src.configStatus,
        sourceNote: src.sourceNote,
        createdBy: actor.id,
      });
      const positions = await tx
        .select()
        .from(examPaperQuestions)
        .where(eq(examPaperQuestions.paperId, src.id));
      const idMap = new Map<string, string>();
      for (const p of positions) {
        const nid = newId();
        idMap.set(p.id, nid);
        await tx.insert(examPaperQuestions).values({
          ...p,
          id: nid,
          paperId: newId_,
          createdAt: undefined,
        });
      }
      const keys = await tx
        .select()
        .from(examPaperKeyHistory)
        .where(eq(examPaperKeyHistory.paperId, src.id))
        .orderBy(
          asc(examPaperKeyHistory.createdAt),
          asc(examPaperKeyHistory.id),
        );
      for (const k of keys) {
        await tx.insert(examPaperKeyHistory).values({
          ...k,
          id: newId(),
          paperId: newId_,
          paperQuestionId: idMap.get(k.paperQuestionId)!,
        });
      }
      await this.audit.record(tx, actor, {
        action: 'exam_paper.revision_started',
        entityType: 'exam_paper',
        entityId: newId_,
        data: { from: src.id, code: src.code },
      });
      return newId_;
    });
    return this.get(newPaperId);
  }

  // ---------------------------------------------------------------- learner

  async listPublished(
    slug: string,
    query: LearnerListPapersQuery,
  ): Promise<LearnerPaperPageDto> {
    const exam = await this.activeExam(slug);
    const limit = query.limit ?? 50;
    const after = decodeCursor(query.cursor);
    const rows = await this.db
      .select()
      .from(examPapers)
      .where(
        and(
          eq(examPapers.examId, exam.id),
          eq(examPapers.status, 'published'),
          after ? lt(examPapers.id, after) : undefined,
        ),
      )
      .orderBy(desc(examPapers.id))
      .limit(limit + 1);
    return toPage(rows, limit, learnerPaper);
  }

  /**
   * A published paper as a learner sees it before any attempt: the questions
   * in their original order and option order. No key, explanation or
   * source information is included, and withdrawn positions are placeholders.
   */
  async getPublished(slug: string, id: string): Promise<LearnerPaperDetailDto> {
    const exam = await this.activeExam(slug);
    const [paper] = await this.db
      .select()
      .from(examPapers)
      .where(
        and(
          eq(examPapers.id, id),
          eq(examPapers.examId, exam.id),
          eq(examPapers.status, 'published'),
        ),
      )
      .limit(1);
    if (!paper) throw ApiError.notFound('Paper');
    const rows = await this.db
      .select({ pq: examPaperQuestions, v: questionVersions })
      .from(examPaperQuestions)
      .leftJoin(
        questionVersions,
        eq(questionVersions.id, examPaperQuestions.questionVersionId),
      )
      .where(eq(examPaperQuestions.paperId, id))
      .orderBy(asc(examPaperQuestions.position));
    return {
      ...learnerPaper(paper),
      positions: rows.map(({ pq, v }) => {
        if (!v)
          return {
            position: pq.position,
            original_ref: pq.originalRef,
            withdrawn: true,
            question_version_id: null,
            stem: null,
            options: null,
          };
        const byId = new Map(v.options.map((o) => [o.id, o]));
        const order = pq.optionOrder ?? v.options.map((o) => o.id);
        return {
          position: pq.position,
          original_ref: pq.originalRef,
          withdrawn: false,
          question_version_id: v.id,
          stem: v.stem,
          options: order.map((oid) => ({ id: oid, text: byId.get(oid)!.text })),
        };
      }),
    };
  }

  // ---------------------------------------------------------------- helpers

  private async activeExam(slug: string) {
    const [exam] = await this.db
      .select()
      .from(exams)
      .where(and(eq(exams.slug, slug), eq(exams.isActive, true)))
      .limit(1);
    if (!exam) throw ApiError.notFound('Exam');
    return exam;
  }

  private awardAllNeedsConfirmation() {
    return new ApiError(
      HttpStatus.UNPROCESSABLE_ENTITY,
      'withdrawn_policy_unconfirmed',
      'Awarding marks for withdrawn questions needs the rule confirmed from the exam body',
      [
        {
          field: 'withdrawn_policy_confirmed',
          reason: 'Must be true for award_all',
        },
      ],
    );
  }

  private async requireBlueprintOf(
    tx: Tx,
    blueprintId: string,
    examId: string,
  ) {
    const [bp] = await tx
      .select({ examId: examBlueprints.examId })
      .from(examBlueprints)
      .where(eq(examBlueprints.id, blueprintId))
      .limit(1);
    if (!bp || bp.examId !== examId) throw ApiError.notFound('Blueprint');
  }

  private async load(tx: Tx | Db, id: string, lock = false): Promise<PaperRow> {
    const q = tx.select().from(examPapers).where(eq(examPapers.id, id));
    const [paper] = await (lock ? q.for('update') : q).limit(1);
    if (!paper) throw ApiError.notFound('Paper');
    return paper;
  }

  /** Locks a paper for a change; only a draft may change. */
  private async lockDraft(tx: Tx, id: string): Promise<PaperRow> {
    const paper = await this.load(tx, id, true);
    if (paper.status !== 'draft') throw paperFrozen(paper);
    return paper;
  }

  private async dropHistory(tx: Tx, paperQuestionId: string): Promise<number> {
    const gone = await tx
      .delete(examPaperKeyHistory)
      .where(eq(examPaperKeyHistory.paperQuestionId, paperQuestionId))
      .returning({ id: examPaperKeyHistory.id });
    return gone.length;
  }

  private async versionsById(tx: Tx, ids: string[]) {
    const out = new Map<string, { version: VersionRow }>();
    if (ids.length === 0) return out;
    const rows = await tx
      .select({ version: questionVersions })
      .from(questionVersions)
      .where(inArray(questionVersions.id, ids));
    for (const r of rows) out.set(r.version.id, { version: r.version });
    return out;
  }

  private async problemsFor(
    tx: Tx | Db,
    paper: PaperRow,
  ): Promise<ErrorDetail[]> {
    const rows = await tx
      .select({
        pq: examPaperQuestions,
        v: questionVersions,
      })
      .from(examPaperQuestions)
      .leftJoin(
        questionVersions,
        eq(questionVersions.id, examPaperQuestions.questionVersionId),
      )
      .where(eq(examPaperQuestions.paperId, paper.id));
    return publishProblems({
      totalQuestions: paper.totalQuestions,
      withdrawnPolicy: paper.withdrawnPolicy,
      withdrawnPolicyConfirmed: paper.withdrawnPolicyConfirmed,
      marksCorrect: num(paper.marksCorrect),
      hasWithdrawn: rows.some((r) => r.pq.answerStatus === 'withdrawn'),
      positions: rows.map(({ pq, v }) => ({
        position: pq.position,
        answerStatus: pq.answerStatus,
        versionProblem: !v
          ? pq.answerStatus === 'withdrawn'
            ? null
            : 'The pinned question version is missing'
          : v.status !== 'published' && v.status !== 'superseded'
            ? `The pinned version is ${v.status}`
            : null,
      })),
    });
  }

  private async staffPositions(
    tx: Tx | Db,
    paper: PaperRow,
  ): Promise<StaffPositionDto[]> {
    const rows = await tx
      .select({ pq: examPaperQuestions, v: questionVersions })
      .from(examPaperQuestions)
      .leftJoin(
        questionVersions,
        eq(questionVersions.id, examPaperQuestions.questionVersionId),
      )
      .where(eq(examPaperQuestions.paperId, paper.id))
      .orderBy(asc(examPaperQuestions.position));
    const keys = await tx
      .select()
      .from(examPaperKeyHistory)
      .where(eq(examPaperKeyHistory.paperId, paper.id))
      .orderBy(asc(examPaperKeyHistory.createdAt), asc(examPaperKeyHistory.id));
    return rows.map(({ pq, v }) => {
      const history = keys.filter((k) => k.paperQuestionId === pq.id);
      const latest = history.length ? history[history.length - 1] : null;
      return {
        id: pq.id,
        position: pq.position,
        answer_status: pq.answerStatus,
        question_id: pq.questionId,
        question_version_id: pq.questionVersionId,
        original_ref: pq.originalRef,
        option_order: pq.optionOrder,
        original_label_scheme: pq.originalLabelScheme,
        official_key_text: pq.officialKeyText,
        source_ref: pq.sourceRef,
        withdrawn_note: pq.withdrawnNote,
        accepted_option_ids: acceptedOptions({
          answerStatus: pq.answerStatus,
          versionCorrect: v?.correctOptionIds ?? [],
          versionAlternates: v?.alternateCorrectOptionIds ?? [],
          latestKey: latest
            ? { kind: latest.kind, acceptedOptionIds: latest.acceptedOptionIds }
            : null,
        }),
        key_history: history.map(toKeyDto),
      };
    });
  }
}

const learnerPaper = (p: PaperRow) => ({
  id: p.id,
  code: p.code,
  revision: p.revision,
  title: p.title,
  edition: p.edition,
  year: p.year,
  set_label: p.setLabel,
  total_questions: p.totalQuestions,
  duration_seconds: p.durationSeconds,
  practice_timer_seconds: p.practiceTimerSeconds,
  config_status: p.configStatus,
});
