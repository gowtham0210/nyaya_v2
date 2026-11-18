import { describe, expect, it } from 'vitest';
import { loadConfig } from '../core/config.js';
import {
  ConstitutionService,
  LARGE_BYTES,
  SCANNED_TEXT_BYTES,
} from './constitution.service.js';
import {
  IndiaCodeClient,
  type LiveItem,
} from './indiacode.client.js';
import { loadManifest, validateManifest, type Manifest } from './manifest.js';

const manifest = loadManifest();
const all = [manifest.original, ...manifest.editions];

/** What India Code would say right now if nothing changed since the review. */
function unchangedLive(): LiveItem[] {
  return all.map((e) => ({
    itemUuid: e.item_uuid,
    handle: e.handle,
    title: `India Code title of ${e.id}`,
    lastModified: `${e.reviewed.item_modified}T08:00:00Z`,
    original: {
      uuid: e.reviewed.bitstream_uuid,
      name: `${e.id}.pdf`,
      sizeBytes: e.reviewed.size_bytes,
      md5: e.reviewed.md5,
    },
    textBytes: e.reviewed.text_bytes,
  }));
}

/** A fake India Code: serves what the test sets, counts and can fail or stall. */
class FakeClient extends IndiaCodeClient {
  items: LiveItem[] = unchangedLive();
  calls = 0;
  failing: string | null = null;
  gate: Promise<void> | null = null;
  async fetchCollection(collectionUuid: string) {
    expect(collectionUuid).toBe(manifest.collection.uuid);
    this.calls++;
    await this.gate;
    if (this.failing) throw new Error(this.failing);
    return structuredClone(this.items);
  }
}

function setup(m: Manifest = manifest) {
  const client = new FakeClient();
  const config = loadConfig({});
  const service = new ConstitutionService(client, config, m);
  let now = new Date('2026-11-17T06:00:00Z');
  service.clock = () => now;
  return {
    client,
    service,
    config,
    advanceHours: (h: number) => (now = new Date(now.getTime() + h * 3_600_000)),
  };
}
const flush = () => new Promise((r) => setTimeout(r, 0));

describe('the manifest', () => {
  it('lists the 26 editions and the original, with unique ids, and the six app languages', () => {
    expect(manifest.editions).toHaveLength(26);
    expect(manifest.original.id).toBe('original');
    const ids = all.map((e) => e.id);
    expect(new Set(ids).size).toBe(27);
    for (const code of ['en', 'hi', 'ta', 'te', 'kn', 'ml'])
      expect(manifest.editions.map((e) => e.language_code)).toContain(code);
  });

  it('says nothing about legal authority until it is reviewed', () => {
    expect(all.every((e) => e.authority_note === null)).toBe(true);
    expect(manifest.notice).toMatch(/India Code/);
  });

  it('refuses a broken file at startup', () => {
    const clone = () => structuredClone(manifest);
    const noNotice = clone();
    noNotice.notice = ' ';
    expect(() => validateManifest(noNotice)).toThrow(/notice/);
    const dup = clone();
    dup.editions[1].id = dup.editions[0].id;
    expect(() => validateManifest(dup)).toThrow(/duplicate/);
    const badUuid = clone();
    badUuid.editions[0].reviewed.bitstream_uuid = 'not-a-uuid';
    expect(() => validateManifest(badUuid)).toThrow(/bitstream_uuid/);
    const badMd5 = clone();
    badMd5.editions[0].reviewed.md5 = 'xyz';
    expect(() => validateManifest(badMd5)).toThrow(/md5/);
  });
});

describe('the list', () => {
  it('gives every edition India Code links, with the original separate', async () => {
    const { service, client, config } = setup();
    const res = await service.list();
    expect(client.calls).toBe(1);
    expect(res.editions).toHaveLength(26);
    expect(res.original?.id).toBe('original');
    expect(res.editions.find((e) => e.id === 'original')).toBeUndefined();
    expect(res.source.stale).toBe(false);
    expect(res.source.fetched_at).toBe('2026-11-17T06:00:00.000Z');
    expect(res.source.collection_url).toBe(
      `${config.indiaCodeBaseUrl}/handle/123456789/618379`,
    );
    const ta = res.editions.find((e) => e.id === 'ta')!;
    expect(ta).toMatchObject({
      language_name: 'Tamil',
      native_name: 'தமிழ்',
      title: 'The Constitution of India in Tamil',
      source_title: 'India Code title of ta',
      authority_note: null,
    });
    expect(ta.download_url).toBe(
      `https://indiacode.gov.in/server/api/core/bitstreams/${manifest.editions.find((e) => e.id === 'ta')!.reviewed.bitstream_uuid}/content`,
    );
    expect(ta.source_page_url).toBe('https://indiacode.gov.in/handle/123456789/618412');
    expect(ta.file.format).toBe('pdf');
    // Every link points at India Code and nowhere else.
    for (const e of [res.original!, ...res.editions]) {
      expect(new URL(e.download_url).origin).toBe('https://indiacode.gov.in');
      expect(new URL(e.source_page_url).origin).toBe('https://indiacode.gov.in');
    }
  });

  it('sorts by the manifest order', async () => {
    const { service } = setup();
    const ids = (await service.list()).editions.map((e) => e.id);
    expect(ids).toEqual(
      [...manifest.editions].sort((a, b) => a.sort - b.sort).map((e) => e.id),
    );
  });

  it('warns about large and scanned editions from what India Code says', async () => {
    const { service } = setup();
    const res = await service.list();
    const flags = Object.fromEntries(
      [res.original!, ...res.editions].map((e) => [e.id, e.flags]),
    );
    expect(flags.kok).toEqual({ large: true, scanned: true }); // 137 MB scan
    expect(flags.original).toEqual({ large: true, scanned: true });
    expect(flags.bn).toEqual({ large: true, scanned: true });
    expect(flags['mni-Beng']).toEqual({ large: true, scanned: true });
    expect(flags['sd-Arab']).toEqual({ large: false, scanned: true });
    expect(flags.en).toEqual({ large: false, scanned: false });
    expect(flags.ta).toEqual({ large: false, scanned: false });
    expect(LARGE_BYTES).toBe(20_000_000);
    expect(SCANNED_TEXT_BYTES).toBe(10_000);
  });

  it('follows a changed file: new link, new size, new warnings', async () => {
    const { service, client } = setup();
    const ta = manifest.editions.find((e) => e.id === 'ta')!;
    const item = client.items.find((i) => i.itemUuid === ta.item_uuid)!;
    item.original = {
      uuid: '11111111-1111-4111-8111-111111111111',
      name: 'new.pdf',
      sizeBytes: 25_000_000,
      md5: 'a'.repeat(32),
    };
    item.textBytes = 12;
    item.lastModified = '2026-11-01T00:00:00Z';
    const e = (await service.list()).editions.find((x) => x.id === 'ta')!;
    expect(e.download_url).toContain('11111111-1111-4111-8111-111111111111');
    expect(e.file).toMatchObject({
      size_bytes: 25_000_000,
      checksum_md5: 'a'.repeat(32),
      source_modified_at: '2026-11-01',
    });
    expect(e.flags).toEqual({ large: true, scanned: true });
  });

  it('lets the manifest override a warning', async () => {
    const m = structuredClone(manifest);
    m.editions.find((e) => e.id === 'kok')!.large = false;
    m.editions.find((e) => e.id === 'en')!.scanned = true;
    const { service } = setup(m);
    const res = await service.list();
    expect(res.editions.find((e) => e.id === 'kok')!.flags.large).toBe(false);
    expect(res.editions.find((e) => e.id === 'en')!.flags.scanned).toBe(true);
  });

  it('hides an edition India Code no longer lists, instead of showing a dead link', async () => {
    const { service, client } = setup();
    client.items = client.items.filter((i) => i.itemUuid !== manifest.editions[0].item_uuid);
    const res = await service.list();
    expect(res.editions).toHaveLength(25);
    expect(res.editions.map((e) => e.id)).not.toContain(manifest.editions[0].id);
    // The same when the item is there but has lost its PDF.
    const other = manifest.editions[1];
    client.items.find((i) => i.itemUuid === other.item_uuid)!.original = null;
    const again = await setupAgain(client);
    expect(again.editions.map((e) => e.id)).not.toContain(other.id);
  });

  it('never shows an item that is not in the manifest', async () => {
    const { service, client } = setup();
    client.items.push({
      itemUuid: '22222222-2222-4222-8222-222222222222',
      handle: '123456789/999999',
      title: 'The Constitution of India in Klingon',
      lastModified: '2026-11-01T00:00:00Z',
      original: { uuid: '33333333-3333-4333-8333-333333333333', name: 'k.pdf', sizeBytes: 1, md5: 'b'.repeat(32) },
      textBytes: 5000,
    });
    const res = await service.list();
    expect(res.editions).toHaveLength(26);
    expect(JSON.stringify(res)).not.toContain('Klingon');
  });
});

/** A fresh service over the same fake, so a second read happens. */
async function setupAgain(client: FakeClient) {
  const s = new ConstitutionService(client, loadConfig({}), manifest);
  return s.list();
}

describe('reading India Code', () => {
  it('falls back to the reviewed values, marked stale, when it cannot be reached', async () => {
    const { service, client } = setup();
    client.failing = 'India Code answered 503';
    const res = await service.list();
    expect(res.source).toMatchObject({ fetched_at: null, stale: true });
    expect(res.editions).toHaveLength(26);
    expect(res.original).not.toBeNull();
    const ta = res.editions.find((e) => e.id === 'ta')!;
    const reviewed = manifest.editions.find((e) => e.id === 'ta')!.reviewed;
    expect(ta.file.checksum_md5).toBe(reviewed.md5);
    expect(ta.download_url).toContain(reviewed.bitstream_uuid);
    expect(res.editions.find((e) => e.id === 'kok')!.flags).toEqual({ large: true, scanned: true });
  });

  it('asks India Code once for requests that arrive together', async () => {
    const { service, client } = setup();
    let release!: () => void;
    client.gate = new Promise<void>((r) => (release = r));
    const calls = Promise.all([service.list(), service.list(), service.list()]);
    await flush();
    release();
    await calls;
    expect(client.calls).toBe(1);
  });

  it('does not ask again within the refresh interval', async () => {
    const { service, client, advanceHours } = setup();
    await service.list();
    advanceHours(11);
    await service.list();
    await flush();
    expect(client.calls).toBe(1);
  });

  it('serves the old copy at once when it is out of date, and renews it in the background', async () => {
    const { service, client, advanceHours } = setup();
    await service.list();
    const ta = client.items.find((i) => i.itemUuid === manifest.editions.find((e) => e.id === 'ta')!.item_uuid)!;
    ta.original!.sizeBytes = 123;
    advanceHours(13);
    // Served from the old copy, not waiting for India Code.
    expect((await service.list()).editions.find((e) => e.id === 'ta')!.file.size_bytes).not.toBe(123);
    await flush();
    expect(client.calls).toBe(2);
    expect((await service.list()).editions.find((e) => e.id === 'ta')!.file.size_bytes).toBe(123);
    expect(client.calls).toBe(2);
  });

  it('keeps the last good copy, marked stale, when a renewal fails', async () => {
    const { service, client, advanceHours } = setup();
    await service.list();
    client.failing = 'timeout';
    advanceHours(13);
    await service.list();
    await flush();
    const res = await service.list();
    expect(res.editions).toHaveLength(26);
    expect(res.source.stale).toBe(true);
    expect(res.source.fetched_at).toBe('2026-11-17T06:00:00.000Z');
    // Recovers on the next read after it works again.
    client.failing = null;
    advanceHours(0);
    await service.drift();
    expect((await service.list()).source.stale).toBe(false);
  });
});

describe('drift', () => {
  it('is all unchanged when India Code matches the review', async () => {
    const { service } = setup();
    const d = await service.drift();
    expect(d.summary).toEqual({ unchanged: 27, changed: 0, missing: 0, new: 0 });
    expect(d.last_error).toBeNull();
    expect(d.items.every((i) => i.state === 'unchanged' && i.live !== null)).toBe(true);
  });

  it('reports a replaced file by what differs', async () => {
    const { service, client } = setup();
    const en = manifest.editions.find((e) => e.id === 'en')!;
    const item = client.items.find((i) => i.itemUuid === en.item_uuid)!;
    item.original!.uuid = '44444444-4444-4444-8444-444444444444';
    item.original!.md5 = 'c'.repeat(32);
    item.original!.sizeBytes += 1;
    const d = await service.drift();
    const row = d.items.find((i) => i.id === 'en')!;
    expect(row.state).toBe('changed');
    expect(row.changed_fields).toEqual(['bitstream', 'checksum', 'size']);
    expect(row.live?.bitstream_uuid).toBe('44444444-4444-4444-8444-444444444444');
    expect(d.summary).toMatchObject({ changed: 1, unchanged: 26 });
  });

  it('notes an edit to the item without calling an identical file changed', async () => {
    const { service, client } = setup();
    const hi = manifest.editions.find((e) => e.id === 'hi')!;
    client.items.find((i) => i.itemUuid === hi.item_uuid)!.lastModified = '2026-11-10T00:00:00Z';
    const row = (await service.drift()).items.find((i) => i.id === 'hi')!;
    expect(row.state).toBe('unchanged');
    expect(row.modified_since_review).toBe(true);
  });

  it('notices when a scan gains a text layer', async () => {
    const { service, client } = setup();
    const bn = manifest.editions.find((e) => e.id === 'bn')!;
    client.items.find((i) => i.itemUuid === bn.item_uuid)!.textBytes = 900_000;
    const row = (await service.drift()).items.find((i) => i.id === 'bn')!;
    expect(row).toMatchObject({ state: 'changed', changed_fields: ['text_layer'] });
  });

  it('reports a missing edition and a new one', async () => {
    const { service, client } = setup();
    client.items = client.items.filter((i) => i.itemUuid !== manifest.editions[3].item_uuid);
    client.items.push({
      itemUuid: '55555555-5555-4555-8555-555555555555',
      handle: '123456789/777777',
      title: 'The Constitution of India in Khasi',
      lastModified: '2026-11-15T00:00:00Z',
      original: { uuid: '66666666-6666-4666-8666-666666666666', name: 'khasi.pdf', sizeBytes: 5_000_000, md5: 'd'.repeat(32) },
      textBytes: 100_000,
    });
    const d = await service.drift();
    expect(d.items.find((i) => i.id === manifest.editions[3].id)).toMatchObject({ state: 'missing', live: null });
    expect(d.new_items).toEqual([
      { item_uuid: '55555555-5555-4555-8555-555555555555', handle: '123456789/777777', title: 'The Constitution of India in Khasi', size_bytes: 5_000_000 },
    ]);
    expect(d.summary).toEqual({ unchanged: 26, changed: 0, missing: 1, new: 1 });
  });

  it('says "unknown", not "unchanged", when India Code cannot be read', async () => {
    const { service, client } = setup();
    client.failing = 'India Code answered 500';
    const d = await service.drift();
    expect(d.fetched_at).toBeNull();
    expect(d.last_error).toBe('India Code answered 500');
    expect(d.items.every((i) => i.state === 'unknown')).toBe(true);
    expect(d.summary.unchanged).toBe(0);
  });
});
