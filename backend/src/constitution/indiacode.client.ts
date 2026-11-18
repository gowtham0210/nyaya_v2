import { Inject, Injectable } from '@nestjs/common';
import { APP_CONFIG, type AppConfig } from '../core/config.js';
import { isUuid } from './manifest.js';

/** The file of one item as India Code describes it. Never its bytes. */
export interface LiveFile {
  uuid: string;
  name: string;
  sizeBytes: number;
  md5: string;
}

/** One item of the Constitution collection, from India Code's metadata. */
export interface LiveItem {
  itemUuid: string;
  /** e.g. `123456789/618412` */
  handle: string;
  /** India Code's own title (kept for the record; it has typos). */
  title: string;
  /** ISO timestamp the item last changed on India Code. */
  lastModified: string;
  /** The PDF; null when the item has none. */
  original: LiveFile | null;
  /** Size of the extracted text file; null when there is none. */
  textBytes: number | null;
}

/**
 * Reads the Constitution collection's metadata. A class (not an interface) so
 * Nest can inject it and tests can replace it with a fake.
 */
export abstract class IndiaCodeClient {
  abstract fetchCollection(collectionUuid: string): Promise<LiveItem[]>;
}

const TIMEOUT_MS = 10_000;
const CONCURRENCY = 4;

/**
 * India Code runs DSpace, whose REST API is open. Only metadata endpoints are
 * called (a search of the collection and each item's file list); no file
 * content is ever requested, and HEAD is not used because the site refuses it.
 */
@Injectable()
export class HttpIndiaCodeClient extends IndiaCodeClient {
  constructor(@Inject(APP_CONFIG) private readonly config: AppConfig) {
    super();
  }

  async fetchCollection(collectionUuid: string): Promise<LiveItem[]> {
    const base = `${this.config.indiaCodeBaseUrl}/server/api`;
    const query = new URLSearchParams({
      scope: collectionUuid,
      dsoType: 'ITEM',
      size: '100',
    });
    const found = await this.json(`${base}/discover/search/objects?${query}`);
    const objects = found?._embedded?.searchResult?._embedded?.objects;
    if (!Array.isArray(objects))
      throw new Error('India Code search returned an unexpected shape');
    const total = found._embedded.searchResult.page?.totalElements;
    if (typeof total === 'number' && total > objects.length)
      throw new Error(`India Code has ${total} items; the first page has ${objects.length}`);

    return mapLimit(objects, CONCURRENCY, async (o: any) => {
      const item = o?._embedded?.indexableObject;
      if (!item || !isUuid(item.uuid) || typeof item.handle !== 'string')
        throw new Error('India Code returned an item without an id');
      const bundles = await this.json(
        `${base}/core/items/${item.uuid}/bundles?embed=bitstreams&size=20`,
      );
      return toLiveItem(item, bundles?._embedded?.bundles);
    });
  }

  /** GET JSON with a timeout; one retry for a timeout or a 5xx. */
  private async json(url: string, attempt = 1): Promise<any> {
    try {
      const res = await fetch(url, {
        headers: {
          Accept: 'application/json',
          'User-Agent': 'NyayaKural-metadata/1.0',
        },
        signal: AbortSignal.timeout(TIMEOUT_MS),
      });
      if (res.status >= 500 && attempt < 2) return this.json(url, attempt + 1);
      if (!res.ok) throw new Error(`India Code answered ${res.status}`);
      return await res.json();
    } catch (e) {
      if (attempt < 2 && (e as Error).name === 'TimeoutError')
        return this.json(url, attempt + 1);
      throw e;
    }
  }
}

/** Picks the PDF and the text layer out of an item's bundles. */
export function toLiveItem(item: any, bundles: any): LiveItem {
  let original: LiveFile | null = null;
  let textBytes: number | null = null;
  for (const b of Array.isArray(bundles) ? bundles : []) {
    const files: any[] = b?._embedded?.bitstreams?._embedded?.bitstreams ?? [];
    if (b?.name === 'ORIGINAL') {
      const pdf =
        files.find((f) => String(f?.name).toLowerCase().endsWith('.pdf')) ??
        null;
      if (
        pdf &&
        isUuid(pdf.uuid) &&
        Number.isFinite(pdf.sizeBytes) &&
        typeof pdf.checkSum?.value === 'string'
      )
        original = {
          uuid: pdf.uuid,
          name: String(pdf.name),
          sizeBytes: pdf.sizeBytes,
          md5: pdf.checkSum.value,
        };
    } else if (b?.name === 'TEXT' && files.length) {
      textBytes = Math.max(...files.map((f) => Number(f?.sizeBytes) || 0));
    }
  }
  return {
    itemUuid: item.uuid,
    handle: item.handle,
    title: String(item.metadata?.['dc.title']?.[0]?.value ?? '')
      .replace(/ /g, ' ')
      .trim(),
    lastModified: String(item.lastModified ?? ''),
    original,
    textBytes,
  };
}

async function mapLimit<T, R>(
  items: T[],
  limit: number,
  fn: (item: T) => Promise<R>,
): Promise<R[]> {
  const out: R[] = Array.from({ length: items.length });
  let next = 0;
  await Promise.all(
    Array.from({ length: Math.min(limit, items.length) }, async () => {
      while (next < items.length) {
        const i = next++;
        out[i] = await fn(items[i]);
      }
    }),
  );
  return out;
}
