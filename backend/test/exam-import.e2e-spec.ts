import { count, eq } from 'drizzle-orm';
import { newId } from '../src/core/ids.js';
import {
  auditLog,
  contentSources,
  examQuestionTags,
  exams,
  importJobs,
  questions,
  questionVersions,
  type LicenseStatus,
} from '../src/db/schema.js';
import { startApp, type TestApp } from './helpers.js';

type Session = Awaited<ReturnType<TestApp['signInAs']>>;

const HEADER = [
  'external_ref',
  'topic',
  'stem',
  'option_a',
  'option_b',
  'option_c',
  'option_d',
  'correct',
  'explanation',
  'source_title',
  'valid_from',
  'exam',
  'exam_only',
  'law_regime',
  'concept_key',
  'alternate_correct',
  'lock_option_order',
].join(',');

const cells = (o: Record<string, string>) =>
  HEADER.split(',')
    .map((h) => `"${(o[h] ?? '').replace(/"/g, '""')}"`)
    .join(',');

const good = (n: number, over: Record<string, string> = {}) =>
  cells({
    external_ref: `exam-ref-${n}`,
    topic: 'constitution-basics',
    stem: `Original reviewer-written question number ${n}?`,
    option_a: 'Alpha',
    option_b: 'Beta',
    option_c: 'Gamma',
    option_d: 'Delta',
    correct: 'a',
    explanation: 'Written by our reviewer.',
    source_title: 'Reviewer-authored',
    valid_from: '2024-07-01',
    exam: 'aibe',
    ...over,
  });

describe('exam question import', () => {
  let t: TestApp;
  let editor: Session, admin: Session, analyst: Session, learner: Session;
  let aibeId: string;

  const upload = (
    s: Session | null,
    content: string,
    opts: { dryRun?: boolean; source?: string; url?: string } = {},
  ) => {
    let req = t.http().post(opts.url ?? '/v1/admin/exam-import-jobs');
    if (s) req = req.auth(s.token, { type: 'bearer' });
    req = req.attach('file', Buffer.from(content), 'exam-questions.csv');
    if (opts.dryRun !== undefined)
      req = req.field('dry_run', String(opts.dryRun));
    if (opts.source) req = req.field('content_source_id', opts.source);
    return req;
  };

  const source = async (licenseStatus: LicenseStatus) => {
    const id = newId();
    await t.db.insert(contentSources).values({
      id,
      kind: licenseStatus === 'permission_granted' ? 'original' : 'third_party',
      title: `Source ${licenseStatus}`,
      licenseStatus,
    });
    return id;
  };

  const counts = async () => ({
    questions: (await t.db.select({ n: count() }).from(questions))[0].n,
    versions: (await t.db.select({ n: count() }).from(questionVersions))[0].n,
    tags: (await t.db.select({ n: count() }).from(examQuestionTags))[0].n,
    jobs: (await t.db.select({ n: count() }).from(importJobs))[0].n,
  });

  beforeAll(async () => {
    t = await startApp();
    [editor, admin, analyst, learner] = await Promise.all([
      t.signInAs('content_editor'),
      t.signInAs('admin'),
      t.signInAs('analyst'),
      t.signInAs('learner'),
    ]);
    aibeId = newId();
    await t.db
      .insert(exams)
      .values({ id: aibeId, slug: 'aibe', name: 'AIBE', shortName: 'AIBE' });
  });
  afterAll(() => t.close());

  it('is for content editors and admins only', async () => {
    const file = [HEADER, good(1)].join('\n');
    await upload(null, file).expect(401);
    await upload(learner, file).expect(403);
    await upload(analyst, file).expect(403);
    await upload(editor, file, { dryRun: true }).expect(201);
    await upload(admin, file, { dryRun: true }).expect(201);
  });

  it('is kept apart from the ordinary import, which still refuses the exam columns', async () => {
    const file = [HEADER, good(2)].join('\n');
    const res = await upload(editor, file, {
      url: '/v1/admin/import-jobs',
    }).expect(422);
    expect(res.body.code).toBe('invalid_file');
    expect(JSON.stringify(res.body.details)).toMatch(/Unknown column.*exam/);
  });

  describe('dry run', () => {
    it('checks every row and reports row-level errors without saving anything', async () => {
      const before = await counts();
      const file = [
        HEADER,
        good(10), // row 2: fine
        good(11, { exam: 'nosuchexam' }), // 3: unknown exam
        good(12, { exam: '' }), // 4: no exam
        good(13, { law_regime: 'ancient' }), // 5
        good(14, { concept_key: 'Bad Key!' }), // 6
        good(15, { alternate_correct: 'a' }), // 7: alternate is also correct
        good(16, { alternate_correct: 'z' }), // 8: not an option
        good(17, { exam_only: 'maybe' }), // 9
        good(18, { lock_option_order: 'sometimes' }), // 10
        good(19, {
          alternate_correct: 'b, c',
          concept_key: 'art.14',
          law_regime: 'new_codes',
          lock_option_order: 'true',
        }), // 11: fine
        good(20, { topic: 'no-such-topic' }), // 12
      ].join('\n');
      const res = await upload(editor, file, { dryRun: true }).expect(201);
      expect(res.body.dry_run).toBe(true);
      expect(res.body.id).toBeNull();
      const byRow = new Map<
        number,
        { outcome: string; problems: { field: string }[] }
      >(res.body.rows.map((r: { row: number }) => [r.row, r]));
      expect(byRow.get(2)!.outcome).toBe('created');
      expect(byRow.get(11)!.outcome).toBe('created');
      const failures: [number, string][] = [
        [3, 'exam'],
        [4, 'exam'],
        [5, 'law_regime'],
        [6, 'concept_key'],
        [7, 'alternate_correct'],
        [8, 'alternate_correct'],
        [9, 'exam_only'],
        [10, 'lock_option_order'],
        [12, 'topic'],
      ];
      for (const [row, field] of failures) {
        expect(byRow.get(row)!.outcome).toBe('failed');
        expect(byRow.get(row)!.problems.map((p) => p.field)).toContain(field);
      }
      expect(res.body.totals).toMatchObject({ created: 2, failed: 9 });
      expect(await counts()).toEqual(before);
    });

    it('is the default, and needs no content source', async () => {
      const res = await upload(editor, [HEADER, good(30)].join('\n')).expect(
        201,
      );
      expect(res.body.dry_run).toBe(true);
      expect(res.body.content_source).toBeNull();
      expect(res.body).not.toHaveProperty('blocker');
      expect(res.body).not.toHaveProperty('can_import');
    });

    it('names a content source for attribution, whatever its historical licence record says', async () => {
      for (const status of ['pending', 'permission_granted'] as const) {
        const src = await source(status);
        const res = await upload(editor, [HEADER, good(31)].join('\n'), {
          dryRun: true,
          source: src,
        }).expect(201);
        expect(res.body.content_source).toEqual({
          id: src,
          title: `Source ${status}`,
        });
        expect(JSON.stringify(res.body)).not.toMatch(/licen[sc]e|cleared/i);
      }
    });

    it('rejects an unknown content source', async () => {
      await upload(editor, [HEADER, good(33)].join('\n'), {
        dryRun: true,
        source: newId(),
      }).expect(422);
    });
  });

  describe('importing for real', () => {
    it('needs no content source, is not blocked by one, and records the one it is given', async () => {
      const none = await upload(editor, [HEADER, good(140)].join('\n'), {
        dryRun: false,
      }).expect(201);
      expect(none.body.totals).toMatchObject({ created: 1, failed: 0 });
      const [noneJob] = await t.db
        .select()
        .from(importJobs)
        .where(eq(importJobs.id, none.body.id));
      expect(noneJob.contentSourceId).toBeNull();
      let n = 141;
      for (const status of ['pending', 'blocked'] as const) {
        const src = await source(status);
        const res = await upload(editor, [HEADER, good(n++)].join('\n'), {
          dryRun: false,
          source: src,
        }).expect(201);
        expect(res.body.totals).toMatchObject({ created: 1, failed: 0 });
        const [job] = await t.db
          .select()
          .from(importJobs)
          .where(eq(importJobs.id, res.body.id));
        expect(job.contentSourceId).toBe(src);
      }
    });

    it('creates exam-only drafts, tagged for the exam, from a named source', async () => {
      const src = await source('permission_granted');
      const file = [
        HEADER,
        good(50, {
          alternate_correct: 'b',
          concept_key: 'import.concept',
          law_regime: 'new_codes',
          lock_option_order: 'yes',
        }),
        good(51),
        good(52, { exam_only: 'false' }),
      ].join('\n');
      const res = await upload(editor, file, {
        dryRun: false,
        source: src,
      }).expect(201);
      expect(res.body.dry_run).toBe(false);
      expect(res.body.totals).toMatchObject({ created: 3, failed: 0 });
      expect(res.body.id).not.toBeNull();

      const rows = await t.db
        .select({ q: questions, v: questionVersions })
        .from(questions)
        .innerJoin(
          questionVersions,
          eq(questionVersions.questionId, questions.id),
        )
        .where(eq(questionVersions.contentSourceId, src));
      expect(rows).toHaveLength(3);
      const by = new Map(rows.map((r) => [r.q.externalRef, r]));

      const first = by.get('exam-ref-50')!;
      expect(first.q.examOnly).toBe(true);
      expect(first.v).toMatchObject({
        status: 'draft',
        lawRegime: 'new_codes',
        conceptKey: 'import.concept',
        alternateCorrectOptionIds: ['b'],
        lockOptionOrder: true,
        contentSourceId: src,
      });
      // The default is exam-only; the file can opt a row out.
      expect(by.get('exam-ref-51')!.q.examOnly).toBe(true);
      expect(by.get('exam-ref-52')!.q.examOnly).toBe(false);
      for (const r of rows) {
        // Never beyond a draft: nothing is live or published.
        expect(r.q.liveVersionId).toBeNull();
        expect(r.v.status).toBe('draft');
        const tags = await t.db
          .select()
          .from(examQuestionTags)
          .where(eq(examQuestionTags.questionId, r.q.id));
        expect(tags.map((x) => x.examId)).toEqual([aibeId]);
      }
      const [job] = await t.db
        .select()
        .from(importJobs)
        .where(eq(importJobs.id, res.body.id));
      expect(job.contentSourceId).toBe(src);
      const log = await t.db
        .select()
        .from(auditLog)
        .where(eq(auditLog.action, 'import.completed'));
      expect(log.length).toBeGreaterThan(0);
    });

    it('skips questions already in the bank and refuses the same file twice', async () => {
      const src = await source('permission_granted');
      const file = [HEADER, good(60), good(61)].join('\n');
      const first = await upload(editor, file, {
        dryRun: false,
        source: src,
      }).expect(201);
      expect(first.body.totals.created).toBe(2);
      const again = await upload(editor, file, {
        dryRun: false,
        source: src,
      }).expect(409);
      expect(again.body.code).toBe('already_imported');
      // A different file repeating a stem is skipped.
      const other = [HEADER, good(60, { external_ref: 'exam-ref-60b' })].join(
        '\n',
      );
      const res = await upload(editor, other, {
        dryRun: false,
        source: src,
      }).expect(201);
      expect(res.body.totals).toMatchObject({ created: 0, skipped: 1 });
    });

    it('fails only the bad rows and still imports the good ones', async () => {
      const src = await source('permission_granted');
      const file = [HEADER, good(70), good(71, { exam: 'nope' })].join('\n');
      const res = await upload(editor, file, {
        dryRun: false,
        source: src,
      }).expect(201);
      expect(res.body.totals).toMatchObject({ created: 1, failed: 1 });
      expect(res.body.rows[1].problems[0]).toMatchObject({
        level: 'error',
        field: 'exam',
      });
    });

    it('cannot be published without review: it creates drafts only', async () => {
      const src = await source('permission_granted');
      await upload(editor, [HEADER, good(80)].join('\n'), {
        dryRun: false,
        source: src,
      }).expect(201);
      const published = await t.db
        .select()
        .from(questionVersions)
        .where(eq(questionVersions.contentSourceId, src));
      expect(published.every((v) => v.status === 'draft')).toBe(true);
    });
  });
});
