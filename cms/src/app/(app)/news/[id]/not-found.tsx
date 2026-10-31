import Link from 'next/link';

export default function ArticleNotFound() {
  return (
    <div className="py-16 text-center">
      <h1 className="font-serif text-3xl">Article not found</h1>
      <Link href="/news" className="mt-4 inline-block text-primary hover:underline">Back to news</Link>
    </div>
  );
}
