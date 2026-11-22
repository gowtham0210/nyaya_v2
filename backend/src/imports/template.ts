import writeXlsxFile from 'write-excel-file/node';
import { LAW_REGIMES } from '../db/schema.js';
import {
  EXAM_IMPORT_COLUMNS,
  guardCell,
  IMPORT_COLUMNS,
  MAX_IMPORT_BYTES,
  MAX_IMPORT_ROWS,
} from './format.js';

export interface TemplateOptions {
  kind: 'general' | 'exam';
  format: 'xlsx' | 'csv';
  /** Exam slug to put in the sample row of an exam template. */
  exam?: string;
  topics: { slug: string; name: string }[];
  exams: { slug: string; name: string }[];
}

export interface TemplateFile {
  body: Buffer;
  type: string;
  fileName: string;
}

const csvCell = (s: string) =>
  /[",\r\n]/.test(s) ? `"${s.replace(/"/g, '""')}"` : s;

/**
 * A blank import file built from the importer's own column lists, so it can
 * not drift from what the importer accepts. The Questions sheet comes first
 * because it is the sheet the importer reads; Instructions and the valid
 * topic (and exam) slugs follow.
 */
export async function buildTemplate(o: TemplateOptions): Promise<TemplateFile> {
  const isExam = o.kind === 'exam';
  const examSlug = o.exam ?? 'aibe';
  const header: string[] = [
    ...IMPORT_COLUMNS,
    ...(isExam ? EXAM_IMPORT_COLUMNS : []),
  ];
  const sample: Record<string, string> = {
    external_ref: isExam ? `${examSlug}-sample-001` : 'my-sample-001',
    topic: o.topics[0]?.slug ?? 'constitution-basics',
    difficulty: '1',
    question_type: 'single_select',
    stem: 'SAMPLE ROW - replace or delete it. When did the Constitution of India come into force?',
    option_a: '26 January 1950',
    option_b: '15 August 1947',
    option_c: '26 November 1949',
    option_d: '26 January 1952',
    correct: 'a',
    explanation: 'It came into force on 26 January 1950.',
    source_title: 'Constitution of India',
    valid_from: '1950-01-26',
    jurisdiction: 'IN',
    language: 'en',
    exam: examSlug,
    exam_only: 'true',
    law_regime: 'neutral',
  };

  const help: [string, string, string][] = [
    ['topic', 'Required', 'Topic slug. See the Topics sheet.'],
    ['stem', 'Required', 'The question text (up to 2000 characters).'],
    [
      'option_a … option_f',
      'a and b required',
      'Fill them in order; up to 500 characters each.',
    ],
    [
      'correct',
      'Required',
      'The letter of the one right option, e.g. b. If the answer key is not known, leave the question out until it is.',
    ],
    [
      'external_ref',
      'Recommended',
      'Your own id or the original question number, e.g. aibe-xx-017. A row whose id is already in the bank is skipped, so importing the same file again is safe.',
    ],
    [
      'source_title, valid_from',
      'Needed before review',
      'A row without them still becomes a draft but cannot go to review. Dates are YYYY-MM-DD.',
    ],
    [
      'explanation',
      'Optional',
      'Why the answer is right. Leave it empty if there is none.',
    ],
    [
      'difficulty, question_type, jurisdiction, language',
      'Optional',
      '1 to 3 (default 1); single_select; IN; en, hi, ta, te, kn or ml.',
    ],
    [
      'source_url, citation, provision_reference, valid_to',
      'Optional',
      'source_url must start with https://.',
    ],
    ...(isExam
      ? ([
          [
            'exam',
            'Required unless chosen in the CMS',
            'Exam slug (see the Topics sheet). A blank cell takes the exam chosen on the import page.',
          ],
          [
            'exam_only',
            'Optional',
            'true (the default) keeps the question out of the games.',
          ],
          ['law_regime', 'Optional', `One of: ${LAW_REGIMES.join(', ')}.`],
          [
            'concept_key',
            'Optional',
            'Keeps near-duplicate questions out of one mock.',
          ],
          [
            'alternate_correct',
            'Optional',
            'Extra letters that an official key also accepts.',
          ],
          [
            'lock_option_order',
            'Optional',
            'true when options such as "Both A and B" must keep their order.',
          ],
        ] as [string, string, string][])
      : []),
    [
      'Limits and safety',
      '',
      `Up to ${MAX_IMPORT_ROWS} questions and ${MAX_IMPORT_BYTES / 1024 / 1024} MB per file. Every question arrives as a draft; nothing is published. Only the first sheet (Questions) is read. Delete the sample row before importing.`,
    ],
  ];

  const base = isExam
    ? `nyaya-exam-question-template${o.exam ? `-${o.exam}` : ''}`
    : 'nyaya-question-template';

  if (o.format === 'csv') {
    const lines = [header, header.map((h) => sample[h] ?? '')].map((r) =>
      r.map((c) => csvCell(guardCell(c))).join(','),
    );
    // The byte order mark makes Excel read the file as UTF-8.
    return {
      body: Buffer.from(`﻿${lines.join('\r\n')}\r\n`, 'utf8'),
      type: 'text/csv; charset=utf-8',
      fileName: `${base}.csv`,
    };
  }

  const bold = (value: string) => ({ value, fontWeight: 'bold' as const });
  // Every cell is written as text, so nothing in it runs as a formula.
  const text = (value: string) => ({ value, type: String });
  const body = await writeXlsxFile([
    {
      sheet: 'Questions',
      data: [header.map(bold), header.map((h) => text(sample[h] ?? ''))],
      stickyRowsCount: 1,
    },
    {
      sheet: 'Instructions',
      data: [
        [bold('Column'), bold('Needed'), bold('What to write')],
        ...help.map((r) => r.map(text)),
      ],
    },
    {
      sheet: 'Topics',
      data: [
        [bold('topic (slug)'), bold('Name')],
        ...o.topics.map((t) => [text(t.slug), text(t.name)]),
        ...(isExam
          ? [
              [text(''), text('')],
              [bold('exam (slug)'), bold('Name')],
              ...o.exams.map((e) => [text(e.slug), text(e.name)]),
            ]
          : []),
      ],
    },
  ] as never).toBuffer();
  return {
    body,
    type: 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
    fileName: `${base}.xlsx`,
  };
}
