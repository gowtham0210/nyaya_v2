import { HttpStatus } from '@nestjs/common';
import { parse } from 'csv-parse/sync';
import { readSheet } from 'read-excel-file/node';
import { ApiError, type ErrorDetail } from '../core/errors.js';
import {
  QUESTION_TYPES,
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

/** Reads the file into rows, or throws invalid_file naming what is wrong with it. */
export async function readRows(
  buf: Buffer,
  format: FileFormat,
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

  const header = (cells[0] ?? []).map((h) =>
    h.trim().toLowerCase().replace(/\s+/g, '_'),
  );
  const known = new Set<string>([...IMPORT_COLUMNS, ...EXPORT_ONLY_COLUMNS]);
  const problems: ErrorDetail[] = [];
  const unknown = header.filter((h) => h && !known.has(h));
  if (unknown.length)
    problems.push({
      reason: `Unknown column${unknown.length > 1 ? 's' : ''}: ${unknown.join(', ')}. Use the column names from the template.`,
    });
  const repeated = header.filter((h, i) => h && header.indexOf(h) !== i);
  if (repeated.length)
    problems.push({
      reason: `Column named twice: ${[...new Set(repeated)].join(', ')}`,
    });
  const missing = REQUIRED_COLUMNS.filter((c) => !header.includes(c));
  if (missing.length)
    problems.push({ reason: `Missing column: ${missing.join(', ')}` });
  if (problems.length) throw invalidFile(problems);

  const rows: SheetRow[] = [];
  cells.slice(1).forEach((r, i) => {
    if (r.every((c) => !c.trim())) return; // blank rows, e.g. at the end of a sheet
    const values: Record<string, string> = {};
    header.forEach((h, j) => {
      if (h) values[h] = unguardCell((r[j] ?? '').trim());
    });
    rows.push({ row: i + 2, values });
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
  stem: 2000,
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
  const topic = topicsBySlug.get(slug);
  if (!slug) error('topic', 'A topic is required');
  else if (!topic) error('topic', `Unknown topic "${slug}"`);

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

  const correct = get('correct')
    .toLowerCase()
    .split(/[\s,;]+/)
    .filter(Boolean);
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

/** Same text in the same topic counts as the same question. */
export const stemKey = (topicId: string, stem: string) =>
  `${topicId}|${stem.toLowerCase().replace(/\s+/g, ' ').trim()}`;
