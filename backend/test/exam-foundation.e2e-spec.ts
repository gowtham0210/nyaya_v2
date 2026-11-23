import { eq } from 'drizzle-orm';
import { newId } from '../src/core/ids.js';
import {
  acts,
  contentSources,
  examBlueprints,
  examQuestionTags,
  examSectionTopics,
  examSections,
  exams,
  questionVersionActs,
  questions,
  questionVersions,
} from '../src/db/schema.js';
import { startApp, type TestApp } from './helpers.js';

/** The schema added for mock exams: defaults keep ordinary questions unchanged and the checks hold. */
describe('exam foundation schema', () => {
  let t: TestApp;

  beforeAll(async () => {
    t = await startApp();
  });
  afterAll(async () => {
    await t.close();
  });

  const addQuestion = async (
    extra: Partial<typeof questionVersions.$inferInsert> = {},
  ) => {
    const questionId = newId();
    const versionId = newId();
    await t.db.insert(questions).values({ id: questionId });
    await t.db.insert(questionVersions).values({
      id: versionId,
      questionId,
      versionNo: 1,
      topicId: t.topicId,
      stem: 'Which article guarantees equality before law?',
      options: [
        { id: 'a', text: 'Article 14' },
        { id: 'b', text: 'Article 19' },
      ],
      correctOptionIds: ['a'],
      ...extra,
    });
    return { questionId, versionId };
  };

  const addExam = async (slug = `aibe-${newId()}`) => {
    const id = newId();
    await t.db
      .insert(exams)
      .values({ id, slug, name: 'AIBE', shortName: 'AIBE' });
    return id;
  };

  const blueprint = (
    examId: string,
    over: Partial<typeof examBlueprints.$inferInsert> = {},
  ) => ({
    id: newId(),
    examId,
    code: 'aibe-test',
    durationSeconds: 10_800,
    totalQuestions: 100,
    marksCorrect: '1',
    ...over,
  });

  it('leaves an ordinary question as it was: not exam-only, neutral, no source', async () => {
    const { questionId, versionId } = await addQuestion();
    const [q] = await t.db
      .select()
      .from(questions)
      .where(eq(questions.id, questionId));
    const [v] = await t.db
      .select()
      .from(questionVersions)
      .where(eq(questionVersions.id, versionId));
    expect(q.examOnly).toBe(false);
    expect(v.lawRegime).toBe('neutral');
    expect(v.lockOptionOrder).toBe(false);
    expect(v.alternateCorrectOptionIds).toEqual([]);
    expect(v.contentSourceId).toBeNull();
    expect(v.conceptKey).toBeNull();
    expect(v.currencyNote).toBeNull();
  });

  it('accepts alternate answers that differ from the correct one, and refuses overlap', async () => {
    const ok = await addQuestion({ alternateCorrectOptionIds: ['b'] });
    const [v] = await t.db
      .select()
      .from(questionVersions)
      .where(eq(questionVersions.id, ok.versionId));
    expect(v.alternateCorrectOptionIds).toEqual(['b']);
    await expect(
      addQuestion({ alternateCorrectOptionIds: ['a'] }),
    ).rejects.toThrow();
  });

  it('starts a content source as pending and checks its url and hash', async () => {
    const id = newId();
    await t.db.insert(contentSources).values({
      id,
      kind: 'third_party',
      title: 'A compilation',
      url: 'https://example.com/paper.pdf',
      sha256: 'a'.repeat(64),
    });
    const [s] = await t.db
      .select()
      .from(contentSources)
      .where(eq(contentSources.id, id));
    expect(s.licenseStatus).toBe('pending');
    expect(s.allowedUses).toEqual([]);
    await expect(
      t.db.insert(contentSources).values({
        id: newId(),
        kind: 'third_party',
        title: 'x',
        url: 'http://example.com',
      }),
    ).rejects.toThrow();
    await expect(
      t.db.insert(contentSources).values({
        id: newId(),
        kind: 'third_party',
        title: 'x',
        sha256: 'NOTHEX',
      }),
    ).rejects.toThrow();
  });

  it('links a question version to its content source', async () => {
    const sourceId = newId();
    await t.db
      .insert(contentSources)
      .values({ id: sourceId, kind: 'official_bci', title: 'BCI key' });
    const { versionId } = await addQuestion({ contentSourceId: sourceId });
    const [v] = await t.db
      .select()
      .from(questionVersions)
      .where(eq(questionVersions.id, versionId));
    expect(v.contentSourceId).toBe(sourceId);
  });

  it('records which Acts a question is about, and which Act replaced another', async () => {
    const oldId = newId();
    const newActId = newId();
    await t.db
      .insert(acts)
      .values({ id: newActId, slug: `bns-${newId()}`, name: 'New code' });
    await t.db.insert(acts).values({
      id: oldId,
      slug: `ipc-${newId()}`,
      name: 'Old code',
      repealedOn: '2024-07-01',
      replacedByActId: newActId,
    });
    const [old] = await t.db.select().from(acts).where(eq(acts.id, oldId));
    expect(old.replacedByActId).toBe(newActId);
    expect(old.repealedOn).toBe('2024-07-01');

    const { versionId } = await addQuestion({ lawRegime: 'old_codes' });
    await t.db.insert(questionVersionActs).values({ versionId, actId: oldId });
    await expect(
      t.db.insert(questionVersionActs).values({ versionId, actId: oldId }),
    ).rejects.toThrow();
  });

  it('keeps a new exam inactive and its blueprint unverified and draft', async () => {
    const examId = await addExam();
    const bp = blueprint(examId);
    await t.db.insert(examBlueprints).values(bp);
    const [e] = await t.db.select().from(exams).where(eq(exams.id, examId));
    const [b] = await t.db
      .select()
      .from(examBlueprints)
      .where(eq(examBlueprints.id, bp.id));
    expect(e.isActive).toBe(false);
    expect(b.status).toBe('draft');
    expect(b.configStatus).toBe('unverified');
    expect(b.negativeMarks).toBe('0.00');
    expect(b.sectionNavigation).toBe('free');
    expect(b.lawRegimeFilter).toBe('any');
    expect(b.alternateAnswerPolicy).toBe('any_accepted');
  });

  it('enforces blueprint rules', async () => {
    const examId = await addExam();
    await t.db.insert(examBlueprints).values(blueprint(examId));
    // Same exam, code and version twice.
    await expect(
      t.db.insert(examBlueprints).values(blueprint(examId)),
    ).rejects.toThrow();
    // A new version of the same code is fine.
    await t.db.insert(examBlueprints).values(blueprint(examId, { version: 2 }));
    await expect(
      t.db
        .insert(examBlueprints)
        .values(blueprint(examId, { code: 'a', durationSeconds: 0 })),
    ).rejects.toThrow();
    await expect(
      t.db
        .insert(examBlueprints)
        .values(blueprint(examId, { code: 'b', totalQuestions: 0 })),
    ).rejects.toThrow();
    await expect(
      t.db
        .insert(examBlueprints)
        .values(blueprint(examId, { code: 'c', negativeMarks: '-0.25' })),
    ).rejects.toThrow();
    await expect(
      t.db
        .insert(examBlueprints)
        .values(blueprint(examId, { code: 'd', passPercentGeneral: '101' })),
    ).rejects.toThrow();
  });

  it('enforces section and topic quota rules', async () => {
    const examId = await addExam();
    const bp = blueprint(examId);
    await t.db.insert(examBlueprints).values(bp);
    const sectionId = newId();
    await t.db.insert(examSections).values({
      id: sectionId,
      blueprintId: bp.id,
      code: 'cpc',
      name: 'CPC',
      position: 1,
      questionCount: 10,
    });
    const section = (over: Partial<typeof examSections.$inferInsert>) => ({
      id: newId(),
      blueprintId: bp.id,
      code: 'x',
      name: 'X',
      position: 2,
      questionCount: 5,
      ...over,
    });
    await expect(
      t.db.insert(examSections).values(section({ code: 'cpc' })),
    ).rejects.toThrow();
    await expect(
      t.db.insert(examSections).values(section({ code: 'y', position: 1 })),
    ).rejects.toThrow();
    await expect(
      t.db
        .insert(examSections)
        .values(section({ code: 'z', questionCount: 0 })),
    ).rejects.toThrow();

    await t.db
      .insert(examSectionTopics)
      .values({ sectionId, topicId: t.topicId, minCount: 2, maxCount: 8 });
    await expect(
      t.db.insert(examSectionTopics).values({ sectionId, topicId: t.topicId }),
    ).rejects.toThrow();
  });

  it('rejects a quota whose maximum is below its minimum', async () => {
    const examId = await addExam();
    const bp = blueprint(examId);
    await t.db.insert(examBlueprints).values(bp);
    const sectionId = newId();
    await t.db.insert(examSections).values({
      id: sectionId,
      blueprintId: bp.id,
      code: 's',
      name: 'S',
      position: 1,
      questionCount: 4,
    });
    await expect(
      t.db
        .insert(examSectionTopics)
        .values({ sectionId, topicId: t.topicId, minCount: 5, maxCount: 2 }),
    ).rejects.toThrow();
  });

  it('starts a blueprint as not current, and lets only a published one be current', async () => {
    const examId = await addExam();
    const draft = blueprint(examId, { code: 'draft-one' });
    await t.db.insert(examBlueprints).values(draft);
    const [row] = await t.db
      .select()
      .from(examBlueprints)
      .where(eq(examBlueprints.id, draft.id));
    expect(row.isCurrent).toBe(false);
    // A draft cannot be marked current, even by writing to the table directly.
    await expect(
      t.db
        .update(examBlueprints)
        .set({ isCurrent: true })
        .where(eq(examBlueprints.id, draft.id)),
    ).rejects.toThrow();
    await expect(
      t.db
        .insert(examBlueprints)
        .values(blueprint(examId, { code: 'born-current', isCurrent: true })),
    ).rejects.toThrow();
  });

  it('allows at most one current blueprint per exam', async () => {
    const examId = await addExam();
    const otherId = await addExam();
    const published = (code: string, exam: string, isCurrent = false) =>
      blueprint(exam, { code, status: 'published', isCurrent });
    await t.db.insert(examBlueprints).values(published('a', examId, true));
    await t.db.insert(examBlueprints).values(published('b', examId));
    // A second current one for the same exam is refused...
    await expect(
      t.db.insert(examBlueprints).values(published('c', examId, true)),
    ).rejects.toThrow();
    // ...but another exam has its own.
    await t.db.insert(examBlueprints).values(published('a', otherId, true));
  });

  it('tags a question for an exam once', async () => {
    const examId = await addExam();
    const { questionId } = await addQuestion();
    await t.db.insert(examQuestionTags).values({ questionId, examId });
    await expect(
      t.db.insert(examQuestionTags).values({ questionId, examId }),
    ).rejects.toThrow();
  });
});
