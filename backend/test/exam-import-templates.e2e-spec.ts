import { eq } from 'drizzle-orm';
import { readSheet } from 'read-excel-file/node';
import { newId } from '../src/core/ids.js';
import {
  contentSources,
  examPapers,
  exams,
  questions,
  questionVersions,
} from '../src/db/schema.js';
import {
  EXAM_IMPORT_COLUMNS,
  IMPORT_COLUMNS,
} from '../src/imports/format.js';
import { startApp, type TestApp } from './helpers.js';

type Session = Awaited<ReturnType<TestApp['signInAs']>>;

const csv = (rows: Record<string, string>[], header: string[]) =>
  [
    header.join(','),
    ...rows.map((r) =>
      header.map((h) => `"${(r[h] ?? '').replace(/"/g, '""')}"`).join(','),
    ),
  ].join('\n');

const row = (n: number, over: Record<string, string> = {}) => ({
  external_ref: `tpl-ref-${n}`,
  topic: 'constitution-basics',
  stem: `Template test question number ${n}?`,
  option_a: 'Alpha',
  option_b: 'Beta',
  option_c: 'Gamma',
  correct: 'b',
  explanation: 'Reviewer written.',
  source_title: 'Reviewer-authored',
  valid_from: '2024-07-01',
  ...over,
});

describe('exam import: templates, chosen exam and paper positions', () => {
  let t: TestApp;
  let editor: Session, admin: Session, learner: Session;
  const examIds: Record<string, string> = {};

  const getTemplate = (s: Session | null, qs: string) => {
    let req = t.http().get(`/v1/admin/import-templates?${qs}`);
    if (s) req = req.auth(s.token, { type: 'bearer' });
    return req.buffer(true).parse((res, cb) => {
      const chunks: Buffer[] = [];
      res.on('data', (c: Buffer) => chunks.push(c));
      res.on('end', () => cb(null, Buffer.concat(chunks)));
    });
  };

  const upload = (
    s: Session,
    url: string,
    content: string | Buffer,
    name: string,
    fields: Record<string, string> = {},
  ) => {
    let req = t
      .http()
      .post(url)
      .auth(s.token, { type: 'bearer' })
      .attach('file', Buffer.from(content), name);
    for (const [k, v] of Object.entries(fields)) req = req.field(k, v);
    return req;
  };

  const source = async () => {
    const id = newId();
    await t.db.insert(contentSources).values({
      id,
      kind: 'original',
      title: 'Cleared source',
      licenseStatus: 'permission_granted',
    });
    return id;
  };

  beforeAll(async () => {
    t = await startApp();
    [editor, admin, learner] = await Promise.all([
      t.signInAs('content_editor'),
      t.signInAs('admin'),
      t.signInAs('learner'),
    ]);
    for (const slug of ['aibe', 'clat', 'ailet']) {
      examIds[slug] = newId();
      await t.db.insert(exams).values({
        id: examIds[slug],
        slug,
        name: slug.toUpperCase(),
        shortName: slug.toUpperCase(),
      });
    }
  });
  afterAll(() => t.close());

  describe('template download', () => {
    it('is for staff only', async () => {
      await getTemplate(null, 'kind=general').expect(401);
      await getTemplate(learner, 'kind=general').expect(403);
      await getTemplate(editor, 'kind=general').expect(200);
    });

    it('rejects an unknown kind or format', async () => {
      await getTemplate(editor, 'kind=other').expect(400);
      await getTemplate(editor, 'kind=exam&format=pdf').expect(400);
      await getTemplate(editor, '').expect(400);
    });

    it('gives an .xlsx whose first sheet is exactly the importer columns, plus instructions', async () => {
      const general = await getTemplate(editor, 'kind=general').expect(200);
      expect(general.headers['content-type']).toContain('spreadsheetml');
      expect(general.headers['content-disposition']).toContain('.xlsx');
      const sheet = await readSheet(general.body as Buffer);
      expect(sheet[0]).toEqual([...IMPORT_COLUMNS]);
      expect(sheet).toHaveLength(2); // header and one sample row
      const instructions = await readSheet(general.body as Buffer, {
        sheet: 'Instructions',
      } as never);
      expect(JSON.stringify(instructions)).toContain('correct');

      const exam = await getTemplate(editor, 'kind=exam&exam=clat').expect(200);
      const examSheet = await readSheet(exam.body as Buffer);
      expect(examSheet[0]).toEqual([...IMPORT_COLUMNS, ...EXAM_IMPORT_COLUMNS]);
      expect(examSheet[1][examSheet[0].indexOf('exam')]).toBe('clat');
      expect(exam.headers['content-disposition']).toContain('-clat.xlsx');
    });

    it('gives a csv too, and the sample row passes the matching importer check', async () => {
      const gen = await getTemplate(editor, 'kind=general&format=csv').expect(
        200,
      );
      const a = await upload(
        editor,
        '/v1/admin/import-jobs',
        gen.body as Buffer,
        'template.csv',
        { dry_run: 'true' },
      ).expect(201);
      expect(a.body.totals).toMatchObject({ created: 1, failed: 0 });

      const xlsx = await getTemplate(editor, 'kind=exam&exam=aibe').expect(200);
      const b = await upload(
        editor,
        '/v1/admin/exam-import-jobs',
        xlsx.body as Buffer,
        'template.xlsx',
        { dry_run: 'true' },
      ).expect(201);
      expect(b.body.totals).toMatchObject({ created: 1, failed: 0 });
    });

    it('keeps the exam columns out of the general template', async () => {
      const gen = await getTemplate(editor, 'kind=general').expect(200);
      const header = (await readSheet(gen.body as Buffer))[0];
      for (const c of EXAM_IMPORT_COLUMNS) expect(header).not.toContain(c);
    });
  });

  describe('exam chosen for the whole file', () => {
    const plain = Object.keys(row(0));

    it('fills a missing exam column, and flags a row that names another exam', async () => {
      const file = csv(
        [
          row(1),
          row(2, { exam: 'aibe' }),
          row(3, { exam: 'clat' }),
          row(4, { topic: 'nope' }),
        ],
        [...plain, 'exam'],
      );
      const res = await upload(
        editor,
        '/v1/admin/exam-import-jobs',
        file,
        'aibe.csv',
        { dry_run: 'true', exam: 'aibe' },
      ).expect(201);
      const by = new Map<number, { outcome: string; problems: { field: string; reason: string }[] }>(
        res.body.rows.map((r: { row: number }) => [r.row, r]),
      );
      expect(by.get(2)!.outcome).toBe('created');
      expect(by.get(3)!.outcome).toBe('created');
      expect(by.get(4)!.outcome).toBe('failed');
      expect(by.get(4)!.problems[0]).toMatchObject({ field: 'exam' });
      expect(by.get(4)!.problems[0].reason).toContain('clat');
      expect(by.get(5)!.outcome).toBe('failed');
      expect(by.get(5)!.problems.map((p) => p.field)).toContain('topic');
    });

    it('without a chosen exam, a missing exam is still an error', async () => {
      const res = await upload(
        editor,
        '/v1/admin/exam-import-jobs',
        csv([row(10)], plain),
        'noexam.csv',
        { dry_run: 'true' },
      ).expect(201);
      expect(res.body.rows[0].outcome).toBe('failed');
      expect(res.body.rows[0].problems[0].field).toBe('exam');
    });

    it('rejects an unknown exam identifier outright', async () => {
      const res = await upload(
        editor,
        '/v1/admin/exam-import-jobs',
        csv([row(11)], plain),
        'x.csv',
        { dry_run: 'true', exam: 'nosuchexam' },
      ).expect(422);
      expect(res.body.details[0].field).toBe('exam');
      await upload(
        editor,
        '/v1/admin/exam-import-jobs',
        csv([row(11)], plain),
        'x.csv',
        { dry_run: 'true', exam: 'BAD EXAM!' },
      ).expect(400);
    });

    it('reports an invalid spreadsheet column, a missing column and missing fields clearly', async () => {
      const unknown = await upload(
        editor,
        '/v1/admin/exam-import-jobs',
        csv([row(12, { colour: 'red' })], [...plain, 'colour']),
        'u.csv',
        { dry_run: 'true', exam: 'aibe' },
      ).expect(422);
      expect(JSON.stringify(unknown.body.details)).toMatch(
        /Unknown column.*colour/,
      );
      const noStem = await upload(
        editor,
        '/v1/admin/exam-import-jobs',
        csv([row(13)], plain.filter((c) => c !== 'stem')),
        'm.csv',
        { dry_run: 'true', exam: 'aibe' },
      ).expect(422);
      expect(JSON.stringify(noStem.body.details)).toMatch(/Missing column.*stem/);
      const bad = await upload(
        editor,
        '/v1/admin/exam-import-jobs',
        csv(
          [
            row(14, { stem: '' }),
            row(15, { option_b: '', option_c: '' }),
            row(16, { correct: 'e' }),
          ],
          plain,
        ),
        'bad.csv',
        { dry_run: 'true', exam: 'aibe' },
      ).expect(201);
      const fields = bad.body.rows.map((r: { problems: { field: string }[] }) =>
        r.problems.map((p) => p.field),
      );
      expect(fields[0]).toContain('stem');
      expect(fields[1].some((f: string) => f.startsWith('option'))).toBe(true);
      expect(fields[2]).toContain('correct');
    });
  });

  describe('importing, retrying and building a paper', () => {
    it('imports drafts for the chosen exam, keeps them drafts, is safe to retry, and activates nothing', async () => {
      const src = await source();
      const file = csv([row(20), row(21), row(22)], Object.keys(row(0)));
      const res = await upload(
        editor,
        '/v1/admin/exam-import-jobs',
        file,
        'aibe-xx.csv',
        { dry_run: 'false', exam: 'aibe', content_source_id: src },
      ).expect(201);
      expect(res.body.totals).toMatchObject({ created: 3, failed: 0 });

      const found = await t.db
        .select()
        .from(questions)
        .where(eq(questions.examOnly, true));
      expect(found.length).toBeGreaterThanOrEqual(3);
      const created = found.filter((q) => q.externalRef?.startsWith('tpl-ref-2'));
      expect(created).toHaveLength(3);
      for (const q of created) expect(q.liveVersionId).toBeNull();
      const versions = await t.db
        .select()
        .from(questionVersions)
        .where(eq(questionVersions.contentSourceId, src));
      expect(versions.every((v) => v.status === 'draft')).toBe(true);

      // The exact same file again changes nothing.
      const again = await upload(
        editor,
        '/v1/admin/exam-import-jobs',
        file,
        'aibe-xx.csv',
        { dry_run: 'false', exam: 'aibe', content_source_id: src },
      ).expect(409);
      expect(again.body.code).toBe('already_imported');
      // An edited file does not duplicate the rows already imported.
      const edited = csv(
        [row(20), row(21), row(22), row(23)],
        Object.keys(row(0)),
      );
      const third = await upload(
        editor,
        '/v1/admin/exam-import-jobs',
        edited,
        'aibe-xx-v2.csv',
        { dry_run: 'false', exam: 'aibe', content_source_id: src },
      ).expect(201);
      expect(third.body.totals).toMatchObject({
        created: 1,
        skipped: 3,
        failed: 0,
      });

      // No exam was switched on by any of this.
      const all = await t.db.select().from(exams);
      expect(all.every((e) => e.isActive === false)).toBe(true);
    });

    it('lists paper positions only for published questions, and the paper accepts exactly those', async () => {
      const src = await source();
      const file = csv([row(30), row(31)], Object.keys(row(0)));
      const job = await upload(
        editor,
        '/v1/admin/exam-import-jobs',
        file,
        'paper.csv',
        { dry_run: 'false', exam: 'aibe', content_source_id: src },
      ).expect(201);
      const id = job.body.id as string;

      const before = await t
        .http()
        .get(`/v1/admin/import-jobs/${id}/paper-positions`)
        .auth(editor.token, { type: 'bearer' })
        .expect(200);
      expect(before.body).toMatchObject({ ready: 0, not_ready: 2, positions: [] });
      expect(before.body.rows[0].reason).toContain('Not published yet');
      await t
        .http()
        .get(`/v1/admin/import-jobs/${id}/paper-positions`)
        .auth(learner.token, { type: 'bearer' })
        .expect(403);
      await t
        .http()
        .get(`/v1/admin/import-jobs/${newId()}/paper-positions`)
        .auth(editor.token, { type: 'bearer' })
        .expect(404);

      // Publish the first question directly (standing in for the review workflow).
      const first = before.body.rows[0].question_id as string;
      const [v] = await t.db
        .select()
        .from(questionVersions)
        .where(eq(questionVersions.questionId, first));
      await t.db
        .update(questionVersions)
        .set({ status: 'published', publishedAt: new Date() })
        .where(eq(questionVersions.id, v.id));
      await t.db
        .update(questions)
        .set({ liveVersionId: v.id })
        .where(eq(questions.id, first));

      const after = await t
        .http()
        .get(`/v1/admin/import-jobs/${id}/paper-positions`)
        .auth(editor.token, { type: 'bearer' })
        .expect(200);
      expect(after.body).toMatchObject({ ready: 1, not_ready: 1 });
      expect(after.body.positions).toEqual([
        { position: 1, question_version_id: v.id, original_ref: 'tpl-ref-30' },
      ]);

      // The unchanged paper rules take the ready position and refuse the draft.
      const paper = await t
        .http()
        .post('/v1/admin/exam-papers')
        .auth(admin.token, { type: 'bearer' })
        .send({
          exam_id: examIds.aibe,
          code: 'tpl-paper',
          title: 'Template test paper',
          total_questions: 2,
        })
        .expect(201);
      await t
        .http()
        .put(`/v1/admin/exam-papers/${paper.body.id}/positions`)
        .auth(admin.token, { type: 'bearer' })
        .send({ positions: after.body.positions })
        .expect(200);
      const draftQ = await t.db
        .select()
        .from(questionVersions)
        .where(eq(questionVersions.questionId, before.body.rows[1].question_id));
      await t
        .http()
        .put(`/v1/admin/exam-papers/${paper.body.id}/positions`)
        .auth(admin.token, { type: 'bearer' })
        .send({
          positions: [
            ...after.body.positions,
            { position: 2, question_version_id: draftQ[0].id },
          ],
        })
        .expect(422);
      const [p] = await t.db
        .select()
        .from(examPapers)
        .where(eq(examPapers.id, paper.body.id));
      expect(p.status).toBe('draft');
    });
  });
});
