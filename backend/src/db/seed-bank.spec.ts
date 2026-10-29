import { readFileSync } from 'node:fs';
import type { BankSource } from './seed-sources.js';

/** The starter bank the seed imports; translations overlay English by id. */
interface Bank {
  chapters: Record<string, { title: string; subtitle: string }>;
  questions: {
    id: string;
    chapter: string;
    level: number;
    difficulty: number;
    question: string;
    options: string[];
    answer?: number;
    explanation: string;
    source?: BankSource;
  }[];
}

const load = (code: string) =>
  JSON.parse(readFileSync(`seed/questions/${code}.json`, 'utf8')) as Bank;

const CHAPTERS = [
  'constitution',
  'rights',
  'criminal',
  'procedure',
  'civil',
  'everyday',
];

describe('starter question bank', () => {
  const en = load('en');

  it('covers every chapter and difficulty', () => {
    for (const c of CHAPTERS) {
      expect(en.chapters[c]?.title, c).toBeTruthy();
      for (const d of [1, 2, 3]) {
        expect(
          en.questions.some((q) => q.chapter === c && q.difficulty === d),
          `${c} difficulty ${d}`,
        ).toBe(true);
      }
    }
  });

  it('has well-formed questions with unique ids', () => {
    const ids = new Set<string>();
    for (const q of en.questions) {
      expect(ids.has(q.id), `duplicate ${q.id}`).toBe(false);
      ids.add(q.id);
      expect(q.options, q.id).toHaveLength(4);
      expect(new Set(q.options).size, q.id).toBe(4);
      expect(q.answer, q.id).toBeGreaterThanOrEqual(0);
      expect(q.answer, q.id).toBeLessThan(4);
      expect(q.question.trim(), q.id).not.toBe('');
      expect(q.explanation.trim(), q.id).not.toBe('');
      expect(CHAPTERS, q.id).toContain(q.chapter);
    }
  });

  it('gives every question a source, an https link or none, and dates', () => {
    const date = /^\d{4}-\d{2}-\d{2}$/;
    for (const q of en.questions) {
      const src = q.source;
      expect(src, q.id).toBeDefined();
      if (!src) continue;
      expect(src.title.trim(), q.id).not.toBe('');
      if (src.url !== null) expect(src.url, q.id).toMatch(/^https:\/\/\S+$/);
      expect(src.valid_from, q.id).toMatch(date);
      if (src.valid_to !== null) {
        expect(src.valid_to, q.id).toMatch(date);
        expect(src.valid_to > src.valid_from, q.id).toBe(true);
      }
      expect(src.note.trim(), q.id).not.toBe('');
    }
  });

  it.each(['hi', 'ta', 'te', 'kn', 'ml'])(
    '%s mirrors English ids and option counts',
    (code) => {
      const t = load(code);
      expect(t.questions).toHaveLength(en.questions.length);
      t.questions.forEach((q, i) => {
        expect(q.id).toBe(en.questions[i].id);
        expect(q.options, q.id).toHaveLength(4);
        expect(q.answer, 'answers must come from English').toBeUndefined();
      });
      for (const c of CHAPTERS)
        expect(t.chapters[c]?.title, `${code} ${c}`).toBeTruthy();
    },
  );
});
