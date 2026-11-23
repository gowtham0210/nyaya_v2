import { eq } from 'drizzle-orm';
import writeXlsxFile from 'write-excel-file/node';
import { newId } from '../src/core/ids.js';
import {
  contentSources,
  examQuestionTags,
  exams,
  questions,
  questionVersions,
} from '../src/db/schema.js';
import { startApp, type TestApp } from './helpers.js';

type Session = Awaited<ReturnType<TestApp['signInAs']>>;
type Cell = string | number | null;

/** A real .xlsx workbook from rows of cells (every cell text or number). */
const workbook = (rows: Cell[][]) =>
  writeXlsxFile(
    rows.map((r) =>
      r.map((value) =>
        value === null
          ? null
          : typeof value === 'number'
            ? { value, type: Number }
            : { value, type: String },
      ),
    ) as never,
  ).toBuffer();

const STANDARD = [
  'S.No',
  'Topic',
  'Question',
  'Option A',
  'Option B',
  'Option C',
  'Option D',
  'Correct Answer',
];

const q = (n: number, over: Partial<Record<number, Cell>> = {}): Cell[] => {
  const base: Cell[] = [
    n,
    'constitution-basics',
    `Standard format question number ${n}?`,
    'Alpha',
    'Beta',
    'Gamma',
    'Delta',
    'B',
  ];
  for (const [i, v] of Object.entries(over)) base[Number(i)] = v as Cell;
  return base;
};

describe('import: the standard Excel format', () => {
  let t: TestApp;
  let editor: Session;

  // The workbook is built asynchronously, so the request is sent inside expect().
  const send = (
    url: string,
    rows: Cell[][],
    name: string,
    fields: Record<string, string> = { dry_run: 'true' },
  ) => ({
    expect: async (status: number) => {
      let req = t
        .http()
        .post(url)
        .auth(editor.token, { type: 'bearer' })
        .attach('file', await workbook(rows), name);
      for (const [k, v] of Object.entries(fields)) req = req.field(k, v);
      const res = await req;
      expect(res.status, JSON.stringify(res.body)).toBe(status);
      return res;
    },
  });
  const general = (rows: Cell[][], name = 'questions.xlsx') =>
    send('/v1/admin/import-jobs', rows, name);
  const exam = (rows: Cell[][], name = 'paper.xlsx', extra = {}) =>
    send('/v1/admin/exam-import-jobs', rows, name, {
      dry_run: 'true',
      exam: 'aibe',
      ...extra,
    });

  beforeAll(async () => {
    t = await startApp();
    editor = await t.signInAs('content_editor');
    await t.db
      .insert(exams)
      .values({ id: newId(), slug: 'aibe', name: 'AIBE', shortName: 'AIBE' });
  });
  afterAll(() => t.close());

  it('1. reads the exact standard headers', async () => {
    const res = await general([STANDARD, q(1), q(2, { 7: 'D' })]).expect(201);
    expect(res.body.totals).toMatchObject({ created: 2, failed: 0 });
    expect(
      res.body.rows.map((r: { external_ref: string }) => r.external_ref),
    ).toEqual(['questions-1', 'questions-2']);
  });

  it('2. accepts other casing, spacing, underscores and common labels', async () => {
    const header = [
      '  s.no ',
      'TOPIC',
      'Question Text',
      'option   a',
      'OPTION_B',
      'Opt C',
      'option-d',
      'Answer',
    ];
    const res = await general([
      header,
      q(1, { 7: '(b)' }),
      q(2, { 7: 'Option C' }),
      q(3, { 7: 'd.' }),
      q(4, { 7: 'a', 1: 'Preamble and Parliament' }), // topic by name
    ]).expect(201);
    expect(res.body.totals).toMatchObject({ created: 4, failed: 0 });
  });

  it('3. skips a title line above the headings and reports real sheet rows', async () => {
    const title = 'AX-2026/1-XI | SET CODE-A | ENGLISH';
    const rows = [[title], STANDARD, q(1), q(2, { 7: 'Z' })];
    const res = await exam(rows).expect(201);
    expect(res.body.rows[0]).toMatchObject({
      row: 3,
      outcome: 'created',
      external_ref: 'aibe-ax-2026-1-xi-set-code-a-english-1',
    });
    // The bad answer is reported against its own spreadsheet row.
    expect(res.body.rows[1]).toMatchObject({ row: 4, outcome: 'failed' });
    expect(res.body.rows[1].problems[0].field).toBe('correct');

    // A title line is fine for a CSV with an empty row too.
    const blank = await general([[title], [null], STANDARD, q(1)]).expect(201);
    expect(blank.body.totals.created).toBe(1);
  });

  it('3b. refuses rows above the headings that look like data, instead of dropping them', async () => {
    const res = await general([
      ['Set A', 'English', 'extra'],
      STANDARD,
      q(1),
    ]).expect(422);
    expect(res.body.code).toBe('invalid_file');
    expect(JSON.stringify(res.body.details)).toContain('Row 1');
  });

  it('3c. refuses a value under a column that has no heading', async () => {
    const rows = [
      [...STANDARD, null],
      [...q(1), 'oops'],
    ];
    const res = await general(rows).expect(422);
    expect(JSON.stringify(res.body.details)).toMatch(/no heading/);
  });

  it('4. says Topic is required when the column is missing, and never invents one', async () => {
    const noTopic = STANDARD.filter((h) => h !== 'Topic');
    const res = await general([noTopic, q(1).filter((_, i) => i !== 1)]).expect(
      422,
    );
    expect(res.body.code).toBe('invalid_file');
    const text = JSON.stringify(res.body.details);
    expect(text).toMatch(/Missing column: topic/);
    expect(text).toMatch(/Topic is required/);
    expect(text).toMatch(/Topics sheet/);
    // An empty or unknown topic cell is a row error, not a default.
    const rows = await general([
      STANDARD,
      q(1, { 1: null }),
      q(2, { 1: 'Made Up Topic' }),
    ]).expect(201);
    expect(rows.body.totals).toMatchObject({ created: 0, failed: 2 });
    expect(rows.body.rows[0].problems[0].field).toBe('topic');
    expect(rows.body.rows[1].problems[0].reason).toMatch(/Unknown topic/);
  });

  it('5. rejects invalid answer letters', async () => {
    const res = await general([
      STANDARD,
      q(1, { 7: 'E' }), // no such option
      q(2, { 7: 'Z' }),
      q(3, { 7: '2' }), // numbers are not guessed at
      q(4, { 7: null }),
      q(5, { 6: null, 7: 'D' }), // option D is empty
      q(6, { 7: 'A, B' }), // two answers in a single-select question
    ]).expect(201);
    expect(res.body.totals).toMatchObject({ created: 0, failed: 6 });
    for (const r of res.body.rows)
      expect(r.problems.map((p: { field: string }) => p.field)).toContain(
        'correct',
      );
  });

  it('6. flags duplicate question numbers instead of creating both', async () => {
    const res = await general([
      STANDARD,
      q(1),
      q(1, { 2: 'A different question that reuses number one?' }),
      q(2),
    ]).expect(201);
    expect(res.body.rows[0].outcome).toBe('created');
    expect(res.body.rows[1]).toMatchObject({ outcome: 'failed' });
    expect(res.body.rows[1].problems[0].reason).toBe('Same question as row 2');
    expect(res.body.totals).toMatchObject({ created: 2, failed: 1 });
    // The same text again with a new number is caught as a repeat of the text.
    const text = await general([STANDARD, q(1), q(9, { 2: q(1)[2] })]).expect(
      201,
    );
    expect(text.body.rows[1].outcome).toBe('failed');
  });

  describe('importing for real', () => {
    const title = 'AX-2026/1-XI | SET CODE-A | ENGLISH';
    let source: string;
    beforeAll(async () => {
      source = newId();
      await t.db.insert(contentSources).values({
        id: source,
        kind: 'original',
        title: 'Cleared',
        licenseStatus: 'permission_granted',
      });
    });
    const real = (rows: Cell[][], name: string, src: string | null = source) =>
      exam(rows, name, {
        dry_run: 'false',
        ...(src ? { content_source_id: src } : {}),
      });

    it('keeps order, option ids, numbers and set, as drafts tagged for the exam', async () => {
      const rows = [
        [title],
        STANDARD,
        q(1),
        q(2, { 7: 'D' }),
        q(3, { 7: 'a' }),
      ];
      const res = await real(rows, 'set-a.xlsx').expect(201);
      expect(res.body.totals).toMatchObject({ created: 3, failed: 0 });

      const stored = await t.db
        .select({ q: questions, v: questionVersions })
        .from(questions)
        .innerJoin(
          questionVersions,
          eq(questionVersions.questionId, questions.id),
        )
        .where(eq(questionVersions.contentSourceId, source));
      const by = new Map(stored.map((s) => [s.q.externalRef, s]));
      const second = by.get('aibe-ax-2026-1-xi-set-code-a-english-2')!;
      expect(second.v.options.map((o) => o.id)).toEqual(['a', 'b', 'c', 'd']);
      expect(second.v.options.map((o) => o.text)).toEqual([
        'Alpha',
        'Beta',
        'Gamma',
        'Delta',
      ]);
      expect(second.v.correctOptionIds).toEqual(['d']);
      expect(
        by.get('aibe-ax-2026-1-xi-set-code-a-english-3')!.v.correctOptionIds,
      ).toEqual(['a']);
      for (const s of stored) {
        expect(s.v.status).toBe('draft');
        expect(s.q.liveVersionId).toBeNull();
        const tags = await t.db
          .select()
          .from(examQuestionTags)
          .where(eq(examQuestionTags.questionId, s.q.id));
        expect(tags).toHaveLength(1);
      }
      // Rows keep their order: file rows 3, 4, 5.
      expect(res.body.rows.map((r: { row: number }) => r.row)).toEqual([
        3, 4, 5,
      ]);
    });

    it('is safe to retry, and a second set does not collide on the same numbers', async () => {
      const rows = [
        [title],
        STANDARD,
        q(1),
        q(2, { 7: 'D' }),
        q(3, { 7: 'a' }),
      ];
      const again = await real(rows, 'set-a.xlsx').expect(409);
      expect(again.body.code).toBe('already_imported');
      // Same workbook, renamed and with one more question: old rows are skipped.
      const more = await real(
        [[title], STANDARD, q(1), q(2, { 7: 'D' }), q(3, { 7: 'a' }), q(4)],
        'set-a-v2.xlsx',
      ).expect(201);
      expect(more.body.totals).toMatchObject({ created: 1, skipped: 3 });
      // Set B reuses S.No 1-2 with different questions: they are new, not skipped.
      const setB = await real(
        [
          ['AX-2026/1-XI | SET CODE-B | ENGLISH'],
          STANDARD,
          q(1, { 2: 'Set B first question, different text?' }),
          q(2, { 2: 'Set B second question, different text?' }),
        ],
        'set-b.xlsx',
      ).expect(201);
      expect(setB.body.totals).toMatchObject({ created: 2, skipped: 0 });
    });

    it('does not need a content source', async () => {
      const res = await real(
        [STANDARD, q(1, { 2: 'No source needed for this question?' })],
        'nosource.xlsx',
        null,
      ).expect(201);
      expect(res.body.totals).toMatchObject({ created: 1, failed: 0 });
    });
  });
});
