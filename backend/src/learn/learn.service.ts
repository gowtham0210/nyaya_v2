import { HttpStatus, Inject, Injectable } from '@nestjs/common';
import {
  and,
  asc,
  count,
  desc,
  eq,
  gte,
  inArray,
  isNotNull,
  lt,
  lte,
  sql,
  type SQL,
} from 'drizzle-orm';
import { APP_CONFIG, type AppConfig } from '../core/config.js';
import { DB, type Db, type Tx } from '../core/db.js';
import { AuditService, type Actor } from '../core/audit.service.js';
import { ApiError } from '../core/errors.js';
import { newId } from '../core/ids.js';
import { decodeCursor, toPage, type Page } from '../core/pagination.js';
import {
  chatUsage,
  chestOpenings,
  coinLedger,
  energyLedger,
  learnerSettings,
  premiumMemberships,
  users,
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
  SettingsDto,
  SessionDto,
  SessionQuestionDto,
  StartSessionDto,
} from './learn.dto.js';
import {
  ECONOMY,
  RULES,
  sessionXp,
  stars,
  type AnsweredQuestion,
} from './rewards.js';
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
import { eligible, liveVersions } from './eligibility.js';
import { LeagueService } from './league.service.js';
import { ReviewService } from './review.service.js';
import { milestoneFor, streakOn } from './streak.js';
import {
  addCoins,
  addEnergy,
  coinBalance,
  energyToday,
  ensureWelcome,
  freezePurchaseDays,
  isPremium,
  paidOnDay,
} from './wallet.js';

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
  questionId: string;
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
  constructor(
    @Inject(DB) private readonly db: Db,
    @Inject(APP_CONFIG) private readonly config: AppConfig,
    private readonly audit: AuditService,
    private readonly league: LeagueService,
    private readonly review: ReviewService,
  ) {}

  /** For read-only helpers the controller calls directly. */
  get database(): Db {
    return this.db;
  }

  /** One write at a time per learner, so balances and rewards see settled history. */
  private lockLearner(tx: Tx, userId: string) {
    return tx.execute(
      sql`select pg_advisory_xact_lock(hashtext(${'progress:' + userId}))`,
    );
  }

  private eligible(language: string, now: Date): SQL {
    return eligible(language, now);
  }

  private liveVersions(tx: Tx, fields: Parameters<Db['select']>[0]) {
    return liveVersions(tx, fields);
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
      await this.lockLearner(tx, userId);
      if (
        dto.mode === 'daily_docket' &&
        (await this.docketDone(tx, userId, now))
      )
        throw err(
          HttpStatus.CONFLICT,
          'docket_done_today',
          "Today's docket is already done; a new one opens at midnight (India time)",
        );

      const cost = (await isPremium(tx, userId))
        ? 0
        : ECONOMY.energyCost[dto.mode];
      if (cost > 0 && (await energyToday(tx, userId, now)) < cost)
        throw err(
          HttpStatus.CONFLICT,
          'not_enough_energy',
          'Not enough energy for this quiz today',
        );

      const where = [this.eligible(language, now)];
      if (dto.mode === 'mistake_review') {
        // Your own mistakes, whatever their topic or difficulty.
        const ids = await this.review.mistakeQuestionIds(tx, userId);
        if (!ids.length)
          throw err(
            HttpStatus.UNPROCESSABLE_ENTITY,
            'no_questions_available',
            'No mistakes to practise right now',
          );
        where.push(inArray(questions.id, ids));
      } else if (topicIds.length)
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
      // Charged when the quiz starts, never mid-quiz.
      await addEnergy(tx, {
        userId,
        amount: -cost,
        reason: 'quiz_start',
        sessionId,
      });
      return this.view(tx, await this.load(tx, userId, sessionId));
    });
  }

  /**
   * Leaving before the first answer: the quiz is removed as if it never
   * started and its energy comes back.
   */
  async abandon(userId: string, id: string): Promise<void> {
    await this.db.transaction(async (tx) => {
      const s = await this.load(tx, userId, id, true);
      const rows = await this.rows(tx, s.id);
      if (isSubmitted(s) || rows.some((q) => q.answeredAt))
        throw err(
          HttpStatus.CONFLICT,
          'quiz_started',
          'This quiz has answers; finish it instead',
        );
      const [charged] = await tx
        .select({ amount: energyLedger.amount })
        .from(energyLedger)
        .where(
          and(
            eq(energyLedger.sessionId, s.id),
            eq(energyLedger.reason, 'quiz_start'),
          ),
        );
      if (charged)
        await addEnergy(tx, {
          userId,
          amount: -charged.amount,
          reason: 'quiz_refund',
          sessionId: s.id,
        });
      await tx.delete(quizSessions).where(eq(quizSessions.id, s.id));
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
        await this.lockLearner(tx, userId);
        const rows = await this.rows(tx, s.id);
        const submittedAt = new Date();
        const scored = scoreSession(rows);
        const finished = { ...s, ...scored, submittedAt };
        const rewards = await this.rewards(tx, finished, rows);
        await tx
          .update(quizSessions)
          .set({ submittedAt, ...scored, xpAwarded: rewards.xp.total })
          .where(eq(quizSessions.id, s.id));
        await ensureWelcome(tx, userId);
        const pay = (
          reason:
            'new_stars' | 'daily_docket' | 'daily_goal' | 'streak_milestone',
          amount: number,
        ) => addCoins(tx, { userId, amount, reason, sessionId: s.id });
        await pay('new_stars', rewards.coins.new_stars);
        await pay('daily_docket', rewards.coins.daily_docket);
        await pay('daily_goal', rewards.coins.daily_goal);
        await pay('streak_milestone', rewards.coins.streak_milestone);
        await addEnergy(tx, {
          userId,
          amount: rewards.energy_bonus,
          reason: 'three_star_bonus',
          sessionId: s.id,
        });
        // The first finished quiz of the week joins this week's league.
        await this.league.join(tx, userId, submittedAt);
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
    await ensureWelcome(this.db, userId);
    const summary = this.summary(
      finished,
      await this.openedChests(this.db, userId),
      await freezePurchaseDays(this.db, userId),
    );
    const premium = await isPremium(this.db, userId);
    return {
      ...summary,
      coins: await coinBalance(this.db, userId),
      energy: {
        today: await energyToday(this.db, userId),
        free_daily: ECONOMY.freeDailyEnergy,
        unlimited: premium,
      },
      premium,
      settings: await this.settings(this.db, userId),
      chat: {
        daily_limit: premium
          ? this.config.chatDailyLimit
          : this.config.chatFreeDailyLimit,
        used_today: await this.chatUsedToday(userId, summary.today),
      },
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
      await this.lockLearner(tx, userId);
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
      await ensureWelcome(tx, userId);
      await addCoins(tx, {
        userId,
        amount: ECONOMY.coinsPerChest,
        reason: 'chest',
        subjectId: node.subjectId,
      });
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
  private summary(
    finished: Finished[],
    opened: Set<string>,
    boughtFreezes: string[] = [],
    now = new Date(),
  ) {
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
    const streak = streakOn(days, today, boughtFreezes);
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
    const paid = await tx
      .select({ reason: coinLedger.reason, amount: coinLedger.amount })
      .from(coinLedger)
      .where(eq(coinLedger.sessionId, s.id));
    const coin = (reason: string) =>
      paid.find((p) => p.reason === reason)?.amount ?? 0;
    const [bonus] = await tx
      .select({ amount: energyLedger.amount })
      .from(energyLedger)
      .where(
        and(
          eq(energyLedger.sessionId, s.id),
          eq(energyLedger.reason, 'three_star_bonus'),
        ),
      );
    const coins = {
      new_stars: coin('new_stars'),
      daily_docket: coin('daily_docket'),
      daily_goal: coin('daily_goal'),
      streak_milestone: coin('streak_milestone'),
      total: 0,
    };
    coins.total =
      coins.new_stars +
      coins.daily_docket +
      coins.daily_goal +
      coins.streak_milestone;
    return {
      ...r,
      xp: { ...r.xp, total: s.xpAwarded ?? 0 },
      coins,
      energy_bonus: bonus?.amount ?? 0,
    };
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
    const bought = await freezePurchaseDays(tx, s.userId);
    const before = streakOn(
      history.map((f) => f.day),
      day,
      bought,
    );
    const after = streakOn([...history.map((f) => f.day), day], day, bought);
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

    const newStars = got === null ? 0 : Math.max(0, got - bestBefore);
    const milestone = extended ? milestoneFor(after.streak) : null;
    const settings = await this.settings(tx, s.userId);
    const goal = settings?.daily_goal ?? ECONOMY.defaultDailyGoal;
    const quizzesToday = history.filter((f) => f.day === day).length + 1;
    // Once a day, even if the goal is changed after reaching it.
    const goalReached =
      quizzesToday >= goal &&
      !(await paidOnDay(tx, s.userId, 'daily_goal', day, s.id));
    const coins = {
      new_stars: newStars * ECONOMY.coinsPerNewStar,
      daily_docket:
        s.mode === 'daily_docket' && !docketAgain
          ? ECONOMY.coinsForDailyDocket
          : 0,
      daily_goal: goalReached ? ECONOMY.coinsForDailyGoal : 0,
      streak_milestone: milestone
        ? (ECONOMY.streakMilestoneCoins[milestone] ?? 0)
        : 0,
      total: 0,
    };
    coins.total =
      coins.new_stars +
      coins.daily_docket +
      coins.daily_goal +
      coins.streak_milestone;
    const energyBonus =
      got === 3 && bestBefore < 3 && !(await isPremium(tx, s.userId))
        ? ECONOMY.threeStarEnergyBonus
        : 0;
    return {
      coins,
      energy_bonus: energyBonus,
      xp,
      level_id: level,
      stars: got,
      best_stars_before: bestBefore,
      new_stars: newStars,
      streak: after.streak,
      streak_extended: extended,
      streak_milestone: milestone,
    };
  }

  // ---------------------------------------------------------------- wallet & settings

  /** Spends 30 coins on one energy for today. */
  async refillEnergy(userId: string): Promise<ProgressDto> {
    await this.db.transaction(async (tx) => {
      await this.lockLearner(tx, userId);
      await ensureWelcome(tx, userId);
      await this.spend(tx, userId, ECONOMY.energyRefillCost, 'energy_refill');
      await addEnergy(tx, { userId, amount: 1, reason: 'refill' });
    });
    return this.progress(userId);
  }

  /** Spends 100 coins on a streak freeze; at most 2 are held. */
  async buyStreakFreeze(userId: string): Promise<ProgressDto> {
    await this.db.transaction(async (tx) => {
      await this.lockLearner(tx, userId);
      await ensureWelcome(tx, userId);
      const held = this.summary(
        await this.finished(tx, userId),
        new Set(),
        await freezePurchaseDays(tx, userId),
      ).streak.freezes;
      if (held >= RULES.maxStreakFreezes)
        throw err(
          HttpStatus.CONFLICT,
          'freezes_full',
          'You already hold the most streak freezes',
        );
      await this.spend(tx, userId, ECONOMY.streakFreezeCost, 'streak_freeze');
    });
    return this.progress(userId);
  }

  private async spend(
    tx: Tx,
    userId: string,
    cost: number,
    reason: 'energy_refill' | 'streak_freeze',
  ) {
    if ((await coinBalance(tx, userId)) < cost)
      throw err(HttpStatus.CONFLICT, 'not_enough_coins', 'Not enough coins');
    await addCoins(tx, { userId, amount: -cost, reason });
  }

  /** Demo premium (testing only, until store purchases are checked). */
  async setPremium(actor: Actor, on: boolean): Promise<ProgressDto> {
    const userId = actor.id;
    await this.db.transaction(async (tx) => {
      if (on)
        await tx
          .insert(premiumMemberships)
          .values({ userId, source: 'demo', startedAt: new Date() })
          .onConflictDoNothing();
      else
        await tx
          .delete(premiumMemberships)
          .where(eq(premiumMemberships.userId, userId));
      await this.audit.record(tx, actor, {
        action: on ? 'premium.started' : 'premium.ended',
        entityType: 'user',
        entityId: userId,
        data: { source: 'demo' },
      });
    });
    return this.progress(userId);
  }

  async settings(tx: Tx, userId: string): Promise<SettingsDto | null> {
    const [row] = await tx
      .select({
        name: users.displayName,
        persona: learnerSettings.persona,
        language: learnerSettings.language,
        dailyGoal: learnerSettings.dailyGoal,
        onboardedAt: learnerSettings.onboardedAt,
      })
      .from(learnerSettings)
      .innerJoin(users, eq(users.id, learnerSettings.userId))
      .where(eq(learnerSettings.userId, userId));
    if (!row) return null;
    return {
      name: row.name,
      persona: row.persona,
      language: row.language,
      daily_goal: row.dailyGoal,
      onboarded: row.onboardedAt !== null,
    };
  }

  async saveSettings(userId: string, dto: SettingsDto): Promise<SettingsDto> {
    await this.db.transaction(async (tx) => {
      const [old] = await tx
        .select({ onboardedAt: learnerSettings.onboardedAt })
        .from(learnerSettings)
        .where(eq(learnerSettings.userId, userId));
      const onboardedAt = dto.onboarded
        ? (old?.onboardedAt ?? new Date())
        : null;
      const values = {
        persona: dto.persona,
        language: dto.language,
        dailyGoal: dto.daily_goal,
        onboardedAt,
        updatedAt: new Date(),
      };
      await tx
        .insert(learnerSettings)
        .values({ userId, ...values })
        .onConflictDoUpdate({ target: learnerSettings.userId, set: values });
      await tx
        .update(users)
        .set({ displayName: dto.name.trim(), updatedAt: new Date() })
        .where(eq(users.id, userId));
    });
    return (await this.settings(this.db, userId))!;
  }

  private async chatUsedToday(userId: string, today: string) {
    const [row] = await this.db
      .select({ answers: chatUsage.answers })
      .from(chatUsage)
      .where(and(eq(chatUsage.userId, userId), eq(chatUsage.day, today)));
    return row?.answers ?? 0;
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
        questionId: questionVersions.questionId,
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
      question_id: q.questionId,
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
