import { eq } from 'drizzle-orm';
import type { Db } from '../core/db.js';
import { newId } from '../core/ids.js';
import { auditLog, subjects, topics } from '../db/schema.js';

/**
 * The five sections of the CLAT UG paper, as topics. Topics are global (one
 * table, one slug each); an exam reaches a topic only through a blueprint
 * section or a question's exam tag. They live under their own subject, which
 * is created inactive, the same way the admin API creates every new subject.
 * The learner app lists only active subjects, so these topics never show up
 * in the games, and an imported exam question is exam-only anyway.
 */
export const CLAT_SUBJECT = {
  slug: 'clat-ug',
  name: 'CLAT UG sections',
  description: 'Section subjects of the CLAT undergraduate paper (exam use only)',
} as const;

export const CLAT_TOPICS: readonly { slug: string; name: string }[] = [
  { slug: 'english-language', name: 'English Language' },
  {
    slug: 'current-affairs-including-general-knowledge',
    name: 'Current Affairs including General Knowledge',
  },
  { slug: 'legal-reasoning', name: 'Legal Reasoning' },
  { slug: 'logical-reasoning', name: 'Logical Reasoning' },
  { slug: 'quantitative-aptitude', name: 'Quantitative Aptitude' },
];

/**
 * Creates the CLAT section topics that are missing. Safe to run again and
 * safe in any environment: a topic that already exists (same slug, or the
 * same name in any subject, in any case) is left exactly as it is, so no
 * duplicate is ever made and nothing existing is changed. It creates no
 * question, exam or blueprint.
 */
export async function seedClatTopics(
  db: Db,
): Promise<{ created: string[]; existing: string[] }> {
  const created: string[] = [];
  const existing: string[] = [];
  await db.transaction(async (tx) => {
    let [subject] = await tx
      .select({ id: subjects.id })
      .from(subjects)
      .where(eq(subjects.slug, CLAT_SUBJECT.slug))
      .limit(1);
    const have = await tx
      .select({ slug: topics.slug, name: topics.name })
      .from(topics);
    const slugs = new Set(have.map((t) => t.slug));
    const names = new Set(have.map((t) => t.name.trim().toLowerCase()));
    const missing = CLAT_TOPICS.filter(
      (t) => !slugs.has(t.slug) && !names.has(t.name.toLowerCase()),
    );
    for (const t of CLAT_TOPICS)
      if (!missing.includes(t)) existing.push(t.slug);
    if (missing.length === 0) return;

    if (!subject) {
      const id = newId();
      await tx.insert(subjects).values({
        id,
        slug: CLAT_SUBJECT.slug,
        name: CLAT_SUBJECT.name,
        description: CLAT_SUBJECT.description,
        sortOrder: 900,
        isActive: false,
      });
      await tx.insert(auditLog).values({
        id: newId(),
        action: 'subject.seeded',
        entityType: 'subject',
        entityId: id,
        data: { slug: CLAT_SUBJECT.slug },
      });
      subject = { id };
    }
    for (const t of missing) {
      const id = newId();
      await tx.insert(topics).values({
        id,
        subjectId: subject.id,
        slug: t.slug,
        name: t.name,
        sortOrder: CLAT_TOPICS.indexOf(t) + 1,
        isActive: true,
      });
      await tx.insert(auditLog).values({
        id: newId(),
        action: 'topic.seeded',
        entityType: 'topic',
        entityId: id,
        data: { slug: t.slug },
      });
      created.push(t.slug);
    }
  });
  return { created, existing };
}
