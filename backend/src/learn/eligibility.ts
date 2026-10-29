import { and, eq, gt, isNull, lte, or, type SQL } from 'drizzle-orm';
import type { Db, Tx } from '../core/db.js';
import { questions, questionVersions, subjects, topics } from '../db/schema.js';
import { indiaToday } from './scoring.js';

/** Published, live, in force today, in an active topic and subject. */
export function eligible(language: string, now: Date): SQL {
  const today = indiaToday(now);
  return and(
    eq(questionVersions.status, 'published'),
    isNull(questions.retiredAt),
    eq(questionVersions.language, language),
    eq(questionVersions.jurisdiction, 'IN'),
    lte(questionVersions.validFrom, today),
    or(isNull(questionVersions.validTo), gt(questionVersions.validTo, today)),
    eq(topics.isActive, true),
    eq(subjects.isActive, true),
  )!;
}

/** question_versions joined to the live pointer, topic and subject. */
export function liveVersions(tx: Tx, fields: Parameters<Db['select']>[0]) {
  return tx
    .select(fields!)
    .from(questionVersions)
    .innerJoin(questions, eq(questions.liveVersionId, questionVersions.id))
    .innerJoin(topics, eq(topics.id, questionVersions.topicId))
    .innerJoin(subjects, eq(subjects.id, topics.subjectId));
}
