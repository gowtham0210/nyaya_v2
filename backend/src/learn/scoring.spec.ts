import {
  indiaToday,
  isCorrect,
  scoreSession,
  sessionDeadline,
  shuffled,
} from './scoring.js';

describe('scoring', () => {
  it('needs exactly the correct options', () => {
    expect(isCorrect(['a'], ['a'])).toBe(true);
    expect(isCorrect(['b'], ['a'])).toBe(false);
    expect(isCorrect([], ['a'])).toBe(false);
    expect(isCorrect(['a', 'b'], ['a'])).toBe(false);
    expect(isCorrect(['b', 'a'], ['a', 'b'])).toBe(true);
    expect(isCorrect(['a', 'a'], ['a', 'b'])).toBe(false);
  });

  it('scores +1 per correct answer and counts unanswered as 0', () => {
    const result = scoreSession([
      { selectedOptionIds: ['a'], correctOptionIds: ['a'] },
      { selectedOptionIds: ['c'], correctOptionIds: ['b'] },
      { selectedOptionIds: null, correctOptionIds: ['d'] },
    ]);
    expect(result).toEqual({ correctCount: 1, answeredCount: 2 });
  });

  it('gives the same score for the same answers', () => {
    const qs = [
      { selectedOptionIds: ['a'], correctOptionIds: ['a'] },
      { selectedOptionIds: ['b'], correctOptionIds: ['a'] },
    ];
    expect(scoreSession(qs)).toEqual(scoreSession([...qs]));
  });
});

describe('session rules', () => {
  const start = new Date('2026-10-27T10:00:00Z');

  it('allows at least 10 minutes, or 2 minutes per question', () => {
    expect(sessionDeadline(start, 3).toISOString()).toBe(
      '2026-10-27T10:10:00.000Z',
    );
    expect(sessionDeadline(start, 10).toISOString()).toBe(
      '2026-10-27T10:20:00.000Z',
    );
  });

  it('uses the date in India for validity', () => {
    // 20:00 UTC is already the next day in India (UTC+5:30).
    expect(indiaToday(new Date('2026-10-27T20:00:00Z'))).toBe('2026-10-28');
    expect(indiaToday(new Date('2026-10-27T18:00:00Z'))).toBe('2026-10-27');
  });

  it('shuffles without losing or duplicating items', () => {
    const items = ['a', 'b', 'c', 'd'];
    const out = shuffled(items);
    expect([...out].sort()).toEqual(items);
    expect(items).toEqual(['a', 'b', 'c', 'd']);
  });
});
