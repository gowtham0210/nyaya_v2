import type { Metadata } from 'next';
import Link from 'next/link';
import { Suspense } from 'react';
import { Skeleton } from '@/components/ui';
import { getMe, getTaxonomy } from '@/lib/session';
import { hasRole } from '@/lib/workflow';
import { createQuestion } from '../actions';
import { OPTION_IDS } from '../form-state';
import { QuestionForm } from '../question-form';

export const metadata: Metadata = { title: 'New question' };

export default function NewQuestionPage() {
  return (
    <div className="mx-auto flex max-w-3xl flex-col gap-6">
      <div>
        <Link href="/questions" className="text-sm text-muted hover:text-text">← Questions</Link>
        <h1 className="mt-2 font-serif text-4xl">New question</h1>
      </div>
      <Suspense fallback={<Skeleton className="h-[40rem]" />}>
        <NewQuestion />
      </Suspense>
    </div>
  );
}

async function NewQuestion() {
  const [me, taxonomy] = await Promise.all([getMe(), getTaxonomy()]);
  if (!hasRole(me, 'content_editor')) {
    return <p className="text-muted">Only content editors can write questions.</p>;
  }
  return (
    <QuestionForm
      taxonomy={taxonomy}
      action={createQuestion}
      submitLabel="Create draft"
      initial={{
        topic_id: '',
        difficulty: '1',
        stem: '',
        options: OPTION_IDS.slice(0, 4).map((id) => ({ id, text: '' })),
        correct: '',
        explanation: '',
        source_title: '',
        source_url: '',
        citation: '',
        provision_reference: '',
        valid_from: '',
        valid_to: '',
      }}
    />
  );
}
