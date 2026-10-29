import { HttpStatus, Inject, Injectable } from '@nestjs/common';
import {
  aliasedTable,
  and,
  asc,
  desc,
  eq,
  isNotNull,
  isNull,
  sql,
  type SQL,
} from 'drizzle-orm';
import { AuditService, type Actor } from '../core/audit.service.js';
import { DB, type Db } from '../core/db.js';
import { ApiError } from '../core/errors.js';
import { newId } from '../core/ids.js';
import {
  contentReports,
  questionVersions,
  quizSessionQuestions,
  quizSessions,
  users,
} from '../db/schema.js';
import type {
  CreateReportDto,
  ListReportsQuery,
  ReportDto,
  ReportListDto,
  ReportReceiptDto,
  ResolveReportDto,
} from './reports.dto.js';

/** Reports a learner may send in one India day. */
export const DAILY_REPORT_LIMIT = 20;
const URGENT = new Set(['wrong_answer', 'outdated_law']);

/**
 * Learner reports about questions, and the staff queue. A report never
 * changes content: staff revise or retire the question through the normal
 * workflow, then close the report here (audit-logged).
 */
@Injectable()
export class ReportsService {
  constructor(
    @Inject(DB) private readonly db: Db,
    private readonly audit: AuditService,
  ) {}

  async create(
    userId: string,
    dto: CreateReportDto,
  ): Promise<ReportReceiptDto> {
    return this.db.transaction(async (tx) => {
      // Only a version this learner was shown can be reported.
      const [shown] = await tx
        .select({ id: quizSessionQuestions.questionVersionId })
        .from(quizSessionQuestions)
        .innerJoin(
          quizSessions,
          eq(quizSessions.id, quizSessionQuestions.sessionId),
        )
        .where(
          and(
            eq(quizSessions.userId, userId),
            eq(quizSessionQuestions.questionVersionId, dto.question_version_id),
          ),
        )
        .limit(1);
      if (!shown) throw ApiError.notFound('Question you were shown');

      const [today] = await tx
        .select({ n: sql<number>`count(*)` })
        .from(contentReports)
        .where(
          and(
            eq(contentReports.userId, userId),
            sql`(${contentReports.createdAt} at time zone 'Asia/Kolkata')::date = (now() at time zone 'Asia/Kolkata')::date`,
          ),
        );
      if (Number(today.n) >= DAILY_REPORT_LIMIT)
        throw new ApiError(
          HttpStatus.TOO_MANY_REQUESTS,
          'report_limit',
          'You have sent the most reports for today',
        );

      const id = newId();
      const [row] = await tx
        .insert(contentReports)
        .values({
          id,
          userId,
          questionVersionId: dto.question_version_id,
          reason: dto.reason,
          comment: dto.comment || null,
        })
        .onConflictDoNothing()
        .returning({
          id: contentReports.id,
          createdAt: contentReports.createdAt,
        });
      if (!row)
        throw new ApiError(
          HttpStatus.CONFLICT,
          'already_reported',
          'You already reported this question; staff will look at it',
        );
      return { id: row.id, created_at: row.createdAt.toISOString() };
    });
  }

  /** Open reports: urgent ones first, then oldest first. Closed: newest first. */
  async list(query: ListReportsQuery): Promise<ReportListDto> {
    const open = (query.status ?? 'open') === 'open';
    const where = [
      open ? isNull(contentReports.outcome) : isNotNull(contentReports.outcome),
    ];
    if (query.question_id)
      where.push(eq(questionVersions.questionId, query.question_id));
    const order = open
      ? [
          sql`case when ${contentReports.reason} in ('wrong_answer', 'outdated_law') then 0 else 1 end`,
          asc(contentReports.createdAt),
        ]
      : [desc(contentReports.resolvedAt)];
    return {
      items: await this.query(and(...where)!, order, query.limit ?? 50),
    };
  }

  private async query(where: SQL, order: SQL[], limit: number) {
    const resolver = aliasedTable(users, 'resolver');
    const rows = await this.db
      .select({
        report: contentReports,
        questionId: questionVersions.questionId,
        versionNo: questionVersions.versionNo,
        stem: questionVersions.stem,
        resolverName: resolver.displayName,
      })
      .from(contentReports)
      .innerJoin(
        questionVersions,
        eq(questionVersions.id, contentReports.questionVersionId),
      )
      .leftJoin(resolver, eq(resolver.id, contentReports.resolvedBy))
      .where(where)
      .orderBy(...order)
      .limit(limit);
    return rows.map((r) => this.view(r.report, r));
  }

  async resolve(
    actor: Actor,
    id: string,
    dto: ResolveReportDto,
  ): Promise<ReportDto> {
    await this.db.transaction(async (tx) => {
      const [updated] = await tx
        .update(contentReports)
        .set({
          outcome: dto.outcome,
          resolutionNote: dto.note,
          resolvedBy: actor.id,
          resolvedAt: new Date(),
        })
        .where(and(eq(contentReports.id, id), isNull(contentReports.outcome)))
        .returning({ id: contentReports.id });
      if (!updated) {
        const [exists] = await tx
          .select({ id: contentReports.id })
          .from(contentReports)
          .where(eq(contentReports.id, id));
        if (!exists) throw ApiError.notFound('Report');
        throw new ApiError(
          HttpStatus.CONFLICT,
          'report_closed',
          'This report is already closed',
        );
      }
      await this.audit.record(tx, actor, {
        action: 'report.resolved',
        entityType: 'content_report',
        entityId: id,
        data: { outcome: dto.outcome },
      });
    });
    const [report] = await this.query(eq(contentReports.id, id), [], 1);
    return report;
  }

  private view(
    r: typeof contentReports.$inferSelect,
    extra: {
      questionId: string;
      versionNo: number;
      stem: string;
      resolverName: string | null;
    },
  ): ReportDto {
    return {
      id: r.id,
      question_id: extra.questionId,
      question_version_id: r.questionVersionId,
      version_no: extra.versionNo,
      stem: extra.stem,
      reason: r.reason,
      urgent: URGENT.has(r.reason),
      comment: r.comment,
      created_at: r.createdAt.toISOString(),
      outcome: r.outcome,
      resolution_note: r.resolutionNote,
      resolved_at: r.resolvedAt?.toISOString() ?? null,
      resolved_by: extra.resolverName,
    };
  }
}
