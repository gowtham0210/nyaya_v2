/**
 * Reference sources for Ask AI: live, free lookups on three websites.
 * Nothing is cited unless a page was really found and the model says it relied
 * on it. Any failure here just means "no sources"; the answer is unaffected.
 */
export const SC_SITE = 'Supreme Court of India';
export const IC_SITE = 'India Code';
export const WIKI_SITE = 'Wikipedia';

export interface Source {
  site: string;
  title: string;
  url: string;
  snippet: string;
}

const TIMEOUT_MS = 4000;
const PER_SITE = 3;
const SNIPPET_CHARS = 400;

const STOPWORDS = new Set(
  `a an the is are was were be been am do does did can could should would will shall may might must
  what which who whom whose when where why how and or but if then than so of in on at to for from by
  with about into over under as it its this that these those i me my we our you your he she they them
  their there here not no yes any some please tell explain give say mean meaning law legal india indian
  abt abut explain explained describe define definition details detail info information know need want
  regarding related kindly simple simply words short brief shortly example examples between difference`
    .split(/\s+/)
    .filter(Boolean),
);

/** The few words worth searching for, or '' when the question has none. */
export function searchTerms(question: string): string {
  const words = question
    .toLowerCase()
    .replace(/[^\p{L}\p{N}\s]/gu, ' ')
    .split(/\s+/)
    .filter((w) => w.length > 2 && !STOPWORDS.has(w) && /^[a-z0-9]+$/.test(w));
  return [...new Set(words)].slice(0, 6).join(' ');
}

const ENTITIES: Record<string, string> = {
  amp: '&',
  lt: '<',
  gt: '>',
  quot: '"',
  apos: "'",
  nbsp: ' ',
  hellip: '…',
};

function plain(html: string): string {
  return html
    .replace(/<[^>]*>/g, ' ')
    .replace(/&(#x?[0-9a-f]+|[a-z]+);/gi, (m, e: string) => {
      if (e[0] === '#') {
        const code =
          e[1].toLowerCase() === 'x'
            ? parseInt(e.slice(2), 16)
            : parseInt(e.slice(1), 10);
        return Number.isFinite(code) ? String.fromCodePoint(code) : m;
      }
      return ENTITIES[e.toLowerCase()] ?? m;
    })
    .replace(/\s+/g, ' ')
    .trim();
}

async function get(url: string): Promise<Response | null> {
  try {
    const res = await fetch(url, {
      headers: { 'user-agent': 'NyayaApp/1.0', accept: '*/*' },
      signal: AbortSignal.timeout(TIMEOUT_MS),
    });
    return res.ok ? res : null;
  } catch {
    return null;
  }
}

/** India Code's public catalogue search (an open DSpace API, no key). */
async function indiaCode(terms: string): Promise<Source[]> {
  const res = await get(
    `https://indiacode.gov.in/server/api/discover/search/objects?size=${PER_SITE}&query=${encodeURIComponent(terms)}`,
  );
  const body = (await res?.json().catch(() => null)) as {
    _embedded?: {
      searchResult?: {
        _embedded?: {
          objects?: {
            hitHighlights?: Record<string, string[]>;
            _embedded?: {
              indexableObject?: {
                name?: string;
                handle?: string;
                metadata?: Record<string, { value?: string }[]>;
              };
            };
          }[];
        };
      };
    };
  } | null;
  const out: Source[] = [];
  for (const o of body?._embedded?.searchResult?._embedded?.objects ?? []) {
    const item = o._embedded?.indexableObject;
    if (!item?.name || !item.handle || !/^\d+\/\d+$/.test(item.handle))
      continue;
    const meta = (k: string) => item.metadata?.[k]?.[0]?.value;
    const parts = [
      item.name,
      meta('dc.identifier.act_name') && `Act: ${meta('dc.identifier.act_name')}`,
      meta('dc.identifier.section_number') &&
        `Section ${meta('dc.identifier.section_number')}`,
      ...Object.values(o.hitHighlights ?? {}).flat(),
    ].filter(Boolean) as string[];
    out.push({
      site: IC_SITE,
      title: plain(item.name),
      url: `https://indiacode.gov.in/handle/${item.handle}`,
      snippet: plain(parts.join('. ')).slice(0, SNIPPET_CHARS),
    });
  }
  return out;
}

/** The Supreme Court website's own (server-rendered) search page. */
async function supremeCourt(terms: string): Promise<Source[]> {
  const res = await get(
    `https://www.sci.gov.in/?s=${encodeURIComponent(terms)}`,
  );
  const html = res ? await res.text().catch(() => '') : '';
  const out: Source[] = [];
  const item =
    /<h2 class="heading3"><a [^>]*href="(https:\/\/www\.sci\.gov\.in\/[^"]*)"[^>]*>(.*?)<\/a><\/h2>\s*(?:<p>(.*?)<\/p>)?/gs;
  for (const m of html.matchAll(item)) {
    const title = plain(m[2]);
    if (!title) continue;
    out.push({
      site: SC_SITE,
      title,
      url: m[1],
      snippet: plain(m[3] ?? title).slice(0, SNIPPET_CHARS),
    });
    if (out.length === PER_SITE) break;
  }
  return out;
}

/** Wikipedia's free search API: broad background for questions the two official sites don't cover. */
async function wikipedia(terms: string): Promise<Source[]> {
  const res = await get(
    `https://en.wikipedia.org/w/api.php?action=query&generator=search&gsrlimit=${PER_SITE}&prop=extracts%7Cinfo&inprop=url&exintro=1&explaintext=1&exchars=${SNIPPET_CHARS}&exlimit=max&format=json&utf8=1&gsrsearch=${encodeURIComponent(`${terms} India`)}`,
  );
  const body = (await res?.json().catch(() => null)) as {
    query?: {
      pages?: Record<
        string,
        { title?: string; index?: number; extract?: string; fullurl?: string }
      >;
    };
  } | null;
  return Object.values(body?.query?.pages ?? {})
    .filter(
      (p) => p.title && p.fullurl?.startsWith('https://en.wikipedia.org/wiki/'),
    )
    .sort((a, b) => (a.index ?? 0) - (b.index ?? 0))
    .map((p) => ({
      site: WIKI_SITE,
      title: p.title!,
      url: p.fullurl!,
      snippet: plain(p.extract ?? p.title!).slice(0, SNIPPET_CHARS),
    }));
}

/** Tries all the words, then just the first few (the sites match every word). */
async function search(
  find: (terms: string) => Promise<Source[]>,
  terms: string,
): Promise<Source[]> {
  const all = await find(terms).catch(() => []);
  const words = terms.split(' ');
  return all.length || words.length <= 3
    ? all
    : find(words.slice(0, 3).join(' ')).catch(() => []);
}

/**
 * Candidate pages for a question; empty when nothing was found. A very short
 * follow-up ("and online?") borrows the words of the earlier question.
 */
export async function findSources(
  question: string,
  earlier?: string,
): Promise<Source[]> {
  let terms = searchTerms(question);
  if (terms.split(' ').filter(Boolean).length < 2 && earlier)
    terms = searchTerms(`${earlier} ${question}`);
  if (!terms) return [];
  const [ic, sc, wiki] = await Promise.all([
    search(indiaCode, terms),
    search(supremeCourt, terms),
    search(wikipedia, terms),
  ]);
  return [...ic, ...sc, ...wiki];
}

/** Appended to the instructions only when pages were found. */
export function sourcesPrompt(sources: Source[]): string {
  const list = sources
    .map((s, i) => `[${i + 1}] ${s.site} — ${s.title}\n    ${s.snippet}`)
    .join('\n');
  return `
Reference pages found just now on the web (they may be irrelevant):
${list}

Every page above is a candidate reference. Before finishing, check each one: if it is about the same law or topic as the question and nothing in it contradicts your answer, it counts as a reference for the answer, even if you already knew the facts. Never invent details from these pages. On its own final line write "SOURCES:" followed by the numbers of all such pages, e.g. "SOURCES: 4,5"; write "SOURCES: none" only if no page is about the topic. Never mention this line or the numbers in the answer itself.
`;
}

/** Removes the model's SOURCES line and returns only the pages it named. */
export function splitSources(
  text: string,
  sources: Source[],
): { text: string; used: Source[] } {
  const line = /^[ \t]*\**SOURCES\**:[ \t]*(.*)$/im;
  const m = line.exec(text);
  if (!m) return { text, used: [] };
  const ids = new Set(
    [...m[1].matchAll(/\d+/g)]
      .map((n) => Number(n[0]))
      .filter((n) => n >= 1 && n <= sources.length),
  );
  const clean = text
    .replace(new RegExp(line.source, 'gim'), '')
    .replace(/\n{3,}/g, '\n\n')
    .trim();
  return {
    text: clean,
    used: sources.filter((_, i) => ids.has(i + 1)),
  };
}
