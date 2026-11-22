import type { Db } from '../core/db.js';
import { newId } from '../core/ids.js';
import { auditLog, exams } from '../db/schema.js';
import type { ExamSlug } from './exam-config.js';

/** The three exams, as the app will list them. They are created switched off. */
export const SEED_EXAMS: readonly {
  slug: ExamSlug;
  name: string;
  shortName: string;
  sortOrder: number;
}[] = [
  {
    slug: 'aibe',
    name: 'All India Bar Examination',
    shortName: 'AIBE',
    sortOrder: 1,
  },
  {
    slug: 'clat',
    name: 'Common Law Admission Test',
    shortName: 'CLAT',
    sortOrder: 2,
  },
  {
    slug: 'ailet',
    name: 'All India Law Entrance Test',
    shortName: 'AILET',
    sortOrder: 3,
  },
];

/**
 * Creates AIBE, CLAT and AILET if they are missing, switched off. Safe to run
 * again, and safe in any environment: an exam that already exists is left
 * exactly as it is (so a later run never switches an exam off or renames it),
 * and no blueprint, question or other content is created.
 */
export async function seedExams(
  db: Db,
): Promise<{ created: string[]; existing: string[] }> {
  const created: string[] = [];
  const existing: string[] = [];
  for (const e of SEED_EXAMS) {
    await db.transaction(async (tx) => {
      const id = newId();
      const inserted = await tx
        .insert(exams)
        .values({
          id,
          slug: e.slug,
          name: e.name,
          shortName: e.shortName,
          sortOrder: e.sortOrder,
          isActive: false,
        })
        .onConflictDoNothing({ target: exams.slug })
        .returning({ id: exams.id });
      if (inserted.length === 0) {
        existing.push(e.slug);
        return;
      }
      created.push(e.slug);
      await tx.insert(auditLog).values({
        id: newId(),
        action: 'exam.seeded',
        entityType: 'exam',
        entityId: id,
        data: { slug: e.slug },
      });
    });
  }
  return { created, existing };
}
