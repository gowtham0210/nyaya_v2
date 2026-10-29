import writeXlsxFile from 'write-excel-file/node';
import { checkRow, guardCell, readRows, type SheetRow } from './format.js';

const topics = new Map([
  ['constitution-basics', { id: 't1', isActive: true }],
  ['old-topic', { id: 't2', isActive: false }],
]);

const complete = {
  topic: 'constitution-basics',
  stem: 'When did the Constitution come into force?',
  option_a: '26 January 1950',
  option_b: '15 August 1947',
  correct: 'A',
  explanation: 'Republic Day.',
  source_title: 'Constitution of India',
  source_url: 'https://legislative.gov.in/constitution-of-india/',
  valid_from: '1950-01-26',
};

const errorsOf = (r: ReturnType<typeof checkRow>) =>
  r.problems.filter((p) => p.level === 'error').map((p) => p.field);

describe('checkRow', () => {
  it('turns a complete row into a draft with no problems', () => {
    const r = checkRow(complete, topics);
    expect(r.problems).toEqual([]);
    expect(r.draft).toMatchObject({
      topicId: 't1',
      difficulty: 1,
      questionType: 'single_select',
      options: [
        { id: 'a', text: '26 January 1950' },
        { id: 'b', text: '15 August 1947' },
      ],
      correctOptionIds: ['a'],
      jurisdiction: 'IN',
      language: 'en',
    });
  });

  it('imports an unfinished row with warnings for what review needs', () => {
    const r = checkRow(
      {
        topic: 'constitution-basics',
        stem: 'Q?',
        option_a: 'x',
        option_b: 'y',
        correct: 'b',
      },
      topics,
    );
    expect(r.draft).not.toBeNull();
    expect(r.problems.map((p) => [p.level, p.field])).toEqual([
      ['warning', 'explanation'],
      ['warning', 'source_title'],
      ['warning', 'valid_from'],
    ]);
  });

  it.each([
    [{ topic: 'nope' }, 'topic'],
    [{ topic: 'old-topic' }, 'topic'],
    [{ difficulty: '4' }, 'difficulty'],
    [{ question_type: 'essay' }, 'question_type'],
    [{ correct: 'c' }, 'correct'],
    [{ correct: 'a;b' }, 'correct'],
    [{ option_b: '', option_c: 'later' }, 'option_c'],
    [{ option_b: '26 January 1950' }, 'options'],
    [{ valid_from: '29/10/2026' }, 'valid_from'],
    [{ valid_from: '2026-02-30' }, 'valid_from'],
    [{ valid_to: '1949-01-01' }, 'valid_to'],
    [{ source_url: 'http://example.com' }, 'source_url'],
    [{ stem: '' }, 'stem'],
    [{ stem: 'x'.repeat(2001) }, 'stem'],
    [{ language: 'fr' }, 'language'],
  ])('refuses %o (error on %s)', (patch, field) => {
    const r = checkRow({ ...complete, ...patch }, topics);
    expect(r.draft).toBeNull();
    expect(errorsOf(r)).toContain(field);
  });
});

describe('readRows', () => {
  const csv = (s: string) => readRows(Buffer.from(s, 'utf8'), 'csv');

  it('reads a UTF-8 CSV with a byte order mark, quoted cells and blank rows', async () => {
    const rows = await csv(
      '﻿Topic,Stem,Option A,option_b,correct\r\n' +
        'constitution-basics,"Which Article, of the two?",14,"21 ""and"" 22",a\r\n' +
        ',,,,\r\n' +
        'constitution-basics,இந்திய அரசியலமைப்பு?,x,y,b\r\n',
    );
    expect(rows).toEqual<SheetRow[]>([
      {
        row: 2,
        values: {
          topic: 'constitution-basics',
          stem: 'Which Article, of the two?',
          option_a: '14',
          option_b: '21 "and" 22',
          correct: 'a',
        },
      },
      expect.objectContaining({
        row: 4,
        values: expect.objectContaining({ stem: 'இந்திய அரசியலமைப்பு?' }),
      }),
    ]);
  });

  it('takes off the apostrophe export adds before formula-like text', async () => {
    const rows = await csv(
      `topic,stem,option_a,option_b,correct\nconstitution-basics,${guardCell('=1+1')},${guardCell('-0.25')},'quoted,a\n`,
    );
    expect(rows[0].values).toMatchObject({
      stem: '=1+1',
      option_a: '-0.25',
      option_b: "'quoted",
    });
  });

  it.each([
    [
      'not UTF-8',
      Buffer.from([0x74, 0x6f, 0x70, 0x69, 0x63, 0xff, 0x0a]),
      'UTF-8',
    ],
    [
      'an unknown column',
      'topic,stem,option_a,option_b,correct,explaination\n',
      'Unknown column: explaination',
    ],
    [
      'a missing column',
      'topic,stem,option_a,option_b\nx,y,z,w\n',
      'Missing column: correct',
    ],
    [
      'a column twice',
      'topic,stem,stem,option_a,option_b,correct\n',
      'Column named twice: stem',
    ],
    [
      'no data rows',
      'topic,stem,option_a,option_b,correct\n,,,,\n',
      'no questions',
    ],
  ])('refuses a file with %s', async (_, content, reason) => {
    const buf = typeof content === 'string' ? Buffer.from(content) : content;
    await expect(readRows(buf, 'csv')).rejects.toMatchObject({
      code: 'invalid_file',
      details: [
        expect.objectContaining({ reason: expect.stringContaining(reason) }),
      ],
    });
  });

  it('refuses more than 500 questions', async () => {
    const body = Array.from({ length: 501 }, (_, i) => `t,q${i},a,b,a`).join(
      '\n',
    );
    await expect(
      csv(`topic,stem,option_a,option_b,correct\n${body}\n`),
    ).rejects.toMatchObject({
      details: [
        expect.objectContaining({
          reason: expect.stringContaining('at most 500'),
        }),
      ],
    });
  });

  it('reads the first sheet of an Excel file, dates and numbers as text', async () => {
    const buf = await writeXlsxFile([
      [
        { value: 'topic' },
        { value: 'stem' },
        { value: 'option_a' },
        { value: 'option_b' },
        { value: 'correct' },
        { value: 'valid_from' },
      ],
      [
        { value: 'constitution-basics' },
        { value: 'When?' },
        { value: 1950, type: Number },
        { value: 'later' },
        { value: 'a' },
        {
          value: new Date(Date.UTC(1950, 0, 26)),
          type: Date,
          format: 'yyyy-mm-dd',
        },
      ],
    ]).toBuffer();
    const rows = await readRows(buf, 'xlsx');
    expect(rows).toEqual([
      {
        row: 2,
        values: {
          topic: 'constitution-basics',
          stem: 'When?',
          option_a: '1950',
          option_b: 'later',
          correct: 'a',
          valid_from: '1950-01-26',
        },
      },
    ]);
  });

  it('refuses a file that is not really Excel', async () => {
    await expect(
      readRows(Buffer.from('topic,stem'), 'xlsx'),
    ).rejects.toMatchObject({
      code: 'invalid_file',
    });
  });
});
