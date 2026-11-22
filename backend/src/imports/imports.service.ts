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
  contentSources,
  examQuestionTags,
  exams,
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
  checkExamRow,
  checkRow,
  EXAM_IMPORT_COLUMNS,
  EXPORT_ONLY_COLUMNS,
  formatOf,
  guardCell,
  IMPORT_COLUMNS,
  invalidFile,
  OPTION_LETTERS,
  readRows,
  contentKey,
  type FileFormat,
  type ImportDraft,
  type Problem,
  type SheetRow,
} from './format.js';
import { buildTemplate, type TemplateFile } from './template.js';
import type {
  ExamImportReportDto,
  ExportQuery,
  ImportJobListDto,
  ImportReportDto,
  ImportRowDto,
  ImportTotalsDto,
  PaperPositionsDto,
  TemplateQuery,
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
  withdrawn: rows.filter((r) => r.outcome === 'withdrawn').length,
  with_warnings: rows.filter(
    (r) =>
      r.outcome === 'created' && r.problems.some((p) => p.level === 'warning'),
  ).length,
});

/** What an exam import needs to know before it reads a row. */
interface ExamImportContext {
  contentSourceId: string | null;
  /** The exam (slug) the whole file is for, when the admin chose one. */
  selectedExam: string | null;
}

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
  run(
    actor: Actor,
    file: { originalname: string; buffer: Buffer } | undefined,
    dryRun: boolean,
  ): Promise<ImportReportDto> {
    return this.execute(actor, file, dryRun);
  }

  /**
   * The exam import: the same checks and the same draft-only outcome, plus
   * the exam columns. A content source is optional and is recorded on the
   * import and its questions for attribution only; it never blocks an import.
   */
  async runExam(
    actor: Actor,
    file: { originalname: string; buffer: Buffer } | undefined,
    dryRun: boolean,
    contentSourceId: string | undefined,
    selectedExam?: string,
  ): Promise<ExamImportReportDto> {
    if (selectedExam) {
      const [found] = await this.db
        .select({ id: exams.id })
        .from(exams)
        .where(eq(exams.slug, selectedExam))
        .limit(1);
      if (!found)
        throw new ApiError(
          HttpStatus.UNPROCESSABLE_ENTITY,
          'validation_failed',
          'The exam does not exist',
          [{ field: 'exam', reason: `Unknown exam "${selectedExam}"` }],
        );
    }
    const source = contentSourceId
      ? ((
          await this.db
            .select({
              id: contentSources.id,
              title: contentSources.title,
            })
            .from(contentSources)
            .where(eq(contentSources.id, contentSourceId))
            .limit(1)
        )[0] ?? null)
      : null;
    if (contentSourceId && !source)
      throw new ApiError(
        HttpStatus.UNPROCESSABLE_ENTITY,
        'validation_failed',
        'The content source does not exist',
        [{ field: 'content_source_id', reason: 'No such content source' }],
      );
    const report = await this.execute(actor, file, dryRun, {
      contentSourceId: source?.id ?? null,
      selectedExam: selectedExam ?? null,
    });
    return {
      ...report,
      content_source: source ? { id: source.id, title: source.title } : null,
    };
  }

  private async execute(
    actor: Actor,
    file: { originalname: string; buffer: Buffer } | undefined,
    dryRun: boolean,
    exam?: ExamImportContext,
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

    const planned = await this.plan(
      await readRows(file.buffer, format, exam ? EXAM_IMPORT_COLUMNS : [], {
        fileName,
        examSlug: exam?.selectedExam,
      }),
      exam,
    );
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
          contentSourceId: exam?.contentSourceId ?? null,
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
  private async plan(
    sheet: SheetRow[],
    exam?: ExamImportContext,
  ): Promise<PlannedRow[]> {
    const topicRows = await this.db
      .select({
        id: topics.id,
        slug: topics.slug,
        name: topics.name,
        isActive: topics.isActive,
      })
      .from(topics);
    // A topic can be written as its slug or its name, in any case.
    const bySlug = new Map(
      topicRows.flatMap((t) => [
        [t.slug, t] as const,
        [t.name.trim().toLowerCase(), t] as const,
      ]),
    );
    const examsBySlug = exam
      ? new Map(
          (
            await this.db.select({ id: exams.id, slug: exams.slug }).from(exams)
          ).map((e) => [e.slug, e.id]),
        )
      : null;
    const checked = sheet.map((s) => ({
      row: s.row,
      externalRef: s.values.external_ref || null,
      ...(examsBySlug
        ? checkExamRow(
            s.values,
            bySlug,
            examsBySlug,
            exam!.contentSourceId,
            exam!.selectedExam,
          )
        : checkRow(s.values, bySlug)),
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
    // Any version counts: a question (text and options) already written for this topic is a duplicate.
    const byStem = new Map(
      topicIds.length
        ? (
            await this.db
              .select({
                questionId: questionVersions.questionId,
                topicId: questionVersions.topicId,
                stem: questionVersions.stem,
                options: questionVersions.options,
              })
              .from(questionVersions)
              .where(inArray(questionVersions.topicId, topicIds))
          ).map((v) => [
            contentKey(v.topicId, v.stem, v.options),
            v.questionId,
          ])
        : [],
    );

    // A row that is not imported shows only what stops it, not what review needs.
    const errorsOf = (problems: Problem[]) =>
      problems.filter((p) => p.level === 'error');
    const seenInFile = new Map<string, number>();
    return checked.map((c): PlannedRow => {
      const base = { row: c.row, externalRef: c.externalRef, draft: null };
      if ((c as { withdrawn?: boolean }).withdrawn) {
        // No question is made. The same reference twice in a file is an error.
        const key = c.externalRef ? `ref|${c.externalRef}` : null;
        const earlier = key ? seenInFile.get(key) : undefined;
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
        if (key) seenInFile.set(key, c.row);
        return {
          ...base,
          outcome: 'withdrawn',
          questionId: null,
          problems: c.problems,
        };
      }
      if (!c.draft)
        return {
          ...base,
          outcome: 'failed',
          questionId: null,
          problems: errorsOf(c.problems),
        };
      const keys = [
        ...(c.externalRef ? [`ref|${c.externalRef}`] : []),
        `stem|${contentKey(c.draft.topicId, c.draft.stem, c.draft.options)}`,
      ];
      const existing =
        (c.externalRef && byRef.get(c.externalRef)) ||
        byStem.get(
          contentKey(c.draft.topicId, c.draft.stem, c.draft.options),
        );
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
                  : 'The same question (text and options) is already in this topic',
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
    const { externalRef, exam, ...content } = r.draft!;
    const questionId = newId();
    const versionId = newId();
    await tx.insert(questions).values({
      id: questionId,
      externalRef,
      createdBy: actor.id,
      examOnly: exam?.examOnly ?? false,
    });
    for (const examId of exam?.examIds ?? [])
      await tx
        .insert(examQuestionTags)
        .values({ questionId, examId, createdBy: actor.id });
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
          withdrawn: n(job.id, 'withdrawn'),
          with_warnings: warned.find((w) => w.jobId === job.id)?.n ?? 0,
        },
      })),
    };
  }

  /** A blank import file with instructions and the valid topic and exam slugs. */
  async templateFile(query: TemplateQuery): Promise<TemplateFile> {
    const [topicRows, examRows] = await Promise.all([
      this.db
        .select({ slug: topics.slug, name: topics.name })
        .from(topics)
        .where(eq(topics.isActive, true))
        .orderBy(asc(topics.slug)),
      this.db
        .select({ slug: exams.slug, name: exams.name })
        .from(exams)
        .orderBy(asc(exams.sortOrder)),
    ]);
    return buildTemplate({
      kind: query.kind,
      format: query.format ?? 'xlsx',
      exam: query.exam,
      topics: topicRows,
      exams: examRows,
    });
  }

  /**
   * What the rows of a saved import could become as paper positions. Read
   * only, and the paper rules are untouched: only a question with a published
   * version can be pinned, so this lists which rows are ready and which still
   * need review or publishing. Positions follow the file's order, so a failed
   * row leaves a visible gap instead of shifting the numbers.
   */
  async paperPositions(id: string): Promise<PaperPositionsDto> {
    const [job] = await this.db
      .select({ id: importJobs.id })
      .from(importJobs)
      .where(eq(importJobs.id, id))
      .limit(1);
    if (!job) throw ApiError.notFound('Import');
    const rows = await this.db
      .select()
      .from(importJobRows)
      .where(eq(importJobRows.jobId, id))
      .orderBy(asc(importJobRows.line));
    const ids = rows.flatMap((r) => (r.questionId ? [r.questionId] : []));
    const liveOf = new Map<string, string>(); // question -> published live version
    const latestStatus = new Map<string, string>();
    if (ids.length) {
      const versions = await this.db
        .select({
          questionId: questionVersions.questionId,
          id: questionVersions.id,
          versionNo: questionVersions.versionNo,
          status: questionVersions.status,
          liveVersionId: questions.liveVersionId,
        })
        .from(questionVersions)
        .innerJoin(questions, eq(questions.id, questionVersions.questionId))
        .where(inArray(questionVersions.questionId, ids))
        .orderBy(asc(questionVersions.versionNo));
      for (const v of versions) {
        latestStatus.set(v.questionId, v.status); // ascending: ends on the latest
        if (v.id === v.liveVersionId && v.status === 'published')
          liveOf.set(v.questionId, v.id);
      }
    }
    const items = rows.map((r, i) => {
      const withdrawn = r.outcome === 'withdrawn';
      const versionId = r.questionId ? liveOf.get(r.questionId) : undefined;
      const status = withdrawn
        ? 'withdrawn'
        : r.questionId
          ? (latestStatus.get(r.questionId) ?? null)
          : null;
      return {
        versionId,
        withdrawn,
        dto: {
          row: r.line,
          position: i + 1,
          external_ref: r.externalRef,
          outcome: r.outcome,
          question_id: r.questionId,
          status,
          // A withdrawn row is a complete position: it pins no question.
          ready: withdrawn || !!versionId,
          reason: withdrawn || versionId
            ? null
            : !r.questionId
              ? 'The row was not imported'
              : `Not published yet (it is ${(status ?? 'unknown').replace('_', ' ')})`,
        },
      };
    });
    return {
      job_id: id,
      rows: items.map((x) => x.dto),
      ready: items.filter((x) => !x.withdrawn && x.dto.ready).length,
      withdrawn: items.filter((x) => x.withdrawn).length,
      not_ready: items.filter((x) => !x.dto.ready).length,
      positions: items.flatMap((x): PaperPositionsDto['positions'] => {
        const ref = x.dto.external_ref
          ? { original_ref: x.dto.external_ref }
          : {};
        if (x.withdrawn)
          return [
            {
              position: x.dto.position,
              question_version_id: null,
              ...ref,
              withdrawn_note: `Marked WITHDRAWN in the imported file (row ${x.dto.row})`,
            },
          ];
        return x.versionId
          ? [
              {
                position: x.dto.position,
                question_version_id: x.versionId,
                ...ref,
              },
            ]
          : [];
      }),
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
