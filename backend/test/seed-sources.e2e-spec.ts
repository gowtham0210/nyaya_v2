import { asc, eq } from 'drizzle-orm';
import { newId } from '../src/core/ids.js';
import {
  auditLog,
  questions,
  questionVersions,
  type VersionStatus,
} from '../src/db/schema.js';
import {
  addSources,
  DEV_SOURCE_TITLE,
  DEV_VALID_FROM,
  type BankSource,
} from '../src/db/seed-sources.js';
import { startApp, type TestApp } from './helpers.js';

const SOURCE: BankSource = {
  title: 'Constitution of India',
  url: 'https://legislative.gov.in/constitution-of-india/',
  citation: null,
  valid_from: '1950-01-26',
  valid_to: null,
  note: 'Original text; confirmed on legislative.gov.in (high)',
};

describe('seed: researched sources on imported questions', () => {
  let t: TestApp;

  beforeAll(async () => {
    t = await startApp();
  });
  afterAll(() => t.close());

  const question = async (
    status: VersionStatus,
    v: Partial<typeof questionVersions.$inferInsert> = {},
  ) => {
    const questionId = newId();
    const versionId = newId();
    await t.db.insert(questions).values({ id: questionId });
    await t.db.insert(questionVersions).values({
      id: versionId,
      questionId,
      versionNo: 1,
      status,
      topicId: t.topicId,
      stem: 'When did the Constitution come into force?',
      options: [
        { id: 'a', text: '26 January 1950' },
        { id: 'b', text: '15 August 1947' },
      ],
      correctOptionIds: ['a'],
      explanation: 'Republic Day.',
      provisionReference: 'Article 394, Constitution of India',
      ...v,
    });
    if (status === 'published')
      await t.db
        .update(questions)
        .set({ liveVersionId: versionId })
        .where(eq(questions.id, questionId));
    return questionId;
  };
  const versions = (questionId: string) =>
    t.db
      .select()
      .from(questionVersions)
      .where(eq(questionVersions.questionId, questionId))
      .orderBy(asc(questionVersions.versionNo));

  it('fills an imported draft in place, and only once', async () => {
    const id = await question('draft');
    expect(await addSources(t.db, id, SOURCE)).toBe('filled');
    const [v] = await versions(id);
    expect(v).toMatchObject({
      status: 'draft',
      sourceTitle: SOURCE.title,
      sourceUrl: SOURCE.url,
      validFrom: SOURCE.valid_from,
    });
    const audit = await t.db
      .select()
      .from(auditLog)
      .where(eq(auditLog.entityId, id));
    expect(audit).toHaveLength(1);
    expect(audit[0]).toMatchObject({
      action: 'question.updated',
      data: { version_id: v.id, by: 'seed' },
    });
    expect(await addSources(t.db, id, SOURCE)).toBeNull();
  });

  it("keeps an editor's own source on a draft", async () => {
    const id = await question('changes_requested', {
      sourceTitle: 'Constituent Assembly Debates',
      sourceUrl: 'https://eparlib.nic.in/',
      validFrom: '1949-11-26',
    });
    expect(await addSources(t.db, id, SOURCE)).toBeNull();
    const [v] = await versions(id);
    expect(v.sourceTitle).toBe('Constituent Assembly Debates');
  });

  it('opens a draft revision for a question published without review', async () => {
    const id = await question('published', {
      sourceTitle: DEV_SOURCE_TITLE,
      validFrom: DEV_VALID_FROM,
    });
    expect(await addSources(t.db, id, SOURCE)).toBe('revised');
    const [live, draft] = await versions(id);
    expect(live).toMatchObject({
      status: 'published',
      sourceTitle: DEV_SOURCE_TITLE,
    });
    expect(draft).toMatchObject({
      versionNo: 2,
      status: 'draft',
      stem: live.stem,
      correctOptionIds: ['a'],
      sourceTitle: SOURCE.title,
      sourceUrl: SOURCE.url,
      validFrom: SOURCE.valid_from,
      reviewerId: null,
      publishedAt: null,
    });
    expect(draft.changeNote).toContain(SOURCE.note);
    const [q] = await t.db.select().from(questions).where(eq(questions.id, id));
    expect(q.liveVersionId).toBe(live.id);
    const audit = await t.db
      .select()
      .from(auditLog)
      .where(eq(auditLog.entityId, id));
    expect(audit.map((a) => a.action)).toEqual(['question.revised']);

    // Running the seed again fills nothing more: the revision already has it.
    expect(await addSources(t.db, id, SOURCE)).toBeNull();
    expect(await versions(id)).toHaveLength(2);
  });

  it('leaves reviewed and in-review versions alone', async () => {
    const reviewer = await t.signInAs('legal_reviewer');
    const reviewed = await question('published', {
      sourceTitle: DEV_SOURCE_TITLE,
      validFrom: DEV_VALID_FROM,
      reviewerId: reviewer.id,
      verifiedAt: new Date(),
    });
    const inReview = await question('in_review');
    expect(await addSources(t.db, reviewed, SOURCE)).toBeNull();
    expect(await addSources(t.db, inReview, SOURCE)).toBeNull();
    expect(await versions(reviewed)).toHaveLength(1);
    expect((await versions(inReview))[0].sourceTitle).toBeNull();
  });
});
