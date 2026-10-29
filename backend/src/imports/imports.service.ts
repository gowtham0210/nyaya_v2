import { createHash } from 'node:crypto';
import { HttpStatus, Inject, Injectable } from '@nestjs/common';
import {
  and,
  asc,
  count,
  desc,
  eq,
  inArray,
  max,
  sql,
  type SQL,
} from 'drizzle-orm';
import writeXlsxFile from 'write-excel-file/node';
import { AuditService, type Actor } from '../core/audit.service.js';
import { DB, type Db, type Tx } from '../core/db.js';
import { ApiError } from '../core/errors.js';
import { newId } from '../core/ids.js';
import {
  importJobRows,
  importJobs,
  importRowProblems,
  questions,
  questionVersions,
  topics,
  users,
  type ImportOutcome,
} from '../db/schema.js';
import {
  checkRow,
  EXPORT_ONLY_COLUMNS,
  formatOf,
  guardCell,
  IMPORT_COLUMNS,
  invalidFile,
  OPTION_LETTERS,
  readRows,
  stemKey,
  type FileFormat,
  type ImportDraft,
  type Problem,
  type SheetRow,
} from './format.js';
import type {
  ExportQuery,
  ImportJobListDto,
  ImportReportDto,
  ImportRowDto,
  ImportTotalsDto,
} from './imports.dto.js';

interface PlannedRow {
  row: number;
  externalRef: string | null;
  outcome: ImportOutcome;
  questionId: string | null;
  problems: Problem[];
  draft: ImportDraft | null;
}

const toRowDto = (r: Omit<PlannedRow, 'draft'>): ImportRowDto => ({
  row: r.row,
  external_ref: r.externalRef,
  outcome: r.outcome,
  question_id: r.questionId,
  problems: r.problems.map((p) => ({
    level: p.level,
    field: p.field,
    reason: p.reason,
  })),
});

const totalsOf = (rows: ImportRowDto[]): ImportTotalsDto => ({
  created: rows.filter((r) => r.outcome === 'created').length,
  skipped: rows.filter((r) => r.outcome === 'skipped').length,
  failed: rows.filter((r) => r.outcome === 'failed').length,
  with_warnings: rows.filter(
    (r) =>
      r.outcome === 'created' && r.problems.some((p) => p.level === 'warning'),
  ).length,
});

/** The only import job constraint a concurrent upload of the same file can hit. */
const isRepeatFile = (e: unknown): boolean => {
  for (let x: any = e; x; x = x.cause)
    if (x.code === '23505' && x.constraint === 'import_jobs_file_sha256_unique')
      return true;
  return false;
};

const alreadyImported = (jobId?: string) =>
  new ApiError(
    HttpStatus.CONFLICT,
    'already_imported',
    'This exact file has already been imported',
    jobId ? [{ field: 'import_job_id', reason: jobId }] : undefined,
  );

const csvCell = (s: string) =>
  /[",\r\n]/.test(s) ? `"${s.replace(/"/g, '""')}"` : s;

@Injectable()
export class ImportsService {
  constructor(
    @Inject(DB) private readonly db: Db,
    private readonly audit: AuditService,
  ) {}

  /**
   * Checks a file of questions and, unless it is a test run, saves every
   * valid new row as a draft (never anything further) in one transaction.
   */
  async run(
    actor: Actor,
    file: { originalname: string; buffer: Buffer } | undefined,
    dryRun: boolean,
  ): Promise<ImportReportDto> {
    if (!file) throw invalidFile([{ reason: 'Attach a .csv or .xlsx file' }]);
    const format = formatOf(file.originalname);
    if (!format) throw invalidFile([{ reason: 'Use a .csv or .xlsx file' }]);
    const fileName = file.originalname.slice(0, 200);
    const sha = createHash('sha256').update(file.buffer).digest('hex');
    if (!dryRun) {
      const [done] = await this.db
        .select({ id: importJobs.id })
        .from(importJobs)
        .where(eq(importJobs.fileSha256, sha))
        .limit(1);
      if (done) throw alreadyImported(done.id);
    }

    const planned = await this.plan(await readRows(file.buffer, format));
    if (dryRun) {
      const rows = planned.map(toRowDto);
      return {
        id: null,
        dry_run: true,
        file_name: fileName,
        format,
        created_at: null,
        totals: totalsOf(rows),
        rows,
      };
    }

    const jobId = newId();
    try {
      await this.db.transaction(async (tx) => {
        await tx.insert(importJobs).values({
          id: jobId,
          createdBy: actor.id,
          fileName,
          fileSha256: sha,
          format,
        });
        for (const r of planned)
          if (r.draft)
            r.questionId = await this.insertDraft(
              tx,
              actor,
              r,
              jobId,
              fileName,
            );
        await tx.insert(importJobRows).values(
          planned.map((r) => ({
            jobId,
            line: r.row,
            externalRef: r.externalRef,
            outcome: r.outcome,
            questionId: r.questionId,
          })),
        );
        const problems = planned.flatMap((r) =>
          r.problems.map((p, i) => ({
            jobId,
            line: r.row,
            position: i,
            level: p.level,
            field: p.field,
            reason: p.reason,
          })),
        );
        if (problems.length)
          await tx.insert(importRowProblems).values(problems);
        await this.audit.record(tx, actor, {
          action: 'import.completed',
          entityType: 'import_job',
          entityId: jobId,
          data: { file_name: fileName, ...totalsOf(planned.map(toRowDto)) },
        });
      });
    } catch (e) {
      if (isRepeatFile(e)) throw alreadyImported();
      throw e;
    }
    return this.report(jobId);
  }

  /** Decides each row's outcome: errors fail it, a match in the bank skips it. */
  private async plan(sheet: SheetRow[]): Promise<PlannedRow[]> {
    const topicRows = await this.db
      .select({ id: topics.id, slug: topics.slug, isActive: topics.isActive })
      .from(topics);
    const bySlug = new Map(topicRows.map((t) => [t.slug, t]));
    const checked = sheet.map((s) => ({
      row: s.row,
      externalRef: s.values.external_ref || null,
      ...checkRow(s.values, bySlug),
    }));

    const refs = [
      ...new Set(
        checked.flatMap((c) => (c.externalRef ? [c.externalRef] : [])),
      ),
    ];
    const byRef = new Map(
      refs.length
        ? (
            await this.db
              .select({ id: questions.id, ref: questions.externalRef })
              .from(questions)
              .where(inArray(questions.externalRef, refs))
          ).map((q) => [q.ref!, q.id])
        : [],
    );
    const topicIds = [
      ...new Set(checked.flatMap((c) => (c.draft ? [c.draft.topicId] : []))),
    ];
    // Any version counts: text already written for this topic is a duplicate.
    const byStem = new Map(
      topicIds.length
        ? (
            await this.db
              .select({
                questionId: questionVersions.questionId,
                topicId: questionVersions.topicId,
                stem: questionVersions.stem,
              })
              .from(questionVersions)
              .where(inArray(questionVersions.topicId, topicIds))
          ).map((v) => [stemKey(v.topicId, v.stem), v.questionId])
        : [],
    );

    // A row that is not imported shows only what stops it, not what review needs.
    const errorsOf = (problems: Problem[]) =>
      problems.filter((p) => p.level === 'error');
    const seenInFile = new Map<string, number>();
    return checked.map((c): PlannedRow => {
      const base = { row: c.row, externalRef: c.externalRef, draft: null };
      if (!c.draft)
        return {
          ...base,
          outcome: 'failed',
          questionId: null,
          problems: errorsOf(c.problems),
        };
      const keys = [
        ...(c.externalRef ? [`ref|${c.externalRef}`] : []),
        `stem|${stemKey(c.draft.topicId, c.draft.stem)}`,
      ];
      const existing =
        (c.externalRef && byRef.get(c.externalRef)) ||
        byStem.get(stemKey(c.draft.topicId, c.draft.stem));
      if (existing)
        return {
          ...base,
          outcome: 'skipped',
          questionId: existing,
          problems: [
            {
              level: 'warning',
              field:
                c.externalRef && byRef.has(c.externalRef)
                  ? 'external_ref'
                  : 'stem',
              reason:
                c.externalRef && byRef.has(c.externalRef)
                  ? 'A question with this external_ref is already in the bank'
                  : 'The same question text is already in this topic',
            },
          ],
        };
      const earlier = keys.map((k) => seenInFile.get(k)).find(Boolean);
      if (earlier)
        return {
          ...base,
          outcome: 'failed',
          questionId: null,
          problems: [
            {
              level: 'error',
              field: null,
              reason: `Same question as row ${earlier}`,
            },
          ],
        };
      for (const k of keys) seenInFile.set(k, c.row);
      return {
        ...base,
        outcome: 'created',
        questionId: null,
        problems: c.problems,
        draft: c.draft,
      };
    });
  }

  private async insertDraft(
    tx: Tx,
    actor: Actor,
    r: PlannedRow,
    jobId: string,
    fileName: string,
  ): Promise<string> {
    const { externalRef, ...content } = r.draft!;
    const questionId = newId();
    const versionId = newId();
    await tx
      .insert(questions)
      .values({ id: questionId, externalRef, createdBy: actor.id });
    await tx.insert(questionVersions).values({
      ...content,
      id: versionId,
      questionId,
      versionNo: 1,
      status: 'draft',
      changeNote: `Imported from ${fileName}, row ${r.row}`,
      createdBy: actor.id,
      updatedBy: actor.id,
    });
    await this.audit.record(tx, actor, {
      action: 'question.imported',
      entityType: 'question',
      entityId: questionId,
      data: { version_id: versionId, import_job_id: jobId, row: r.row },
    });
    return questionId;
  }

  async report(id: string): Promise<ImportReportDto> {
    const [job] = await this.db
      .select()
      .from(importJobs)
      .where(eq(importJobs.id, id))
      .limit(1);
    if (!job) throw ApiError.notFound('Import');
    const [rows, problems] = await Promise.all([
      this.db
        .select()
        .from(importJobRows)
        .where(eq(importJobRows.jobId, id))
        .orderBy(asc(importJobRows.line)),
      this.db
        .select()
        .from(importRowProblems)
        .where(eq(importRowProblems.jobId, id))
        .orderBy(asc(importRowProblems.line), asc(importRowProblems.position)),
    ]);
    const byLine = new Map<number, Problem[]>();
    for (const p of problems) {
      const list = byLine.get(p.line) ?? [];
      list.push(p);
      byLine.set(p.line, list);
    }
    const dtos = rows.map((r) =>
      toRowDto({
        row: r.line,
        externalRef: r.externalRef,
        outcome: r.outcome,
        questionId: r.questionId,
        problems: byLine.get(r.line) ?? [],
      }),
    );
    return {
      id: job.id,
      dry_run: false,
      file_name: job.fileName,
      format: job.format,
      created_at: job.createdAt.toISOString(),
      totals: totalsOf(dtos),
      rows: dtos,
    };
  }

  async list(): Promise<ImportJobListDto> {
    const jobs = await this.db
      .select({ job: importJobs, by: users.displayName })
      .from(importJobs)
      .innerJoin(users, eq(users.id, importJobs.createdBy))
      .orderBy(desc(importJobs.createdAt))
      .limit(50);
    const ids = jobs.map((j) => j.job.id);
    if (ids.length === 0) return { items: [] };
    const [outcomes, warned] = await Promise.all([
      this.db
        .select({
          jobId: importJobRows.jobId,
          outcome: importJobRows.outcome,
          n: count(),
        })
        .from(importJobRows)
        .where(inArray(importJobRows.jobId, ids))
        .groupBy(importJobRows.jobId, importJobRows.outcome),
      this.db
        .select({
          jobId: importRowProblems.jobId,
          n: sql<number>`count(distinct ${importRowProblems.line})::int`,
        })
        .from(importRowProblems)
        .innerJoin(
          importJobRows,
          and(
            eq(importJobRows.jobId, importRowProblems.jobId),
            eq(importJobRows.line, importRowProblems.line),
          ),
        )
        .where(
          and(
            inArray(importRowProblems.jobId, ids),
            eq(importRowProblems.level, 'warning'),
            eq(importJobRows.outcome, 'created'),
          ),
        )
        .groupBy(importRowProblems.jobId),
    ]);
    const n = (jobId: string, outcome: ImportOutcome) =>
      outcomes.find((o) => o.jobId === jobId && o.outcome === outcome)?.n ?? 0;
    return {
      items: jobs.map(({ job, by }) => ({
        id: job.id,
        file_name: job.fileName,
        format: job.format,
        created_at: job.createdAt.toISOString(),
        created_by_name: by,
        totals: {
          created: n(job.id, 'created'),
          skipped: n(job.id, 'skipped'),
          failed: n(job.id, 'failed'),
          with_warnings: warned.find((w) => w.jobId === job.id)?.n ?? 0,
        },
      })),
    };
  }

  /** Each question's latest version in the import columns, so a file can go back in. */
  async exportFile(
    query: ExportQuery,
  ): Promise<{ body: Buffer; type: string; fileName: string }> {
    const latestNo = this.db
      .select({
        questionId: questionVersions.questionId,
        maxNo: max(questionVersions.versionNo).as('max_no'),
      })
      .from(questionVersions)
      .groupBy(questionVersions.questionId)
      .as('latest_no');
    const where: SQL[] = [];
    if (query.status) where.push(eq(questionVersions.status, query.status));
    if (query.topic_id)
      where.push(eq(questionVersions.topicId, query.topic_id));
    const found = await this.db
      .select({ q: questions, v: questionVersions, topic: topics.slug })
      .from(questions)
      .innerJoin(latestNo, eq(latestNo.questionId, questions.id))
      .innerJoin(
        questionVersions,
        and(
          eq(questionVersions.questionId, questions.id),
          eq(questionVersions.versionNo, latestNo.maxNo),
        ),
      )
      .innerJoin(topics, eq(topics.id, questionVersions.topicId))
      .where(and(...where))
      .orderBy(asc(topics.slug), asc(questions.id));

    const header = [...IMPORT_COLUMNS, ...EXPORT_ONLY_COLUMNS];
    const rows = found.map(({ q, v, topic }) => {
      const option = Object.fromEntries(
        OPTION_LETTERS.map((l) => [
          `option_${l}`,
          v.options.find((o) => o.id === l)?.text ?? '',
        ]),
      );
      const cells: Record<(typeof header)[number], string> = {
        external_ref: q.externalRef ?? '',
        topic,
        difficulty: String(v.difficulty),
        question_type: v.questionType,
        stem: v.stem,
        ...(option as Record<
          `option_${(typeof OPTION_LETTERS)[number]}`,
          string
        >),
        correct: v.correctOptionIds.join(';'),
        explanation: v.explanation,
        source_title: v.sourceTitle ?? '',
        source_url: v.sourceUrl ?? '',
        citation: v.citation ?? '',
        provision_reference: v.provisionReference ?? '',
        valid_from: v.validFrom ?? '',
        valid_to: v.validTo ?? '',
        jurisdiction: v.jurisdiction,
        language: v.language,
        question_id: q.id,
        version_no: String(v.versionNo),
        status: v.status,
        live: q.liveVersionId ? 'yes' : 'no',
      };
      return header.map((h) => cells[h]);
    });

    const stamp = new Date().toISOString().slice(0, 10);
    const format: FileFormat = query.format ?? 'csv';
    if (format === 'xlsx') {
      // Every cell is written as text, so nothing in it runs as a formula.
      const body = await writeXlsxFile([
        header.map((h) => ({ value: h, fontWeight: 'bold' as const })),
        ...rows.map((r) => r.map((value) => ({ value, type: String }))),
      ]).toBuffer();
      return {
        body,
        type: 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
        fileName: `nyaya-questions-${stamp}.xlsx`,
      };
    }
    const lines = [header, ...rows].map((r) =>
      r.map((c) => csvCell(guardCell(c))).join(','),
    );
    // The byte order mark makes Excel read the file as UTF-8 (Hindi, Tamil…).
    return {
      body: Buffer.from(`﻿${lines.join('\r\n')}\r\n`, 'utf8'),
      type: 'text/csv; charset=utf-8',
      fileName: `nyaya-questions-${stamp}.csv`,
    };
  }
}
