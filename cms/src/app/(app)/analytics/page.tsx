import type { Metadata } from 'next';
import Link from 'next/link';
import { Suspense, type ReactNode } from 'react';
import { Card, Skeleton } from '@/components/ui';
import { api, must } from '@/lib/api';
import { getMe } from '@/lib/session';
import { hasRole } from '@/lib/workflow';
import { BarChart } from './bar-chart';

export const metadata: Metadata = { title: 'Analytics' };

const PERIODS = [7, 30, 90] as const;
const MODE_LABEL: Record<string, string> = {
  case_path: 'Case Path',
  daily_docket: 'Daily Docket',
  duel: 'Moot Court Duel',
  exam: 'Exam Chamber',
  mistake_review: 'Mistake practice',
};
const num = (n: number) => n.toLocaleString('en-IN');
const pct = (part: number, whole: number) => (whole === 0 ? '—' : `${Math.round((100 * part) / whole)}%`);
const SHORT_DATE = new Intl.DateTimeFormat('en-IN', { day: 'numeric', month: 'short', timeZone: 'UTC' });
const shortDate = (iso: string) => SHORT_DATE.format(new Date(`${iso}T00:00:00Z`));

export default function AnalyticsPage({ searchParams }: PageProps<'/analytics'>) {
  return (
    <div className="flex flex-col gap-6">
      <Suspense fallback={<Skeleton className="h-96" />}>
        <Analytics searchParams={searchParams} />
      </Suspense>
    </div>
  );
}

function Stat({ label, value, note }: { label: string; value: ReactNode; note?: string }) {
  return (
    <div className="rounded-xl border border-border bg-surface px-4 py-3">
      <div className="font-serif text-3xl">{value}</div>
      <div className="text-sm">{label}</div>
      {note && <div className="mt-0.5 text-xs text-muted">{note}</div>}
    </div>
  );
}

async function Analytics({ searchParams }: { searchParams: PageProps<'/analytics'>['searchParams'] }) {
  const me = await getMe();
  if (!hasRole(me, 'admin', 'analyst')) return <p className="text-muted">Only admins and analysts see the analytics.</p>;
  const sp = await searchParams;
  const asked = Number(Array.isArray(sp.days) ? sp.days[0] : sp.days);
  const days = PERIODS.find((d) => d === asked) ?? 30;
  const client = await api();
  const o = await client.GET('/v1/admin/analytics/overview', { params: { query: { days } } }).then(must);
  const { learners: l, active: a, content: c } = o;

  const tab = (on: boolean) =>
    `rounded-lg px-3 py-1.5 text-sm ${on ? 'bg-surface-2 font-medium text-text' : 'text-muted hover:text-text'}`;

  return (
    <>
      <div className="flex flex-wrap items-end justify-between gap-4">
        <div>
          <h1 className="font-serif text-4xl">Analytics</h1>
          <p className="mt-1 max-w-3xl text-sm text-muted">
            Worked out from what the app already records (quizzes, answers, AI questions, reports) plus the days learners open the
            app. No names or emails here, and learners&rsquo; data is removed when they delete their account. Days are India dates;
            today is {shortDate(o.as_of)}.
          </p>
        </div>
        <nav className="flex gap-1" aria-label="Period">
          {PERIODS.map((d) => (
            <Link key={d} href={`/analytics?days=${d}`} aria-current={d === days ? 'page' : undefined} className={tab(d === days)}>
              {d} days
            </Link>
          ))}
        </nav>
      </div>

      <section className="grid grid-cols-2 gap-3 lg:grid-cols-4" aria-label="Totals">
        <Stat label="Learners" value={num(l.total)} note={`${num(l.new_in_period)} new in ${days} days`} />
        <Stat label="Active today" value={num(a.today)} note={`${num(a.last_7_days)} in 7 days · ${num(a.last_30_days)} in 30 days`} />
        <Stat label="Finished a quiz" value={pct(l.finished_a_quiz, l.total)} note={`${num(l.finished_a_quiz)} of ${num(l.total)} learners`} />
        <Stat label="Finished onboarding" value={pct(l.onboarded, l.total)} note={`${num(l.onboarded)} of ${num(l.total)} learners`} />
      </section>

      <Card className="flex flex-col gap-8">
        <BarChart title="Active learners a day" unit="learners" points={o.daily.map((d) => ({ label: shortDate(d.date), value: d.active_learners }))} />
        <BarChart title="Quizzes finished a day" unit="quizzes" points={o.daily.map((d) => ({ label: shortDate(d.date), value: d.quizzes_finished }))} />
        <BarChart title="New learners a day" unit="sign-ups" points={o.daily.map((d) => ({ label: shortDate(d.date), value: d.new_learners }))} />
        <BarChart title="AI answers a day" unit="answers" points={o.daily.map((d) => ({ label: shortDate(d.date), value: d.ai_answers }))} />
      </Card>

      <div className="grid gap-6 lg:grid-cols-2">
        <Card className="flex flex-col gap-3">
          <h2 className="font-serif text-2xl">Coming back</h2>
          <p className="text-sm text-muted">
            Of people who signed up in the last 90 days, how many were active exactly 1, 7 and 30 days later (they opened the app,
            played a quiz or asked the AI). Only people old enough to be measured are counted.
          </p>
          <table className="w-full text-sm">
            <thead className="border-b border-border text-left text-xs tracking-wide text-muted uppercase">
              <tr>
                <th className="py-2 font-medium">After</th>
                <th className="py-2 font-medium">Came back</th>
                <th className="py-2 font-medium">Measured</th>
              </tr>
            </thead>
            <tbody className="divide-y divide-border">
              {o.retention.map((r) => (
                <tr key={r.day}>
                  <td className="py-2">{r.day === 1 ? '1 day' : `${r.day} days`}</td>
                  <td className="py-2 font-medium">{r.eligible < 5 ? '—' : pct(r.retained, r.eligible)}</td>
                  <td className="py-2 text-muted">
                    {r.eligible === 0 ? 'nobody old enough yet' : `${r.retained} of ${r.eligible}${r.eligible < 5 ? ' (too few to read)' : ''}`}
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        </Card>

        <Card className="flex flex-col gap-3">
          <h2 className="font-serif text-2xl">Quizzes by mode</h2>
          <p className="text-sm text-muted">Started in the last {days} days. Score is the average share of questions right in finished quizzes.</p>
          {o.modes.length === 0 ? (
            <p className="text-sm text-muted">No quizzes in this period.</p>
          ) : (
            <table className="w-full text-sm">
              <thead className="border-b border-border text-left text-xs tracking-wide text-muted uppercase">
                <tr>
                  <th className="py-2 font-medium">Mode</th>
                  <th className="py-2 font-medium">Started</th>
                  <th className="py-2 font-medium">Finished</th>
                  <th className="py-2 font-medium">Score</th>
                </tr>
              </thead>
              <tbody className="divide-y divide-border">
                {o.modes.map((m) => (
                  <tr key={m.mode}>
                    <td className="py-2">{MODE_LABEL[m.mode] ?? m.mode}</td>
                    <td className="py-2">{num(m.started)}</td>
                    <td className="py-2">{pct(m.finished, m.started)}</td>
                    <td className="py-2">{m.average_score_percent === null ? '—' : `${m.average_score_percent}%`}</td>
                  </tr>
                ))}
              </tbody>
            </table>
          )}
        </Card>
      </div>

      <Card className="flex flex-col gap-3">
        <div className="flex flex-wrap items-baseline justify-between gap-2">
          <h2 className="font-serif text-2xl">Questions to look at</h2>
          <p className="text-sm text-muted">
            <Link href="/reports" className="text-primary hover:underline">
              {c.open_reports} open report{c.open_reports === 1 ? '' : 's'}
            </Link>
            {' · '}
            {c.reports_in_period} sent in {days} days
          </p>
        </div>
        <p className="text-sm text-muted">
          The most often missed questions in the last {days} days (at least {c.min_answers} answers). A very low score can mean a
          hard question, a confusing one or a wrong answer key, so check these first.
        </p>
        {c.hardest_questions.length === 0 ? (
          <p className="text-sm text-muted">No question has {c.min_answers} answers in this period yet.</p>
        ) : (
          <ol className="divide-y divide-border">
            {c.hardest_questions.map((q) => (
              <li key={q.question_id} className="flex items-start gap-4 py-3">
                <span className="w-14 shrink-0 font-serif text-2xl">{q.correct_percent}%</span>
                <div className="min-w-0">
                  <Link href={`/questions/${q.question_id}`} className="line-clamp-2 font-medium hover:text-primary">
                    {q.stem}
                  </Link>
                  <p className="text-xs text-muted">
                    {q.topic} · {num(q.answers)} answers
                  </p>
                </div>
              </li>
            ))}
          </ol>
        )}
      </Card>
    </>
  );
}
