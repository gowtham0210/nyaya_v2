import Link from 'next/link';

export default function QuestionNotFound() {
  return (
    <div className="py-16 text-center">
      <h1 className="font-serif text-3xl">Question not found</h1>
      <Link href="/questions" className="mt-4 inline-block text-primary hover:underline">Back to questions</Link>
    </div>
  );
}
