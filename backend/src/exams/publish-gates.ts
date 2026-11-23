import { HttpStatus } from '@nestjs/common';
import { eq } from 'drizzle-orm';
import type { Tx } from '../core/db.js';
import { ApiError, type ErrorDetail } from '../core/errors.js';
import { examQuestionTags, questions } from '../db/schema.js';

export interface PublishBlocker extends ErrorDetail {
  code: 'exam_tag_required';
}

/**
 * What stops a question from being published on exam grounds: an exam-only
 * question needs an exam tag first (it could not be used anywhere without
 * one). An ordinary question has no blockers, so existing publishing is
 * unchanged. A content source is recorded for attribution only and never
 * blocks publishing.
 */
export async function publishBlockers(
  tx: Tx,
  questionId: string,
): Promise<PublishBlocker[]> {
  const blockers: PublishBlocker[] = [];
  const [q] = await tx
    .select({ examOnly: questions.examOnly })
    .from(questions)
    .where(eq(questions.id, questionId))
    .limit(1);
  if (q?.examOnly) {
    const [tag] = await tx
      .select({ id: examQuestionTags.questionId })
      .from(examQuestionTags)
      .where(eq(examQuestionTags.questionId, questionId))
      .limit(1);
    if (!tag)
      blockers.push({
        code: 'exam_tag_required',
        field: 'exam_tags',
        reason:
          'An exam-only question needs at least one exam tag before it can be published',
      });
  }
  return blockers;
}

/** Throws a 422 naming the first blocker's code, with every blocker in the details. */
export async function requirePublishable(
  tx: Tx,
  questionId: string,
): Promise<void> {
  const blockers = await publishBlockers(tx, questionId);
  if (blockers.length)
    throw new ApiError(
      HttpStatus.UNPROCESSABLE_ENTITY,
      blockers[0].code,
      'This question cannot be published yet',
      blockers.map(({ field, reason }) => ({ field, reason })),
    );
}
