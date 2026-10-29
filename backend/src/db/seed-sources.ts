import { desc, eq } from 'drizzle-orm';
import type { Db } from '../core/db.js';
import { newId } from '../core/ids.js';
import { auditLog, questionVersions } from './schema.js';

/** Researched source of a bank question; `note` says how sure the research is. */
export interface BankSource {
  title: string;
  url: string | null;
  citation: string | null;
  valid_from: string;
  valid_to: string | null;
  note: string;
}

/** Placeholders the dev publish puts on questions without a source. */
export const DEV_SOURCE_TITLE = 'Nyaya starter bank (UNREVIEWED dev data)';
export const DEV_VALID_FROM = '2000-01-01';

export const sourceFields = (s: BankSource | undefined) =>
  s
    ? {
        sourceTitle: s.title,
        sourceUrl: s.url,
        citation: s.citation,
        validFrom: s.valid_from,
        validTo: s.valid_to,
      }
    : {};

/**
 * Brings an imported question's researched source in without skipping review:
 * - an open draft gets the source where it has none (or only the dev
 *   placeholders), so an editor's own source is never overwritten;
 * - a version published without review (dev seed) gets a new draft revision
 *   carrying the source, which then goes through review like any other edit.
 * Reviewed, submitted and approved versions are left alone.
 */
export async function addSources(
  db: Db,
  questionId: string,
  source: BankSource,
): Promise<'filled' | 'revised' | null> {
  const [latest] = await db
    .select()
    .from(questionVersions)
    .where(eq(questionVersions.questionId, questionId))
    .orderBy(desc(questionVersions.versionNo))
    .limit(1);
  if (!latest) return null;
  const want = sourceFields(source);
  const missingTitle =
    !latest.sourceTitle || latest.sourceTitle === DEV_SOURCE_TITLE;
  const missingFrom = !latest.validFrom || latest.validFrom === DEV_VALID_FROM;

  if (latest.status === 'draft' || latest.status === 'changes_requested') {
    if (!missingTitle && !missingFrom) return null;
    const patch = {
      ...(missingTitle && {
        sourceTitle: want.sourceTitle,
        sourceUrl: latest.sourceUrl ?? want.sourceUrl,
        citation: latest.citation ?? want.citation,
      }),
      ...(missingFrom && {
        validFrom: want.validFrom,
        validTo: latest.validTo ?? want.validTo,
      }),
    };
    await db.transaction(async (tx) => {
      await tx
        .update(questionVersions)
        .set({ ...patch, updatedAt: new Date() })
        .where(eq(questionVersions.id, latest.id));
      // Logged like an editor's change, so the question's history shows it.
      await tx.insert(auditLog).values({
        id: newId(),
        action: 'question.updated',
        entityType: 'question',
        entityId: questionId,
        data: {
          version_id: latest.id,
          fields: Object.keys(patch),
          by: 'seed',
        },
      });
    });
    return 'filled';
  }

  if (latest.status !== 'published' || latest.reviewerId) return null;
  if (!missingTitle && !missingFrom) return null;
  const {
    id: fromVersionId,
    versionNo,
    status: _s,
    verifiedAt: _va,
    reviewerId: _r,
    submittedAt: _sa,
    approvedAt: _aa,
    publishedAt: _pa,
    publishedBy: _pb,
    endedAt: _e,
    createdAt: _c,
    updatedAt: _u,
    createdBy: _cb,
    updatedBy: _ub,
    ...content
  } = latest;
  const versionId = newId();
  const changeNote = `Source and dates added from research: ${source.note}`;
  await db.transaction(async (tx) => {
    await tx.insert(questionVersions).values({
      ...content,
      ...want,
      id: versionId,
      versionNo: versionNo + 1,
      status: 'draft',
      changeNote,
    });
    await tx.insert(auditLog).values({
      id: newId(),
      action: 'question.revised',
      entityType: 'question',
      entityId: questionId,
      data: {
        version_id: versionId,
        from_version_id: fromVersionId,
        change_note: changeNote,
        by: 'seed',
      },
    });
  });
  return 'revised';
}
