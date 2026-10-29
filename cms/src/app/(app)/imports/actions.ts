'use server';

import { redirect } from 'next/navigation';
import { api, asApiError, type Schemas } from '@/lib/api';
import { SESSION_ENDED_URL } from '@/lib/session-cookies';

export interface UploadState {
  report?: Schemas['ImportReportDto'];
  error?: string;
  reasons?: string[];
  /** Set when this exact file was imported before. */
  previousImportId?: string;
}

/**
 * Sends the chosen file to the API: a test run returns the report; a real
 * import opens the saved report. The API decides who may import.
 */
export async function uploadImport(form: FormData): Promise<UploadState> {
  const file = form.get('file');
  if (!(file instanceof File) || file.size === 0) return { error: 'Choose a .csv or .xlsx file first.' };
  const dryRun = form.get('dry_run') !== 'false';
  const body = new FormData();
  body.set('file', file, file.name);
  body.set('dry_run', String(dryRun));

  const client = await api();
  const { data, error, response } = await client.POST('/v1/admin/import-jobs', {
    body: body as never,
    bodySerializer: (b) => b as unknown as FormData,
  });
  if (!data) {
    if (response.status === 401) redirect(SESSION_ENDED_URL);
    const err = asApiError(error, response.status);
    if (err.code === 'already_imported')
      return { error: err.message, previousImportId: err.details?.[0]?.reason };
    return { error: err.message, reasons: (err.details ?? []).map((d) => d.reason) };
  }
  if (!dryRun && data.id) redirect(`/imports/${data.id}`);
  return { report: data };
}
