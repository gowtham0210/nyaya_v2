import { HttpStatus, Inject, Injectable } from '@nestjs/common';
import { and, asc, desc, eq, inArray, max } from 'drizzle-orm';
import { AuditService, isAdmin, type Actor } from '../core/audit.service.js';
import { DB, type Db, type Tx } from '../core/db.js';
import {
  ApiError,
  isUniqueViolation,
  type ErrorDetail,
} from '../core/errors.js';
import { newId } from '../core/ids.js';
import {
  examBlueprints,
  examSectionTopics,
  examSections,
  exams,
  subjects,
  topics,
  type LawRegimeFilter,
} from '../db/schema.js';
import {
  configEvidenceProblems,
  sectionProblems,
  structureProblems,
  timedModeVerdict,
  type SectionDraft,
} from './blueprint-rules.js';
import type {
  BlueprintDto,
  CreateBlueprintDto,
  CreateExamDto,
  ExamDetailDto,
  ExamDto,
  ExamListDto,
  ReplaceSectionsDto,
  SectionOutDto,
  UpdateBlueprintDto,
  UpdateExamDto,
} from './exams.dto.js';

type ExamRow = typeof exams.$inferSelect;
type BlueprintRow = typeof examBlueprints.$inferSelect;
type SectionRow = typeof examSections.$inferSelect;
type SectionTopicRow = typeof examSectionTopics.$inferSelect;

const toExamDto = (e: ExamRow): ExamDto => ({
  id: e.id,
  slug: e.slug as ExamDto['slug'],
  name: e.name,
  short_name: e.shortName,
  is_active: e.isActive,
  sort_order: e.sortOrder,
  instructions: e.instructions,
  created_at: e.createdAt.toISOString(),
  updated_at: e.updatedAt.toISOString(),
});

const num = (v: string | null): number | null =>
  v === null ? null : Number(v);
/** numeric(5,2) columns take text, and two decimal places are all they keep. */
const fixed2 = (v: number): string => v.toFixed(2);

const validation = (details: ErrorDetail[]) =>
  new ApiError(
    HttpStatus.UNPROCESSABLE_ENTITY,
    'validation_failed',
    'Request is invalid',
    details,
  );

function toBlueprintDto(
  b: BlueprintRow,
  sections: { row: SectionRow; topics: SectionTopicRow[] }[],
): BlueprintDto {
  const verdict = timedModeVerdict(b);
  return {
    id: b.id,
    exam_id: b.examId,
    code: b.code,
    version: b.version,
    status: b.status,
    is_current: b.isCurrent,
    duration_seconds: b.durationSeconds,
    total_questions: b.totalQuestions,
    marks_correct: Number(b.marksCorrect),
    negative_marks: Number(b.negativeMarks),
    marks_unanswered: Number(b.marksUnanswered),
    pass_percent_general: num(b.passPercentGeneral),
    pass_percent_reserved: num(b.passPercentReserved),
    section_navigation: b.sectionNavigation,
    law_regime_filter: b.lawRegimeFilter,
    config_status: b.configStatus,
    config_source: b.configSource,
    config_checked_on: b.configCheckedOn,
    timed_allowed: verdict.allowed,
    timed_blocked_reason: verdict.allowed ? null : verdict.reason,
    sections: sections
      .sort((a, b2) => a.row.position - b2.row.position)
      .map(({ row, topics: ts }): SectionOutDto => ({
        id: row.id,
        code: row.code,
        name: row.name,
        position: row.position,
        question_count: row.questionCount,
        duration_seconds: row.durationSeconds,
        marks_correct: num(row.marksCorrect),
        topics: ts.map((t) => ({
          topic_id: t.topicId,
          min_count: t.minCount,
          max_count: t.maxCount,
          weight: t.weight,
        })),
      })),
    created_at: b.createdAt.toISOString(),
    updated_at: b.updatedAt.toISOString(),
  };
}

@Injectable()
export class ExamsService {
  constructor(
    @Inject(DB) private readonly db: Db,
    private readonly audit: AuditService,
  ) {}

  // ---------------------------------------------------------------- exams

  async listExams(): Promise<ExamListDto> {
    const rows = await this.db
      .select()
      .from(exams)
      .orderBy(asc(exams.sortOrder), asc(exams.slug));
    return { items: rows.map(toExamDto) };
  }

  async getExam(id: string): Promise<ExamDetailDto> {
    const [e] = await this.db.select().from(exams).where(eq(exams.id, id));
    if (!e) throw ApiError.notFound('Exam');
    const blueprints = await this.db
      .select()
      .from(examBlueprints)
      .where(eq(examBlueprints.examId, id))
      .orderBy(asc(examBlueprints.code), desc(examBlueprints.version));
    return {
      ...toExamDto(e),
      current_blueprint_id: blueprints.find((b) => b.isCurrent)?.id ?? null,
      blueprints: await Promise.all(
        blueprints.map((b) => this.blueprintDto(this.db, b)),
      ),
    };
  }

  /** A new exam is created switched off; it cannot be switched on without a published blueprint. */
  async createExam(actor: Actor, dto: CreateExamDto): Promise<ExamDto> {
    try {
      return await this.db.transaction(async (tx) => {
        const id = newId();
        const [row] = await tx
          .insert(exams)
          .values({
            id,
            slug: dto.slug,
            name: dto.name.trim(),
            shortName: dto.short_name.trim(),
            instructions: dto.instructions ?? '',
            sortOrder: dto.sort_order ?? 0,
            isActive: false,
          })
          .returning();
        await this.audit.record(tx, actor, {
          action: 'exam.created',
          entityType: 'exam',
          entityId: id,
          data: { slug: dto.slug },
        });
        return toExamDto(row);
      });
    } catch (e) {
      if (isUniqueViolation(e))
        throw new ApiError(
          HttpStatus.CONFLICT,
          'exam_exists',
          `The ${dto.slug} exam already exists`,
        );
      throw e;
    }
  }

  async updateExam(
    actor: Actor,
    id: string,
    dto: UpdateExamDto,
  ): Promise<ExamDto> {
    return this.db.transaction(async (tx) => {
      const [current] = await tx
        .select()
        .from(exams)
        .where(eq(exams.id, id))
        .for('update')
        .limit(1);
      if (!current) throw ApiError.notFound('Exam');
      if (dto.is_active === true && !current.isActive) {
        const [published] = await tx
          .select({ id: examBlueprints.id })
          .from(examBlueprints)
          .where(
            and(
              eq(examBlueprints.examId, id),
              eq(examBlueprints.status, 'published'),
            ),
          )
          .limit(1);
        if (!published)
          throw new ApiError(
            HttpStatus.CONFLICT,
            'no_published_blueprint',
            'An exam needs a published blueprint before it can be switched on',
          );
      }
      const [row] = await tx
        .update(exams)
        .set({
          ...(dto.name !== undefined && { name: dto.name.trim() }),
          ...(dto.short_name !== undefined && {
            shortName: dto.short_name.trim(),
          }),
          ...(dto.instructions !== undefined && {
            instructions: dto.instructions,
          }),
          ...(dto.sort_order !== undefined && { sortOrder: dto.sort_order }),
          ...(dto.is_active !== undefined && { isActive: dto.is_active }),
          updatedAt: new Date(),
        })
        .where(eq(exams.id, id))
        .returning();
      await this.audit.record(tx, actor, {
        action: 'exam.updated',
        entityType: 'exam',
        entityId: id,
        data: {
          fields: Object.keys(dto),
          ...(dto.is_active !== undefined && {
            is_active: { from: current.isActive, to: dto.is_active },
          }),
        },
      });
      return toExamDto(row);
    });
  }

  // ---------------------------------------------------------------- blueprints

  async getBlueprint(id: string): Promise<BlueprintDto> {
    return this.blueprintDto(this.db, await this.loadBlueprint(this.db, id));
  }

  /** The first version of a new blueprint, as a draft. */
  async createBlueprint(
    actor: Actor,
    dto: CreateBlueprintDto,
  ): Promise<BlueprintDto> {
    const config = {
      configStatus: dto.config_status ?? 'unverified',
      configSource: dto.config_source?.trim() || null,
      configCheckedOn: dto.config_checked_on ?? null,
    } as const;
    const evidence = configEvidenceProblems(config);
    if (evidence.length) throw validation(evidence);
    try {
      return await this.db.transaction(async (tx) => {
        const [exam] = await tx
          .select({ id: exams.id })
          .from(exams)
          .where(eq(exams.id, dto.exam_id))
          .limit(1);
        if (!exam) throw ApiError.notFound('Exam');
        const id = newId();
        const [row] = await tx
          .insert(examBlueprints)
          .values({
            id,
            examId: dto.exam_id,
            code: dto.code,
            version: 1,
            status: 'draft',
            durationSeconds: dto.duration_seconds,
            totalQuestions: dto.total_questions,
            marksCorrect: fixed2(dto.marks_correct),
            negativeMarks: fixed2(dto.negative_marks ?? 0),
            marksUnanswered: fixed2(dto.marks_unanswered ?? 0),
            passPercentGeneral:
              dto.pass_percent_general == null
                ? null
                : fixed2(dto.pass_percent_general),
            passPercentReserved:
              dto.pass_percent_reserved == null
                ? null
                : fixed2(dto.pass_percent_reserved),
            sectionNavigation: dto.section_navigation ?? 'free',
            lawRegimeFilter: dto.law_regime_filter ?? 'any',
            ...config,
            createdBy: actor.id,
          })
          .returning();
        await this.audit.record(tx, actor, {
          action: 'exam_blueprint.created',
          entityType: 'exam_blueprint',
          entityId: id,
          data: { exam_id: dto.exam_id, code: dto.code, version: 1 },
        });
        return toBlueprintDto(row, []);
      });
    } catch (e) {
      if (isUniqueViolation(e))
        throw new ApiError(
          HttpStatus.CONFLICT,
          'blueprint_exists',
          `A blueprint with code ${dto.code} already exists for this exam; make a new version of it instead`,
        );
      throw e;
    }
  }

  async updateBlueprint(
    actor: Actor,
    id: string,
    dto: UpdateBlueprintDto,
  ): Promise<BlueprintDto> {
    return this.db.transaction(async (tx) => {
      const current = await this.lockDraft(tx, id);
      const merged = {
        configStatus: dto.config_status ?? current.configStatus,
        configSource:
          dto.config_source !== undefined
            ? dto.config_source?.trim() || null
            : current.configSource,
        configCheckedOn:
          dto.config_checked_on !== undefined
            ? dto.config_checked_on
            : current.configCheckedOn,
      };
      const evidence = configEvidenceProblems(merged);
      if (evidence.length) throw validation(evidence);
      const [row] = await tx
        .update(examBlueprints)
        .set({
          ...(dto.duration_seconds !== undefined && {
            durationSeconds: dto.duration_seconds,
          }),
          ...(dto.total_questions !== undefined && {
            totalQuestions: dto.total_questions,
          }),
          ...(dto.marks_correct !== undefined && {
            marksCorrect: fixed2(dto.marks_correct),
          }),
          ...(dto.negative_marks !== undefined && {
            negativeMarks: fixed2(dto.negative_marks),
          }),
          ...(dto.marks_unanswered !== undefined && {
            marksUnanswered: fixed2(dto.marks_unanswered),
          }),
          ...(dto.pass_percent_general !== undefined && {
            passPercentGeneral:
              dto.pass_percent_general === null
                ? null
                : fixed2(dto.pass_percent_general),
          }),
          ...(dto.pass_percent_reserved !== undefined && {
            passPercentReserved:
              dto.pass_percent_reserved === null
                ? null
                : fixed2(dto.pass_percent_reserved),
          }),
          ...(dto.section_navigation !== undefined && {
            sectionNavigation: dto.section_navigation,
          }),
          ...(dto.law_regime_filter !== undefined && {
            lawRegimeFilter: dto.law_regime_filter,
          }),
          ...merged,
          updatedAt: new Date(),
        })
        .where(eq(examBlueprints.id, id))
        .returning();
      await this.audit.record(tx, actor, {
        action: 'exam_blueprint.updated',
        entityType: 'exam_blueprint',
        entityId: id,
        data: { fields: Object.keys(dto) },
      });
      return this.blueprintDto(tx, row);
    });
  }

  /** Replaces all of a draft blueprint's sections and their topic quotas. */
  async replaceSections(
    actor: Actor,
    id: string,
    dto: ReplaceSectionsDto,
  ): Promise<BlueprintDto> {
    return this.db.transaction(async (tx) => {
      await this.lockDraft(tx, id);
      const topicIds = [
        ...new Set(
          dto.sections.flatMap((s) => s.topics.map((t) => t.topic_id)),
        ),
      ];
      if (topicIds.length) {
        const found = await tx
          .select({ id: topics.id })
          .from(topics)
          .where(inArray(topics.id, topicIds));
        const known = new Set(found.map((t) => t.id));
        const missing = topicIds.filter((t) => !known.has(t));
        if (missing.length)
          throw validation(
            missing.map((t) => ({
              field: 'sections',
              reason: `Unknown topic ${t}`,
            })),
          );
      }
      // Totals and quotas are checked when the blueprint is published, so a
      // draft can be built step by step; repeats are refused at once.
      const repeats = structureProblems(toDrafts(dto));
      if (repeats.length) throw validation(repeats);

      const old = await tx
        .select({ id: examSections.id })
        .from(examSections)
        .where(eq(examSections.blueprintId, id));
      if (old.length) {
        await tx.delete(examSectionTopics).where(
          inArray(
            examSectionTopics.sectionId,
            old.map((s) => s.id),
          ),
        );
        await tx.delete(examSections).where(eq(examSections.blueprintId, id));
      }
      for (const s of dto.sections) {
        const sectionId = newId();
        await tx.insert(examSections).values({
          id: sectionId,
          blueprintId: id,
          code: s.code,
          name: s.name.trim(),
          position: s.position,
          questionCount: s.question_count,
          durationSeconds: s.duration_seconds ?? null,
          marksCorrect:
            s.marks_correct == null ? null : fixed2(s.marks_correct),
        });
        if (s.topics.length)
          await tx.insert(examSectionTopics).values(
            s.topics.map((t) => ({
              sectionId,
              topicId: t.topic_id,
              minCount: t.min_count ?? 0,
              maxCount: t.max_count ?? null,
              weight: t.weight ?? 1,
            })),
          );
      }
      await tx
        .update(examBlueprints)
        .set({ updatedAt: new Date() })
        .where(eq(examBlueprints.id, id));
      await this.audit.record(tx, actor, {
        action: 'exam_blueprint.sections_replaced',
        entityType: 'exam_blueprint',
        entityId: id,
        data: { sections: dto.sections.length },
      });
      return this.blueprintDto(tx, await this.loadBlueprint(tx, id));
    });
  }

  /**
   * Publishes a draft. Its sections must add up to the blueprint's question
   * count with satisfiable topic quotas, in active topics, and an
   * official-confirmed blueprint must name its evidence. An unverified or
   * inferred blueprint may be published, but it stays practice-only.
   * Publishing never makes a blueprint "current" for anything.
   */
  async publishBlueprint(actor: Actor, id: string): Promise<BlueprintDto> {
    return this.db.transaction(async (tx) => {
      const bp = await this.lockDraft(tx, id);
      if (!isAdmin(actor) && bp.createdBy === actor.id)
        throw ApiError.forbidden('You cannot publish a blueprint you created');
      const loaded = await this.sectionsOf(tx, id);
      const problems: ErrorDetail[] = [
        ...configEvidenceProblems(bp),
        ...sectionProblems(
          bp,
          loaded.map(({ row, topics: ts }) => ({
            code: row.code,
            position: row.position,
            questionCount: row.questionCount,
            durationSeconds: row.durationSeconds,
            topics: ts.map((t) => ({
              topicId: t.topicId,
              minCount: t.minCount,
              maxCount: t.maxCount,
            })),
          })),
        ),
      ];
      const topicIds = [
        ...new Set(loaded.flatMap((s) => s.topics.map((t) => t.topicId))),
      ];
      if (topicIds.length) {
        const rows = await tx
          .select({
            id: topics.id,
            topicActive: topics.isActive,
            subjectActive: subjects.isActive,
          })
          .from(topics)
          .innerJoin(subjects, eq(subjects.id, topics.subjectId))
          .where(inArray(topics.id, topicIds));
        for (const r of rows)
          if (!r.topicActive || !r.subjectActive)
            problems.push({
              field: 'sections',
              reason: `Topic ${r.id} is inactive`,
            });
      }
      if (problems.length)
        throw new ApiError(
          HttpStatus.UNPROCESSABLE_ENTITY,
          'blueprint_incomplete',
          'The blueprint is not ready to publish',
          problems,
        );
      const [row] = await tx
        .update(examBlueprints)
        .set({ status: 'published', updatedAt: new Date() })
        .where(eq(examBlueprints.id, id))
        .returning();
      await this.audit.record(tx, actor, {
        action: 'exam_blueprint.published',
        entityType: 'exam_blueprint',
        entityId: id,
        data: {
          code: bp.code,
          version: bp.version,
          config_status: bp.configStatus,
          timed_allowed: timedModeVerdict(row).allowed,
        },
      });
      return this.blueprintDto(tx, row);
    });
  }

  async retireBlueprint(actor: Actor, id: string): Promise<BlueprintDto> {
    return this.db.transaction(async (tx) => {
      const [bp] = await tx
        .select()
        .from(examBlueprints)
        .where(eq(examBlueprints.id, id))
        .for('update')
        .limit(1);
      if (!bp) throw ApiError.notFound('Blueprint');
      if (bp.status !== 'published')
        throw ApiError.invalidTransition(
          'Only a published blueprint can be retired',
        );
      if (bp.isCurrent)
        throw new ApiError(
          HttpStatus.CONFLICT,
          'blueprint_is_current',
          "This is the exam's current blueprint; clear it as current before retiring it",
        );
      const [exam] = await tx
        .select()
        .from(exams)
        .where(eq(exams.id, bp.examId))
        .for('update')
        .limit(1);
      if (exam.isActive) {
        const others = await tx
          .select({ id: examBlueprints.id })
          .from(examBlueprints)
          .where(
            and(
              eq(examBlueprints.examId, bp.examId),
              eq(examBlueprints.status, 'published'),
            ),
          );
        if (others.length <= 1)
          throw new ApiError(
            HttpStatus.CONFLICT,
            'last_published_blueprint',
            'Switch the exam off before retiring its only published blueprint',
          );
      }
      const [row] = await tx
        .update(examBlueprints)
        .set({ status: 'retired', updatedAt: new Date() })
        .where(eq(examBlueprints.id, id))
        .returning();
      await this.audit.record(tx, actor, {
        action: 'exam_blueprint.retired',
        entityType: 'exam_blueprint',
        entityId: id,
        data: { code: bp.code, version: bp.version },
      });
      return this.blueprintDto(tx, row);
    });
  }

  /** A published or retired blueprint never changes; its next version starts as a copy, as a draft. */
  async newVersion(actor: Actor, id: string): Promise<BlueprintDto> {
    return this.db.transaction(async (tx) => {
      const source = await this.loadBlueprint(tx, id);
      if (source.status === 'draft')
        throw ApiError.invalidTransition(
          'A draft can be edited directly; make a new version of a published or retired blueprint',
        );
      const [latest] = await tx
        .select({ v: max(examBlueprints.version) })
        .from(examBlueprints)
        .where(
          and(
            eq(examBlueprints.examId, source.examId),
            eq(examBlueprints.code, source.code),
          ),
        );
      const newId_ = newId();
      const { id: _id, createdAt: _c, updatedAt: _u, ...rest } = source;
      await tx.insert(examBlueprints).values({
        ...rest,
        id: newId_,
        version: (latest?.v ?? source.version) + 1,
        status: 'draft',
        // A copy never inherits the "current" mark.
        isCurrent: false,
        createdBy: actor.id,
      });
      for (const s of await this.sectionsOf(tx, id)) {
        const sectionId = newId();
        await tx.insert(examSections).values({
          id: sectionId,
          blueprintId: newId_,
          code: s.row.code,
          name: s.row.name,
          position: s.row.position,
          questionCount: s.row.questionCount,
          durationSeconds: s.row.durationSeconds,
          marksCorrect: s.row.marksCorrect,
        });
        if (s.topics.length)
          await tx.insert(examSectionTopics).values(
            s.topics.map((t) => ({
              sectionId,
              topicId: t.topicId,
              minCount: t.minCount,
              maxCount: t.maxCount,
              weight: t.weight,
            })),
          );
      }
      await this.audit.record(tx, actor, {
        action: 'exam_blueprint.new_version',
        entityType: 'exam_blueprint',
        entityId: newId_,
        data: { from: id, code: source.code },
      });
      return this.blueprintDto(tx, await this.loadBlueprint(tx, newId_));
    });
  }

  /**
   * The blueprint and law-regime rule a pool check should use: the named
   * blueprint (which must be the exam's), or else the exam's current one.
   * With neither, the rule is 'any', which already keeps old-code-only
   * questions out of random mocks.
   */
  async lawRegimeFilterOf(
    examId: string,
    blueprintId?: string,
  ): Promise<{ blueprintId: string | null; filter: LawRegimeFilter }> {
    const [exam] = await this.db
      .select({ id: exams.id })
      .from(exams)
      .where(eq(exams.id, examId))
      .limit(1);
    if (!exam) throw ApiError.notFound('Exam');
    if (blueprintId) {
      const bp = await this.loadBlueprint(this.db, blueprintId);
      if (bp.examId !== examId) throw ApiError.notFound('Blueprint');
      return { blueprintId: bp.id, filter: bp.lawRegimeFilter };
    }
    const current = await this.currentBlueprint(this.db, examId);
    return current
      ? { blueprintId: current.id, filter: current.lawRegimeFilter }
      : { blueprintId: null, filter: 'any' };
  }

  // ---------------------------------------------------------------- the current blueprint

  /**
   * Designates a published blueprint as the one randomised mocks of its exam
   * use, replacing the exam's previous one. Nothing else does this: not
   * publishing, not making a new version. The change is audited.
   */
  async makeCurrent(actor: Actor, id: string): Promise<BlueprintDto> {
    return this.db.transaction(async (tx) => {
      const [bp] = await tx
        .select()
        .from(examBlueprints)
        .where(eq(examBlueprints.id, id))
        .for('update')
        .limit(1);
      if (!bp) throw ApiError.notFound('Blueprint');
      // One exam is changed at a time, so two requests cannot leave two current blueprints.
      await tx
        .select({ id: exams.id })
        .from(exams)
        .where(eq(exams.id, bp.examId))
        .for('update');
      if (bp.status !== 'published')
        throw new ApiError(
          HttpStatus.CONFLICT,
          'blueprint_not_published',
          `Only a published blueprint can be current; this one is ${bp.status}`,
        );
      if (bp.isCurrent)
        throw new ApiError(
          HttpStatus.CONFLICT,
          'already_current',
          "This blueprint is already the exam's current blueprint",
        );
      const previous = await this.currentBlueprint(tx, bp.examId);
      if (previous)
        await tx
          .update(examBlueprints)
          .set({ isCurrent: false, updatedAt: new Date() })
          .where(eq(examBlueprints.id, previous.id));
      const [row] = await tx
        .update(examBlueprints)
        .set({ isCurrent: true, updatedAt: new Date() })
        .where(eq(examBlueprints.id, id))
        .returning();
      await this.audit.record(tx, actor, {
        action: 'exam_blueprint.made_current',
        entityType: 'exam_blueprint',
        entityId: id,
        data: {
          exam_id: bp.examId,
          code: bp.code,
          version: bp.version,
          previous_blueprint_id: previous?.id ?? null,
        },
      });
      return this.blueprintDto(tx, row);
    });
  }

  /** Takes the current mark off a blueprint; the exam then has no current blueprint. Audited. */
  async clearCurrent(actor: Actor, id: string): Promise<BlueprintDto> {
    return this.db.transaction(async (tx) => {
      const [bp] = await tx
        .select()
        .from(examBlueprints)
        .where(eq(examBlueprints.id, id))
        .for('update')
        .limit(1);
      if (!bp) throw ApiError.notFound('Blueprint');
      if (!bp.isCurrent)
        throw new ApiError(
          HttpStatus.CONFLICT,
          'not_current',
          "This blueprint is not the exam's current blueprint",
        );
      const [row] = await tx
        .update(examBlueprints)
        .set({ isCurrent: false, updatedAt: new Date() })
        .where(eq(examBlueprints.id, id))
        .returning();
      await this.audit.record(tx, actor, {
        action: 'exam_blueprint.current_cleared',
        entityType: 'exam_blueprint',
        entityId: id,
        data: { exam_id: bp.examId, code: bp.code, version: bp.version },
      });
      return this.blueprintDto(tx, row);
    });
  }

  /**
   * The blueprint a randomised mock of [examId] must use. Mock creation calls
   * this, so an exam with no current blueprint is refused clearly instead of
   * guessing one.
   */
  async requireCurrentBlueprint(examId: string): Promise<BlueprintDto> {
    const [exam] = await this.db
      .select({ id: exams.id, slug: exams.slug })
      .from(exams)
      .where(eq(exams.id, examId))
      .limit(1);
    if (!exam) throw ApiError.notFound('Exam');
    const current = await this.currentBlueprint(this.db, examId);
    if (!current)
      throw new ApiError(
        HttpStatus.CONFLICT,
        'no_current_blueprint',
        `The ${exam.slug} exam has no current blueprint, so a randomised mock cannot be created`,
      );
    return this.blueprintDto(this.db, current);
  }

  private async currentBlueprint(
    tx: Tx,
    examId: string,
  ): Promise<BlueprintRow | null> {
    const [bp] = await tx
      .select()
      .from(examBlueprints)
      .where(
        and(
          eq(examBlueprints.examId, examId),
          eq(examBlueprints.isCurrent, true),
        ),
      )
      .limit(1);
    return bp ?? null;
  }

  /**
   * Throws unless the blueprint may be used for a timed mock. The attempt
   * code added in a later stage must call this before it starts one.
   */
  async assertTimedAllowed(blueprintId: string): Promise<void> {
    const bp = await this.loadBlueprint(this.db, blueprintId);
    const verdict = timedModeVerdict(bp);
    if (!verdict.allowed)
      throw new ApiError(
        HttpStatus.CONFLICT,
        'timed_mode_not_allowed',
        verdict.reason,
        [{ field: 'blueprint', reason: verdict.code }],
      );
  }

  // ---------------------------------------------------------------- helpers

  private async loadBlueprint(tx: Tx, id: string): Promise<BlueprintRow> {
    const [bp] = await tx
      .select()
      .from(examBlueprints)
      .where(eq(examBlueprints.id, id))
      .limit(1);
    if (!bp) throw ApiError.notFound('Blueprint');
    return bp;
  }

  /** Locks a blueprint for a change; only a draft may change. */
  private async lockDraft(tx: Tx, id: string): Promise<BlueprintRow> {
    const [bp] = await tx
      .select()
      .from(examBlueprints)
      .where(eq(examBlueprints.id, id))
      .for('update')
      .limit(1);
    if (!bp) throw ApiError.notFound('Blueprint');
    if (bp.status !== 'draft')
      throw new ApiError(
        HttpStatus.CONFLICT,
        'blueprint_not_draft',
        `A ${bp.status} blueprint cannot be changed; make a new version instead`,
      );
    return bp;
  }

  private async sectionsOf(tx: Tx, blueprintId: string) {
    const rows = await tx
      .select()
      .from(examSections)
      .where(eq(examSections.blueprintId, blueprintId))
      .orderBy(asc(examSections.position));
    const topicRows = rows.length
      ? await tx
          .select()
          .from(examSectionTopics)
          .where(
            inArray(
              examSectionTopics.sectionId,
              rows.map((r) => r.id),
            ),
          )
      : [];
    return rows.map((row) => ({
      row,
      topics: topicRows.filter((t) => t.sectionId === row.id),
    }));
  }

  private async blueprintDto(tx: Tx, b: BlueprintRow): Promise<BlueprintDto> {
    return toBlueprintDto(b, await this.sectionsOf(tx, b.id));
  }
}

const toDrafts = (dto: ReplaceSectionsDto): SectionDraft[] =>
  dto.sections.map((s) => ({
    code: s.code,
    position: s.position,
    questionCount: s.question_count,
    durationSeconds: s.duration_seconds ?? null,
    topics: s.topics.map((t) => ({
      topicId: t.topic_id,
      minCount: t.min_count ?? 0,
      maxCount: t.max_count ?? null,
    })),
  }));
