import type { Metadata } from 'next';
import Link from 'next/link';
import { Suspense } from 'react';
import { Card, Skeleton } from '@/components/ui';
import { getAllTaxonomy, getMe } from '@/lib/session';
import { hasRole } from '@/lib/workflow';
import { ActiveToggle, ItemRow, TaxonomyForm } from './taxonomy-forms';

export const metadata: Metadata = { title: 'Topics' };

const plural = (n: number, one: string, many = `${one}s`) => `${n} ${n === 1 ? one : many}`;

function Badge({ shown }: { shown: boolean }) {
  return (
    <span
      className={`rounded-full px-2 py-0.5 text-xs font-medium ${shown ? 'bg-[var(--st-live-bg)] text-[var(--st-live-fg)]' : 'bg-surface-2 text-muted'}`}
    >
      {shown ? 'Shown' : 'Hidden'}
    </span>
  );
}

export default function TopicsPage() {
  return (
    <div className="flex flex-col gap-6">
      <div>
        <h1 className="font-serif text-4xl">Topics</h1>
        <p className="mt-1 max-w-3xl text-sm text-muted">
          Subjects are the chapters of the learners&rsquo; Case Path; each holds topics, and questions belong to a topic. Hiding
          a subject or topic takes its questions out of quizzes straight away; nothing is deleted. Slugs never change, because
          the app, learners&rsquo; progress and import files refer to them.
        </p>
      </div>
      <Suspense fallback={<Skeleton className="h-96" />}>
        <Taxonomy />
      </Suspense>
    </div>
  );
}

async function Taxonomy() {
  const [me, taxonomy] = await Promise.all([getMe(), getAllTaxonomy()]);
  const admin = hasRole(me, 'admin');
  const editsTopics = hasRole(me, 'content_editor', 'admin');
  const actName = new Map(taxonomy.acts.map((a) => [a.id, a.short_name || a.name]));
  const actChoices = taxonomy.acts.filter((a) => a.is_active).map((a) => ({ id: a.id, name: a.name }));

  return (
    <>
      {taxonomy.subjects.map((s) => {
        const live = s.topics.reduce((n, t) => n + t.live_count, 0);
        return (
          <Card key={s.id} className="flex flex-col">
            <ItemRow
              info={
                <>
                  <div className="flex flex-wrap items-center gap-2">
                    <h2 className="font-serif text-2xl">{s.name}</h2>
                    <Badge shown={s.is_active} />
                  </div>
                  <p className="mt-0.5 text-xs text-muted">
                    <span className="font-mono">{s.slug}</span> · order {s.sort_order} · {plural(live, 'live question')}
                  </p>
                  {s.description && <p className="mt-1 text-sm text-muted">{s.description}</p>}
                </>
              }
              actions={
                admin && (
                  <ActiveToggle
                    kind="subjects"
                    id={s.id}
                    active={s.is_active}
                    confirmText={
                      s.is_active
                        ? `Hide "${s.name}"? Its chapter leaves the learners' road and its ${plural(live, 'live question')} leave quizzes straight away.`
                        : `Show "${s.name}" to learners? It adds a chapter to the Case Path road after the subjects with a lower order. The app shows only its built-in chapters, so learners will not see this one until the app is updated; give it the highest order so it does not stand in front of existing chapters.`
                    }
                  />
                )
              }
              editForm={admin && <TaxonomyForm kind="subjects" id={s.id} defaults={s} />}
            />

            <div className="divide-y divide-border border-t border-border">
              {s.topics.length === 0 && <p className="py-3 text-sm text-muted">No topics yet.</p>}
              {s.topics.map((t) => (
                <ItemRow
                  key={t.id}
                  info={
                    <>
                      <div className="flex flex-wrap items-center gap-2">
                        <span className="font-medium">{t.name}</span>
                        <Badge shown={t.is_active} />
                      </div>
                      <p className="mt-0.5 text-xs text-muted">
                        <span className="font-mono">{t.slug}</span>
                        {t.act_id && <> · {actName.get(t.act_id)}</>} ·{' '}
                        <Link href={`/questions?topic=${t.id}`} className="text-primary hover:underline">
                          {plural(t.question_count, 'question')}
                        </Link>
                        , {t.live_count} live
                      </p>
                    </>
                  }
                  actions={
                    editsTopics && (
                      <ActiveToggle
                        kind="topics"
                        id={t.id}
                        active={t.is_active}
                        confirmText={
                          t.is_active
                            ? `Hide "${t.name}"? Its ${plural(t.live_count, 'live question')} leave learners' quizzes straight away.`
                            : `Show "${t.name}"? Its live questions return to learners' quizzes.`
                        }
                      />
                    )
                  }
                  editForm={editsTopics && <TaxonomyForm kind="topics" id={t.id} defaults={t} acts={actChoices} />}
                />
              ))}
            </div>
            {editsTopics && (
              <details className="border-t border-border pt-3">
                <summary className="cursor-pointer text-sm font-medium text-primary">Add a topic to {s.name}</summary>
                <div className="mt-3">
                  <TaxonomyForm kind="topics" subjectId={s.id} acts={actChoices} />
                </div>
              </details>
            )}
          </Card>
        );
      })}

      {admin && (
        <Card>
          <details>
            <summary className="cursor-pointer font-medium text-primary">Add a subject</summary>
            <p className="mt-2 text-sm text-muted">New subjects start hidden. Show one only when its topics have published questions.</p>
            <div className="mt-3">
              <TaxonomyForm kind="subjects" />
            </div>
          </details>
        </Card>
      )}

      <section className="flex flex-col gap-3">
        <h2 className="font-serif text-2xl">Acts</h2>
        <p className="text-sm text-muted">Laws a topic can name as its main source. Hiding an act only takes it off the lists here.</p>
        <Card className="flex flex-col divide-y divide-border py-0">
          {taxonomy.acts.map((a) => (
            <ItemRow
              key={a.id}
              info={
                <>
                  <div className="flex flex-wrap items-center gap-2">
                    <span className="font-medium">{a.name}</span>
                    <Badge shown={a.is_active} />
                  </div>
                  <p className="mt-0.5 text-xs text-muted">
                    <span className="font-mono">{a.slug}</span>
                    {a.short_name && <> · {a.short_name}</>}
                    {a.year && <> · {a.year}</>} · {plural(a.topic_count, 'topic')}
                  </p>
                </>
              }
              actions={
                editsTopics && (
                  <ActiveToggle
                    kind="acts"
                    id={a.id}
                    active={a.is_active}
                    confirmText={a.is_active ? `Hide "${a.name}" from the act lists?` : `Show "${a.name}" in the act lists?`}
                  />
                )
              }
              editForm={editsTopics && <TaxonomyForm kind="acts" id={a.id} defaults={a} />}
            />
          ))}
          {editsTopics && (
            <details className="py-3">
              <summary className="cursor-pointer text-sm font-medium text-primary">Add an act</summary>
              <div className="mt-3">
                <TaxonomyForm kind="acts" />
              </div>
            </details>
          )}
        </Card>
      </section>
    </>
  );
}
