import Link from 'next/link';
import { Card } from '@/components/ui';
import { api, must } from '@/lib/api';

/**
 * Read only. A fixed paper can pin only published questions, so this shows how
 * many questions of the import are ready and gives their positions in the
 * format the paper's "Set positions" box takes. It changes nothing.
 */
export async function PaperPanel({ jobId }: { jobId: string }) {
  const client = await api();
  const data = await client
    .GET('/v1/admin/import-jobs/{id}/paper-positions', { params: { path: { id: jobId } } })
    .then(must);
  if (data.rows.every((r) => !r.question_id && r.outcome !== 'withdrawn')) return null;
  const waiting = data.rows.filter((r) => !r.ready && r.question_id);

  return (
    <Card className="flex flex-col gap-3">
      <div>
        <h2 className="font-serif text-2xl">Build a paper from this import</h2>
        <p className="mt-1 text-sm text-muted">
          A paper can only use <strong>published</strong> questions. {data.ready} of {data.rows.length} rows are published and ready
          {data.withdrawn > 0 && `, ${data.withdrawn} are withdrawn positions (no question; the paper keeps the slot)`}
          {data.not_ready > 0 && `; ${data.not_ready} are not ready`}. Positions follow the order of the file.
        </p>
      </div>
      {waiting.length > 0 && (
        <ul className="max-h-48 overflow-y-auto text-sm text-muted">
          {waiting.map((r) => (
            <li key={r.row}>
              Row {r.row}
              {r.external_ref && ` (${r.external_ref})`}: {r.reason}.{' '}
              <Link href={`/questions/${r.question_id}`} className="text-primary hover:underline">Open</Link>
            </li>
          ))}
        </ul>
      )}
      {data.positions.length > 0 ? (
        <div className="flex flex-col gap-2">
          <p className="text-sm">
            Copy this into <strong>Set positions</strong> on a draft paper under <Link href="/exams" className="text-primary hover:underline">Exams</Link>.
            Once every position is filled, the paper follows its usual checks and publishing.
          </p>
          <textarea
            readOnly
            rows={8}
            className="w-full rounded-lg border border-border bg-surface-2 p-3 font-mono text-xs"
            value={JSON.stringify(data.positions, null, 2)}
            aria-label="Paper positions"
          />
        </div>
      ) : (
        <p className="text-sm text-muted">
          Nothing to pin yet. Submit, review and publish the questions first (Review queue, then Ready to publish).
        </p>
      )}
    </Card>
  );
}
