import { HttpStatus, Inject, Injectable } from '@nestjs/common';
import { and, asc, desc, eq, inArray, isNotNull, lt, lte } from 'drizzle-orm';
import { AuditService, type Actor } from '../core/audit.service.js';
import { DB, type Db, type Tx } from '../core/db.js';
import { ApiError, isUniqueViolation } from '../core/errors.js';
import { newId } from '../core/ids.js';
import { decodeCursor, toPage } from '../core/pagination.js';
import {
  examAttemptQuestions,
  examAttempts,
  examBlueprints,
  examPaperKeyHistory,
  examPaperQuestions,
  examPapers,
  exams,
  questionVersions,
  type PaperAnswerStatus,
} from '../db/schema.js';
import {
  answerSaveVerdict,
  computeResult,
  remainingSeconds,
  type AttemptResult,
} from './attempt-rules.js';
import { ExamsService } from './exams.service.js';
import { MockPlanService } from './mock-plan.service.js';
import { acceptedOptions } from './paper-rules.js';
import type {
  AttemptDto,
  AttemptPageDto,
  AttemptResultDto,
  AttemptStatsDto,
  ListAttemptsQuery,
  SaveAnswersDto,
  SaveAnswersResultDto,
  StartAttemptDto,
} from './attempts.dto.js';

type AttemptRow = typeof examAttempts.$inferSelect;

const num = (v: string | null): number | null =>
  v === null ? null : Number(v);
const fixed2 = (v: number | null): string | null =>
  v === null ? null : v.toFixed(2);
const iso = (d: Date | null) => (d ? d.toISOString() : null);

const closed = (a: AttemptRow) =>
  new ApiError(
    HttpStatus.CONFLICT,
    a.status === 'expired' ? 'attempt_expired' : 'attempt_submitted',
    a.status === 'expired'
      ? 'The time for this attempt has run out'
      : 'This attempt has already been submitted',
  );

const isExpired = (a: AttemptRow, now: Date) =>
  a.status === 'in_progress' &&
  a.deadlineAt !== null &&
  now.getTime() >= a.deadlineAt.getTime();

/** Formal exam attempts: start, answer, resume, submit, expire and score. */
@Injectable()
export class AttemptsService {
  constructor(
    @Inject(DB) private readonly db: Db,
    private readonly audit: AuditService,
    private readonly exams: ExamsService,
    private readonly plans: MockPlanService,
  ) {}

  // ---------------------------------------------------------------- start

  async start(
    actor: Actor,
    slug: string,
    dto: StartAttemptDto,
  ): Promise<AttemptDto> {
    const [exam] = await this.db
      .select()
      .from(exams)
      .where(and(eq(exams.slug, slug), eq(exams.isActive, true)))
      .limit(1);
    if (!exam) throw ApiError.notFound('Exam');

    // An unfinished attempt whose time ran out is finished first, so the
    // learner can start again instead of being blocked by it.
    const open = await this.openAttempt(this.db, actor.id, exam.id);
    if (open) {
      await this.finaliseIfExpired(open.id, 'expiry');
      const still = await this.openAttempt(this.db, actor.id, exam.id);
      if (still)
        throw new ApiError(
          HttpStatus.CONFLICT,
          'attempt_in_progress',
          'You already have an unfinished attempt for this exam',
          [{ field: 'attempt_id', reason: still.id }],
        );
    }

    const mode = dto.mode ?? 'practice';
    if (dto.practice_timer) {
      // A practice clock is its own thing: never with the official timed mode,
      // and only on a fixed paper that has one.
      if (mode === 'timed')
        throw new ApiError(
          HttpStatus.UNPROCESSABLE_ENTITY,
          'validation_failed',
          'The practice timer is for practice mode; the official timed mode cannot use it',
          [{ field: 'practice_timer', reason: 'Use mode practice' }],
        );
      if (dto.kind !== 'fixed_paper')
        throw new ApiError(
          HttpStatus.UNPROCESSABLE_ENTITY,
          'validation_failed',
          'The practice timer is only for a fixed paper',
          [{ field: 'practice_timer', reason: 'Use kind fixed_paper' }],
        );
    }
    const built =
      dto.kind === 'fixed_paper'
        ? await this.buildFixed(exam.id, dto, mode)
        : await this.buildRandom(actor.id, exam.id, dto, mode);

    const now = new Date();
    const attemptId = newId();
    // The clock: the official one for timed mode, or the paper's practice timer.
    const clockSeconds =
      mode === 'timed' ? built.durationSeconds : built.practiceTimerSeconds;
    try {
      await this.db.transaction(async (tx) => {
        await tx.insert(examAttempts).values({
          id: attemptId,
          userId: actor.id,
          examId: exam.id,
          kind: dto.kind,
          mode,
          paperId: built.paperId,
          paperRevision: built.paperRevision,
          blueprintId: built.blueprintId,
          language: built.language,
          seed: built.seed,
          algorithmVersion: built.algorithmVersion,
          startedAt: now,
          durationSeconds: clockSeconds,
          deadlineAt:
            clockSeconds !== null
              ? new Date(now.getTime() + clockSeconds * 1000)
              : null,
          sectionNavigation: built.sectionNavigation,
          currentSectionPosition:
            built.sectionNavigation === 'locked_order'
              ? Math.min(...built.questions.map((q) => q.sectionPosition ?? 1))
              : null,
          marksCorrect: fixed2(built.rules.marksCorrect),
          negativeMarks: fixed2(built.rules.negativeMarks),
          marksUnanswered: fixed2(built.rules.marksUnanswered),
          withdrawnPolicy: built.rules.withdrawnPolicy,
          withdrawnPolicyConfirmed: built.rules.withdrawnPolicyConfirmed,
          rulesVerified: built.rules.rulesVerified,
          passPercentGeneral: fixed2(built.rules.passPercentGeneral),
          passPercentReserved: fixed2(built.rules.passPercentReserved),
        });
        await tx.insert(examAttemptQuestions).values(
          built.questions.map((q) => ({
            id: newId(),
            attemptId,
            ...q,
            marksCorrect: fixed2(q.marksCorrect),
          })),
        );
        await this.audit.record(tx, actor, {
          action: 'exam_attempt.started',
          entityType: 'exam_attempt',
          entityId: attemptId,
          data: {
            kind: dto.kind,
            mode,
            paper_id: built.paperId,
            blueprint_id: built.blueprintId,
            positions: built.questions.length,
          },
        });
      });
    } catch (e) {
      if (isUniqueViolation(e)) {
        const winner = await this.openAttempt(this.db, actor.id, exam.id);
        throw new ApiError(
          HttpStatus.CONFLICT,
          'attempt_in_progress',
          'You already have an unfinished attempt for this exam',
          winner ? [{ field: 'attempt_id', reason: winner.id }] : undefined,
        );
      }
      throw e;
    }
    return this.view(this.db, attemptId);
  }

  /** The frozen content of a fixed-paper attempt, from its published revision. */
  private async buildFixed(
    examId: string,
    dto: StartAttemptDto,
    mode: 'practice' | 'timed',
  ): Promise<Built> {
    if (!dto.paper_id)
      throw new ApiError(
        HttpStatus.UNPROCESSABLE_ENTITY,
        'validation_failed',
        'paper_id is required for a fixed-paper attempt',
        [{ field: 'paper_id', reason: 'Required' }],
      );
    const [paper] = await this.db
      .select()
      .from(examPapers)
      .where(
        and(
          eq(examPapers.id, dto.paper_id),
          eq(examPapers.examId, examId),
          eq(examPapers.status, 'published'),
        ),
      )
      .limit(1);
    if (!paper) throw ApiError.notFound('Paper');

    const verified = paper.configStatus === 'official_confirmed';
    if (dto.practice_timer && paper.practiceTimerSeconds === null)
      throw new ApiError(
        HttpStatus.CONFLICT,
        'practice_timer_not_available',
        'This paper has no practice timer',
      );
    if (mode === 'timed') {
      if (paper.durationSeconds === null || !verified)
        throw new ApiError(
          HttpStatus.CONFLICT,
          'timed_mode_not_allowed',
          paper.durationSeconds === null
            ? 'This paper has no confirmed duration, so it can only be taken in practice mode'
            : 'The rules of this paper are not officially confirmed, so it can only be taken in practice mode',
        );
    }

    const rows = await this.db
      .select({ pq: examPaperQuestions, v: questionVersions })
      .from(examPaperQuestions)
      .leftJoin(
        questionVersions,
        eq(questionVersions.id, examPaperQuestions.questionVersionId),
      )
      .where(eq(examPaperQuestions.paperId, paper.id))
      .orderBy(asc(examPaperQuestions.position));
    const keys = await this.db
      .select()
      .from(examPaperKeyHistory)
      .where(eq(examPaperKeyHistory.paperId, paper.id))
      .orderBy(asc(examPaperKeyHistory.createdAt), asc(examPaperKeyHistory.id));

    // Pass criteria come only from a confirmed, published blueprint.
    let passGeneral: number | null = null;
    let passReserved: number | null = null;
    if (paper.blueprintId) {
      const [bp] = await this.db
        .select()
        .from(examBlueprints)
        .where(eq(examBlueprints.id, paper.blueprintId))
        .limit(1);
      if (
        bp &&
        bp.status === 'published' &&
        bp.configStatus === 'official_confirmed'
      ) {
        passGeneral = num(bp.passPercentGeneral);
        passReserved = num(bp.passPercentReserved);
      }
    }

    return {
      paperId: paper.id,
      paperRevision: paper.revision,
      blueprintId: paper.blueprintId,
      language: 'en',
      seed: null,
      algorithmVersion: null,
      durationSeconds: paper.durationSeconds,
      practiceTimerSeconds: dto.practice_timer
        ? paper.practiceTimerSeconds
        : null,
      sectionNavigation: 'free',
      rules: {
        marksCorrect: num(paper.marksCorrect),
        negativeMarks: num(paper.negativeMarks),
        marksUnanswered: num(paper.marksUnanswered),
        withdrawnPolicy: paper.withdrawnPolicy,
        withdrawnPolicyConfirmed: paper.withdrawnPolicyConfirmed,
        rulesVerified: verified,
        passPercentGeneral: passGeneral,
        passPercentReserved: passReserved,
      },
      questions: rows.map(({ pq, v }) => {
        const history = keys.filter((k) => k.paperQuestionId === pq.id);
        const latest = history.length ? history[history.length - 1] : null;
        return {
          position: pq.position,
          sectionCode: null,
          sectionPosition: null,
          questionId: pq.questionId,
          questionVersionId: pq.questionVersionId,
          topicId: v?.topicId ?? null,
          answerStatus: pq.answerStatus,
          questionType: v?.questionType ?? 'single_select',
          optionOrder: v
            ? (pq.optionOrder ?? v.options.map((o) => o.id))
            : null,
          originalRef: pq.originalRef,
          originalLabelScheme: pq.originalLabelScheme,
          acceptedOptionIds: acceptedOptions({
            answerStatus: pq.answerStatus,
            versionCorrect: v?.correctOptionIds ?? [],
            versionAlternates: v?.alternateCorrectOptionIds ?? [],
            latestKey: latest
              ? {
                  kind: latest.kind,
                  acceptedOptionIds: latest.acceptedOptionIds,
                }
              : null,
          }),
          marksCorrect: null,
        };
      }),
    };
  }

  /** A random mock built by the Stage 3 engine and frozen as it was generated. */
  private async buildRandom(
    userId: string,
    examId: string,
    dto: StartAttemptDto,
    mode: 'practice' | 'timed',
  ): Promise<Built> {
    const language = dto.language ?? 'en';
    const seen = await this.seenQuestionIds(userId, examId);
    const plan = await this.plans.generate(examId, {
      language,
      seen_question_ids: seen,
    });
    const bp = await this.exams.getBlueprint(plan.blueprint_id);
    if (mode === 'timed') await this.exams.assertTimedAllowed(bp.id);

    const versionIds = plan.sections.flatMap((s) =>
      s.questions.map((q) => q.version_id),
    );
    const versions = new Map(
      (
        await this.db
          .select()
          .from(questionVersions)
          .where(inArray(questionVersions.id, versionIds))
      ).map((v) => [v.id, v]),
    );
    const sectionMeta = new Map(bp.sections.map((s) => [s.code, s]));

    const questions: Built['questions'] = [];
    let position = 0;
    for (const section of [...plan.sections].sort(
      (a, b) => a.position - b.position,
    )) {
      const meta = sectionMeta.get(section.code)!;
      for (const q of section.questions) {
        const v = versions.get(q.version_id)!;
        const status: PaperAnswerStatus =
          v.alternateCorrectOptionIds.length > 0 ||
          v.correctOptionIds.length > 1
            ? 'multi_accepted'
            : 'keyed';
        questions.push({
          position: ++position,
          sectionCode: section.code,
          sectionPosition: section.position,
          questionId: q.question_id,
          questionVersionId: q.version_id,
          topicId: q.topic_id,
          answerStatus: status,
          questionType: v.questionType,
          optionOrder: q.option_order,
          originalRef: null,
          originalLabelScheme: null,
          acceptedOptionIds: [
            ...new Set([...v.correctOptionIds, ...v.alternateCorrectOptionIds]),
          ],
          marksCorrect: meta.marks_correct ?? bp.marks_correct,
        });
      }
    }

    return {
      paperId: null,
      paperRevision: null,
      blueprintId: bp.id,
      language,
      seed: plan.seed,
      algorithmVersion: plan.algorithm_version,
      durationSeconds: bp.duration_seconds,
      practiceTimerSeconds: null,
      sectionNavigation: bp.section_navigation as 'free' | 'locked_order',
      rules: {
        marksCorrect: bp.marks_correct,
        negativeMarks: bp.negative_marks,
        marksUnanswered: bp.marks_unanswered,
        withdrawnPolicy: 'unscored',
        withdrawnPolicyConfirmed: false,
        rulesVerified: bp.config_status === 'official_confirmed',
        passPercentGeneral: bp.pass_percent_general,
        passPercentReserved: bp.pass_percent_reserved,
      },
      questions,
    };
  }

  /** Questions the learner met in earlier, finished attempts at this exam. */
  private async seenQuestionIds(
    userId: string,
    examId: string,
  ): Promise<string[]> {
    const rows = await this.db
      .selectDistinct({ id: examAttemptQuestions.questionId })
      .from(examAttemptQuestions)
      .innerJoin(
        examAttempts,
        eq(examAttempts.id, examAttemptQuestions.attemptId),
      )
      .where(
        and(
          eq(examAttempts.userId, userId),
          eq(examAttempts.examId, examId),
          inArray(examAttempts.status, ['submitted', 'expired']),
          isNotNull(examAttemptQuestions.questionId),
        ),
      )
      .limit(5000);
    return rows.map((r) => r.id!);
  }

  // ---------------------------------------------------------------- read

  async active(userId: string, slug: string): Promise<AttemptDto> {
    const [exam] = await this.db
      .select({ id: exams.id })
      .from(exams)
      .where(eq(exams.slug, slug))
      .limit(1);
    if (!exam) throw ApiError.notFound('Exam');
    const open = await this.openAttempt(this.db, userId, exam.id);
    if (open) await this.finaliseIfExpired(open.id, 'expiry');
    const still = open && (await this.openAttempt(this.db, userId, exam.id));
    if (!still)
      throw new ApiError(
        HttpStatus.NOT_FOUND,
        'no_active_attempt',
        'You have no unfinished attempt for this exam',
      );
    return this.view(this.db, still.id);
  }

  async get(userId: string, id: string): Promise<AttemptDto> {
    await this.owned(this.db, userId, id);
    await this.finaliseIfExpired(id, 'expiry');
    return this.view(this.db, id);
  }

  async result(userId: string, id: string): Promise<AttemptResultDto> {
    await this.owned(this.db, userId, id);
    await this.finaliseIfExpired(id, 'expiry');
    const a = await this.owned(this.db, userId, id);
    return this.resultOf(a);
  }

  /** The full answer review: keys and explanations, only after finalisation. */
  async review(userId: string, id: string) {
    await this.owned(this.db, userId, id);
    await this.finaliseIfExpired(id, 'expiry');
    const a = await this.owned(this.db, userId, id);
    if (a.status === 'in_progress')
      throw new ApiError(
        HttpStatus.CONFLICT,
        'attempt_in_progress',
        'The answer review is available once the attempt is submitted',
      );
    const result = a.result as unknown as AttemptResult;
    const outcomes = new Map(result.positions.map((p) => [p.position, p]));
    const rows = await this.db
      .select({ q: examAttemptQuestions, v: questionVersions })
      .from(examAttemptQuestions)
      .leftJoin(
        questionVersions,
        eq(questionVersions.id, examAttemptQuestions.questionVersionId),
      )
      .where(eq(examAttemptQuestions.attemptId, id))
      .orderBy(asc(examAttemptQuestions.position));
    return {
      attempt_id: a.id,
      provisional: result.provisional,
      provisional_reasons: result.provisional_reasons,
      questions: rows.map(({ q, v }) => {
        const byId = new Map((v?.options ?? []).map((o) => [o.id, o]));
        const o = outcomes.get(q.position)!;
        return {
          position: q.position,
          section_code: q.sectionCode,
          original_ref: q.originalRef,
          withdrawn: q.answerStatus === 'withdrawn',
          question_version_id: q.questionVersionId,
          stem: v?.stem ?? null,
          options: v
            ? (q.optionOrder ?? []).map((oid) => ({
                id: oid,
                text: byId.get(oid)?.text ?? '',
              }))
            : null,
          selected_option_ids: q.selectedOptionIds,
          accepted_option_ids: q.acceptedOptionIds,
          outcome: o.outcome,
          marks: o.marks,
          explanation: v?.explanation ?? null,
        };
      }),
    };
  }

  async history(
    userId: string,
    query: ListAttemptsQuery,
  ): Promise<AttemptPageDto> {
    await this.settleOverdue(userId);

    const limit = query.limit ?? 20;
    const after = decodeCursor(query.cursor);
    const rows = await this.db
      .select({ a: examAttempts, slug: exams.slug, title: examPapers.title })
      .from(examAttempts)
      .innerJoin(exams, eq(exams.id, examAttempts.examId))
      .leftJoin(examPapers, eq(examPapers.id, examAttempts.paperId))
      .where(
        and(
          eq(examAttempts.userId, userId),
          query.exam ? eq(exams.slug, query.exam) : undefined,
          query.status ? eq(examAttempts.status, query.status) : undefined,
          after ? lt(examAttempts.id, after) : undefined,
        ),
      )
      .orderBy(desc(examAttempts.id))
      .limit(limit + 1);
    return toPage(
      rows.map((r) => ({ id: r.a.id, ...r })),
      limit,
      ({ a, slug, title }) => {
        const r = a.result as unknown as AttemptResult | null;
        return {
          id: a.id,
          kind: a.kind,
          mode: a.mode,
          status: a.status,
          exam: slug,
          paper_title: title ?? null,
          started_at: a.startedAt.toISOString(),
          submitted_at: iso(a.submittedAt),
          marks_obtained: r?.overall.marks_obtained ?? null,
          max_marks: r?.overall.max_marks ?? null,
          percentage: r?.overall.percentage ?? null,
          provisional: r ? r.provisional : null,
        };
      },
    );
  }

  /** Finishes the learner's unfinished attempts whose time has run out, so what they read is true. */
  private async settleOverdue(userId: string) {
    const open = await this.db
      .select({ id: examAttempts.id })
      .from(examAttempts)
      .where(
        and(
          eq(examAttempts.userId, userId),
          eq(examAttempts.status, 'in_progress'),
        ),
      );
    for (const o of open) await this.finaliseIfExpired(o.id, 'expiry');
  }

  async stats(userId: string): Promise<AttemptStatsDto> {
    await this.settleOverdue(userId);
    const rows = await this.db
      .select({ a: examAttempts, slug: exams.slug })
      .from(examAttempts)
      .innerJoin(exams, eq(exams.id, examAttempts.examId))
      .where(
        and(
          eq(examAttempts.userId, userId),
          inArray(examAttempts.status, ['submitted', 'expired']),
        ),
      );
    const by = new Map<string, typeof rows>();
    for (const r of rows) by.set(r.slug, [...(by.get(r.slug) ?? []), r]);
    return {
      exams: [...by.entries()].map(([exam, list]) => {
        const pcts = list
          .map(
            (r) => (r.a.result as unknown as AttemptResult).overall.percentage,
          )
          .filter((p): p is number => p !== null);
        const last = list.reduce<Date | null>(
          (m, r) =>
            !m || (r.a.submittedAt && r.a.submittedAt > m)
              ? r.a.submittedAt
              : m,
          null,
        );
        return {
          exam,
          attempts: list.length,
          with_marks: pcts.length,
          average_percentage: pcts.length
            ? Math.round(
                (pcts.reduce((a, b) => a + b, 0) / pcts.length) * 100,
              ) / 100
            : null,
          best_percentage: pcts.length ? Math.max(...pcts) : null,
          last_attempt_at: iso(last),
        };
      }),
    };
  }

  // ---------------------------------------------------------------- answers

  async saveAnswers(
    userId: string,
    id: string,
    dto: SaveAnswersDto,
  ): Promise<SaveAnswersResultDto> {
    await this.owned(this.db, userId, id);
    // Settle expiry in its own transaction so it is kept even though the save is refused.
    await this.finaliseIfExpired(id, 'expiry');

    return this.db.transaction(async (tx) => {
      const a = await this.lock(tx, userId, id);
      if (a.status !== 'in_progress') throw closed(a);
      const now = new Date();
      if (isExpired(a, now)) throw closed({ ...a, status: 'expired' });

      const positions = [...new Set(dto.answers.map((x) => x.position))];
      if (positions.length !== dto.answers.length)
        throw new ApiError(
          HttpStatus.UNPROCESSABLE_ENTITY,
          'validation_failed',
          'A position appears more than once in the request',
          [{ field: 'answers', reason: 'Duplicate position' }],
        );
      const rows = await tx
        .select()
        .from(examAttemptQuestions)
        .where(
          and(
            eq(examAttemptQuestions.attemptId, id),
            inArray(examAttemptQuestions.position, positions),
          ),
        );
      const byPos = new Map(rows.map((r) => [r.position, r]));

      // Check everything first: a request is applied whole or not at all.
      for (const ans of dto.answers) {
        const q = byPos.get(ans.position);
        const field = `answers[position=${ans.position}]`;
        if (!q)
          throw this.invalid(
            field,
            'There is no such position in this attempt',
          );
        if (q.answerStatus === 'withdrawn')
          throw this.invalid(field, 'A withdrawn position cannot be answered');
        const ids = q.optionOrder ?? [];
        if (ans.selected_option_ids.some((o) => !ids.includes(o)))
          throw this.invalid(
            field,
            'An option is not one of this question’s options',
          );
        if (
          new Set(ans.selected_option_ids).size !==
          ans.selected_option_ids.length
        )
          throw this.invalid(field, 'An option is listed more than once');
        if (
          q.questionType === 'single_select' &&
          ans.selected_option_ids.length > 1
        )
          throw this.invalid(field, 'Choose only one option');
        if (
          a.sectionNavigation === 'locked_order' &&
          q.sectionPosition !== a.currentSectionPosition
        )
          throw new ApiError(
            HttpStatus.CONFLICT,
            'section_locked',
            'Answers can only be saved in the current section',
            [{ field, reason: 'Section is locked' }],
          );
      }

      const results: SaveAnswersResultDto['results'] = [];
      for (const ans of dto.answers) {
        const q = byPos.get(ans.position)!;
        const incoming = {
          seq: ans.seq,
          selected: ans.selected_option_ids.length
            ? ans.selected_option_ids
            : null,
        };
        const verdict = answerSaveVerdict(
          { seq: q.answerSeq, selected: q.selectedOptionIds },
          incoming,
        );
        if (verdict.apply) {
          // The WHERE keeps even a concurrent writer from lowering the counter.
          const updated = await tx
            .update(examAttemptQuestions)
            .set({
              selectedOptionIds: incoming.selected,
              answerSeq: ans.seq,
              answeredAt: now,
            })
            .where(
              and(
                eq(examAttemptQuestions.id, q.id),
                lt(examAttemptQuestions.answerSeq, ans.seq),
              ),
            )
            .returning({ id: examAttemptQuestions.id });
          results.push({
            position: ans.position,
            applied: updated.length === 1,
            reason: updated.length === 1 ? null : 'stale',
            selected_option_ids:
              updated.length === 1 ? incoming.selected : q.selectedOptionIds,
            seq: updated.length === 1 ? ans.seq : q.answerSeq,
          });
        } else {
          results.push({
            position: ans.position,
            applied: false,
            reason: verdict.reason,
            selected_option_ids: q.selectedOptionIds,
            seq: q.answerSeq,
          });
        }
      }
      await tx
        .update(examAttempts)
        .set({ updatedAt: now })
        .where(eq(examAttempts.id, id));
      return {
        attempt_id: id,
        server_now: now.toISOString(),
        deadline_at: iso(a.deadlineAt),
        remaining_seconds: remainingSeconds(a.deadlineAt, now),
        results,
      };
    });
  }

  /** Locked-order blueprints: moves on to the next section; the earlier one is then closed. */
  async advanceSection(userId: string, id: string): Promise<AttemptDto> {
    await this.owned(this.db, userId, id);
    await this.finaliseIfExpired(id, 'expiry');
    await this.db.transaction(async (tx) => {
      const a = await this.lock(tx, userId, id);
      if (a.status !== 'in_progress') throw closed(a);
      if (a.sectionNavigation !== 'locked_order')
        throw new ApiError(
          HttpStatus.CONFLICT,
          'not_locked_order',
          'This attempt lets you move between sections freely',
        );
      const sections = await tx
        .selectDistinct({ p: examAttemptQuestions.sectionPosition })
        .from(examAttemptQuestions)
        .where(eq(examAttemptQuestions.attemptId, id));
      const order = sections
        .map((s) => s.p)
        .filter((p): p is number => p !== null)
        .sort((x, y) => x - y);
      const next = order.find((p) => p > (a.currentSectionPosition ?? 0));
      if (next === undefined)
        throw new ApiError(
          HttpStatus.CONFLICT,
          'last_section',
          'This is already the last section; submit the attempt instead',
        );
      await tx
        .update(examAttempts)
        .set({ currentSectionPosition: next, updatedAt: new Date() })
        .where(eq(examAttempts.id, id));
    });
    return this.view(this.db, id);
  }

  // ---------------------------------------------------------------- finishing

  /** Submits the attempt. Repeating it returns the same result. */
  async submit(actor: Actor, id: string): Promise<AttemptResultDto> {
    await this.owned(this.db, actor.id, id);
    await this.db.transaction(async (tx) => {
      const a = await this.lock(tx, actor.id, id);
      if (a.status !== 'in_progress') return; // already finished: idempotent
      const by = isExpired(a, new Date()) ? 'expiry' : 'learner';
      await this.finalise(tx, a, by, actor);
    });
    return this.resultOf(await this.owned(this.db, actor.id, id));
  }

  /**
   * Finishes an attempt whose deadline has passed. Safe to call any number of
   * times, at once: the row is locked and only an in-progress attempt changes.
   */
  async finaliseIfExpired(
    id: string,
    by: 'expiry' | 'sweep',
    now = new Date(),
  ): Promise<boolean> {
    return this.db.transaction(async (tx) => {
      const [a] = await tx
        .select()
        .from(examAttempts)
        .where(eq(examAttempts.id, id))
        .for('update')
        .limit(1);
      if (!a || !isExpired(a, now)) return false;
      await this.finalise(tx, a, by, null);
      return true;
    });
  }

  /** The low-frequency sweep: finishes every overdue attempt. Returns how many. */
  async sweepExpired(now = new Date(), limit = 200): Promise<number> {
    const due = await this.db
      .select({ id: examAttempts.id })
      .from(examAttempts)
      .where(
        and(
          eq(examAttempts.status, 'in_progress'),
          lte(examAttempts.deadlineAt, now),
        ),
      )
      .orderBy(asc(examAttempts.deadlineAt))
      .limit(limit);
    let n = 0;
    for (const d of due)
      if (await this.finaliseIfExpired(d.id, 'sweep', now)) n++;
    return n;
  }

  /** Scores and closes an attempt; the caller holds the row lock. */
  private async finalise(
    tx: Tx,
    a: AttemptRow,
    by: 'learner' | 'expiry' | 'sweep',
    actor: Actor | null,
  ) {
    const rows = await tx
      .select()
      .from(examAttemptQuestions)
      .where(eq(examAttemptQuestions.attemptId, a.id));
    const result = computeResult(
      {
        marksCorrect: num(a.marksCorrect),
        negativeMarks: num(a.negativeMarks),
        marksUnanswered: num(a.marksUnanswered),
        withdrawnPolicy: a.withdrawnPolicy,
        withdrawnPolicyConfirmed: a.withdrawnPolicyConfirmed,
        rulesVerified: a.rulesVerified,
        passPercentGeneral: num(a.passPercentGeneral),
        passPercentReserved: num(a.passPercentReserved),
      },
      rows.map((q) => ({
        position: q.position,
        sectionCode: q.sectionCode,
        sectionPosition: q.sectionPosition,
        answerStatus: q.answerStatus,
        questionType: q.questionType,
        accepted: q.acceptedOptionIds,
        marksCorrect: num(q.marksCorrect),
        selected: q.selectedOptionIds,
      })),
    );
    const now = new Date();
    const expired = by !== 'learner';
    const updated = await tx
      .update(examAttempts)
      .set({
        status: expired ? 'expired' : 'submitted',
        // An expired attempt ended at its deadline, whenever it was noticed.
        submittedAt: expired && a.deadlineAt ? a.deadlineAt : now,
        finalisedBy: by,
        result: result as unknown as Record<string, unknown>,
        updatedAt: now,
      })
      .where(
        and(eq(examAttempts.id, a.id), eq(examAttempts.status, 'in_progress')),
      )
      .returning({ id: examAttempts.id });
    if (updated.length === 0) return;
    await this.audit.record(tx, actor, {
      action: expired ? 'exam_attempt.expired' : 'exam_attempt.submitted',
      entityType: 'exam_attempt',
      entityId: a.id,
      data: {
        finalised_by: by,
        marks_obtained: result.overall.marks_obtained,
        provisional: result.provisional,
      },
    });
  }

  private resultOf(a: AttemptRow): AttemptResultDto {
    if (a.status === 'in_progress' || !a.result || !a.submittedAt)
      throw new ApiError(
        HttpStatus.CONFLICT,
        'attempt_in_progress',
        'Results are available once the attempt is submitted',
      );
    return {
      attempt_id: a.id,
      status: a.status,
      finalised_by: a.finalisedBy ?? 'learner',
      submitted_at: a.submittedAt.toISOString(),
      result: a.result,
    };
  }

  // ---------------------------------------------------------------- helpers

  private invalid(field: string, reason: string) {
    return new ApiError(
      HttpStatus.UNPROCESSABLE_ENTITY,
      'invalid_answer',
      'The answers cannot be saved',
      [{ field, reason }],
    );
  }

  private async openAttempt(tx: Tx | Db, userId: string, examId: string) {
    const [a] = await tx
      .select()
      .from(examAttempts)
      .where(
        and(
          eq(examAttempts.userId, userId),
          eq(examAttempts.examId, examId),
          eq(examAttempts.status, 'in_progress'),
        ),
      )
      .limit(1);
    return a ?? null;
  }

  /** The attempt if it belongs to the learner; anyone else's is simply not found. */
  private async owned(
    tx: Tx | Db,
    userId: string,
    id: string,
  ): Promise<AttemptRow> {
    const [a] = await tx
      .select()
      .from(examAttempts)
      .where(and(eq(examAttempts.id, id), eq(examAttempts.userId, userId)))
      .limit(1);
    if (!a) throw ApiError.notFound('Attempt');
    return a;
  }

  private async lock(tx: Tx, userId: string, id: string): Promise<AttemptRow> {
    const [a] = await tx
      .select()
      .from(examAttempts)
      .where(and(eq(examAttempts.id, id), eq(examAttempts.userId, userId)))
      .for('update')
      .limit(1);
    if (!a) throw ApiError.notFound('Attempt');
    return a;
  }

  /** What a learner may see of an attempt: questions and their own answers, never keys. */
  private async view(tx: Tx | Db, id: string): Promise<AttemptDto> {
    const [row] = await tx
      .select({ a: examAttempts, slug: exams.slug, paper: examPapers })
      .from(examAttempts)
      .innerJoin(exams, eq(exams.id, examAttempts.examId))
      .leftJoin(examPapers, eq(examPapers.id, examAttempts.paperId))
      .where(eq(examAttempts.id, id))
      .limit(1);
    if (!row) throw ApiError.notFound('Attempt');
    const { a } = row;
    const qs = await tx
      .select({
        position: examAttemptQuestions.position,
        sectionCode: examAttemptQuestions.sectionCode,
        sectionPosition: examAttemptQuestions.sectionPosition,
        originalRef: examAttemptQuestions.originalRef,
        answerStatus: examAttemptQuestions.answerStatus,
        optionOrder: examAttemptQuestions.optionOrder,
        selected: examAttemptQuestions.selectedOptionIds,
        seq: examAttemptQuestions.answerSeq,
        versionId: examAttemptQuestions.questionVersionId,
        stem: questionVersions.stem,
        options: questionVersions.options,
      })
      .from(examAttemptQuestions)
      .leftJoin(
        questionVersions,
        eq(questionVersions.id, examAttemptQuestions.questionVersionId),
      )
      .where(eq(examAttemptQuestions.attemptId, id))
      .orderBy(asc(examAttemptQuestions.position));

    const sections = new Map<
      string,
      { code: string; position: number; question_count: number }
    >();
    for (const q of qs)
      if (q.sectionCode !== null && q.sectionPosition !== null) {
        const s = sections.get(q.sectionCode) ?? {
          code: q.sectionCode,
          position: q.sectionPosition,
          question_count: 0,
        };
        s.question_count++;
        sections.set(q.sectionCode, s);
      }
    const now = new Date();
    return {
      id: a.id,
      kind: a.kind,
      mode: a.mode,
      status: a.status,
      exam: row.slug,
      paper: row.paper
        ? {
            id: row.paper.id,
            code: row.paper.code,
            title: row.paper.title,
            revision: row.paper.revision,
          }
        : null,
      language: a.language,
      started_at: a.startedAt.toISOString(),
      deadline_at: iso(a.deadlineAt),
      server_now: now.toISOString(),
      remaining_seconds:
        a.status === 'in_progress' ? remainingSeconds(a.deadlineAt, now) : 0,
      section_navigation: a.sectionNavigation,
      current_section_position: a.currentSectionPosition,
      sections: [...sections.values()].sort((x, y) => x.position - y.position),
      total_questions: qs.length,
      answered_count: qs.filter((q) => q.selected && q.selected.length > 0)
        .length,
      submitted_at: iso(a.submittedAt),
      result_available: a.status !== 'in_progress',
      questions: qs.map((q) => {
        const withdrawn = q.answerStatus === 'withdrawn';
        const byId = new Map((q.options ?? []).map((o) => [o.id, o]));
        return {
          position: q.position,
          section_code: q.sectionCode,
          original_ref: q.originalRef,
          withdrawn,
          question_version_id: q.versionId,
          stem: withdrawn ? null : q.stem,
          options: withdrawn
            ? null
            : (q.optionOrder ?? []).map((oid) => ({
                id: oid,
                text: byId.get(oid)?.text ?? '',
              })),
          selected_option_ids: q.selected,
          answer_seq: q.seq,
        };
      }),
    };
  }
}

interface Built {
  paperId: string | null;
  paperRevision: number | null;
  blueprintId: string | null;
  language: string;
  seed: string | null;
  algorithmVersion: number | null;
  durationSeconds: number | null;
  /** Set only when a learner chose the paper's practice timer. */
  practiceTimerSeconds: number | null;
  sectionNavigation: 'free' | 'locked_order';
  rules: {
    marksCorrect: number | null;
    negativeMarks: number | null;
    marksUnanswered: number | null;
    withdrawnPolicy: 'unscored' | 'award_all';
    withdrawnPolicyConfirmed: boolean;
    rulesVerified: boolean;
    passPercentGeneral: number | null;
    passPercentReserved: number | null;
  };
  questions: {
    position: number;
    sectionCode: string | null;
    sectionPosition: number | null;
    questionId: string | null;
    questionVersionId: string | null;
    topicId: string | null;
    answerStatus: PaperAnswerStatus;
    questionType: string;
    optionOrder: string[] | null;
    originalRef: string | null;
    originalLabelScheme: string | null;
    acceptedOptionIds: string[];
    marksCorrect: number | null;
  }[];
}
