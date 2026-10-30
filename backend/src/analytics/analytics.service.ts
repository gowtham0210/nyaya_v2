import { Inject, Injectable } from '@nestjs/common';
import { sql } from 'drizzle-orm';
import { DB, type Db } from '../core/db.js';
import { indiaToday } from '../learn/scoring.js';
import type { QuizMode } from '../db/schema.js';
import type { AnalyticsOverviewDto } from './analytics.dto.js';

/** Raw query rows (node-postgres and PGlite both return `rows`). */
const rowsOf = (res: unknown) =>
  (res as { rows: Record<string, unknown>[] }).rows;
const n = (v: unknown) => Number(v ?? 0);

const RETENTION_DAYS = [1, 7, 30] as const;
const COHORT_DAYS = 90;
const MIN_ANSWERS = 5;

/**
 * Learner accounts only (staff are left out), and the days each was active:
 * a quiz started, an AI answer asked for, or the app opened. Everything here
 * is calculated from records the app keeps anyway, so no extra tracking.
 */
const LEARNERS = sql`
  learners as (
    select u.id, u.created_at, (u.created_at at time zone 'Asia/Kolkata')::date as signup_day
    from users u where u.roles = array['learner']::text[]
  ),
  activity as (
    select l.id as user_id, (s.started_at at time zone 'Asia/Kolkata')::date as day
      from quiz_sessions s join learners l on l.id = s.user_id
    union
    select c.user_id, c.day from chat_usage c join learners l on l.id = c.user_id where c.answers > 0
    union
    select o.user_id, o.day from app_opens o join learners l on l.id = o.user_id
  )`;

/** Answers that count: final ones (exam answers only once submitted). */
const ANSWERED = sql`
  qsq.answered_at is not null
  and (s.submitted_at is not null or s.mode <> 'exam')`;

@Injectable()
export class AnalyticsService {
  constructor(@Inject(DB) private readonly db: Db) {}

  async overview(
    days: number,
    now = new Date(),
  ): Promise<AnalyticsOverviewDto> {
    const today = indiaToday(now);
    const start = shift(today, -(days - 1));
    const cohortStart = shift(today, -COHORT_DAYS);
    const last7 = shift(today, -6);
    const last30 = shift(today, -29);

    const [totals, active, daily, retention, modes, hard, reports] =
      await Promise.all([
        this.db.execute(sql`
        with ${LEARNERS}
        select
          (select count(*) from learners) as total,
          (select count(*) from learners where signup_day >= ${start}::date) as new_in_period,
          (select count(*) from learner_settings ls join learners l on l.id = ls.user_id where ls.onboarded_at is not null) as onboarded,
          (select count(distinct s.user_id) from quiz_sessions s join learners l on l.id = s.user_id where s.submitted_at is not null) as finished_a_quiz`),
        this.db.execute(sql`
        with ${LEARNERS}
        select
          count(distinct user_id) filter (where day = ${today}::date) as today,
          count(distinct user_id) filter (where day >= ${last7}::date) as last_7,
          count(distinct user_id) filter (where day >= ${last30}::date) as last_30
        from activity where day <= ${today}::date`),
        this.db.execute(sql`
        with ${LEARNERS},
        days as (select d::date as day from generate_series(${start}::date, ${today}::date, interval '1 day') d),
        started as (
          select (s.started_at at time zone 'Asia/Kolkata')::date as day, count(*) as c
          from quiz_sessions s join learners l on l.id = s.user_id group by 1),
        finished as (
          select (s.submitted_at at time zone 'Asia/Kolkata')::date as day, count(*) as c
          from quiz_sessions s join learners l on l.id = s.user_id where s.submitted_at is not null group by 1),
        ai as (
          select c.day, sum(c.answers) as c from chat_usage c join learners l on l.id = c.user_id group by 1),
        act as (select day, count(distinct user_id) as c from activity group by 1),
        signups as (select signup_day as day, count(*) as c from learners group by 1)
        select days.day::text as date,
          coalesce(signups.c, 0) as new_learners, coalesce(act.c, 0) as active_learners,
          coalesce(started.c, 0) as quizzes_started, coalesce(finished.c, 0) as quizzes_finished,
          coalesce(ai.c, 0) as ai_answers
        from days
        left join signups on signups.day = days.day
        left join act on act.day = days.day
        left join started on started.day = days.day
        left join finished on finished.day = days.day
        left join ai on ai.day = days.day
        order by days.day`),
        this.db.execute(sql`
        with ${LEARNERS},
        steps(n) as (values (1), (7), (30))
        select steps.n as day,
          count(*) filter (where l.signup_day + steps.n <= ${today}::date) as eligible,
          count(*) filter (where l.signup_day + steps.n <= ${today}::date and exists (
            select 1 from activity a where a.user_id = l.id and a.day = l.signup_day + steps.n)) as retained
        from learners l cross join steps
        where l.signup_day >= ${cohortStart}::date
        group by steps.n order by steps.n`),
        this.db.execute(sql`
        with ${LEARNERS}
        select s.mode,
          count(*) as started,
          count(*) filter (where s.submitted_at is not null) as finished,
          round(avg(100.0 * s.correct_count / nullif(s.question_count, 0)) filter (where s.submitted_at is not null), 0) as average_score
        from quiz_sessions s join learners l on l.id = s.user_id
        where (s.started_at at time zone 'Asia/Kolkata')::date >= ${start}::date
        group by s.mode order by count(*) desc, s.mode`),
        this.db.execute(sql`
        with ${LEARNERS}
        select qv.question_id,
          (array_agg(qv.stem order by qsq.answered_at desc))[1] as stem,
          (array_agg(t.name order by qsq.answered_at desc))[1] as topic,
          count(*) as answers,
          round(100.0 * count(*) filter (where qsq.is_correct) / count(*), 0) as correct_percent
        from quiz_session_questions qsq
        join quiz_sessions s on s.id = qsq.session_id
        join learners l on l.id = s.user_id
        join question_versions qv on qv.id = qsq.question_version_id
        join topics t on t.id = qv.topic_id
        where ${ANSWERED} and (qsq.answered_at at time zone 'Asia/Kolkata')::date >= ${start}::date
        group by qv.question_id
        having count(*) >= ${MIN_ANSWERS}
        order by round(100.0 * count(*) filter (where qsq.is_correct) / count(*), 0) asc, count(*) desc
        limit 10`),
        this.db.execute(sql`
        select
          count(*) filter (where outcome is null) as open_reports,
          count(*) filter (where (created_at at time zone 'Asia/Kolkata')::date >= ${start}::date) as in_period
        from content_reports`),
      ]);

    const t = rowsOf(totals)[0] ?? {};
    const a = rowsOf(active)[0] ?? {};
    const r = rowsOf(reports)[0] ?? {};
    const retained = new Map(rowsOf(retention).map((x) => [n(x.day), x]));
    return {
      as_of: today,
      days,
      learners: {
        total: n(t.total),
        new_in_period: n(t.new_in_period),
        onboarded: n(t.onboarded),
        finished_a_quiz: n(t.finished_a_quiz),
      },
      active: {
        today: n(a.today),
        last_7_days: n(a.last_7),
        last_30_days: n(a.last_30),
      },
      daily: rowsOf(daily).map((x) => ({
        date: String(x.date),
        new_learners: n(x.new_learners),
        active_learners: n(x.active_learners),
        quizzes_started: n(x.quizzes_started),
        quizzes_finished: n(x.quizzes_finished),
        ai_answers: n(x.ai_answers),
      })),
      retention: RETENTION_DAYS.map((day) => ({
        day,
        eligible: n(retained.get(day)?.eligible),
        retained: n(retained.get(day)?.retained),
      })),
      modes: rowsOf(modes).map((x) => ({
        mode: String(x.mode) as QuizMode,
        started: n(x.started),
        finished: n(x.finished),
        average_score_percent:
          x.average_score === null ? null : n(x.average_score),
      })),
      content: {
        open_reports: n(r.open_reports),
        reports_in_period: n(r.in_period),
        min_answers: MIN_ANSWERS,
        hardest_questions: rowsOf(hard).map((x) => ({
          question_id: String(x.question_id),
          stem: String(x.stem),
          topic: String(x.topic),
          answers: n(x.answers),
          correct_percent: n(x.correct_percent),
        })),
      },
    };
  }
}

/** A YYYY-MM-DD date moved by a number of days. */
function shift(day: string, delta: number): string {
  const d = new Date(`${day}T00:00:00Z`);
  d.setUTCDate(d.getUTCDate() + delta);
  return d.toISOString().slice(0, 10);
}
