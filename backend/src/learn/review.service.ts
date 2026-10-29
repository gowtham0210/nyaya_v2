import { Inject, Injectable } from '@nestjs/common';
import { and, desc, eq, inArray, sql } from 'drizzle-orm';
import { DB, type Db, type Tx } from '../core/db.js';
import { ApiError } from '../core/errors.js';
import {
  questionBookmarks,
  questions,
  questionVersions,
  type QuestionOption,
} from '../db/schema.js';
import { eligible, liveVersions } from './eligibility.js';
import type {
  BookmarkDto,
  BookmarkListDto,
  MistakeListDto,
  ReviewQuestionDto,
} from './review.dto.js';

interface Mistake {
  questionId: string;
  seenVersionId: string;
  wrong: number;
  lastWrong: Date;
}

/** Raw query rows (node-postgres and PGlite both return `rows`). */
const rowsOf = (res: unknown) =>
  (res as { rows: Record<string, unknown>[] }).rows;

/** Answers that count: final ones (exam answers only once submitted). */
const ANSWERED = sql`
  qsq.answered_at is not null
  and (s.submitted_at is not null or s.mode <> 'exam')`;

/**
 * Saved questions and the mistakes list. Mistakes are not stored: they are
 * the questions whose latest final answer was wrong, so a question leaves
 * the list the next time it is answered correctly, in any quiz.
 */
@Injectable()
export class ReviewService {
  constructor(@Inject(DB) private readonly db: Db) {}

  async mistakes(userId: string): Promise<MistakeListDto> {
    const list = await this.mistakeRows(this.db, userId);
    const shown = await this.questions(
      this.db,
      list.map((m) => ({ questionId: m.questionId, seen: m.seenVersionId })),
    );
    const saved = await this.savedIds(
      this.db,
      userId,
      list.map((m) => m.questionId),
    );
    return {
      items: list.map((m) => ({
        question: shown.get(m.questionId)!,
        wrong_count: m.wrong,
        last_wrong_at: m.lastWrong.toISOString(),
        saved: saved.has(m.questionId),
      })),
    };
  }

  /** Question ids on the mistakes list, most recent first (for mistake practice). */
  async mistakeQuestionIds(tx: Tx, userId: string): Promise<string[]> {
    return (await this.mistakeRows(tx, userId)).map((m) => m.questionId);
  }

  async bookmarks(userId: string): Promise<BookmarkListDto> {
    const rows = await this.db
      .select({
        questionId: questionBookmarks.questionId,
        savedAt: questionBookmarks.createdAt,
      })
      .from(questionBookmarks)
      .where(eq(questionBookmarks.userId, userId))
      .orderBy(desc(questionBookmarks.createdAt));
    const seen = await this.lastSeen(
      this.db,
      userId,
      rows.map((r) => r.questionId),
    );
    const shown = await this.questions(
      this.db,
      rows.map((r) => ({
        questionId: r.questionId,
        seen: seen.get(r.questionId)!,
      })),
    );
    return {
      items: rows.map((r) => ({
        question: shown.get(r.questionId)!,
        saved_at: r.savedAt.toISOString(),
      })),
    };
  }

  /** Saves a question the learner has answered (others would reveal answer keys). */
  async save(userId: string, questionId: string): Promise<BookmarkDto> {
    const seen = (await this.lastSeen(this.db, userId, [questionId])).get(
      questionId,
    );
    if (!seen) throw ApiError.notFound('Answered question');
    await this.db
      .insert(questionBookmarks)
      .values({ userId, questionId })
      .onConflictDoNothing();
    const [row] = await this.db
      .select({ savedAt: questionBookmarks.createdAt })
      .from(questionBookmarks)
      .where(
        and(
          eq(questionBookmarks.userId, userId),
          eq(questionBookmarks.questionId, questionId),
        ),
      );
    const shown = await this.questions(this.db, [{ questionId, seen }]);
    return {
      question: shown.get(questionId)!,
      saved_at: row.savedAt.toISOString(),
    };
  }

  async unsave(userId: string, questionId: string): Promise<void> {
    await this.db
      .delete(questionBookmarks)
      .where(
        and(
          eq(questionBookmarks.userId, userId),
          eq(questionBookmarks.questionId, questionId),
        ),
      );
  }

  // ---------------------------------------------------------------- helpers

  private async mistakeRows(tx: Tx, userId: string): Promise<Mistake[]> {
    const res = await tx.execute(sql`
      with seen as (
        select qv.question_id, qsq.question_version_id, qsq.is_correct, qsq.answered_at
        from quiz_session_questions qsq
        join quiz_sessions s on s.id = qsq.session_id
        join question_versions qv on qv.id = qsq.question_version_id
        where s.user_id = ${userId} and ${ANSWERED}
      ), ranked as (
        select seen.*,
          row_number() over (partition by question_id order by answered_at desc) as rn,
          count(*) filter (where not is_correct) over (partition by question_id) as wrong,
          max(answered_at) filter (where not is_correct) over (partition by question_id) as last_wrong
        from seen
      )
      select question_id, question_version_id, wrong, last_wrong
      from ranked where rn = 1 and not is_correct
      order by last_wrong desc`);
    return rowsOf(res).map((r) => ({
      questionId: String(r.question_id),
      seenVersionId: String(r.question_version_id),
      wrong: Number(r.wrong),
      lastWrong: new Date(r.last_wrong as string),
    }));
  }

  /** The latest version of each question the learner was shown and answered. */
  private async lastSeen(tx: Tx, userId: string, questionIds: string[]) {
    const out = new Map<string, string>();
    if (!questionIds.length) return out;
    const res = await tx.execute(sql`
      select distinct on (qv.question_id) qv.question_id, qsq.question_version_id
      from quiz_session_questions qsq
      join quiz_sessions s on s.id = qsq.session_id
      join question_versions qv on qv.id = qsq.question_version_id
      where s.user_id = ${userId} and ${ANSWERED}
        and qv.question_id in (${sql.join(
          questionIds.map((id) => sql`${id}::uuid`),
          sql`, `,
        )})
      order by qv.question_id, qsq.answered_at desc`);
    for (const r of rowsOf(res))
      out.set(String(r.question_id), String(r.question_version_id));
    return out;
  }

  private async savedIds(tx: Tx, userId: string, questionIds: string[]) {
    if (!questionIds.length) return new Set<string>();
    const rows = await tx
      .select({ id: questionBookmarks.questionId })
      .from(questionBookmarks)
      .where(
        and(
          eq(questionBookmarks.userId, userId),
          inArray(questionBookmarks.questionId, questionIds),
        ),
      );
    return new Set(rows.map((r) => r.id));
  }

  /**
   * Each question as the learner answered it. Answers only leave the server
   * for versions the learner answered: when the question was revised since,
   * the answered version is shown (marked updated); when it is no longer
   * live or in force, only its text is shown, as unavailable.
   */
  private async questions(
    tx: Tx,
    wanted: { questionId: string; seen: string }[],
  ): Promise<Map<string, ReviewQuestionDto>> {
    const out = new Map<string, ReviewQuestionDto>();
    if (!wanted.length) return out;
    const live = (await liveVersions(tx, {
      questionId: questions.id,
      versionId: questionVersions.id,
    }).where(
      and(
        inArray(
          questions.id,
          wanted.map((w) => w.questionId),
        ),
        eligible('en', new Date()),
      ),
    )) as unknown as { questionId: string; versionId: string }[];
    const liveOf = new Map(live.map((l) => [l.questionId, l.versionId]));
    const versions = await tx
      .select({
        id: questionVersions.id,
        stem: questionVersions.stem,
        options: questionVersions.options,
        correct: questionVersions.correctOptionIds,
        explanation: questionVersions.explanation,
        provision: questionVersions.provisionReference,
        sourceTitle: questionVersions.sourceTitle,
        topicId: questionVersions.topicId,
      })
      .from(questionVersions)
      .where(
        inArray(
          questionVersions.id,
          wanted.map((w) => w.seen),
        ),
      );
    const byId = new Map(versions.map((v) => [v.id, v]));
    for (const w of wanted) {
      const v = byId.get(w.seen);
      const liveId = liveOf.get(w.questionId);
      if (!v || !liveId) {
        out.set(w.questionId, {
          question_id: w.questionId,
          available: false,
          updated_since: false,
          stem: v?.stem ?? '',
          options: [],
          correct_option_ids: [],
          explanation: null,
          provision_reference: null,
          source_title: null,
          topic_id: null,
        });
        continue;
      }
      out.set(w.questionId, {
        question_id: w.questionId,
        available: true,
        updated_since: liveId !== w.seen,
        stem: v.stem,
        options: (v.options as QuestionOption[]).map((o) => ({
          id: o.id,
          text: o.text,
        })),
        correct_option_ids: v.correct,
        explanation: v.explanation,
        provision_reference: v.provision,
        source_title: v.sourceTitle,
        topic_id: v.topicId,
      });
    }
    return out;
  }
}
