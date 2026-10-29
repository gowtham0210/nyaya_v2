import { eq } from 'drizzle-orm';
import {
  auditLog,
  importJobs,
  questions,
  questionVersions,
} from '../src/db/schema.js';
import { readRows } from '../src/imports/format.js';
import { startApp, type TestApp } from './helpers.js';

type Session = Awaited<ReturnType<TestApp['signInAs']>>;

const HEADER =
  'external_ref,topic,difficulty,stem,option_a,option_b,option_c,correct,explanation,source_title,source_url,valid_from';
const row = (cells: string[]) => cells.map((c) => `"${c}"`).join(',');
const complete = (ref: string, stem: string) =>
  row([
    ref,
    'constitution-basics',
    '2',
    stem,
    'Article 14',
    'Article 21',
    'Article 32',
    'b',
    'Life and personal liberty.',
    'Constitution of India',
    'https://legislative.gov.in/constitution-of-india/',
    '1950-01-26',
  ]);

const FILE = [
  HEADER,
  complete('ext-1', 'Which Article protects life and personal liberty?'), // row 2: created
  row([
    'ext-2',
    'constitution-basics',
    '',
    'Unfinished question?',
    'x',
    'y',
    '',
    'a',
    '',
    '',
    '',
    '',
  ]), // 3: created, warnings
  row([
    'ext-3',
    'no-such-topic',
    '',
    'Bad topic?',
    'x',
    'y',
    '',
    'a',
    '',
    '',
    '',
    '',
  ]), // 4: failed
  complete('ext-4', 'Which Article protects life and personal liberty?'), // 5: same text as row 2
  row([
    '',
    'constitution-basics',
    '9',
    'Bad difficulty and answer?',
    'x',
    '',
    'z',
    'd',
    '',
    '',
    'http://x',
    '',
  ]), // 6: failed
].join('\n');

describe('question import and export', () => {
  let t: TestApp;
  let editor: Session, reviewer: Session, analyst: Session;

  const upload = (
    s: Session,
    content: string | Buffer,
    name: string,
    dryRun?: boolean,
  ) => {
    const req = t
      .http()
      .post('/v1/admin/import-jobs')
      .auth(s.token, { type: 'bearer' })
      .attach('file', Buffer.from(content), name);
    return dryRun === undefined ? req : req.field('dry_run', String(dryRun));
  };
  const get = (s: Session, url: string) =>
    t.http().get(url).auth(s.token, { type: 'bearer' });

  beforeAll(async () => {
    t = await startApp();
    [editor, reviewer, analyst] = await Promise.all([
      t.signInAs('content_editor'),
      t.signInAs('legal_reviewer'),
      t.signInAs('analyst'),
    ]);
  });
  afterAll(() => t.close());

  it('checks a file without saving anything by default', async () => {
    const res = await upload(editor, FILE, 'questions.csv').expect(201);
    expect(res.body).toMatchObject({
      id: null,
      dry_run: true,
      totals: { created: 2, skipped: 0, failed: 3, with_warnings: 1 },
    });
    expect(
      res.body.rows.map((r: { row: number; outcome: string }) => [
        r.row,
        r.outcome,
      ]),
    ).toEqual([
      [2, 'created'],
      [3, 'created'],
      [4, 'failed'],
      [5, 'failed'],
      [6, 'failed'],
    ]);
    const fields = (n: number) =>
      res.body.rows
        .find((r: { row: number }) => r.row === n)
        .problems.filter((p: { level: string }) => p.level === 'error')
        .map((p: { field: string }) => p.field);
    expect(fields(4)).toEqual(['topic']);
    expect(res.body.rows[3].problems).toContainEqual(
      expect.objectContaining({
        level: 'error',
        reason: 'Same question as row 2',
      }),
    );
    expect(fields(6)).toEqual(
      expect.arrayContaining([
        'difficulty',
        'option_c',
        'correct',
        'source_url',
      ]),
    );
    expect(await t.db.select().from(importJobs)).toEqual([]);
    expect(
      await t.db
        .select()
        .from(questions)
        .where(eq(questions.externalRef, 'ext-1')),
    ).toEqual([]);
  });

  it('imports the valid rows as drafts only, once per file', async () => {
    const res = await upload(editor, FILE, 'questions.csv', false).expect(201);
    expect(res.body).toMatchObject({
      dry_run: false,
      file_name: 'questions.csv',
      format: 'csv',
      totals: { created: 2, skipped: 0, failed: 3, with_warnings: 1 },
    });
    expect(res.body.id).toBeTruthy();
    const created = res.body.rows[0].question_id;

    const [q] = await t.db
      .select()
      .from(questions)
      .where(eq(questions.id, created));
    expect(q).toMatchObject({
      externalRef: 'ext-1',
      createdBy: editor.id,
      liveVersionId: null,
    });
    const [v] = await t.db
      .select()
      .from(questionVersions)
      .where(eq(questionVersions.questionId, created));
    expect(v).toMatchObject({
      status: 'draft',
      versionNo: 1,
      difficulty: 2,
      correctOptionIds: ['b'],
      createdBy: editor.id,
      changeNote: 'Imported from questions.csv, row 2',
    });
    const audit = await t.db
      .select()
      .from(auditLog)
      .where(eq(auditLog.entityId, created));
    expect(audit).toMatchObject([
      {
        action: 'question.imported',
        actorId: editor.id,
        data: { import_job_id: res.body.id, row: 2 },
      },
    ]);

    // The saved report is the same as the one returned.
    const again = await get(
      analyst,
      `/v1/admin/import-jobs/${res.body.id}`,
    ).expect(200);
    expect(again.body).toEqual({
      ...res.body,
      created_at: again.body.created_at,
    });

    const repeat = await upload(editor, FILE, 'renamed.csv', false).expect(409);
    expect(repeat.body).toMatchObject({
      code: 'already_imported',
      details: [{ field: 'import_job_id', reason: res.body.id }],
    });

    // A new file with the same questions skips them, by external_ref or by text.
    const next = await upload(
      editor,
      [
        HEADER,
        complete('ext-1', 'Reworded'),
        complete(
          'other',
          'Which article protects LIFE and personal   liberty?',
        ),
      ].join('\n'),
      'next.csv',
      false,
    ).expect(201);
    expect(next.body.rows).toMatchObject([
      {
        outcome: 'skipped',
        question_id: created,
        problems: [{ field: 'external_ref' }],
      },
      {
        outcome: 'skipped',
        question_id: created,
        problems: [{ field: 'stem' }],
      },
    ]);

    const list = await get(analyst, '/v1/admin/import-jobs').expect(200);
    expect(list.body.items).toMatchObject([
      {
        file_name: 'next.csv',
        totals: { created: 0, skipped: 2, failed: 0, with_warnings: 0 },
      },
      {
        file_name: 'questions.csv',
        created_by_name: expect.any(String),
        totals: { created: 2, skipped: 0, failed: 3, with_warnings: 1 },
      },
    ]);
  });

  it('refuses unusable files and checks roles', async () => {
    const bad = await upload(editor, 'topic,stem\n', 'q.csv').expect(422);
    expect(bad.body.code).toBe('invalid_file');
    await upload(editor, FILE, 'questions.txt').expect(422);
    await t
      .http()
      .post('/v1/admin/import-jobs')
      .auth(editor.token, { type: 'bearer' })
      .field('dry_run', 'true')
      .expect(422);
    await upload(editor, FILE, 'q.csv').field('dry_run', 'maybe').expect(400);
    await upload(reviewer, FILE, 'q.csv').expect(403);
    await upload(analyst, FILE, 'q.csv').expect(403);
    await get(reviewer, '/v1/admin/import-jobs/not-a-uuid').expect(400);
    await get(
      reviewer,
      '/v1/admin/import-jobs/00000000-0000-7000-8000-000000000000',
    ).expect(404);
    await t.http().get('/v1/admin/question-export').expect(401);
  });

  it('exports the latest versions in a file that imports back as duplicates', async () => {
    const csv = await get(
      analyst,
      '/v1/admin/question-export?status=draft',
    ).expect(200);
    expect(csv.headers['content-type']).toContain('text/csv');
    expect(csv.headers['content-disposition']).toMatch(
      /attachment; filename="nyaya-questions-.*\.csv"/,
    );
    const rows = await readRows(Buffer.from(csv.text), 'csv');
    expect(rows.map((r) => r.values.external_ref).sort()).toEqual([
      'ext-1',
      'ext-2',
    ]);
    expect(
      rows.find((r) => r.values.external_ref === 'ext-1')!.values,
    ).toMatchObject({
      topic: 'constitution-basics',
      correct: 'b',
      option_c: 'Article 32',
      status: 'draft',
      live: 'no',
    });

    const xlsx = await get(analyst, '/v1/admin/question-export?format=xlsx')
      .buffer(true)
      .parse((res, done) => {
        const chunks: Buffer[] = [];
        res.on('data', (c: Buffer) => chunks.push(c));
        res.on('end', () => done(null, Buffer.concat(chunks)));
      })
      .expect(200);
    const fromExcel = await readRows(xlsx.body as Buffer, 'xlsx');
    expect(fromExcel).toHaveLength(2);

    const back = await upload(
      editor,
      Buffer.from(csv.text),
      'export.csv',
      true,
    ).expect(201);
    expect(back.body.totals).toEqual({
      created: 0,
      skipped: 2,
      failed: 0,
      with_warnings: 0,
    });
  });
});
