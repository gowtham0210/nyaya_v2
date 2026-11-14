import { eq } from 'drizzle-orm';
import { chatUsage } from '../src/db/schema.js';
import { DECLINED_REPLY, OFF_TOPIC_REPLY } from '../src/chat/chat.prompt.js';
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
  // Source lookups on the two official sites are not Azure calls: they find
  // nothing here unless a test hands them pages, so fetchMock only sees Azure.
  vi.stubGlobal('fetch', (url: string, init?: RequestInit) =>
    url.startsWith(azure.endpoint)
      ? (fetchMock(url, init) as Promise<Response>)
      : Promise.resolve(sitePages(url)),
  );
  return fetchMock;
}

let sitePages: (url: string) => Response = () =>
  new Response('{}', { status: 404 });

const answer = (text: string) => ({
  json: { choices: [{ finish_reason: 'stop', message: { content: text } }] },
});

describe('chat', () => {
  let t: TestApp;
  beforeAll(
    async () =>
      (t = await startApp({
        azureOpenAi: azure,
        chatDailyLimit: 2,
        chatFreeDailyLimit: 2,
      })),
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

  it('never returns code, but still counts that paid answer', async () => {
    const s = await t.signInAs('learner');
    const fetchMock = azureReplies(
      answer('Sure:\n```python\nprint("hello")\n```'),
    );
    const res = await t
      .http()
      .post('/v1/chat')
      .set('Authorization', `Bearer ${s.token}`)
      .send(question('Tell me about hello'))
      .expect(200);
    expect(res.body.reply).toBe(OFF_TOPIC_REPLY);
    expect(res.body.remaining_today).toBe(1);
    // The model is also told to stay in scope.
    const sent = JSON.parse(
      (fetchMock.mock.calls[0] as [string, RequestInit])[1].body as string,
    );
    expect(sent.messages[0].content).toContain('Never write, fix, explain');
    const rows = await t.db
      .select({ answers: chatUsage.answers })
      .from(chatUsage)
      .where(eq(chatUsage.userId, s.id));
    expect(rows).toEqual([{ answers: 1 }]);
  });

  it('refuses requests to write code without calling the model', async () => {
    const s = await t.signInAs('learner');
    const fetchMock = azureReplies();
    const ask = (content: string) =>
      t
        .http()
        .post('/v1/chat')
        .set('Authorization', `Bearer ${s.token}`)
        .send(question(content))
        .expect(200);
    for (const q of [
      'Write a Python program to sort a list',
      'please fix this javascript bug',
      'Give me source code for a login page',
    ])
      expect((await ask(q)).body.reply).toBe(OFF_TOPIC_REPLY);
    expect(fetchMock).not.toHaveBeenCalled();
  });

  it('answers legal questions that use words that are also code names', async () => {
    const s = await t.signInAs('learner');
    const fetchMock = azureReplies(answer('Stay calm.'), answer('Stay calm.'));
    // Two questions: the test limit is 2 answers a day.
    for (const q of [
      'Show me how to react if police stop me',
      'Give me the rules for a swift trial in Dart district',
    ]) {
      const res = await t
        .http()
        .post('/v1/chat')
        .set('Authorization', `Bearer ${s.token}`)
        .send(question(q))
        .expect(200);
      expect(res.body.reply).toBe('Stay calm.');
    }
    expect(fetchMock).toHaveBeenCalledTimes(2);
  });

  it('still answers legal questions that mention a code', async () => {
    const s = await t.signInAs('learner');
    azureReplies(answer('It sets out the court procedure.'));
    const res = await t
      .http()
      .post('/v1/chat')
      .set('Authorization', `Bearer ${s.token}`)
      .send(question('Explain the Code of Criminal Procedure in simple words'))
      .expect(200);
    expect(res.body.reply).toBe('It sets out the court procedure.');
  });

  it('also catches code that is not in a fenced block', async () => {
    const s = await t.signInAs('learner');
    azureReplies(answer('import os\ndef run():\n  pass'));
    const res = await t
      .http()
      .post('/v1/chat')
      .set('Authorization', `Bearer ${s.token}`)
      .send(question('Tell me about bail'))
      .expect(200);
    expect(res.body.reply).toBe(OFF_TOPIC_REPLY);
  });

  describe('reference sources', () => {
    const icPage = {
      _embedded: {
        searchResult: {
          _embedded: {
            objects: [
              {
                _embedded: {
                  indexableObject: {
                    name: 'The Bharatiya Nyaya Sanhita, 2023',
                    handle: '123456789/496548',
                  },
                },
              },
            ],
          },
        },
      },
    };
    const sciPage =
      '<div class="searchItem"><h2 class="heading3"><a title="x" href="https://www.sci.gov.in/legal-aid/" target="_self">Legal Aid</a></h2><p>Free legal aid &amp; advice [&hellip;]</p></div>';
    const withSites = () => {
      sitePages = (url) =>
        url.startsWith('https://indiacode.gov.in/')
          ? new Response(JSON.stringify(icPage))
          : url.startsWith('https://www.sci.gov.in/')
            ? new Response(sciPage)
            : new Response('', { status: 404 });
    };
    afterEach(() => {
      sitePages = () => new Response('{}', { status: 404 });
    });
    const ask = async (q: string) => {
      const s = await t.signInAs('learner');
      return t
        .http()
        .post('/v1/chat')
        .set('Authorization', `Bearer ${s.token}`)
        .send(question(q))
        .expect(200);
    };

    it('cites only the pages the answer relied on and hides the marker', async () => {
      withSites();
      const fetchMock = azureReplies(
        answer('Murder is punishable under BNS.\n\nSOURCES: 1'),
      );
      const res = await ask('What is the punishment for murder under BNS?');
      expect(res.body.reply).toBe('Murder is punishable under BNS.');
      expect(res.body.sources).toEqual([
        {
          site: 'India Code',
          title: 'The Bharatiya Nyaya Sanhita, 2023',
          url: 'https://indiacode.gov.in/handle/123456789/496548',
        },
      ]);
      const prompt = JSON.parse(
        (fetchMock.mock.calls[0] as [string, RequestInit])[1].body as string,
      ).messages[0].content as string;
      expect(prompt).toContain('[1] India Code');
      expect(prompt).toContain('[2] Supreme Court of India');
    });

    it('can cite Wikipedia, using the page address the site returned', async () => {
      sitePages = (url) =>
        url.startsWith('https://en.wikipedia.org/')
          ? new Response(
              JSON.stringify({
                query: {
                  pages: {
                    '1': {
                      title: 'Collegium system',
                      index: 1,
                      extract: 'The collegium system appoints judges.',
                      fullurl: 'https://en.wikipedia.org/wiki/Collegium_system',
                    },
                  },
                },
              }),
            )
          : new Response('', { status: 404 });
      azureReplies(answer('Judges are appointed by the collegium.\nSOURCES: 1'));
      const res = await ask('How does the collegium system work?');
      expect(res.body.sources).toEqual([
        {
          site: 'Wikipedia',
          title: 'Collegium system',
          url: 'https://en.wikipedia.org/wiki/Collegium_system',
        },
      ]);
    });

    it('cites nothing when the model used none of the pages', async () => {
      withSites();
      azureReplies(answer('Bail is a right in some cases.\nSOURCES: none'));
      const res = await ask('Explain bail rules');
      expect(res.body.reply).toBe('Bail is a right in some cases.');
      expect(res.body).not.toHaveProperty('sources');
    });

    it('ignores source numbers it was never given', async () => {
      withSites();
      azureReplies(answer('Answer.\nSOURCES: 7'));
      const res = await ask('Explain bail rules');
      expect(res.body).not.toHaveProperty('sources');
    });

    it('answers normally, with no sources, when the sites find nothing', async () => {
      const fetchMock = azureReplies(answer('A Zero FIR can be filed anywhere.'));
      const res = await ask('What is a Zero FIR?');
      expect(res.body.reply).toBe('A Zero FIR can be filed anywhere.');
      expect(res.body).not.toHaveProperty('sources');
      const prompt = JSON.parse(
        (fetchMock.mock.calls[0] as [string, RequestInit])[1].body as string,
      ).messages[0].content as string;
      expect(prompt).not.toContain('SOURCES');
    });
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
