import { readFileSync } from 'node:fs';

/**
 * The curated list of Constitution of India editions published on India Code.
 * India Code's own metadata has no language field, uses inconsistent titles
 * and says nothing about authority, so what we say about each edition is kept
 * here, in `manifest.json`, and reviewed by people. What India Code says about
 * the files themselves (size, checksum, date) is read live and compared with
 * the `reviewed` snapshot to spot changes.
 */

/** What was seen on India Code when a person last reviewed the edition. */
export interface ReviewedFile {
  bitstream_uuid: string;
  md5: string;
  size_bytes: number;
  /** Size of the extracted text file; tiny means the PDF is scanned images. */
  text_bytes: number | null;
  item_modified: string;
}

export interface ManifestEdition {
  /** Stable id used by the app (`ta`, `mni-Mtei`, `original`). */
  id: string;
  /** BCP 47 style code; null for the original copy, which is not a language. */
  language_code: string | null;
  language_name: string;
  native_name: string | null;
  script: string | null;
  /** Our English display title (India Code's titles have typos). */
  title: string;
  sort: number;
  item_uuid: string;
  /** India Code handle, e.g. `123456789/618412`. */
  handle: string;
  /**
   * What we say about this edition's legal standing. Null until the legal
   * reviewer approves wording; the app then shows only the neutral notice.
   */
  authority_note: string | null;
  /** Overrides for the computed warnings (leave out to compute them). */
  large?: boolean;
  scanned?: boolean;
  reviewed: ReviewedFile;
}

export interface Manifest {
  version: 1;
  collection: { uuid: string; handle: string; name: string };
  /** Neutral attribution shown with the list. */
  notice: string;
  editions: ManifestEdition[];
  original: ManifestEdition;
}

const UUID = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/;
const HANDLE = /^\d+\/\d+$/;

export const isUuid = (v: unknown): v is string =>
  typeof v === 'string' && UUID.test(v);

/** Reads and checks the manifest; a bad file stops startup, not a request. */
export function loadManifest(
  path: URL = new URL('./manifest.json', import.meta.url),
): Manifest {
  return validateManifest(JSON.parse(readFileSync(path, 'utf8')));
}

export function validateManifest(raw: unknown): Manifest {
  const m = raw as Manifest;
  const bad = (why: string): never => {
    throw new Error(`constitution manifest is invalid: ${why}`);
  };
  if (!m || m.version !== 1) bad('version must be 1');
  if (!isUuid(m.collection?.uuid)) bad('collection.uuid');
  if (!m.notice?.trim()) bad('notice is required');
  if (!Array.isArray(m.editions) || m.editions.length === 0) bad('no editions');
  const seen = new Set<string>();
  for (const e of [...m.editions, m.original]) {
    if (!e) bad('original is required');
    if (!e.id || seen.has(e.id)) bad(`duplicate or empty id "${e.id}"`);
    seen.add(e.id);
    if (!e.title?.trim() || !e.language_name?.trim())
      bad(`${e.id}: title and language_name are required`);
    if (!isUuid(e.item_uuid)) bad(`${e.id}: item_uuid`);
    if (!HANDLE.test(e.handle ?? '')) bad(`${e.id}: handle`);
    if (!isUuid(e.reviewed?.bitstream_uuid))
      bad(`${e.id}: reviewed.bitstream_uuid`);
    if (!/^[0-9a-f]{32}$/.test(e.reviewed?.md5 ?? ''))
      bad(`${e.id}: reviewed.md5`);
    if (!(e.reviewed?.size_bytes > 0)) bad(`${e.id}: reviewed.size_bytes`);
  }
  const uuids = [...m.editions, m.original].map((e) => e.item_uuid);
  if (new Set(uuids).size !== uuids.length) bad('an item appears twice');
  return m;
}
