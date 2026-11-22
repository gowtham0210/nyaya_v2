import { count, eq } from 'drizzle-orm';
import {
  auditLog,
  examBlueprints,
  exams,
  questions,
} from '../src/db/schema.js';
import { SEED_EXAMS, seedExams } from '../src/exams/exam-seed.js';
import { startApp, type TestApp } from './helpers.js';

describe('seeding the exams', () => {
  let t: TestApp;

  beforeAll(async () => {
    t = await startApp();
  });
  afterAll(() => t.close());

  const rows = () => t.db.select().from(exams).orderBy(exams.sortOrder);

  it('creates AIBE, CLAT and AILET, all switched off, and nothing else', async () => {
    const questionsBefore = (
      await t.db.select({ n: count() }).from(questions)
    )[0].n;
    const result = await seedExams(t.db);
    expect(result).toEqual({
      created: ['aibe', 'clat', 'ailet'],
      existing: [],
    });

    const all = await rows();
    expect(all.map((e) => [e.slug, e.shortName, e.isActive])).toEqual([
      ['aibe', 'AIBE', false],
      ['clat', 'CLAT', false],
      ['ailet', 'AILET', false],
    ]);
    // No blueprints, and no questions were created.
    expect((await t.db.select({ n: count() }).from(examBlueprints))[0].n).toBe(
      0,
    );
    expect((await t.db.select({ n: count() }).from(questions))[0].n).toBe(
      questionsBefore,
    );
  });

  it('can be run again without changing anything', async () => {
    const before = await rows();
    const again = await seedExams(t.db);
    expect(again).toEqual({ created: [], existing: ['aibe', 'clat', 'ailet'] });
    expect(await rows()).toEqual(before);
    const seeded = await t.db
      .select()
      .from(auditLog)
      .where(eq(auditLog.action, 'exam.seeded'));
    expect(seeded).toHaveLength(SEED_EXAMS.length);
  });

  it('never switches an exam off or renames it on a later run', async () => {
    await t.db
      .update(exams)
      .set({ isActive: true, name: 'Renamed by an admin' })
      .where(eq(exams.slug, 'aibe'));
    await seedExams(t.db);
    const [aibe] = await t.db
      .select()
      .from(exams)
      .where(eq(exams.slug, 'aibe'));
    expect(aibe).toMatchObject({ isActive: true, name: 'Renamed by an admin' });
  });

  it('only creates the ones that are missing', async () => {
    await t.db.delete(exams).where(eq(exams.slug, 'ailet'));
    const result = await seedExams(t.db);
    expect(result).toEqual({ created: ['ailet'], existing: ['aibe', 'clat'] });
    const [ailet] = await t.db
      .select()
      .from(exams)
      .where(eq(exams.slug, 'ailet'));
    expect(ailet.isActive).toBe(false);
  });
});
