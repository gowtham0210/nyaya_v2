import { existsSync, readFileSync } from 'node:fs';
import { and, eq, isNull, like, sql } from 'drizzle-orm';
import { hashPassword } from '../auth/passwords.js';
import { loadConfig } from '../core/config.js';
import { openDb, type Db } from '../core/db.js';
import { newId } from '../core/ids.js';
import {
  acts,
  auditLog,
  questions,
  questionVersions,
  subjects,
  topics,
  users,
  type Role,
} from './schema.js';

/**
 * Dev seed, safe to re-run (everything is upserted by slug, email or external ref):
 * - taxonomy built from the app's six chapters, plus the core acts;
 * - the starter question bank (seed/questions/en.json) as DRAFTS (imports
 *   never publish; each needs a source, validity date and legal review first);
 * - one account per role when SEED_PASSWORD is set (never in production);
 * - with SEED_PUBLISH_IMPORTED=true (never in production), the imported drafts
 *   are published so the app has content locally. They are marked as
 *   unreviewed dev data and must not be copied to a real database.
 */

const ACTS = [
  {
    slug: 'constitution-of-india',
    name: 'Constitution of India',
    shortName: 'Constitution',
    year: 1950,
  },
  {
    slug: 'bns-2023',
    name: 'Bharatiya Nyaya Sanhita, 2023',
    shortName: 'BNS',
    year: 2023,
  },
  {
    slug: 'bnss-2023',
    name: 'Bharatiya Nagarik Suraksha Sanhita, 2023',
    shortName: 'BNSS',
    year: 2023,
  },
  {
    slug: 'bsa-2023',
    name: 'Bharatiya Sakshya Adhiniyam, 2023',
    shortName: 'BSA',
    year: 2023,
  },
  {
    slug: 'indian-contract-act-1872',
    name: 'Indian Contract Act, 1872',
    shortName: 'Contract Act',
    year: 1872,
  },
  {
    slug: 'consumer-protection-act-2019',
    name: 'Consumer Protection Act, 2019',
    shortName: 'CPA',
    year: 2019,
  },
];

/** App chapter → its topic's primary act, where there is one. */
const CHAPTER_ACT: Record<string, string | undefined> = {
  constitution: 'constitution-of-india',
  rights: 'constitution-of-india',
  criminal: 'bns-2023',
};

const STAFF: { email: string; name: string; roles: Role[] }[] = [
  { email: 'admin@nyaya.local', name: 'Dev Admin', roles: ['admin'] },
  {
    email: 'editor@nyaya.local',
    name: 'Dev Editor',
    roles: ['content_editor'],
  },
  {
    email: 'reviewer@nyaya.local',
    name: 'Dev Reviewer',
    roles: ['legal_reviewer'],
  },
  { email: 'learner@nyaya.local', name: 'Dev Learner', roles: ['learner'] },
  {
    email: 'publisher@nyaya.local',
    name: 'Dev Publisher',
    roles: ['publisher'],
  },
];

interface Bank {
  chapters: Record<string, { title: string; subtitle: string }>;
  questions: {
    id: string;
    chapter: string;
    difficulty: number;
    question: string;
    options: string[];
    answer: number;
    explanation: string;
    reference: string;
  }[];
}

async function upsertBySlug<
  T extends typeof subjects | typeof topics | typeof acts,
>(
  db: Db,
  table: T,
  slug: string,
  values: Omit<T['$inferInsert'], 'id' | 'slug'>,
): Promise<string> {
  const [row] = await db
    .select({ id: table.id })
    .from(table as typeof subjects)
    .where(eq(table.slug, slug))
    .limit(1);
  if (row) {
    await db
      .update(table)
      .set({ ...values, updatedAt: new Date() } as never)
      .where(eq(table.id, row.id));
    return row.id;
  }
  const id = newId();
  await db.insert(table).values({ id, slug, ...values } as never);
  return id;
}

async function seed() {
  if (existsSync('.env')) process.loadEnvFile('.env');
  if (!process.env.DATABASE_URL) process.env.PGLITE_DIR ??= '.data/pglite';
  const config = loadConfig();
  const { db, close } = await openDb(config);
  const bankPath = process.env.QUESTION_BANK ?? 'seed/questions/en.json';
  const bank = JSON.parse(readFileSync(bankPath, 'utf8')) as Bank;

  const actIds: Record<string, string> = {};
  for (const a of ACTS)
    actIds[a.slug] = await upsertBySlug(db, acts, a.slug, {
      ...a,
      jurisdiction: 'IN',
    });

  const topicIds: Record<string, string> = {};
  for (const [i, [chapter, meta]] of Object.entries(bank.chapters).entries()) {
    const subjectId = await upsertBySlug(db, subjects, chapter, {
      name: meta.title,
      description: meta.subtitle,
      sortOrder: i,
    });
    const actSlug = CHAPTER_ACT[chapter];
    topicIds[chapter] = await upsertBySlug(db, topics, `${chapter}-basics`, {
      subjectId,
      actId: actSlug ? actIds[actSlug] : null,
      name: meta.subtitle,
      sortOrder: 0,
    });
  }

  let imported = 0;
  for (const q of bank.questions) {
    const externalRef = `app:${q.id}`;
    const [existing] = await db
      .select({ id: questions.id })
      .from(questions)
      .where(eq(questions.externalRef, externalRef))
      .limit(1);
    if (existing) continue;
    const letters = q.options.map((_, i) => String.fromCharCode(97 + i));
    await db.transaction(async (tx) => {
      const questionId = newId();
      const versionId = newId();
      await tx.insert(questions).values({ id: questionId, externalRef });
      await tx.insert(questionVersions).values({
        id: versionId,
        questionId,
        versionNo: 1,
        status: 'draft',
        topicId: topicIds[q.chapter],
        difficulty: q.difficulty,
        stem: q.question,
        options: q.options.map((text, i) => ({ id: letters[i], text })),
        correctOptionIds: [letters[q.answer]],
        explanation: q.explanation,
        provisionReference: q.reference,
        changeNote: 'Imported from the app question bank',
      });
      await tx.insert(auditLog).values({
        id: newId(),
        action: 'question.imported',
        entityType: 'question',
        entityId: questionId,
        data: { external_ref: externalRef, version_id: versionId },
      });
    });
    imported++;
  }

  let devPublished = 0;
  if (process.env.SEED_PUBLISH_IMPORTED === 'true') {
    if (config.isProduction)
      throw new Error('SEED_PUBLISH_IMPORTED is for development only');
    devPublished = await publishImportedForDev(db);
  }

  const password = process.env.SEED_PASSWORD;
  if (password && !config.isProduction) {
    const hash = await hashPassword(password);
    for (const s of STAFF) {
      const [u] = await db
        .select({ id: users.id })
        .from(users)
        .where(eq(users.email, s.email))
        .limit(1);
      if (u)
        await db
          .update(users)
          .set({ passwordHash: hash, roles: s.roles, updatedAt: new Date() })
          .where(eq(users.id, u.id));
      else
        await db.insert(users).values({
          id: newId(),
          email: s.email,
          displayName: s.name,
          passwordHash: hash,
          roles: s.roles,
        });
    }
  }

  console.log(
    `Seeded ${ACTS.length} acts, ${Object.keys(topicIds).length} subjects/topics, ` +
      `${imported} new draft questions (${bank.questions.length - imported} already present)` +
      (password && !config.isProduction
        ? `, ${STAFF.length} dev accounts.`
        : '. Set SEED_PASSWORD to create dev accounts.') +
      (devPublished
        ? ` Published ${devPublished} imported drafts as UNREVIEWED dev data.`
        : ''),
  );
  await close();
}

/** Dev only: publishes untouched imported drafts, skipping review. */
async function publishImportedForDev(db: Db): Promise<number> {
  const drafts = await db
    .select({ questionId: questions.id, versionId: questionVersions.id })
    .from(questions)
    .innerJoin(questionVersions, eq(questionVersions.questionId, questions.id))
    .where(
      and(
        like(questions.externalRef, 'app:%'),
        isNull(questions.liveVersionId),
        eq(questionVersions.versionNo, 1),
        eq(questionVersions.status, 'draft'),
      ),
    );
  const now = new Date();
  for (const d of drafts) {
    await db.transaction(async (tx) => {
      await tx
        .update(questionVersions)
        .set({
          status: 'published',
          sourceTitle: sql`coalesce(${questionVersions.sourceTitle}, 'Nyaya starter bank (UNREVIEWED dev data)')`,
          validFrom: sql`coalesce(${questionVersions.validFrom}, '2000-01-01')`,
          changeNote:
            'Imported from the app question bank · published by the dev seed without legal review',
          publishedAt: now,
          updatedAt: now,
        })
        .where(eq(questionVersions.id, d.versionId));
      await tx
        .update(questions)
        .set({ liveVersionId: d.versionId, updatedAt: now })
        .where(eq(questions.id, d.questionId));
      await tx.insert(auditLog).values({
        id: newId(),
        action: 'question.dev_published',
        entityType: 'question',
        entityId: d.questionId,
        data: { version_id: d.versionId },
      });
    });
  }
  return drafts.length;
}

await seed();
