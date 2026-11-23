import { createServer, type Server } from 'node:http';
import type { AddressInfo } from 'node:net';
import { loadManifest } from '../src/constitution/manifest.js';
import { startApp, type TestApp } from './helpers.js';

const manifest = loadManifest();
const all = [manifest.original, ...manifest.editions];

/** A stand-in for India Code's open (DSpace) API, serving metadata only. */
function fakeIndiaCode() {
  // The state of each item: starts as the reviewed manifest says.
  const items = all.map((e) => ({
    uuid: e.item_uuid,
    handle: e.handle,
    title: `India Code: ${e.title}`,
    lastModified: `${e.reviewed.item_modified}T08:00:00Z`,
    pdf: {
      uuid: e.reviewed.bitstream_uuid,
      name: `${e.id}.pdf`,
      sizeBytes: e.reviewed.size_bytes,
      md5: e.reviewed.md5,
    },
    textBytes: e.reviewed.text_bytes,
  }));
  const log: { method: string; path: string }[] = [];
  const bitstream = (
    uuid: string,
    name: string,
    sizeBytes: number,
    md5: string,
  ) => ({
    uuid,
    name,
    sizeBytes,
    checkSum: { checkSumAlgorithm: 'MD5', value: md5 },
  });
  const server: Server = createServer((req, res) => {
    const url = new URL(req.url!, 'http://x');
    log.push({ method: req.method!, path: url.pathname });
    const send = (code: number, body: unknown) => {
      res.writeHead(code, { 'content-type': 'application/hal+json' });
      res.end(JSON.stringify(body));
    };
    if (url.pathname === '/server/api/discover/search/objects') {
      return send(200, {
        _embedded: {
          searchResult: {
            _embedded: {
              objects: items.map((i) => ({
                _embedded: {
                  indexableObject: {
                    uuid: i.uuid,
                    handle: i.handle,
                    lastModified: i.lastModified,
                    metadata: { 'dc.title': [{ value: i.title }] },
                  },
                },
              })),
            },
            page: {
              size: 100,
              totalElements: items.length,
              totalPages: 1,
              number: 0,
            },
          },
        },
      });
    }
    const m = url.pathname.match(
      /^\/server\/api\/core\/items\/([0-9a-f-]{36})\/bundles$/,
    );
    if (m) {
      const i = items.find((x) => x.uuid === m[1]);
      if (!i) return send(404, { status: 404 });
      const bundles: any[] = [];
      if (i.pdf)
        bundles.push({
          name: 'ORIGINAL',
          _embedded: {
            bitstreams: {
              _embedded: {
                bitstreams: [
                  bitstream(i.pdf.uuid, i.pdf.name, i.pdf.sizeBytes, i.pdf.md5),
                ],
              },
            },
          },
        });
      if (i.textBytes !== null)
        bundles.push({
          name: 'TEXT',
          _embedded: {
            bitstreams: {
              _embedded: {
                bitstreams: [
                  bitstream(
                    '99999999-9999-4999-8999-999999999999',
                    `${i.pdf?.name}.txt`,
                    i.textBytes,
                    'e'.repeat(32),
                  ),
                ],
              },
            },
          },
        });
      bundles.push({
        name: 'THUMBNAIL',
        _embedded: { bitstreams: { _embedded: { bitstreams: [] } } },
      });
      return send(200, { _embedded: { bundles } });
    }
    send(404, { status: 404 });
  });
  return { items, log, server };
}

describe('Constitution of India editions', () => {
  const india = fakeIndiaCode();
  let t: TestApp;
  let admin: Awaited<ReturnType<TestApp['signInAs']>>;
  let editor: Awaited<ReturnType<TestApp['signInAs']>>;
  let base: string;

  beforeAll(async () => {
    await new Promise<void>((r) => india.server.listen(0, '127.0.0.1', r));
    base = `http://127.0.0.1:${(india.server.address() as AddressInfo).port}`;
    t = await startApp({ indiaCodeBaseUrl: base });
    admin = await t.signInAs('admin');
    editor = await t.signInAs('content_editor');
  });
  afterAll(async () => {
    await t.close();
    await new Promise((r) => india.server.close(r));
  });

  it('reads nothing from India Code until somebody asks', () => {
    expect(india.log).toEqual([]);
  });

  it('serves the list publicly: 26 editions, the original apart, India Code links, warnings', async () => {
    const res = await t.http().get('/v1/constitution').expect(200);
    expect(res.headers['cache-control']).toBe('public, max-age=3600');
    expect(res.body.editions).toHaveLength(26);
    expect(res.body.original.id).toBe('original');
    expect(res.body.notice).toMatch(/India Code/);
    expect(res.body.source).toMatchObject({ stale: false });
    expect(res.body.source.collection_url).toBe(
      `${base}/handle/123456789/618379`,
    );

    const ta = res.body.editions.find((e: { id: string }) => e.id === 'ta');
    expect(ta).toMatchObject({
      language_name: 'Tamil',
      title: 'The Constitution of India in Tamil',
      source_title: 'India Code: The Constitution of India in Tamil',
      authority_note: null,
      flags: { large: false, scanned: false },
      file: {
        format: 'pdf',
        checksum_md5: manifest.editions.find((e) => e.id === 'ta')!.reviewed
          .md5,
      },
    });
    expect(ta.download_url).toBe(
      `${base}/server/api/core/bitstreams/${manifest.editions.find((e) => e.id === 'ta')!.reviewed.bitstream_uuid}/content`,
    );
    const kok = res.body.editions.find((e: { id: string }) => e.id === 'kok');
    expect(kok.flags).toEqual({ large: true, scanned: true });
    expect(res.body.original.flags).toEqual({ large: true, scanned: true });
  });

  it('only ever asks India Code for metadata, never a document', () => {
    const paths = new Set(
      india.log.map((l) => l.path.replace(/[0-9a-f-]{36}/, '<id>')),
    );
    expect([...paths].sort()).toEqual([
      '/server/api/core/items/<id>/bundles',
      '/server/api/discover/search/objects',
    ]);
    expect(india.log.every((l) => l.method === 'GET')).toBe(true);
    expect(
      india.log.some(
        (l) => l.path.includes('/content') || l.path.includes('/download'),
      ),
    ).toBe(false);
    // One search plus one file list per item.
    expect(india.log).toHaveLength(1 + 27);
  });

  it('does not ask India Code again for the next request', async () => {
    await t.http().get('/v1/constitution').expect(200);
    await t.http().get('/v1/constitution').expect(200);
    expect(india.log).toHaveLength(1 + 27);
  });

  it('keeps the drift report to admins', async () => {
    await t.http().get('/v1/admin/constitution/drift').expect(401);
    await t
      .http()
      .get('/v1/admin/constitution/drift')
      .auth(editor.token, { type: 'bearer' })
      .expect(403);
    const learner = await t.signInAs('learner');
    await t
      .http()
      .get('/v1/admin/constitution/drift')
      .auth(learner.token, { type: 'bearer' })
      .expect(403);
  });

  it('reports no drift while India Code matches the review', async () => {
    const res = await t
      .http()
      .get('/v1/admin/constitution/drift')
      .auth(admin.token, { type: 'bearer' })
      .expect(200);
    expect(res.body.summary).toEqual({
      unchanged: 27,
      changed: 0,
      missing: 0,
      new: 0,
    });
    expect(res.body.last_error).toBeNull();
    expect(res.body.fetched_at).not.toBeNull();
  });

  it('shows a replaced file, a removed edition and a new one in the drift report', async () => {
    const en = india.items.find(
      (i) => i.uuid === manifest.editions.find((e) => e.id === 'en')!.item_uuid,
    )!;
    en.pdf.md5 = 'f'.repeat(32);
    en.pdf.uuid = '77777777-7777-4777-8777-777777777777';
    const gone = india.items.findIndex(
      (i) => i.uuid === manifest.editions.find((e) => e.id === 'ur')!.item_uuid,
    );
    india.items.splice(gone, 1);
    india.items.push({
      uuid: '88888888-8888-4888-8888-888888888888',
      handle: '123456789/888888',
      title: 'Khasi edition',
      lastModified: '2026-11-16T00:00:00Z',
      pdf: {
        uuid: '12121212-1212-4212-8212-121212121212',
        name: 'k.pdf',
        sizeBytes: 4_000_000,
        md5: '1'.repeat(32),
      },
      textBytes: 50_000,
    });
    const res = await t
      .http()
      .get('/v1/admin/constitution/drift')
      .auth(admin.token, { type: 'bearer' })
      .expect(200);
    expect(res.body.summary).toEqual({
      unchanged: 25,
      changed: 1,
      missing: 1,
      new: 1,
    });
    expect(
      res.body.items.find((i: { id: string }) => i.id === 'en'),
    ).toMatchObject({
      state: 'changed',
      changed_fields: ['bitstream', 'checksum'],
    });
    expect(
      res.body.items.find((i: { id: string }) => i.id === 'ur').state,
    ).toBe('missing');
    expect(res.body.new_items).toHaveLength(1);
    expect(res.body.new_items[0]).toMatchObject({
      handle: '123456789/888888',
      title: 'Khasi edition',
    });
  });

  it('then serves the replaced file and hides the removed edition, and never the new one', async () => {
    // The drift read renewed the copy the list uses.
    const res = await t.http().get('/v1/constitution').expect(200);
    const ids = res.body.editions.map((e: { id: string }) => e.id);
    expect(ids).toHaveLength(25);
    expect(ids).not.toContain('ur');
    expect(JSON.stringify(res.body)).not.toContain('Khasi');
    const en = res.body.editions.find((e: { id: string }) => e.id === 'en');
    expect(en.download_url).toContain('77777777-7777-4777-8777-777777777777');
    expect(en.file.checksum_md5).toBe('f'.repeat(32));
  });
});

describe('Constitution editions when India Code cannot be reached', () => {
  let t: TestApp;
  let admin: Awaited<ReturnType<TestApp['signInAs']>>;
  beforeAll(async () => {
    // Nothing listens on port 1.
    t = await startApp({ indiaCodeBaseUrl: 'http://127.0.0.1:1' });
    admin = await t.signInAs('admin');
  });
  afterAll(() => t.close());

  it('still answers, from the reviewed values, marked stale', async () => {
    const res = await t.http().get('/v1/constitution').expect(200);
    expect(res.body.source).toMatchObject({ fetched_at: null, stale: true });
    expect(res.body.editions).toHaveLength(26);
    expect(res.body.original.id).toBe('original');
    expect(res.body.editions[0].download_url).toMatch(
      /\/server\/api\/core\/bitstreams\/[0-9a-f-]{36}\/content$/,
    );
  });

  it('tells admins it does not know, rather than claiming nothing changed', async () => {
    const res = await t
      .http()
      .get('/v1/admin/constitution/drift')
      .auth(admin.token, { type: 'bearer' })
      .expect(200);
    expect(res.body.summary.unchanged).toBe(0);
    expect(res.body.last_error).toEqual(expect.any(String));
    expect(
      res.body.items.every((i: { state: string }) => i.state === 'unknown'),
    ).toBe(true);
  });
});
