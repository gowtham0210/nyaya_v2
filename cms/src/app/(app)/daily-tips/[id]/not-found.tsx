import Link from 'next/link';

export default function TipNotFound() {
  return (
    <div className="py-16 text-center">
      <h1 className="font-serif text-3xl">Tip not found</h1>
      <Link href="/daily-tips" className="mt-4 inline-block text-primary hover:underline">Back to daily tips</Link>
    </div>
  );
}
