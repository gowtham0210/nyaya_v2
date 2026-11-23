import { count, eq } from 'drizzle-orm';
import { newId } from '../src/core/ids.js';
import {
  contentSources,
  examPapers,
  exams,
  questions,
  questionVersions,
  subjects,
  topics,
} from '../src/db/schema.js';
import { CLAT_TOPICS, seedClatTopics } from '../src/exams/exam-topic-seed.js';
import { startApp, type TestApp } from './helpers.js';

type Session = Awaited<ReturnType<TestApp['signInAs']>>;

const SECTION_NAMES = CLAT_TOPICS.map((t) => t.name);
const COLUMNS = [
  'external_ref',
  'exam',
  'topic',
  'stem',
  'option_a',
  'option_b',
  'option_c',
  'option_d',
  'correct',
  'source_title',
  'valid_from',
  'language',
];

const csv = (rows: Record<string, string>[], columns = COLUMNS) =>
  [
    columns.join(','),
    ...rows.map((r) =>
      columns.map((c) => `"${(r[c] ?? '').replace(/"/g, '""')}"`).join(','),
    ),
  ].join('\n');

const row = (n: number, over: Record<string, string> = {}) => ({
  external_ref: `clat-t-${String(n).padStart(3, '0')}`,
  exam: 'clat',
  topic: SECTION_NAMES[n % SECTION_NAMES.length],
  stem: `CLAT test question number ${n}?`,
  option_a: 'Alpha',
  option_b: 'Beta',
  option_c: 'Gamma',
  option_d: 'Delta',
  correct: 'b',
  source_title: 'Test source',
  valid_from: '2025-12-07',
  language: 'en',
  ...over,
});

describe('CLAT topics, withdrawn questions and long stems', () => {
  let t: TestApp;
  let editor: Session, admin: Session, learner: Session;
  const examIds: Record<string, string> = {};

  const upload = (
    url: string,
    rows: Record<string, string>[],
    name: string,
    fields: Record<string, string> = { dry_run: 'true', exam: 'clat' },
  ) => {
    let req = t
      .http()
      .post(url)
      .auth(editor.token, { type: 'bearer' })
      .attach('file', Buffer.from(csv(rows)), name);
    for (const [k, v] of Object.entries(fields)) req = req.field(k, v);
    return req;
  };
  const examUpload = (rows: Record<string, string>[], name = 'clat.csv') =>
    upload('/v1/admin/exam-import-jobs', rows, name);
  const source = async () => {
    const id = newId();
    await t.db.insert(contentSources).values({
      id,
      kind: 'original',
      title: 'Cleared test source',
      licenseStatus: 'permission_granted',
    });
    return id;
  };
  const qCount = async () =>
    (await t.db.select({ n: count() }).from(questions))[0].n;

  beforeAll(async () => {
    t = await startApp();
    [editor, admin, learner] = await Promise.all([
      t.signInAs('content_editor'),
      t.signInAs('admin'),
      t.signInAs('learner'),
    ]);
    for (const slug of ['aibe', 'ailet', 'clat']) {
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

  describe('CLAT section topics', () => {
    it('are refused before they exist', async () => {
      const res = await examUpload([row(0), row(1)]).expect(201);
      expect(res.body.totals).toMatchObject({ created: 0, failed: 2 });
      expect(res.body.rows[0].problems[0].reason).toMatch(/Unknown topic/);
    });

    it('are created once, under an inactive subject, and a second run changes nothing', async () => {
      const before = await t.db.select({ n: count() }).from(topics);
      const first = await seedClatTopics(t.db);
      expect(first.created).toHaveLength(5);
      expect(first.existing).toHaveLength(0);
      const second = await seedClatTopics(t.db);
      expect(second.created).toHaveLength(0);
      expect(second.existing).toHaveLength(5);
      const after = await t.db.select({ n: count() }).from(topics);
      expect(after[0].n).toBe(before[0].n + 5);

      const [subject] = await t.db
        .select()
        .from(subjects)
        .where(eq(subjects.slug, 'clat-ug'));
      expect(subject.isActive).toBe(false);
      const mine = await t.db
        .select()
        .from(topics)
        .where(eq(topics.subjectId, subject.id));
      expect(mine.map((x) => x.name).sort()).toEqual([...SECTION_NAMES].sort());
      expect(mine.every((x) => x.isActive)).toBe(true);
    });

    it('stay out of the learner-facing topic list', async () => {
      const res = await t
        .http()
        .get('/v1/taxonomy')
        .auth(learner.token, { type: 'bearer' })
        .expect(200);
      const names = JSON.stringify(res.body);
      for (const n of SECTION_NAMES) expect(names).not.toContain(n);
      expect(names).toContain('Preamble and Parliament'); // the existing topic
    });

    it('do not duplicate a topic that already exists under another slug', async () => {
      // Run on a fresh app so the earlier seed does not hide the case.
      const t2 = await startApp();
      try {
        const [subj] = await t2.db.select().from(subjects).limit(1);
        await t2.db.insert(topics).values({
          id: newId(),
          subjectId: subj.id,
          slug: 'my-own-legal-reasoning',
          name: 'legal reasoning',
        });
        const res = await seedClatTopics(t2.db);
        expect(res.created).toHaveLength(4);
        expect(res.existing).toContain('legal-reasoning');
        const all = await t2.db.select().from(topics);
        expect(
          all.filter((x) => x.name.toLowerCase() === 'legal reasoning'),
        ).toHaveLength(1);
      } finally {
        await t2.close();
      }
    });

    it('are accepted by the exam import by name or slug, while AIBE and AILET imports are unaffected', async () => {
      const res = await examUpload([
        row(0),
        row(1, { topic: 'current-affairs-including-general-knowledge' }),
        row(2),
        row(3),
        row(4),
      ]).expect(201);
      expect(res.body.totals).toMatchObject({ created: 5, failed: 0 });

      for (const slug of ['aibe', 'ailet']) {
        const other = await upload(
          '/v1/admin/exam-import-jobs',
          [
            row(10, {
              exam: slug,
              topic: 'constitution-basics',
              external_ref: `${slug}-t-1`,
            }),
          ],
          `${slug}.csv`,
          { dry_run: 'true', exam: slug },
        ).expect(201);
        expect(other.body.totals).toMatchObject({ created: 1, failed: 0 });
      }
      // An unrelated made-up topic is still refused: no bypass.
      const bad = await examUpload([row(11, { topic: 'Astrology' })]).expect(
        201,
      );
      expect(bad.body.rows[0].outcome).toBe('failed');
    });
  });

  describe('stem length', () => {
    it('is accepted at 7000 characters and refused at 7001, by the import', async () => {
      const res = await examUpload([
        row(20, { stem: 'x'.repeat(7000) }),
        row(21, { stem: 'x'.repeat(7001) }),
      ]).expect(201);
      expect(res.body.rows[0].outcome).toBe('created');
      expect(res.body.rows[1].outcome).toBe('failed');
      expect(res.body.rows[1].problems[0]).toMatchObject({
        field: 'stem',
        reason: 'Longer than 7000 characters',
      });
    });

    it('is accepted at 7000 characters and refused at 7001, by the question API (create and edit)', async () => {
      const make = (stem: string) =>
        t
          .http()
          .post('/v1/editor/questions')
          .auth(editor.token, { type: 'bearer' })
          .send({ topic_id: t.topicId, stem });
      const ok = await make('y'.repeat(7000)).expect(201);
      expect(ok.body.latest.stem).toHaveLength(7000);
      await make('y'.repeat(7001)).expect(400);
      const id = ok.body.id as string;
      await t
        .http()
        .patch(`/v1/editor/questions/${id}`)
        .auth(editor.token, { type: 'bearer' })
        .send({ stem: 'z'.repeat(7001) })
        .expect(400);
      await t
        .http()
        .patch(`/v1/editor/questions/${id}`)
        .auth(editor.token, { type: 'bearer' })
        .send({ stem: 'z'.repeat(7000) })
        .expect(200);
    });
  });

  describe('withdrawn question', () => {
    it('is recorded as a withdrawn row and creates no question', async () => {
      const before = await qCount();
      const res = await examUpload([
        row(30),
        row(31, { correct: 'WITHDRAWN' }),
        row(32),
      ]).expect(201);
      expect(res.body.totals).toMatchObject({
        created: 2,
        failed: 0,
        withdrawn: 1,
      });
      expect(res.body.rows[1]).toMatchObject({
        outcome: 'withdrawn',
        question_id: null,
      });
      expect(res.body.rows[1].problems[0].reason).toMatch(/WITHDRAWN/);
      expect(await qCount()).toBe(before); // dry run saves nothing
    });

    it('does not weaken normal validation: a blank or wrong answer still fails, and the general import still refuses WITHDRAWN', async () => {
      const res = await examUpload([
        row(40, { correct: '' }),
        row(41, { correct: 'e' }),
        row(42, { correct: 'a, b' }),
        row(43, { correct: 'withdrawn', topic: 'Astrology' }), // other errors still count
      ]).expect(201);
      expect(res.body.totals).toMatchObject({
        created: 0,
        failed: 4,
        withdrawn: 0,
      });
      const general = await t
        .http()
        .post('/v1/admin/import-jobs')
        .auth(editor.token, { type: 'bearer' })
        .attach(
          'file',
          Buffer.from(
            csv(
              [row(44, { correct: 'WITHDRAWN', topic: 'constitution-basics' })],
              COLUMNS.filter((c) => c !== 'exam'),
            ),
          ),
          'general.csv',
        )
        .field('dry_run', 'true')
        .expect(201);
      expect(general.body.rows[0].outcome).toBe('failed');
    });

    it('twice with the same reference in one file is an error', async () => {
      const res = await examUpload([
        row(50, { correct: 'WITHDRAWN' }),
        row(50, { correct: 'WITHDRAWN' }),
      ]).expect(201);
      expect(res.body.rows[0].outcome).toBe('withdrawn');
      expect(res.body.rows[1].outcome).toBe('failed');
    });
  });

  describe('duplicate questions', () => {
    const SAME =
      'Which of the following is the author most likely to agree with?';
    const T = 'Logical Reasoning'; // one topic, so only the text and options differ

    it('treats the same text with different options as different questions, but identical text and options as a duplicate', async () => {
      const res = await examUpload([
        row(60, { topic: T, stem: SAME }),
        row(61, { topic: T, stem: SAME, option_a: 'A different first option' }),
        row(62, {
          topic: T,
          stem: SAME,
          option_b: 'A different second option',
        }),
        row(63, { topic: T, stem: SAME }), // identical to row 60 in text and options
      ]).expect(201);
      expect(res.body.rows.map((r: { outcome: string }) => r.outcome)).toEqual([
        'created',
        'created',
        'created',
        'failed',
      ]);
      expect(res.body.rows[3].problems[0].reason).toBe(
        'Same question as row 2',
      );
    });

    it('also holds against questions already in the bank', async () => {
      const src = await source();
      const first = await upload(
        '/v1/admin/exam-import-jobs',
        [row(70, { topic: T, stem: SAME })],
        'first.csv',
        { dry_run: 'false', exam: 'clat', content_source_id: src },
      ).expect(201);
      expect(first.body.totals.created).toBe(1);
      const next = await upload(
        '/v1/admin/exam-import-jobs',
        [
          row(71, { topic: T, stem: SAME }), // same text and options as the one in the bank
          row(72, { topic: T, stem: SAME, option_c: 'Other third option' }), // different options
        ],
        'second.csv',
        { dry_run: 'false', exam: 'clat', content_source_id: src },
      ).expect(201);
      expect(next.body.rows.map((r: { outcome: string }) => r.outcome)).toEqual(
        ['skipped', 'created'],
      );
      expect(next.body.rows[0].problems[0].reason).toMatch(/text and options/);
    });
  });

  describe('a full 120-position paper', () => {
    it('imports 119 drafts plus one withdrawn row, retries safely, and fills all 120 positions', async () => {
      const src = await source();
      const rows = Array.from({ length: 120 }, (_, i) =>
        i + 1 === 100
          ? row(100 + 1000, { correct: 'WITHDRAWN', external_ref: 'paper-100' })
          : row(1000 + i, { external_ref: `paper-${i + 1}` }),
      );
      const real = (r: Record<string, string>[], name: string) =>
        upload('/v1/admin/exam-import-jobs', r, name, {
          dry_run: 'false',
          exam: 'clat',
          content_source_id: src,
        });
      const questionsBefore = await qCount();
      const res = await real(rows, 'paper.csv').expect(201);
      expect(res.body.totals).toMatchObject({
        created: 119,
        failed: 0,
        withdrawn: 1,
        skipped: 0,
      });
      expect(await qCount()).toBe(questionsBefore + 119);
      const jobId = res.body.id as string;

      // Everything is a draft; nothing is live and no exam was switched on.
      const imported = await t.db
        .select()
        .from(questionVersions)
        .where(eq(questionVersions.contentSourceId, src));
      expect(imported).toHaveLength(119);
      expect(imported.every((v) => v.status === 'draft')).toBe(true);
      expect(
        (await t.db.select().from(exams)).every((e) => e.isActive === false),
      ).toBe(true);

      // Same file again: refused. Edited file: nothing duplicated.
      const again = await real(rows, 'paper.csv').expect(409);
      expect(again.body.code).toBe('already_imported');
      const edited = [...rows, row(2000, { external_ref: 'paper-121' })];
      const third = await real(edited, 'paper-v2.csv').expect(201);
      expect(third.body.totals).toMatchObject({
        created: 1,
        skipped: 119,
        withdrawn: 1,
      });
      expect(await qCount()).toBe(questionsBefore + 120);

      // Before publishing: only the withdrawn slot is complete.
      const early = await t
        .http()
        .get(`/v1/admin/import-jobs/${jobId}/paper-positions`)
        .auth(editor.token, { type: 'bearer' })
        .expect(200);
      expect(early.body).toMatchObject({
        ready: 0,
        withdrawn: 1,
        not_ready: 119,
      });
      expect(early.body.positions).toHaveLength(1);
      expect(early.body.positions[0]).toMatchObject({
        position: 100,
        question_version_id: null,
        original_ref: 'paper-100',
      });

      // Publish the 119 through the data (standing in for review).
      for (const v of imported) {
        await t.db
          .update(questionVersions)
          .set({ status: 'published', publishedAt: new Date() })
          .where(eq(questionVersions.id, v.id));
        await t.db
          .update(questions)
          .set({ liveVersionId: v.id })
          .where(eq(questions.id, v.questionId));
      }
      const full = await t
        .http()
        .get(`/v1/admin/import-jobs/${jobId}/paper-positions`)
        .auth(editor.token, { type: 'bearer' })
        .expect(200);
      expect(full.body).toMatchObject({
        ready: 119,
        withdrawn: 1,
        not_ready: 0,
      });
      expect(full.body.positions).toHaveLength(120);
      expect(
        full.body.positions.map((p: { position: number }) => p.position),
      ).toEqual(Array.from({ length: 120 }, (_, i) => i + 1));

      // The unchanged paper rules take all 120 positions.
      const paper = await t
        .http()
        .post('/v1/admin/exam-papers')
        .auth(admin.token, { type: 'bearer' })
        .send({
          exam_id: examIds.clat,
          code: 'clat-2026-ug-set-a-test',
          title: 'CLAT 2026 UG Set A (test)',
          total_questions: 120,
        })
        .expect(201);
      const saved = await t
        .http()
        .put(`/v1/admin/exam-papers/${paper.body.id}/positions`)
        .auth(admin.token, { type: 'bearer' })
        .send({ positions: full.body.positions })
        .expect(200);
      expect(saved.body.positions).toHaveLength(120);
      const p100 = saved.body.positions.find(
        (p: { position: number }) => p.position === 100,
      );
      expect(p100).toMatchObject({
        answer_status: 'withdrawn',
        original_ref: 'paper-100',
      });
      expect(
        saved.body.positions.filter(
          (p: { answer_status: string }) => p.answer_status === 'withdrawn',
        ),
      ).toHaveLength(1);
      const ready = await t
        .http()
        .get(`/v1/admin/exam-papers/${paper.body.id}/readiness`)
        .auth(admin.token, { type: 'bearer' })
        .expect(200);
      expect(ready.body).toEqual({ ready: true, problems: [] });
      const [stored] = await t.db
        .select()
        .from(examPapers)
        .where(eq(examPapers.id, paper.body.id));
      expect(stored.status).toBe('draft'); // never published by the import
    });

    it('needs no content source and is not blocked by a historical licence record', async () => {
      const pending = newId();
      await t.db.insert(contentSources).values({
        id: pending,
        kind: 'third_party',
        title: 'Source with a pending historical record',
        licenseStatus: 'pending',
      });
      const withSource = await upload(
        '/v1/admin/exam-import-jobs',
        [row(3000, { correct: 'WITHDRAWN' }), row(3001)],
        'withsource.csv',
        { dry_run: 'false', exam: 'clat', content_source_id: pending },
      ).expect(201);
      expect(withSource.body.totals).toMatchObject({
        created: 1,
        withdrawn: 1,
        failed: 0,
      });
      const without = await upload(
        '/v1/admin/exam-import-jobs',
        [row(3002)],
        'nosource.csv',
        { dry_run: 'false', exam: 'clat' },
      ).expect(201);
      expect(without.body.totals).toMatchObject({ created: 1, failed: 0 });
    });
  });
});
