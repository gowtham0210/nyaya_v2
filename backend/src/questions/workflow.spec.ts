import { contentProblems, type VersionContent } from './workflow.js';

const complete: VersionContent = {
  questionType: 'single_select',
  stem: 'When did the Constitution of India come into force?',
  options: [
    { id: 'a', text: '26 January 1950' },
    { id: 'b', text: '15 August 1947' },
  ],
  correctOptionIds: ['a'],
  explanation: 'It came into force on 26 January 1950.',
  sourceTitle: 'Constitution of India',
  sourceUrl: 'https://legislative.gov.in/constitution-of-india/',
  jurisdiction: 'IN',
  language: 'en',
  validFrom: '1950-01-26',
  validTo: null,
};

const fields = (v: Partial<VersionContent>, topicActive = true) =>
  contentProblems({ ...complete, ...v }, topicActive).map((p) => p.field);

describe('contentProblems', () => {
  it('accepts a complete question', () => {
    expect(contentProblems(complete, true)).toEqual([]);
  });

  it('requires text, explanation, source and validity date', () => {
    expect(
      fields({
        stem: ' ',
        explanation: '',
        sourceTitle: null,
        validFrom: null,
      }),
    ).toEqual(['stem', 'explanation', 'source_title', 'valid_from']);
  });

  it('checks options and the answer key', () => {
    expect(
      fields({
        options: [{ id: 'a', text: 'Only one' }],
        correctOptionIds: ['a'],
      }),
    ).toEqual(['options']);
    expect(
      fields({
        options: [
          { id: 'a', text: 'x' },
          { id: 'a', text: 'y' },
        ],
      }),
    ).toEqual(['options']);
    expect(
      fields({
        options: [
          { id: 'a', text: 'Same' },
          { id: 'b', text: 'same ' },
        ],
      }),
    ).toEqual(['options']);
    expect(fields({ correctOptionIds: ['z'] })).toEqual(['correct_option_ids']);
    expect(fields({ correctOptionIds: ['a', 'b'] })).toEqual([
      'correct_option_ids',
    ]);
  });

  it('checks URL scheme, locale, jurisdiction, dates and topic', () => {
    expect(fields({ sourceUrl: 'http://example.com' })).toEqual(['source_url']);
    expect(fields({ language: 'fr', jurisdiction: 'US' })).toEqual([
      'jurisdiction',
      'language',
    ]);
    expect(fields({ validTo: '1949-01-01' })).toEqual(['valid_to']);
    expect(fields({}, false)).toEqual(['topic_id']);
  });
});
