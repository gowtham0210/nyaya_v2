import { eq } from 'drizzle-orm';
import { chatUsage } from '../src/db/schema.js';
import { DECLINED_REPLY } from '../src/chat/chat.prompt.js';
import { startApp, type TestApp } from './helpers.js';

const azure = {
  endpoint: 'https://azure.test',
  apiKey: 'test-key',
  chatDeployment: 'gpt-test',
};

const question = (content = 'What is a Zero FIR?') => ({
  messages: [{ role: 'user', content }],
  language: 'ta',
  persona: 'citizen',
});

/** Replaces the call to Azure; supertest itself does not use fetch. */
function azureReplies(...bodies: { status?: number; json: unknown }[]) {
  const fetchMock = vi.fn();
  for (const b of bodies)
    fetchMock.mockResolvedValueOnce(
      new Response(JSON.stringify(b.json), { status: b.status ?? 200 }),
    );
  vi.stubGlobal('fetch', fetchMock);
  return fetchMock;
}

const answer = (text: string) => ({
  json: { choices: [{ finish_reason: 'stop', message: { content: text } }] },
});

describe('chat', () => {
  let t: TestApp;
  beforeAll(
    async () => (t = await startApp({ azureOpenAi: azure, chatDailyLimit: 2 })),
  );
  afterAll(() => t.close());
  afterEach(() => vi.unstubAllGlobals());

  it('needs a signed-in user', async () => {
    await t.http().post('/v1/chat').send(question()).expect(401);
  });

  it('answers with the deployment, prompt and history, and counts the answer', async () => {
    const s = await t.signInAs('learner');
    const fetchMock = azureReplies(answer('A Zero FIR can be filed anywhere.'));
    const res = await t
      .http()
      .post('/v1/chat')
      .set('Authorization', `Bearer ${s.token}`)
      .send({
        ...question('And online?'),
        messages: [
          { role: 'user', content: 'What is a Zero FIR?' },
          { role: 'assistant', content: 'It can be filed at any station.' },
          { role: 'user', content: 'And online?' },
        ],
      })
      .expect(200);
    expect(res.body).toEqual({
      reply: 'A Zero FIR can be filed anywhere.',
      remaining_today: 1,
    });

    const [url, init] = fetchMock.mock.calls[0] as [string, RequestInit];
    expect(url).toBe('https://azure.test/openai/v1/chat/completions');
    expect((init.headers as Record<string, string>)['api-key']).toBe(
      'test-key',
    );
    const sent = JSON.parse(init.body as string);
    expect(sent.model).toBe('gpt-test');
    expect(sent.messages[0].role).toBe('system');
    expect(sent.messages[0].content).toContain('Tamil');
    expect(sent.messages[0].content).toContain('common citizen');
    expect(sent.messages.slice(1).map((m: { role: string }) => m.role)).toEqual(
      ['user', 'assistant', 'user'],
    );
  });

  it('stops at the daily limit', async () => {
    const s = await t.signInAs('learner');
    azureReplies(answer('One.'), answer('Two.'));
    const ask = () =>
      t
        .http()
        .post('/v1/chat')
        .set('Authorization', `Bearer ${s.token}`)
        .send(question());
    await ask().expect(200);
    expect((await ask().expect(200)).body.remaining_today).toBe(0);
    const res = await ask().expect(429);
    expect(res.body.code).toBe('chat_limit_reached');
  });

  it('holds the limit when questions arrive at the same time', async () => {
    const s = await t.signInAs('learner');
    vi.stubGlobal(
      'fetch',
      vi.fn(async () => new Response(JSON.stringify(answer('Yes.').json))),
    );
    const statuses = await Promise.all(
      Array.from({ length: 5 }, () =>
        t
          .http()
          .post('/v1/chat')
          .set('Authorization', `Bearer ${s.token}`)
          .send(question())
          .then((r) => r.status),
      ),
    );
    expect(statuses.sort()).toEqual([200, 200, 429, 429, 429]);
  });

  it('does not count declined or failed questions', async () => {
    const s = await t.signInAs('learner');
    azureReplies(
      { status: 400, json: { error: { code: 'content_filter' } } },
      { status: 500, json: { error: { code: 'server_error' } } },
    );
    const ask = () =>
      t
        .http()
        .post('/v1/chat')
        .set('Authorization', `Bearer ${s.token}`)
        .send(question());
    expect((await ask().expect(200)).body.reply).toBe(DECLINED_REPLY);
    expect((await ask().expect(502)).body.code).toBe('chat_failed');
    const rows = await t.db
      .select({ answers: chatUsage.answers })
      .from(chatUsage)
      .where(eq(chatUsage.userId, s.id));
    expect(rows).toEqual([{ answers: 0 }]);
  });

  it('rejects a conversation that does not end with a question', async () => {
    const s = await t.signInAs('learner');
    await t
      .http()
      .post('/v1/chat')
      .set('Authorization', `Bearer ${s.token}`)
      .send({
        ...question(),
        messages: [{ role: 'assistant', content: 'Hello' }],
      })
      .expect(400);
  });
});

describe('chat without Azure configured', () => {
  let t: TestApp;
  beforeAll(async () => (t = await startApp({ azureOpenAi: undefined })));
  afterAll(() => t.close());

  it('says chat is unavailable', async () => {
    const s = await t.signInAs('learner');
    const res = await t
      .http()
      .post('/v1/chat')
      .set('Authorization', `Bearer ${s.token}`)
      .send(question())
      .expect(503);
    expect(res.body.code).toBe('chat_unavailable');
  });
});
