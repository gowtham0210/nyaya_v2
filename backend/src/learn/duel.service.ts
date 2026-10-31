import { Injectable } from '@nestjs/common';
import {
  and,
  asc,
  desc,
  eq,
  inArray,
  isNotNull,
  notInArray,
  sql,
} from 'drizzle-orm';
import { alias } from 'drizzle-orm/pg-core';
import type { Tx } from '../core/db.js';
import {
  duelMatches,
  questionVersions,
  quizSessionQuestions,
  quizSessions,
  users,
  type QuestionOption,
} from '../db/schema.js';
import {
  DUEL,
  nextRating,
  outcomeOf,
  practiceAnswers,
  totalPoints,
  type GhostAnswer,
} from './duel.js';
import { eligible, liveVersions } from './eligibility.js';
import type {
  DuelRecordDto,
  ResultDuelDto,
  SessionDuelDto,
} from './learn.dto.js';
import { practiceName, publicName } from './league.js';

/** A question picked for a duel, as the session needs it. */
export interface DuelQuestion {
  id: string;
  options: QuestionOption[];
  difficulty: number;
}

/** Another learner's finished duel to race, with its questions in order. */
export interface Ghost {
  sessionId: string;
  name: string;
  rating: number;
  answers: GhostAnswer[];
  questions: DuelQuestion[];
}

/** One of the player's answered (or timed-out) questions. */
export interface PlayedAnswer {
  correct: boolean;
  /** As stored; null when unanswered or sent without a time. */
  elapsedMs: number | null;
}

const opponentSessions = alias(quizSessions, 'opponent_sessions');

/**
 * Picks duel opponents and settles duels. A learner's rating, wins and
 * count are worked out from their finished duels, never stored apart.
 */
@Injectable()
export class DuelService {
  async record(tx: Tx, userId: string): Promise<DuelRecordDto> {
    const rows = await tx
      .select({
        ratingAfter: duelMatches.ratingAfter,
        outcome: duelMatches.outcome,
      })
      .from(duelMatches)
      .innerJoin(quizSessions, eq(quizSessions.id, duelMatches.sessionId))
      .where(
        and(eq(quizSessions.userId, userId), isNotNull(duelMatches.outcome)),
      )
      .orderBy(desc(quizSessions.submittedAt), desc(quizSessions.id));
    return {
      rating: rows[0]?.ratingAfter ?? DUEL.startingRating,
      played: rows.length,
      won: rows.filter((r) => r.outcome === 'won').length,
    };
  }

  /**
   * A finished duel by someone else near [rating], whose questions are all
   * still live and inside [topicIds] (when given), skipping the learners met
   * in the last few duels. Null when none fits.
   */
  async findGhost(
    tx: Tx,
    opts: {
      userId: string;
      rating: number;
      language: string;
      topicIds: string[];
      count: number;
      now: Date;
    },
  ): Promise<Ghost | null> {
    const recent = await tx
      .select({ userId: opponentSessions.userId })
      .from(duelMatches)
      .innerJoin(quizSessions, eq(quizSessions.id, duelMatches.sessionId))
      .innerJoin(
        opponentSessions,
        eq(opponentSessions.id, duelMatches.opponentSessionId),
      )
      .where(eq(quizSessions.userId, opts.userId))
      .orderBy(desc(quizSessions.startedAt))
      .limit(DUEL.recentOpponents);
    const skip = [opts.userId, ...recent.map((r) => r.userId)];
    const distance = sql`abs(${duelMatches.ratingBefore} - ${opts.rating})`;
    const candidates = await tx
      .select({
        sessionId: quizSessions.id,
        name: users.displayName,
        rating: duelMatches.ratingBefore,
      })
      .from(quizSessions)
      .innerJoin(duelMatches, eq(duelMatches.sessionId, quizSessions.id))
      .innerJoin(users, eq(users.id, quizSessions.userId))
      .where(
        and(
          eq(quizSessions.mode, 'duel'),
          isNotNull(duelMatches.outcome),
          notInArray(quizSessions.userId, skip),
          eq(users.isActive, true),
          eq(quizSessions.language, opts.language),
          eq(quizSessions.questionCount, opts.count),
          sql`${distance} <= ${DUEL.matchRange}`,
        ),
      )
      .orderBy(distance, sql`random()`)
      .limit(20);

    for (const c of candidates) {
      const rows = await tx
        .select({
          versionId: quizSessionQuestions.questionVersionId,
          answeredAt: quizSessionQuestions.answeredAt,
          isCorrect: quizSessionQuestions.isCorrect,
          elapsedMs: quizSessionQuestions.elapsedMs,
        })
        .from(quizSessionQuestions)
        .where(eq(quizSessionQuestions.sessionId, c.sessionId))
        .orderBy(asc(quizSessionQuestions.position));
      const ids = rows.map((r) => r.versionId);
      const live = (await liveVersions(tx, {
        id: questionVersions.id,
        options: questionVersions.options,
        difficulty: questionVersions.difficulty,
      }).where(
        and(
          eligible(opts.language, opts.now),
          inArray(questionVersions.id, ids),
          opts.topicIds.length
            ? inArray(questionVersions.topicId, opts.topicIds)
            : undefined,
        ),
      )) as unknown as DuelQuestion[];
      if (live.length !== ids.length) continue;
      const byId = new Map(live.map((v) => [v.id, v]));
      return {
        sessionId: c.sessionId,
        name: publicName(c.name),
        rating: c.rating,
        answers: rows.map((r) => ({
          correct: !!r.answeredAt && !!r.isCorrect,
          // Unanswered: timed out.
          elapsed_ms: r.answeredAt
            ? (r.elapsedMs ?? DUEL.seconds * 1000)
            : DUEL.seconds * 1000,
        })),
        questions: ids.map((id) => byId.get(id)!),
      };
    }
    return null;
  }

  /** Records who a new duel session races: [ghost], or a practice player. */
  async open(
    tx: Tx,
    opts: {
      sessionId: string;
      rating: number;
      ghost: Ghost | null;
      questions: DuelQuestion[];
    },
  ) {
    const { ghost } = opts;
    const practiceRating = Math.min(
      2400,
      Math.max(600, opts.rating + Math.floor(Math.random() * 301) - 150),
    );
    await tx.insert(duelMatches).values({
      sessionId: opts.sessionId,
      opponentSessionId: ghost?.sessionId ?? null,
      opponentName: ghost?.name ?? practiceName(opts.sessionId),
      practice: !ghost,
      opponentRating: ghost?.rating ?? practiceRating,
      opponentAnswers:
        ghost?.answers ??
        practiceAnswers(
          practiceRating,
          opts.questions.map((q) => q.difficulty),
          Math.random,
        ),
      ratingBefore: opts.rating,
    });
  }

  /** Scores the duel, decides it and moves the rating. Once only. */
  async settle(
    tx: Tx,
    opts: { sessionId: string; userId: string; answers: PlayedAnswer[] },
  ) {
    const [m] = await tx
      .select()
      .from(duelMatches)
      .where(eq(duelMatches.sessionId, opts.sessionId))
      .limit(1);
    if (!m || m.outcome) return;
    const player = totalPoints(
      opts.answers.map((a) => ({
        correct: a.correct,
        elapsed_ms: a.elapsedMs ?? DUEL.seconds * 1000,
      })),
    );
    const opponent = totalPoints(m.opponentAnswers);
    const outcome = outcomeOf(player, opponent);
    const { played } = await this.record(tx, opts.userId);
    await tx
      .update(duelMatches)
      .set({
        playerPoints: player,
        opponentPoints: opponent,
        outcome,
        ratingAfter: nextRating({
          rating: m.ratingBefore,
          opponent: m.opponentRating,
          outcome,
          played,
        }),
      })
      .where(eq(duelMatches.sessionId, opts.sessionId));
  }

  async won(tx: Tx, sessionId: string): Promise<boolean> {
    const [m] = await tx
      .select({ outcome: duelMatches.outcome })
      .from(duelMatches)
      .where(eq(duelMatches.sessionId, sessionId))
      .limit(1);
    return m?.outcome === 'won';
  }

  async sessionView(tx: Tx, sessionId: string): Promise<SessionDuelDto | null> {
    const m = await this.match(tx, sessionId);
    if (!m) return null;
    return {
      opponent: {
        name: m.opponentName,
        rating: m.opponentRating,
        practice: m.practice,
      },
      opponent_answers: m.opponentAnswers,
    };
  }

  async resultView(tx: Tx, sessionId: string): Promise<ResultDuelDto | null> {
    const m = await this.match(tx, sessionId);
    if (!m?.outcome) return null;
    return {
      opponent: {
        name: m.opponentName,
        rating: m.opponentRating,
        practice: m.practice,
      },
      player_points: m.playerPoints!,
      opponent_points: m.opponentPoints!,
      outcome: m.outcome,
      rating_before: m.ratingBefore,
      rating_after: m.ratingAfter!,
    };
  }

  private async match(tx: Tx, sessionId: string) {
    const [m] = await tx
      .select()
      .from(duelMatches)
      .where(eq(duelMatches.sessionId, sessionId))
      .limit(1);
    return m;
  }
}
