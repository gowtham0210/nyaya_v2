import { Inject, Injectable, Logger } from '@nestjs/common';
import { APP_CONFIG, type AppConfig } from '../core/config.js';
import type {
  ConstitutionDriftDto,
  ConstitutionDto,
  ConstitutionEditionDto,
  DriftItemDto,
  DriftNewItemDto,
} from './constitution.dto.js';
import { IndiaCodeClient, type LiveItem } from './indiacode.client.js';
import { isUuid, type Manifest, type ManifestEdition } from './manifest.js';

export const CONSTITUTION_MANIFEST = Symbol('CONSTITUTION_MANIFEST');

/** A download of at least this many bytes gets a "large file" warning. */
export const LARGE_BYTES = 20_000_000;
/** An extracted text file smaller than this means the PDF is scanned images. */
export const SCANNED_TEXT_BYTES = 10_000;

const day = (iso: string) => iso.slice(0, 10);

/**
 * The Constitution editions for the app: our curated manifest, combined with
 * what India Code says about each file right now. India Code is read lazily
 * (nothing at startup, no scheduler), at most once per refresh interval, one
 * request at a time. If it cannot be reached, the last good copy, or failing
 * that the reviewed values in the manifest, are used. No document is ever
 * downloaded, stored or proxied: the app is only given India Code's addresses.
 */
@Injectable()
export class ConstitutionService {
  private readonly log = new Logger(ConstitutionService.name);
  /** Replaced by tests to move time. */
  clock: () => Date = () => new Date();

  private snapshot: { items: LiveItem[]; at: Date } | null = null;
  private lastError: string | null = null;
  private inflight: Promise<void> | null = null;

  constructor(
    private readonly client: IndiaCodeClient,
    @Inject(APP_CONFIG) private readonly config: AppConfig,
    @Inject(CONSTITUTION_MANIFEST) private readonly manifest: Manifest,
  ) {}

  async list(): Promise<ConstitutionDto> {
    await this.ensureFresh();
    const live = this.snapshot ? liveByItem(this.snapshot.items) : null;
    const build = (e: ManifestEdition) => this.edition(e, live);
    const original = build(this.manifest.original);
    return {
      source: {
        name: 'India Code, Legislative Department, Ministry of Law and Justice',
        collection_url: `${this.base}/handle/${this.manifest.collection.handle}`,
        fetched_at: this.snapshot?.at.toISOString() ?? null,
        stale: this.isStale(),
      },
      notice: this.manifest.notice,
      original,
      editions: [...this.manifest.editions]
        .sort((a, b) => a.sort - b.sort)
        .map(build)
        .filter((e): e is ConstitutionEditionDto => e !== null),
    };
  }

  /** What changed on India Code since the manifest was reviewed. Reads it afresh. */
  async drift(): Promise<ConstitutionDriftDto> {
    await this.refresh();
    const live = this.snapshot ? liveByItem(this.snapshot.items) : null;
    const entries = [this.manifest.original, ...this.manifest.editions];
    const items = entries.map((e) => driftOf(e, live));
    const known = new Set(entries.map((e) => e.item_uuid));
    const newItems: DriftNewItemDto[] = (this.snapshot?.items ?? [])
      .filter((i) => !known.has(i.itemUuid))
      .map((i) => ({
        item_uuid: i.itemUuid,
        handle: i.handle,
        title: i.title,
        size_bytes: i.original?.sizeBytes ?? null,
      }));
    const count = (s: string) => items.filter((i) => i.state === s).length;
    return {
      fetched_at: this.snapshot?.at.toISOString() ?? null,
      last_error: this.lastError,
      summary: {
        unchanged: count('unchanged'),
        changed: count('changed'),
        missing: count('missing'),
        new: newItems.length,
      },
      items,
      new_items: newItems,
    };
  }

  // ---------------------------------------------------------------- helpers

  private get base() {
    return this.config.indiaCodeBaseUrl;
  }

  private isStale() {
    return !this.snapshot || this.lastError !== null;
  }

  private expired() {
    const ttl = this.config.constitutionRefreshHours * 3_600_000;
    return (
      !this.snapshot ||
      this.clock().getTime() - this.snapshot.at.getTime() >= ttl
    );
  }

  /**
   * First use waits for India Code; after that an expired copy is served
   * while a new one is read in the background, so a slow site never slows the app.
   */
  private async ensureFresh() {
    if (!this.snapshot) await this.refresh();
    else if (this.expired()) void this.refresh();
  }

  /** One read at a time; never throws (the failure is kept in lastError). */
  private refresh(): Promise<void> {
    this.inflight ??= (async () => {
      try {
        const items = await this.client.fetchCollection(
          this.manifest.collection.uuid,
        );
        this.snapshot = { items, at: this.clock() };
        this.lastError = null;
      } catch (e) {
        this.lastError = (e as Error).message;
        this.log.warn(`India Code could not be read: ${this.lastError}`);
      } finally {
        this.inflight = null;
      }
    })();
    return this.inflight;
  }

  /**
   * One edition for the app, or null if India Code was read and no longer
   * lists its PDF (so a link that would fail is never shown).
   */
  private edition(
    e: ManifestEdition,
    live: Map<string, LiveItem> | null,
  ): ConstitutionEditionDto | null {
    const item = live?.get(e.item_uuid);
    const file = item?.original;
    if (live && !file) return null;
    const bitstream = file?.uuid ?? e.reviewed.bitstream_uuid;
    if (!isUuid(bitstream)) return null;
    const size = file?.sizeBytes ?? e.reviewed.size_bytes;
    const textBytes = live ? (item?.textBytes ?? null) : e.reviewed.text_bytes;
    const handle = item?.handle ?? e.handle;
    return {
      id: e.id,
      language_code: e.language_code,
      language_name: e.language_name,
      native_name: e.native_name,
      script: e.script,
      title: e.title,
      source_title: item?.title || null,
      authority_note: e.authority_note,
      // Only ever India Code's own host, built here from a checked UUID.
      download_url: `${this.base}/server/api/core/bitstreams/${bitstream}/content`,
      source_page_url: `${this.base}/handle/${handle}`,
      file: {
        format: 'pdf',
        size_bytes: size,
        checksum_md5: file?.md5 ?? e.reviewed.md5,
        source_modified_at: item?.lastModified
          ? day(item.lastModified)
          : e.reviewed.item_modified,
      },
      flags: {
        large: e.large ?? size >= LARGE_BYTES,
        scanned:
          e.scanned ?? (textBytes === null || textBytes < SCANNED_TEXT_BYTES),
      },
    };
  }
}

function liveByItem(items: LiveItem[]) {
  return new Map(items.map((i) => [i.itemUuid, i]));
}

function driftOf(
  e: ManifestEdition,
  live: Map<string, LiveItem> | null,
): DriftItemDto {
  const base = { id: e.id, language_name: e.language_name };
  if (!live)
    return {
      ...base,
      state: 'unknown',
      changed_fields: [],
      modified_since_review: false,
      live: null,
    };
  const item = live.get(e.item_uuid);
  const file = item?.original;
  if (!item || !file)
    return {
      ...base,
      state: 'missing',
      changed_fields: [],
      modified_since_review: false,
      live: null,
    };
  const r = e.reviewed;
  const changed: string[] = [];
  if (file.uuid !== r.bitstream_uuid) changed.push('bitstream');
  if (file.md5 !== r.md5) changed.push('checksum');
  if (file.sizeBytes !== r.size_bytes) changed.push('size');
  if (
    (item.textBytes ?? 0) < SCANNED_TEXT_BYTES !==
    (r.text_bytes ?? 0) < SCANNED_TEXT_BYTES
  )
    changed.push('text_layer');
  return {
    ...base,
    // The file itself is what matters; a bare metadata edit is only noted.
    state: changed.length ? 'changed' : 'unchanged',
    changed_fields: changed,
    modified_since_review: day(item.lastModified) !== r.item_modified,
    live: {
      bitstream_uuid: file.uuid,
      md5: file.md5,
      size_bytes: file.sizeBytes,
      item_modified: day(item.lastModified),
    },
  };
}
