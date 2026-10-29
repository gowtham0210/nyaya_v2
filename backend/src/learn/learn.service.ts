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
  isNotNull,
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
  chestOpenings,
  questions,
  questionVersions,
  quizSessionQuestions,
  quizSessions,
  quizSessionTopics,
  subjects,
  topics,
  type QuestionOption,
  type QuizMode,
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
  RewardsDto,
  SessionDto,
  SessionQuestionDto,
  StartSessionDto,
} from './learn.dto.js';
import { sessionXp, stars, type AnsweredQuestion } from './rewards.js';
import {
  EXAM_NEGATIVE_VERSION,
  MAX_QUESTIONS,
  SCORING_VERSION,
  dailySetDate,
  feedbackModeFor,
  indiaToday,
  isCorrect,
  isoWeek,
  scoreFor,
  scoreSession,
  sessionDeadline,
  shuffled,
} from './scoring.js';
import { milestoneFor, streakOn } from './streak.js';

/** A session row with its topics; everything else about it is worked out from these. */
type SessionRow = typeof quizSessions.$inferSelect & { topicIds: string[] };

const isSubmitted = (s: SessionRow) => s.submittedAt !== null;
const feedbackOf = (s: SessionRow) => feedbackModeFor(s.mode);

/** Levels per subject on the Case Path road (difficulties 1–3), then its chest. */
export const ROAD_LEVELS = 3;
const levelId = (subjectSlug: string, difficulty: number) =>
  `${subjectSlug}_${difficulty}`;
const chestId = (subjectSlug: string) => `${subjectSlug}_chest`;

/** A submitted session, as progress and rewards need it. */
interface Finished {
  id: string;
  mode: QuizMode;
  submittedAt: Date;
  day: string;
  correct: number;
  answered: number;
  total: number;
  xp: number;
  /** Case Path level, e.g. constitution_2. */
  level: string | null;
}

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
    const minDifficulty = dto.difficulty ?? dto.min_difficulty ?? null;
    const maxDifficulty = dto.difficulty ?? dto.max_difficulty ?? null;
    const now = new Date();
    const daily = dailySetDate(dto.mode, now);
    return this.db.transaction(async (tx) => {
      let subjectIds = new Set<string>();
      if (topicIds.length) {
        const found = await tx
          .select({ id: topics.id, subjectId: topics.subjectId })
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
        subjectIds = new Set(found.map((t) => t.subjectId));
      }
      if (
        dto.mode === 'case_path' &&
        (subjectIds.size !== 1 ||
          minDifficulty === null ||
          minDifficulty !== maxDifficulty)
      )
        throw err(
          HttpStatus.BAD_REQUEST,
          'invalid_quiz',
          'A Case Path level is one subject at one difficulty',
        );
      if (
        dto.mode === 'daily_docket' &&
        (await this.docketDone(tx, userId, now))
      )
        throw err(
          HttpStatus.CONFLICT,
          'docket_done_today',
          "Today's docket is already done; a new one opens at midnight (India time)",
        );

      const where = [this.eligible(language, now)];
      if (topicIds.length)
        where.push(inArray(questionVersions.topicId, topicIds));
      if (minDifficulty)
        where.push(gte(questionVersions.difficulty, minDifficulty));
      if (maxDifficulty)
        where.push(lte(questionVersions.difficulty, maxDifficulty));
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
        mode: dto.mode,
        language,
        minDifficulty,
        maxDifficulty,
        scoringVersion:
          dto.mode === 'exam' && dto.negative_marking !== false
            ? EXAM_NEGATIVE_VERSION
            : SCORING_VERSION,
        questionCount: picked.length,
        startedAt: now,
      });
      if (topicIds.length)
        await tx
          .insert(quizSessionTopics)
          .values(topicIds.map((topicId) => ({ sessionId, topicId })));
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
      if (isSubmitted(s))
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
      if (feedbackOf(s) === 'immediate' && q.answeredAt) {
        if (!same)
          throw err(
            HttpStatus.CONFLICT,
            'already_answered',
            'This question has already been answered',
          );
        return this.answerView(s, q);
      }
      if (new Date() > sessionDeadline(s.startedAt, s.questionCount))
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

  /**
   * Finalises and scores the session and records its XP. Submitting again
   * returns the same result.
   */
  async submit(userId: string, id: string): Promise<ResultDto> {
    return this.db.transaction(async (tx) => {
      let s = await this.load(tx, userId, id, true);
      if (!isSubmitted(s)) {
        // One submit at a time per learner, so rewards see a settled history.
        await tx.execute(
          sql`select pg_advisory_xact_lock(hashtext(${'progress:' + userId}))`,
        );
        const rows = await this.rows(tx, s.id);
        const submittedAt = new Date();
        const scored = scoreSession(rows);
        const finished = { ...s, ...scored, submittedAt };
        const rewards = await this.rewards(tx, finished, rows);
        await tx
          .update(quizSessions)
          .set({ submittedAt, ...scored, xpAwarded: rewards.xp.total })
          .where(eq(quizSessions.id, s.id));
        s = await this.load(tx, userId, id);
      }
      return this.resultView(tx, s);
    });
  }

  async result(userId: string, id: string): Promise<ResultDto> {
    const s = await this.load(this.db, userId, id);
    if (!isSubmitted(s))
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
      isNotNull(quizSessions.submittedAt),
    ];
    if (after) where.push(lt(quizSessions.id, after));
    const rows = await this.db
      .select()
      .from(quizSessions)
      .where(and(...where))
      .orderBy(desc(quizSessions.id))
      .limit(limit + 1);
    const topicsBy = await this.topicsOf(
      this.db,
      rows.map((r) => r.id),
    );
    return toPage(rows, limit, (s) => ({
      session_id: s.id,
      mode: s.mode,
      topic_ids: topicsBy.get(s.id) ?? [],
      score: scoreFor(s.scoringVersion, s.correctCount!, s.answeredCount!),
      total: s.questionCount,
      xp: s.xpAwarded ?? 0,
      scoring_version: s.scoringVersion,
      feedback_mode: feedbackModeFor(s.mode),
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
          isNotNull(quizSessions.submittedAt),
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
    const finished = await this.finished(this.db, userId);
    return {
      ...this.summary(finished, await this.openedChests(this.db, userId)),
      attempts: finished.length,
      questions_answered: finished.reduce((n, f) => n + f.answered, 0),
      correct: finished.reduce((n, f) => n + f.correct, 0),
      topics: topicsOut,
    };
  }

  /**
   * Opens a chapter chest on the Case Path road. Only the next step on the
   * road can be opened; opening it again is harmless.
   */
  async openChest(userId: string, id: string): Promise<ProgressDto> {
    await this.db.transaction(async (tx) => {
      const road = await this.road(tx);
      const node = road.find((n) => n.kind === 'chest' && n.id === id);
      if (!node) throw ApiError.notFound('Chest');
      const opened = await this.openedChests(tx, userId);
      if (opened.has(id)) return;
      const best = this.summary(await this.finished(tx, userId), opened).stars;
      const next = road.find((n) =>
        n.kind === 'chest' ? !opened.has(n.id) : !(best[n.id] > 0),
      );
      if (next?.id !== id)
        throw err(
          HttpStatus.CONFLICT,
          'chest_locked',
          'Finish the levels before this chest first',
        );
      await tx
        .insert(chestOpenings)
        .values({ userId, subjectId: node.subjectId, openedAt: new Date() });
    });
    return this.progress(userId);
  }

  // ---------------------------------------------------------------- progress

  /** The Case Path road: each active subject's levels, then its chest. */
  private async road(tx: Tx) {
    const rows = await tx
      .select({ id: subjects.id, slug: subjects.slug })
      .from(subjects)
      .where(eq(subjects.isActive, true))
      .orderBy(asc(subjects.sortOrder), asc(subjects.slug));
    return rows.flatMap((sub) => [
      ...Array.from({ length: ROAD_LEVELS }, (_, i) => ({
        kind: 'level' as const,
        id: levelId(sub.slug, i + 1),
        subjectId: sub.id,
      })),
      { kind: 'chest' as const, id: chestId(sub.slug), subjectId: sub.id },
    ]);
  }

  private async openedChests(tx: Tx, userId: string): Promise<Set<string>> {
    const rows = await tx
      .select({ slug: subjects.slug })
      .from(chestOpenings)
      .innerJoin(subjects, eq(subjects.id, chestOpenings.subjectId))
      .where(eq(chestOpenings.userId, userId));
    return new Set(rows.map((r) => chestId(r.slug)));
  }

  /** Submitted sessions, oldest first, with each Case Path session's level. */
  private async finished(tx: Tx, userId: string): Promise<Finished[]> {
    const rows = await tx
      .select({
        id: quizSessions.id,
        mode: quizSessions.mode,
        submittedAt: quizSessions.submittedAt,
        correct: quizSessions.correctCount,
        answered: quizSessions.answeredCount,
        total: quizSessions.questionCount,
        xp: quizSessions.xpAwarded,
        difficulty: quizSessions.minDifficulty,
        subjectSlug: sql<string | null>`min(${subjects.slug})`,
      })
      .from(quizSessions)
      .leftJoin(
        quizSessionTopics,
        eq(quizSessionTopics.sessionId, quizSessions.id),
      )
      .leftJoin(topics, eq(topics.id, quizSessionTopics.topicId))
      .leftJoin(subjects, eq(subjects.id, topics.subjectId))
      .where(
        and(
          eq(quizSessions.userId, userId),
          isNotNull(quizSessions.submittedAt),
        ),
      )
      .groupBy(quizSessions.id)
      .orderBy(asc(quizSessions.submittedAt), asc(quizSessions.id));
    return rows.map((r) => ({
      id: r.id,
      mode: r.mode,
      submittedAt: r.submittedAt!,
      day: indiaToday(r.submittedAt!),
      correct: r.correct ?? 0,
      answered: r.answered ?? 0,
      total: r.total,
      xp: r.xp ?? 0,
      level:
        r.mode === 'case_path' && r.subjectSlug && r.difficulty
          ? levelId(r.subjectSlug, r.difficulty)
          : null,
    }));
  }

  /** Everything progress shows, worked out from finished sessions. */
  private summary(finished: Finished[], opened: Set<string>, now = new Date()) {
    const today = indiaToday(now);
    const week = isoWeek(today);
    const lastWeek = isoWeek(
      new Date(Date.parse(today) - 7 * 86_400_000).toISOString().slice(0, 10),
    );
    const best: Record<string, number> = {};
    let weekXp = 0;
    let lastWeekXp = 0;
    for (const f of finished) {
      if (f.level)
        best[f.level] = Math.max(best[f.level] ?? 0, stars(f.correct, f.total));
      const w = isoWeek(f.day);
      if (w === week) weekXp += f.xp;
      else if (w === lastWeek) lastWeekXp += f.xp;
    }
    const days = finished.map((f) => f.day);
    const streak = streakOn(days, today);
    const recent = (list: string[]) => [...new Set(list)].sort().slice(-21);
    return {
      today,
      total_xp: finished.reduce((n, f) => n + f.xp, 0),
      week: { week_id: week, xp: weekXp },
      last_week: { week_id: lastWeek, xp: lastWeekXp },
      streak: {
        current: streak.streak,
        longest: streak.longest,
        freezes: streak.freezes,
        last_active_day: streak.lastActiveDay,
        active_days: recent(days),
        frozen_days: recent(streak.frozenDays),
      },
      stars: best,
      opened_chests: [...opened].sort(),
      quizzes_completed: finished.length,
      quizzes_today: finished.filter((f) => f.day === today).length,
      docket_done_today: finished.some(
        (f) => f.mode === 'daily_docket' && f.day === today,
      ),
    };
  }

  private async docketDone(tx: Tx, userId: string, now: Date) {
    const today = indiaToday(now);
    return (await this.finished(tx, userId)).some(
      (f) => f.mode === 'daily_docket' && f.day === today,
    );
  }

  /** Rewards as recorded at submit (the XP total is the stored award). */
  private async storedRewards(tx: Tx, s: SessionRow, rows: Row[]) {
    const r = await this.rewards(
      tx,
      { ...s, submittedAt: s.submittedAt! },
      rows,
    );
    return { ...r, xp: { ...r.xp, total: s.xpAwarded ?? 0 } };
  }

  /**
   * What a session earns, from its answers and the learner's history before
   * it: XP (speed timed by the server, between answers), stars and streak.
   */
  private async rewards(
    tx: Tx,
    s: SessionRow & { submittedAt: Date },
    rows: Row[],
  ): Promise<RewardsDto> {
    const history = (await this.finished(tx, s.userId)).filter(
      (f) => f.id !== s.id && f.submittedAt <= s.submittedAt,
    );
    const day = indiaToday(s.submittedAt);
    const before = streakOn(
      history.map((f) => f.day),
      day,
    );
    const after = streakOn([...history.map((f) => f.day), day], day);
    const extended = !history.some((f) => f.day === day);

    let level: string | null = null;
    if (s.mode === 'case_path') {
      const [sub] = await tx
        .select({ slug: subjects.slug })
        .from(quizSessionTopics)
        .innerJoin(topics, eq(topics.id, quizSessionTopics.topicId))
        .innerJoin(subjects, eq(subjects.id, topics.subjectId))
        .where(eq(quizSessionTopics.sessionId, s.id))
        .limit(1);
      if (sub && s.minDifficulty) level = levelId(sub.slug, s.minDifficulty);
    }
    const bestBefore = Math.max(
      0,
      ...history
        .filter((f) => level && f.level === level)
        .map((f) => stars(f.correct, f.total)),
    );
    const got = level ? stars(s.correctCount!, s.questionCount) : null;
    const docketAgain =
      s.mode === 'daily_docket' &&
      history.some((f) => f.mode === 'daily_docket' && f.day === day);

    let previous = s.startedAt.getTime();
    const answered: AnsweredQuestion[] = rows.map((q) => {
      const at = q.answeredAt?.getTime() ?? previous;
      const elapsedMs = Math.max(0, at - previous);
      previous = Math.max(previous, at);
      return {
        correct:
          !!q.selectedOptionIds &&
          isCorrect(q.selectedOptionIds, q.correctOptionIds),
        difficulty: q.difficulty,
        elapsedMs,
      };
    });
    const xp = sessionXp({
      mode: s.mode,
      questions: answered,
      streak: before.streak,
      isReplayOfMastered: bestBefore === 3,
    });
    // A second docket on the same day earns nothing (the first one counts).
    if (docketAgain) xp.total = 0;
    return {
      xp,
      level_id: level,
      stars: got,
      best_stars_before: bestBefore,
      new_stars: got === null ? 0 : Math.max(0, got - bestBefore),
      streak: after.streak,
      streak_extended: extended,
      streak_milestone: extended ? milestoneFor(after.streak) : null,
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
    return {
      ...s,
      topicIds: (await this.topicsOf(tx, [s.id])).get(s.id) ?? [],
    };
  }

  private async topicsOf(tx: Tx, sessionIds: string[]) {
    const out = new Map<string, string[]>();
    if (!sessionIds.length) return out;
    const rows = await tx
      .select()
      .from(quizSessionTopics)
      .where(inArray(quizSessionTopics.sessionId, sessionIds))
      .orderBy(asc(quizSessionTopics.topicId));
    for (const r of rows)
      out.set(r.sessionId, [...(out.get(r.sessionId) ?? []), r.topicId]);
    return out;
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
      isSubmitted(s) || (feedbackOf(s) === 'immediate' && !!q.answeredAt);
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
      feedback: feedbackOf(s) === 'immediate' ? this.feedback(q) : null,
    };
  }

  private async view(tx: Tx, s: SessionRow): Promise<SessionDto> {
    const rows = await this.rows(tx, s.id);
    return {
      id: s.id,
      mode: s.mode,
      topic_ids: s.topicIds,
      daily: dailySetDate(s.mode, s.startedAt),
      language: s.language,
      difficulty:
        s.minDifficulty !== null && s.minDifficulty === s.maxDifficulty
          ? s.minDifficulty
          : null,
      feedback_mode: feedbackOf(s),
      status: isSubmitted(s) ? 'submitted' : 'in_progress',
      scoring_version: s.scoringVersion,
      question_count: s.questionCount,
      started_at: s.startedAt.toISOString(),
      expires_at: sessionDeadline(s.startedAt, s.questionCount).toISOString(),
      submitted_at: s.submittedAt?.toISOString() ?? null,
      questions: rows.map((q) => this.questionView(s, q)),
    };
  }

  private async resultView(tx: Tx, s: SessionRow): Promise<ResultDto> {
    const rows = await this.rows(tx, s.id);
    return {
      session_id: s.id,
      mode: s.mode,
      topic_ids: s.topicIds,
      scoring_version: s.scoringVersion,
      score: scoreFor(s.scoringVersion, s.correctCount!, s.answeredCount!),
      total: s.questionCount,
      correct_count: s.correctCount!,
      answered_count: s.answeredCount!,
      started_at: s.startedAt.toISOString(),
      submitted_at: s.submittedAt!.toISOString(),
      duration_seconds: Math.round(
        (s.submittedAt!.getTime() - s.startedAt.getTime()) / 1000,
      ),
      questions: rows.map((q) => this.questionView(s, q)),
      rewards: await this.rewards(
        tx,
        { ...s, submittedAt: s.submittedAt! },
        rows,
      ),
    };
  }
}
