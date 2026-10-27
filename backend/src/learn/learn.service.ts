import { HttpStatus, Inject, Injectable } from '@nestjs/common';
import {
  and,
  asc,
  count,
  desc,
  eq,
  gt,
  gte,
  inArray,
  isNull,
  lt,
  lte,
  or,
  sql,
  type SQL,
} from 'drizzle-orm';
import { DB, type Db, type Tx } from '../core/db.js';
import { ApiError } from '../core/errors.js';
import { newId } from '../core/ids.js';
import { decodeCursor, toPage, type Page } from '../core/pagination.js';
import {
  questions,
  questionVersions,
  quizSessionQuestions,
  quizSessions,
  subjects,
  topics,
  type QuestionOption,
} from '../db/schema.js';
import type {
  AnswerDto,
  AnswerResultDto,
  AttemptDto,
  AttemptsQuery,
  CatalogDto,
  FeedbackDto,
  ProgressDto,
  ResultDto,
  SessionDto,
  SessionQuestionDto,
  StartSessionDto,
} from './learn.dto.js';
import {
  MAX_QUESTIONS,
  SCORING_VERSION,
  indiaToday,
  isCorrect,
  scoreSession,
  sessionDeadline,
  shuffled,
} from './scoring.js';

type SessionRow = typeof quizSessions.$inferSelect;

/** A session question joined with the version it shows. */
interface Row {
  position: number;
  questionVersionId: string;
  topicId: string;
  optionOrder: string[];
  selectedOptionIds: string[] | null;
  answeredAt: Date | null;
  difficulty: number;
  questionType: string;
  stem: string;
  options: QuestionOption[];
  correctOptionIds: string[];
  explanation: string;
  sourceTitle: string | null;
  sourceUrl: string | null;
  provisionReference: string | null;
}

const err = (status: HttpStatus, code: string, message: string) =>
  new ApiError(status, code, message);

/**
 * Learner side of the question bank. Learners only ever see published
 * versions that are in force today, the server picks and scores every
 * question, and answer keys leave the server only after a question is
 * answered (practice) or the session is submitted (exam).
 */
@Injectable()
export class LearnService {
  constructor(@Inject(DB) private readonly db: Db) {}

  /** Published, live, in force today, in an active topic and subject. */
  private eligible(language: string, now: Date): SQL {
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
  private liveVersions(tx: Tx, fields: Parameters<Db['select']>[0]) {
    return tx
      .select(fields!)
      .from(questionVersions)
      .innerJoin(questions, eq(questions.liveVersionId, questionVersions.id))
      .innerJoin(topics, eq(topics.id, questionVersions.topicId))
      .innerJoin(subjects, eq(subjects.id, topics.subjectId));
  }

  async catalog(language = 'en'): Promise<CatalogDto> {
    const rows = await this.liveVersions(this.db, {
      topicId: topics.id,
      topicSlug: topics.slug,
      topicName: topics.name,
      subjectId: subjects.id,
      subjectSlug: subjects.slug,
      subjectName: subjects.name,
      difficulty: questionVersions.difficulty,
      n: count(),
    })
      .where(this.eligible(language, new Date()))
      .groupBy(
        topics.id,
        topics.slug,
        topics.name,
        topics.sortOrder,
        subjects.id,
        subjects.slug,
        subjects.name,
        subjects.sortOrder,
        questionVersions.difficulty,
      )
      .orderBy(asc(subjects.sortOrder), asc(topics.sortOrder));

    const byTopic = new Map<string, CatalogDto['topics'][number]>();
    for (const r of rows as unknown as {
      topicId: string;
      topicSlug: string;
      topicName: string;
      subjectId: string;
      subjectSlug: string;
      subjectName: string;
      difficulty: number;
      n: number;
    }[]) {
      const t =
        byTopic.get(r.topicId) ??
        byTopic
          .set(r.topicId, {
            topic_id: r.topicId,
            topic_slug: r.topicSlug,
            topic_name: r.topicName,
            subject_id: r.subjectId,
            subject_slug: r.subjectSlug,
            subject_name: r.subjectName,
            available: 0,
            by_difficulty: { '1': 0, '2': 0, '3': 0 },
          })
          .get(r.topicId)!;
      t.available += Number(r.n);
      t.by_difficulty[String(r.difficulty)] = Number(r.n);
    }
    return {
      language,
      topics: [...byTopic.values()],
      max_questions: MAX_QUESTIONS,
    };
  }

  async start(userId: string, dto: StartSessionDto): Promise<SessionDto> {
    const language = dto.language ?? 'en';
    const wanted = dto.question_count ?? 10;
    const topicIds = [
      ...new Set([
        ...(dto.topic_ids ?? []),
        ...(dto.topic_id ? [dto.topic_id] : []),
      ]),
    ];
    const now = new Date();
    const daily = dto.daily ? indiaToday(now) : null;
    return this.db.transaction(async (tx) => {
      if (topicIds.length) {
        const found = await tx
          .select({ id: topics.id })
          .from(topics)
          .innerJoin(subjects, eq(subjects.id, topics.subjectId))
          .where(
            and(
              inArray(topics.id, topicIds),
              eq(topics.isActive, true),
              eq(subjects.isActive, true),
            ),
          );
        if (found.length !== topicIds.length) throw ApiError.notFound('Topic');
      }

      const where = [this.eligible(language, now)];
      if (topicIds.length)
        where.push(inArray(questionVersions.topicId, topicIds));
      if (dto.difficulty)
        where.push(eq(questionVersions.difficulty, dto.difficulty));
      if (dto.min_difficulty)
        where.push(gte(questionVersions.difficulty, dto.min_difficulty));
      if (dto.max_difficulty)
        where.push(lte(questionVersions.difficulty, dto.max_difficulty));
      const picked = (await this.liveVersions(tx, {
        id: questionVersions.id,
        options: questionVersions.options,
      })
        .where(and(...where))
        // A daily set is ordered by a hash of the date, so everyone gets the same questions.
        .orderBy(
          daily
            ? sql`md5(${questionVersions.id}::text || ${daily})`
            : sql`random()`,
        )
        .limit(wanted)) as unknown as {
        id: string;
        options: QuestionOption[];
      }[];
      if (picked.length === 0) {
        throw err(
          HttpStatus.UNPROCESSABLE_ENTITY,
          'no_questions_available',
          'No published questions match this quiz yet',
        );
      }

      const sessionId = newId();
      await tx.insert(quizSessions).values({
        id: sessionId,
        userId,
        topicId: topicIds.length === 1 ? topicIds[0] : null,
        topicIds,
        language,
        difficulty: dto.difficulty ?? null,
        minDifficulty: dto.min_difficulty ?? null,
        maxDifficulty: dto.max_difficulty ?? null,
        daily,
        feedbackMode: dto.feedback_mode ?? 'immediate',
        scoringVersion: SCORING_VERSION,
        questionCount: picked.length,
        startedAt: now,
        expiresAt: sessionDeadline(now, picked.length),
      });
      await tx.insert(quizSessionQuestions).values(
        picked.map((p, i) => ({
          sessionId,
          position: i + 1,
          questionVersionId: p.id,
          optionOrder: shuffled(p.options.map((o) => o.id)),
        })),
      );
      return this.view(tx, await this.load(tx, userId, sessionId));
    });
  }

  async get(userId: string, id: string): Promise<SessionDto> {
    return this.view(this.db, await this.load(this.db, userId, id));
  }

  /**
   * Saves one answer. In immediate mode an answer is final: re-sending the
   * same one returns the stored result (safe retry), a different one is refused.
   */
  async answer(
    userId: string,
    id: string,
    dto: AnswerDto,
  ): Promise<AnswerResultDto> {
    return this.db.transaction(async (tx) => {
      const s = await this.load(tx, userId, id, true);
      if (s.status === 'submitted')
        throw err(
          HttpStatus.CONFLICT,
          'session_submitted',
          'This quiz has already been submitted',
        );
      const [q] = (await this.rows(tx, s.id)).filter(
        (r) => r.position === dto.position,
      );
      if (!q)
        throw err(
          HttpStatus.BAD_REQUEST,
          'invalid_answer',
          'There is no question at this position',
        );

      const selected = dto.selected_option_ids;
      const same =
        !!q.selectedOptionIds &&
        [...q.selectedOptionIds].sort().join() === [...selected].sort().join();
      if (s.feedbackMode === 'immediate' && q.answeredAt) {
        if (!same)
          throw err(
            HttpStatus.CONFLICT,
            'already_answered',
            'This question has already been answered',
          );
        return this.answerView(s, q);
      }
      if (new Date() > s.expiresAt)
        throw err(
          HttpStatus.CONFLICT,
          'session_expired',
          'Time is up for this quiz; submit it to see your result',
        );

      const ids = new Set(q.options.map((o) => o.id));
      if (
        new Set(selected).size !== selected.length ||
        selected.some((o) => !ids.has(o))
      ) {
        throw err(
          HttpStatus.BAD_REQUEST,
          'invalid_answer',
          'Choose from the options shown',
        );
      }
      if (q.questionType === 'single_select' && selected.length !== 1) {
        throw err(
          HttpStatus.BAD_REQUEST,
          'invalid_answer',
          'Choose exactly one option',
        );
      }

      const answeredAt = new Date();
      await tx
        .update(quizSessionQuestions)
        .set({
          selectedOptionIds: selected,
          answeredAt,
          isCorrect: isCorrect(selected, q.correctOptionIds),
        })
        .where(
          and(
            eq(quizSessionQuestions.sessionId, s.id),
            eq(quizSessionQuestions.position, q.position),
          ),
        );
      return this.answerView(s, {
        ...q,
        selectedOptionIds: selected,
        answeredAt,
      });
    });
  }

  /** Finalises and scores the session. Submitting again returns the same result. */
  async submit(userId: string, id: string): Promise<ResultDto> {
    return this.db.transaction(async (tx) => {
      let s = await this.load(tx, userId, id, true);
      if (s.status === 'in_progress') {
        const rows = await this.rows(tx, s.id);
        const scored = scoreSession(rows);
        await tx
          .update(quizSessions)
          .set({ status: 'submitted', submittedAt: new Date(), ...scored })
          .where(eq(quizSessions.id, s.id));
        s = await this.load(tx, userId, id);
      }
      return this.resultView(tx, s);
    });
  }

  async result(userId: string, id: string): Promise<ResultDto> {
    const s = await this.load(this.db, userId, id);
    if (s.status !== 'submitted')
      throw err(
        HttpStatus.CONFLICT,
        'not_submitted',
        'Submit the quiz to see its result',
      );
    return this.resultView(this.db, s);
  }

  async attempts(
    userId: string,
    query: AttemptsQuery,
  ): Promise<Page<AttemptDto>> {
    const limit = query.limit ?? 20;
    const after = decodeCursor(query.cursor);
    const where = [
      eq(quizSessions.userId, userId),
      eq(quizSessions.status, 'submitted'),
    ];
    if (after) where.push(lt(quizSessions.id, after));
    const rows = await this.db
      .select()
      .from(quizSessions)
      .where(and(...where))
      .orderBy(desc(quizSessions.id))
      .limit(limit + 1);
    return toPage(rows, limit, (s) => ({
      session_id: s.id,
      topic_ids: s.topicIds,
      score: s.score!,
      total: s.questionCount,
      scoring_version: s.scoringVersion,
      feedback_mode: s.feedbackMode,
      submitted_at: s.submittedAt!.toISOString(),
    }));
  }

  /**
   * Totals per topic over submitted sessions, counted from the questions
   * actually shown (a session can span topics). Accuracy counts unanswered
   * questions as wrong; best is the highest share correct in one session.
   */
  async progress(userId: string): Promise<ProgressDto> {
    const perSession = this.db
      .select({
        sessionId: quizSessions.id,
        topicId: questionVersions.topicId,
        submittedAt: quizSessions.submittedAt,
        shown: count().as('shown'),
        answered: sql<number>`count(${quizSessionQuestions.answeredAt})`.as(
          'answered',
        ),
        correct:
          sql<number>`count(*) filter (where ${quizSessionQuestions.isCorrect})`.as(
            'correct',
          ),
      })
      .from(quizSessionQuestions)
      .innerJoin(
        quizSessions,
        eq(quizSessions.id, quizSessionQuestions.sessionId),
      )
      .innerJoin(
        questionVersions,
        eq(questionVersions.id, quizSessionQuestions.questionVersionId),
      )
      .where(
        and(
          eq(quizSessions.userId, userId),
          eq(quizSessions.status, 'submitted'),
        ),
      )
      .groupBy(
        quizSessions.id,
        questionVersions.topicId,
        quizSessions.submittedAt,
      )
      .as('per_session');

    const rows = await this.db
      .select({
        topicId: perSession.topicId,
        attempts: count(),
        shown: sql<number>`sum(${perSession.shown})`.mapWith(Number),
        answered: sql<number>`sum(${perSession.answered})`.mapWith(Number),
        correct: sql<number>`sum(${perSession.correct})`.mapWith(Number),
        best: sql<number>`max(${perSession.correct}::float / ${perSession.shown})`.mapWith(
          Number,
        ),
        last: sql<Date>`max(${perSession.submittedAt})`.mapWith(
          (v: string | Date) => new Date(v),
        ),
      })
      .from(perSession)
      .groupBy(perSession.topicId)
      .orderBy(desc(sql`max(${perSession.submittedAt})`));

    const topicsOut = rows.map((r) => ({
      topic_id: r.topicId,
      attempts: Number(r.attempts),
      questions_answered: r.answered,
      correct: r.correct,
      accuracy: r.shown ? r.correct / r.shown : 0,
      best: r.best,
      last_attempt_at: r.last.toISOString(),
    }));
    const [totals] = await this.db
      .select({
        attempts: count(),
        answered:
          sql<number>`coalesce(sum(${quizSessions.answeredCount}), 0)`.mapWith(
            Number,
          ),
        correct:
          sql<number>`coalesce(sum(${quizSessions.correctCount}), 0)`.mapWith(
            Number,
          ),
      })
      .from(quizSessions)
      .where(
        and(
          eq(quizSessions.userId, userId),
          eq(quizSessions.status, 'submitted'),
        ),
      );
    return {
      attempts: Number(totals.attempts),
      questions_answered: totals.answered,
      correct: totals.correct,
      topics: topicsOut,
    };
  }

  // ---------------------------------------------------------------- helpers

  /** Someone else's session is reported as not found, so ids reveal nothing. */
  private async load(
    tx: Tx,
    userId: string,
    id: string,
    lock = false,
  ): Promise<SessionRow> {
    const base = tx
      .select()
      .from(quizSessions)
      .where(and(eq(quizSessions.id, id), eq(quizSessions.userId, userId)));
    const [s] = lock ? await base.for('update').limit(1) : await base.limit(1);
    if (!s) throw ApiError.notFound('Quiz session');
    return s;
  }

  private rows(tx: Tx, sessionId: string): Promise<Row[]> {
    return tx
      .select({
        position: quizSessionQuestions.position,
        questionVersionId: quizSessionQuestions.questionVersionId,
        topicId: questionVersions.topicId,
        optionOrder: quizSessionQuestions.optionOrder,
        selectedOptionIds: quizSessionQuestions.selectedOptionIds,
        answeredAt: quizSessionQuestions.answeredAt,
        difficulty: questionVersions.difficulty,
        questionType: questionVersions.questionType,
        stem: questionVersions.stem,
        options: questionVersions.options,
        correctOptionIds: questionVersions.correctOptionIds,
        explanation: questionVersions.explanation,
        sourceTitle: questionVersions.sourceTitle,
        sourceUrl: questionVersions.sourceUrl,
        provisionReference: questionVersions.provisionReference,
      })
      .from(quizSessionQuestions)
      .innerJoin(
        questionVersions,
        eq(questionVersions.id, quizSessionQuestions.questionVersionId),
      )
      .where(eq(quizSessionQuestions.sessionId, sessionId))
      .orderBy(asc(quizSessionQuestions.position));
  }

  private feedback(q: Row): FeedbackDto {
    return {
      correct:
        !!q.selectedOptionIds &&
        isCorrect(q.selectedOptionIds, q.correctOptionIds),
      correct_option_ids: q.correctOptionIds,
      explanation: q.explanation,
      source_title: q.sourceTitle,
      source_url: q.sourceUrl,
      provision_reference: q.provisionReference,
    };
  }

  /** The only place questions are rendered for learners; it decides when the key is revealed. */
  private questionView(s: SessionRow, q: Row): SessionQuestionDto {
    const reveal =
      s.status === 'submitted' ||
      (s.feedbackMode === 'immediate' && !!q.answeredAt);
    const byId = new Map(q.options.map((o) => [o.id, o]));
    return {
      position: q.position,
      question_version_id: q.questionVersionId,
      topic_id: q.topicId,
      difficulty: q.difficulty,
      stem: q.stem,
      options: q.optionOrder.map((id) => ({
        id,
        text: byId.get(id)?.text ?? '',
      })),
      selected_option_ids: q.selectedOptionIds,
      answered_at: q.answeredAt?.toISOString() ?? null,
      feedback: reveal ? this.feedback(q) : null,
    };
  }

  private answerView(s: SessionRow, q: Row): AnswerResultDto {
    return {
      position: q.position,
      selected_option_ids: q.selectedOptionIds!,
      answered_at: q.answeredAt!.toISOString(),
      feedback: s.feedbackMode === 'immediate' ? this.feedback(q) : null,
    };
  }

  private async view(tx: Tx, s: SessionRow): Promise<SessionDto> {
    const rows = await this.rows(tx, s.id);
    return {
      id: s.id,
      topic_ids: s.topicIds,
      daily: s.daily,
      language: s.language,
      difficulty: s.difficulty,
      feedback_mode: s.feedbackMode,
      status: s.status,
      scoring_version: s.scoringVersion,
      question_count: s.questionCount,
      started_at: s.startedAt.toISOString(),
      expires_at: s.expiresAt.toISOString(),
      submitted_at: s.submittedAt?.toISOString() ?? null,
      questions: rows.map((q) => this.questionView(s, q)),
    };
  }

  private async resultView(tx: Tx, s: SessionRow): Promise<ResultDto> {
    const rows = await this.rows(tx, s.id);
    return {
      session_id: s.id,
      topic_ids: s.topicIds,
      scoring_version: s.scoringVersion,
      score: s.score!,
      total: s.questionCount,
      correct_count: s.correctCount!,
      answered_count: s.answeredCount!,
      started_at: s.startedAt.toISOString(),
      submitted_at: s.submittedAt!.toISOString(),
      duration_seconds: Math.round(
        (s.submittedAt!.getTime() - s.startedAt.getTime()) / 1000,
      ),
      questions: rows.map((q) => this.questionView(s, q)),
    };
  }
}
