import { HttpStatus } from '@nestjs/common';
import { parse } from 'csv-parse/sync';
import { readSheet } from 'read-excel-file/node';
import { ApiError, type ErrorDetail } from '../core/errors.js';
import {
  LAW_REGIMES,
  QUESTION_TYPES,
  type LawRegime,
  type ProblemLevel,
  type QuestionOption,
  type QuestionType,
} from '../db/schema.js';
import { contentProblems } from '../questions/workflow.js';

/*
 * The question file format shared by import, export and the template:
 * one question per row, a header row naming the columns.
 */

export const OPTION_LETTERS = ['a', 'b', 'c', 'd', 'e', 'f'] as const;

export const IMPORT_COLUMNS = [
  'external_ref',
  'topic',
  'difficulty',
  'question_type',
  'stem',
  ...OPTION_LETTERS.map((l) => `option_${l}` as const),
  'correct',
  'explanation',
  'source_title',
  'source_url',
  'citation',
  'provision_reference',
  'valid_from',
  'valid_to',
  'jurisdiction',
  'language',
] as const;

/**
 * Extra columns only the exam import reads. The ordinary import rejects them
 * as unknown columns, so a file meant for exams cannot slip into the games.
 */
export const EXAM_IMPORT_COLUMNS = [
  'exam',
  'exam_only',
  'law_regime',
  'concept_key',
  'alternate_correct',
  'lock_option_order',
] as const;

/** Written by export so a file can be read back; ignored by import. */
export const EXPORT_ONLY_COLUMNS = [
  'question_id',
  'version_no',
  'status',
  'live',
] as const;

const REQUIRED_COLUMNS = ['topic', 'stem', 'option_a', 'option_b', 'correct'];

export const MAX_IMPORT_ROWS = 500;
export const MAX_IMPORT_BYTES = 2 * 1024 * 1024;

export type FileFormat = 'csv' | 'xlsx';

/** A data row: its number in the file (the header is row 1) and its cells by column. */
export interface SheetRow {
  row: number;
  values: Record<string, string>;
}

export interface Problem {
  level: ProblemLevel;
  field: string | null;
  reason: string;
}

/** What a valid row becomes: the content of a new draft. */
export interface ImportDraft {
  externalRef: string | null;
  topicId: string;
  difficulty: number;
  questionType: QuestionType;
  stem: string;
  options: QuestionOption[];
  correctOptionIds: string[];
  explanation: string;
  sourceTitle: string | null;
  sourceUrl: string | null;
  citation: string | null;
  provisionReference: string | null;
  validFrom: string | null;
  validTo: string | null;
  jurisdiction: string;
  language: string;
  /** Set only by the exam import; absent values leave the column defaults. */
  contentSourceId?: string;
  lawRegime?: LawRegime;
  conceptKey?: string | null;
  alternateCorrectOptionIds?: string[];
  lockOptionOrder?: boolean;
  exam?: { examOnly: boolean; examIds: string[] };
}

export const invalidFile = (details: ErrorDetail[]) =>
  new ApiError(
    HttpStatus.UNPROCESSABLE_ENTITY,
    'invalid_file',
    'This file cannot be imported',
    details,
  );

export function formatOf(fileName: string): FileFormat | null {
  const ext = fileName.toLowerCase().split('.').pop();
  return ext === 'csv' || ext === 'xlsx' ? ext : null;
}

// Spreadsheet apps run cells starting with these as formulas. Export guards
// them with a leading apostrophe; import takes that apostrophe off again.
const FORMULA_START = /^[=+\-@\t\r]/;
export const guardCell = (s: string) => (FORMULA_START.test(s) ? `'${s}` : s);
const unguardCell = (s: string) =>
  s.startsWith("'") && FORMULA_START.test(s.slice(1)) ? s.slice(1) : s;

const cellText = (v: unknown): string => {
  if (v === null || v === undefined) return '';
  if (v instanceof Date) return v.toISOString().slice(0, 10);
  return String(v);
};

/** A header as a key: lower case, every run of other characters one underscore. */
export const headerKey = (h: string) =>
  h
    .trim()
    .toLowerCase()
    .replace(/[^a-z0-9]+/g, '_')
    .replace(/^_+|_+$/g, '');

/**
 * Common labels for the standard columns (keys as headerKey writes them), so
 * a sheet headed "S.No, Topic, Question, Option A ... Correct Answer" imports
 * without renaming. Anything not listed stays an unknown column.
 */
const HEADER_ALIASES: Record<string, string> = {
  s_no: 'external_ref',
  sno: 'external_ref',
  sl_no: 'external_ref',
  slno: 'external_ref',
  sr_no: 'external_ref',
  srno: 'external_ref',
  serial_no: 'external_ref',
  serial_number: 'external_ref',
  serial: 'external_ref',
  q_no: 'external_ref',
  qno: 'external_ref',
  question_no: 'external_ref',
  question_number: 'external_ref',
  topic_name: 'topic',
  question: 'stem',
  question_text: 'stem',
  question_stem: 'stem',
  correct_answer: 'correct',
  correct_option: 'correct',
  correct_ans: 'correct',
  answer: 'correct',
  ans: 'correct',
  right_answer: 'correct',
  answer_key: 'correct',
  ...Object.fromEntries(
    OPTION_LETTERS.flatMap((l) => [
      [`opt_${l}`, `option_${l}`],
      [`option${l}`, `option_${l}`],
      [`choice_${l}`, `option_${l}`],
    ]),
  ),
};

/** The importer's name for a header cell, or the cleaned header if it has no alias. */
export const canonicalHeader = (h: string) =>
  HEADER_ALIASES[headerKey(h)] ?? headerKey(h);

/** The letters in an answer cell: "B", "(b)", "Option B." or "a; c" give ['b'] or ['a','c']. */
export const answerLetters = (raw: string): string[] =>
  raw
    .toLowerCase()
    .replace(/option/g, ' ')
    .replace(/[().]/g, ' ')
    .split(/[\s,;/&]+/)
    .filter(Boolean);

/** How far down a sheet to look for the header row. */
const HEADER_SEARCH_ROWS = 15;

const slugOf = (s: string, max: number) =>
  s
    .toLowerCase()
    .replace(/[^a-z0-9]+/g, '-')
    .replace(/^-+|-+$/g, '')
    .slice(0, max)
    .replace(/-+$/, '');

export interface ReadOptions {
  /** Used to make question numbers unique when the sheet has no title row. */
  fileName?: string;
  /** Exam slug put first in a generated reference, so papers cannot collide. */
  examSlug?: string | null;
}

/** Reads the file into rows, or throws invalid_file naming what is wrong with it. */
export async function readRows(
  buf: Buffer,
  format: FileFormat,
  extraColumns: readonly string[] = [],
  opts: ReadOptions = {},
): Promise<SheetRow[]> {
  let cells: string[][];
  if (format === 'csv') {
    let text: string;
    try {
      text = new TextDecoder('utf-8', { fatal: true }).decode(buf);
    } catch {
      throw invalidFile([
        {
          reason:
            'The file is not UTF-8 text. In Excel, save it as "CSV UTF-8 (Comma delimited)".',
        },
      ]);
    }
    try {
      cells = parse(text.replace(/^﻿/, ''), {
        relax_column_count: true,
      }) as string[][];
    } catch (e) {
      throw invalidFile([
        { reason: `The CSV could not be read: ${(e as Error).message}` },
      ]);
    }
  } else {
    try {
      cells = (await readSheet(buf)).map((r) => r.map(cellText));
    } catch {
      throw invalidFile([{ reason: 'This is not a readable Excel file.' }]);
    }
  }

  const known = new Set<string>([
    ...IMPORT_COLUMNS,
    ...EXPORT_ONLY_COLUMNS,
    ...extraColumns,
  ]);
  const blank = (r: string[]) => r.every((c) => !c.trim());
  // The header is the first row (within the top few) with at least three
  // recognised column names. Rows above it are a title or metadata line such
  // as "AX-2026/1-XI | SET CODE-A | ENGLISH"; a row above it that looks like
  // data stops the import rather than being dropped.
  const recognised = (r: string[]) =>
    r.filter((c) => c.trim() && known.has(canonicalHeader(c))).length;
  let headerAt = cells
    .slice(0, HEADER_SEARCH_ROWS)
    .findIndex((r) => recognised(r) >= 3);
  if (headerAt < 0)
    headerAt = Math.max(
      0,
      cells.findIndex((r) => !blank(r)),
    );
  const above = cells.slice(0, headerAt).filter((r) => !blank(r));
  const dataAbove = above.filter((r) => r.filter((c) => c.trim()).length > 1);
  if (dataAbove.length)
    throw invalidFile([
      {
        reason: `Row ${cells.indexOf(dataAbove[0]) + 1} sits above the column headings but holds several cells. Keep only a single title line above the headings, or move the headings to the top.`,
      },
    ]);
  const title = above.map((r) => r.find((c) => c.trim())!.trim()).join(' ');
  const rawHeader = cells[headerAt] ?? [];
  const header = rawHeader.map(canonicalHeader);
  const problems: ErrorDetail[] = [];
  const unknown = header.filter((h) => h && !known.has(h));
  if (unknown.length)
    problems.push({
      reason: `Unknown column${unknown.length > 1 ? 's' : ''}: ${unknown.join(', ')}. Use the column names from the template (S.No, Topic, Question, Option A to D, Correct Answer).`,
    });
  const repeated = header.filter((h, i) => h && header.indexOf(h) !== i);
  if (repeated.length)
    problems.push({
      reason: `Column named twice: ${[...new Set(repeated)].join(', ')}`,
    });
  const missing = REQUIRED_COLUMNS.filter((c) => !header.includes(c));
  if (missing.length)
    problems.push({
      reason: `Missing column: ${missing.join(', ')}${
        missing.includes('topic')
          ? '. Topic is required and is never guessed: add a Topic column holding a topic name or slug from the Topics sheet of the template'
          : ''
      }`,
    });
  if (problems.length) throw invalidFile(problems);

  // A question number from an "S.No"-style column is only unique within its
  // own sheet, but external_ref is unique across the bank. So that column
  // becomes <exam>-<title line or file name>-<number>; a column literally
  // named external_ref is kept exactly as written.
  const numberedBySheet = rawHeader.some(
    (h) =>
      headerKey(h) !== 'external_ref' && canonicalHeader(h) === 'external_ref',
  );
  const prefix = numberedBySheet
    ? [
        opts.examSlug ?? '',
        slugOf(title, 80) ||
          slugOf((opts.fileName ?? '').replace(/\.[^.]+$/, ''), 80),
      ]
        .filter(Boolean)
        .join('-')
    : '';
  const rows: SheetRow[] = [];
  cells.slice(headerAt + 1).forEach((r, i) => {
    if (blank(r)) return; // blank rows, e.g. at the end of a sheet
    const stray = r.findIndex((c, j) => c.trim() && !header[j]);
    if (stray >= 0)
      throw invalidFile([
        {
          reason: `Row ${headerAt + i + 2} has a value in column ${stray + 1}, which has no heading. Give the column a heading from the template or remove it.`,
        },
      ]);
    const values: Record<string, string> = {};
    header.forEach((h, j) => {
      if (h) values[h] = unguardCell((r[j] ?? '').trim());
    });
    if (prefix && values.external_ref)
      values.external_ref = `${prefix}-${values.external_ref}`;
    rows.push({ row: headerAt + i + 2, values });
  });
  if (rows.length === 0)
    throw invalidFile([{ reason: 'The file has no questions in it.' }]);
  if (rows.length > MAX_IMPORT_ROWS)
    throw invalidFile([
      {
        reason: `The file has ${rows.length} questions; import at most ${MAX_IMPORT_ROWS} at a time.`,
      },
    ]);
  return rows;
}

const LIMITS: Record<string, number> = {
  external_ref: 200,
  stem: 7000,
  explanation: 5000,
  source_title: 500,
  source_url: 2000,
  citation: 1000,
  provision_reference: 500,
  jurisdiction: 8,
  language: 8,
  ...Object.fromEntries(OPTION_LETTERS.map((l) => [`option_${l}`, 500])),
};

const isDate = (s: string) => {
  if (!/^\d{4}-\d{2}-\d{2}$/.test(s)) return false;
  const d = new Date(`${s}T00:00:00Z`);
  return !Number.isNaN(d.getTime()) && d.toISOString().startsWith(s);
};

/** Problems the review check finds that make a row unusable, not just unfinished. */
const BLOCKING_FIELDS = new Set([
  'stem',
  'options',
  'correct_option_ids',
  'jurisdiction',
  'language',
  'topic_id',
  'valid_to',
  'source_url',
]);
const COLUMN_OF: Record<string, string> = {
  correct_option_ids: 'correct',
  topic_id: 'topic',
};

/**
 * Checks one row. Errors keep it out; warnings say what the draft still needs
 * before it can go to review (the same check as "Submit for review").
 */
export function checkRow(
  values: Record<string, string>,
  topicsBySlug: ReadonlyMap<string, { id: string; isActive: boolean }>,
): { draft: ImportDraft | null; problems: Problem[] } {
  const problems: Problem[] = [];
  const error = (field: string | null, reason: string) =>
    problems.push({ level: 'error', field, reason });
  const get = (k: string) => values[k] ?? '';
  const orNull = (k: string) => get(k) || null;

  for (const [k, max] of Object.entries(LIMITS))
    if (get(k).length > max) error(k, `Longer than ${max} characters`);

  const slug = get('topic');
  const topic = topicsBySlug.get(slug) ?? topicsBySlug.get(slug.toLowerCase());
  if (!slug) error('topic', 'A topic is required');
  else if (!topic)
    error(
      'topic',
      `Unknown topic "${slug}". Use a topic name or slug from the Topics sheet of the template`,
    );

  const difficulty = Number(get('difficulty') || 1);
  if (![1, 2, 3].includes(difficulty))
    error('difficulty', 'Difficulty must be 1, 2 or 3');

  const questionType = (get('question_type') ||
    'single_select') as QuestionType;
  if (!QUESTION_TYPES.includes(questionType))
    error('question_type', `Unsupported question type "${questionType}"`);

  const options: QuestionOption[] = [];
  let gap: string | null = null;
  for (const l of OPTION_LETTERS) {
    const text = get(`option_${l}`);
    if (!text) gap ??= l;
    else if (gap)
      error(
        `option_${l}`,
        `Fill the options in order: option_${gap} is empty but option_${l} is not`,
      );
    else options.push({ id: l, text });
  }

  const correct = answerLetters(get('correct'));
  if (correct.length === 0)
    error('correct', 'Give the letter of the correct option');
  else if (correct.some((c) => !options.some((o) => o.id === c)))
    error('correct', `"${get('correct')}" is not one of the filled options`);

  for (const k of ['valid_from', 'valid_to'])
    if (get(k) && !isDate(get(k)))
      error(k, 'Use a real date written as YYYY-MM-DD');

  const draft: ImportDraft = {
    externalRef: orNull('external_ref'),
    topicId: topic?.id ?? '',
    difficulty,
    questionType,
    stem: get('stem'),
    options,
    correctOptionIds: [...new Set(correct)],
    explanation: get('explanation'),
    sourceTitle: orNull('source_title'),
    sourceUrl: orNull('source_url'),
    citation: orNull('citation'),
    provisionReference: orNull('provision_reference'),
    validFrom: isDate(get('valid_from')) ? get('valid_from') : null,
    validTo: isDate(get('valid_to')) ? get('valid_to') : null,
    jurisdiction: get('jurisdiction') || 'IN',
    language: get('language') || 'en',
  };

  const seen = new Set(problems.map((p) => p.field));
  for (const p of contentProblems(draft, topic?.isActive ?? true)) {
    const field = COLUMN_OF[p.field ?? ''] ?? p.field ?? null;
    if (seen.has(field)) continue; // already reported more precisely above
    if (BLOCKING_FIELDS.has(p.field ?? '')) error(field, p.reason);
    else
      problems.push({
        level: 'warning',
        field,
        reason: `${p.reason} before review`,
      });
  }

  return {
    draft: problems.some((p) => p.level === 'error') ? null : draft,
    problems,
  };
}

/** The answer-key word for a question the exam body withdrew. */
export const WITHDRAWN_KEY = 'withdrawn';

const TRUE_WORDS = new Set(['true', 'yes', 'y', '1']);
const FALSE_WORDS = new Set(['false', 'no', 'n', '0']);

/**
 * Checks one row of an exam import: everything checkRow checks, plus the exam
 * columns. exam_only defaults to true, so a question is kept out of the games
 * unless the file says otherwise; each row names at least one exam (by slug).
 */
export function checkExamRow(
  values: Record<string, string>,
  topicsBySlug: ReadonlyMap<string, { id: string; isActive: boolean }>,
  examsBySlug: ReadonlyMap<string, string>,
  contentSourceId: string | null,
  selectedExam: string | null = null,
): { draft: ImportDraft | null; problems: Problem[]; withdrawn?: boolean } {
  const base = checkRow(values, topicsBySlug);
  const get = (k: string) => (values[k] ?? '').trim();
  // The exam body can withdraw a question; its key then reads WITHDRAWN. That
  // is not an answer option, so no question is made for the row. It is kept as
  // a withdrawn paper position instead. Every other check still applies.
  const withdrawnRow = get('correct').toLowerCase() === WITHDRAWN_KEY;
  const problems = withdrawnRow
    ? base.problems.filter((p) => p.level === 'error' && p.field !== 'correct')
    : [...base.problems];
  const before = problems.length;
  const error = (field: string, reason: string) =>
    problems.push({ level: 'error', field, reason });

  let examOnly = true;
  if (get('exam_only')) {
    const w = get('exam_only').toLowerCase();
    if (TRUE_WORDS.has(w)) examOnly = true;
    else if (FALSE_WORDS.has(w)) examOnly = false;
    else error('exam_only', 'Use true or false');
  }

  const slugs = get('exam')
    .toLowerCase()
    .split(/[\s,;]+/)
    .filter(Boolean);
  // An exam chosen for the whole file fills a blank exam cell and rejects a
  // row that names a different exam.
  if (selectedExam) {
    if (slugs.length === 0) slugs.push(selectedExam);
    else if (slugs.some((s) => s !== selectedExam))
      error(
        'exam',
        `This row names "${get('exam')}" but the file is being imported for ${selectedExam}`,
      );
  }
  const examIds: string[] = [];
  for (const slug of slugs) {
    const id = examsBySlug.get(slug);
    if (!id) error('exam', `Unknown exam "${slug}"`);
    else if (!examIds.includes(id)) examIds.push(id);
  }
  if (slugs.length === 0) error('exam', 'Name at least one exam, e.g. aibe');

  const regime = (get('law_regime') || 'neutral').toLowerCase();
  if (!(LAW_REGIMES as readonly string[]).includes(regime))
    error('law_regime', `Use one of: ${LAW_REGIMES.join(', ')}`);

  const concept = get('concept_key').toLowerCase() || null;
  if (concept && !/^[a-z0-9][a-z0-9._-]{0,118}[a-z0-9]$/.test(concept))
    error(
      'concept_key',
      'Use lowercase letters, digits, dots, dashes or underscores (2 to 120 characters)',
    );

  let lockOptionOrder = false;
  if (get('lock_option_order')) {
    const w = get('lock_option_order').toLowerCase();
    if (TRUE_WORDS.has(w)) lockOptionOrder = true;
    else if (!FALSE_WORDS.has(w))
      error('lock_option_order', 'Use true or false');
  }

  const filled = OPTION_LETTERS.filter((l) => get(`option_${l}`));
  const correct = answerLetters(get('correct'));
  const alternates = get('alternate_correct')
    .toLowerCase()
    .split(/[\s,;]+/)
    .filter(Boolean);
  if (alternates.some((a) => !filled.includes(a as never)))
    error(
      'alternate_correct',
      'Each alternate must be one of the filled options',
    );
  if (alternates.some((a) => correct.includes(a)))
    error('alternate_correct', 'An alternate cannot also be a correct answer');
  if (new Set(alternates).size !== alternates.length)
    error('alternate_correct', 'An option is listed more than once');

  const extraErrors = problems.length > before;
  if (withdrawnRow) {
    const ok = !problems.some((p) => p.level === 'error');
    if (ok)
      problems.push({
        level: 'warning',
        field: 'correct',
        reason:
          'Marked WITHDRAWN: no question is created. It becomes a withdrawn position when the paper is built',
      });
    return { draft: null, problems, withdrawn: ok };
  }
  return {
    draft:
      base.draft && !extraErrors
        ? {
            ...base.draft,
            ...(contentSourceId ? { contentSourceId } : {}),
            lawRegime: regime as LawRegime,
            conceptKey: concept,
            alternateCorrectOptionIds: [...new Set(alternates)],
            lockOptionOrder,
            exam: { examOnly, examIds },
          }
        : null,
    problems,
  };
}

const squash = (s: string) => s.toLowerCase().replace(/\s+/g, ' ').trim();

/** Same text in the same topic counts as the same question. */
export const stemKey = (topicId: string, stem: string) =>
  `${topicId}|${squash(stem)}`;

/**
 * Same question text AND the same options, in the same topic, counts as the
 * same question. Questions that share a stem but offer different options (for
 * example "Which of the following is the author most likely to agree with?"
 * after different reading passages) are different questions.
 */
export const contentKey = (
  topicId: string,
  stem: string,
  options: readonly { text: string }[],
) =>
  `${stemKey(topicId, stem)}|${options.map((o) => squash(o.text)).join('\u00a6')}`;
