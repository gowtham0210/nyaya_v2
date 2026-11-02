import sharp from 'sharp';
import { startApp, type TestApp } from './helpers.js';

const complete = {
  category: 'high_courts',
  title: 'High Court on tenant rights',
  summary: 'A High Court said a tenant cannot be evicted without notice.',
  key_points: ['Notice is required.'],
  why_it_matters: 'Tenants know where they stand.',
  source: 'Bombay High Court, 2 February 2026',
  event_date: '2026-02-02',
  read_minutes: 2,
};

/** A plain picture in [format], [width] × [height] pixels. */
const picture = (
  format: 'jpeg' | 'png' | 'webp' | 'gif',
  width = 1600,
  height = 1000,
) =>
  sharp({
    create: {
      width,
      height,
      channels: 3,
      background: { r: 135, g: 63, b: 43 },
    },
  })
    .toFormat(format)
    .toBuffer();

const binary = (
  res: { on: (e: string, f: (c?: Buffer) => void) => void },
  done: (e: null, b: Buffer) => void,
) => {
  const chunks: Buffer[] = [];
  res.on('data', (c?: Buffer) => chunks.push(c!));
  res.on('end', () => done(null, Buffer.concat(chunks)));
};

describe('news card pictures', () => {
  let t: TestApp;
  let editor: Awaited<ReturnType<TestApp['signInAs']>>;
  let reviewer: Awaited<ReturnType<TestApp['signInAs']>>;
  let publisher: Awaited<ReturnType<TestApp['signInAs']>>;

  beforeAll(async () => {
    t = await startApp();
    editor = await t.signInAs('content_editor');
    reviewer = await t.signInAs('legal_reviewer');
    publisher = await t.signInAs('publisher');
  });
  afterAll(() => t.close());

  const draft = async () =>
    (
      await t
        .http()
        .post('/v1/editor/news')
        .auth(editor.token, { type: 'bearer' })
        .send(complete)
        .expect(201)
    ).body.id as string;

  const upload = (id: string, file: Buffer, token = editor.token) =>
    t
      .http()
      .put(`/v1/editor/news/${id}/image`)
      .auth(token, { type: 'bearer' })
      .attach('file', file, 'picture');

  const publish = async (id: string) => {
    for (const [token, step] of [
      [editor.token, 'submit'],
      [reviewer.token, 'approve'],
      [publisher.token, 'publish'],
    ] as const)
      await t
        .http()
        .post(`/v1/editor/news/${id}/${step}`)
        .auth(token, { type: 'bearer' })
        .expect(200);
  };

  it('stores an upload as a smaller WebP and shows it in the app once published', async () => {
    const id = await draft();
    const res = await upload(id, await picture('jpeg', 2400, 1600)).expect(200);
    expect(res.body.image).toMatchObject({ width: 1200, height: 800 });
    expect(res.body.image.url).toMatch(
      new RegExp(`^/v1/editor/news/${id}/image\\?v=[0-9a-f]{16}$`),
    );

    // Staff can see it; the app can't until the article is published.
    const staff = await t
      .http()
      .get(res.body.image.url)
      .auth(editor.token, { type: 'bearer' })
      .buffer(true)
      .parse(binary)
      .expect(200);
    expect(staff.headers['content-type']).toBe('image/webp');
    expect((await sharp(staff.body as Buffer).metadata()).format).toBe('webp');
    await t.http().get(`/v1/news/${id}/image`).expect(404);

    await publish(id);
    const item = (await t.http().get('/v1/news').expect(200)).body.items.find(
      (a: { id: string }) => a.id === id,
    );
    expect(item.image_url).toMatch(
      new RegExp(`^/v1/news/${id}/image\\?v=[0-9a-f]{16}$`),
    );
    const pub = await t
      .http()
      .get(item.image_url)
      .buffer(true)
      .parse(binary)
      .expect(200);
    expect(pub.headers['cache-control']).toBe(
      'public, max-age=31536000, immutable',
    );
    expect(pub.headers['content-type']).toBe('image/webp');
  });

  it('refuses files that are not a usable picture', async () => {
    const id = await draft();
    const gif = await upload(id, await picture('gif')).expect(422);
    expect(gif.body.code).toBe('invalid_picture');
    await upload(id, Buffer.from('not a picture')).expect(422);
    const small = await upload(id, await picture('png', 300, 200)).expect(422);
    expect(small.body.message).toMatch(/at least 480 pixels/);
    await upload(id, Buffer.alloc(6 * 1024 * 1024, 1)).expect(413);
    const detail = await t
      .http()
      .get(`/v1/editor/news/${id}`)
      .auth(editor.token, { type: 'bearer' })
      .expect(200);
    expect(detail.body.image).toBeNull();
  });

  it('changes only with the article: not once published, and only by editors', async () => {
    const id = await draft();
    await upload(id, await picture('webp'), reviewer.token).expect(403);
    await upload(id, await picture('webp')).expect(200);
    await publish(id);
    const locked = await upload(id, await picture('png')).expect(409);
    expect(locked.body.code).toBe('invalid_transition');
    await t
      .http()
      .delete(`/v1/editor/news/${id}/image`)
      .auth(editor.token, { type: 'bearer' })
      .expect(409);
  });

  it('can be replaced and removed while a draft, and articles without one say so', async () => {
    const id = await draft();
    const first = (await upload(id, await picture('jpeg')).expect(200)).body
      .image.url;
    const second = (
      await upload(id, await picture('png', 1000, 1000)).expect(200)
    ).body.image;
    expect(second.url).not.toBe(first);
    expect(second).toMatchObject({ width: 1000, height: 1000 });
    const removed = await t
      .http()
      .delete(`/v1/editor/news/${id}/image`)
      .auth(editor.token, { type: 'bearer' })
      .expect(200);
    expect(removed.body.image).toBeNull();
    await t
      .http()
      .get(`/v1/editor/news/${id}/image`)
      .auth(editor.token, { type: 'bearer' })
      .expect(404);

    const starter = (
      await t.http().get('/v1/news').expect(200)
    ).body.items.find(
      (a: { title: string }) =>
        a.title === 'Supreme Court sets timelines for Governors on State Bills',
    );
    expect(starter.image_url).toBeNull();
  });
});
