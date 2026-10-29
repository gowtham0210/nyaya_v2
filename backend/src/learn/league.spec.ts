import { describe, expect, it } from 'vitest';
import {
  nextTier,
  practicePlayers,
  publicName,
  weekProgress,
  weekStart,
} from './league.js';

describe('league rules', () => {
  it('promotes, keeps and demotes by rank, with no demotion in the entry tiers', () => {
    expect([nextTier(1, 15), nextTier(1, 16), nextTier(1, 30)]).toEqual([
      2, 1, 1,
    ]);
    expect([nextTier(3, 10), nextTier(3, 25), nextTier(3, 26)]).toEqual([
      4, 3, 2,
    ]);
    expect([nextTier(8, 1), nextTier(8, 26)]).toEqual([8, 7]);
  });

  it('starts weeks on Monday 00:00 India time', () => {
    expect(weekStart('2026-W44').toISOString()).toBe(
      '2026-10-25T18:30:00.000Z',
    );
    expect(weekStart('2026-W01').toISOString()).toBe(
      '2025-12-28T18:30:00.000Z',
    );
    expect(
      weekProgress('2026-W44', new Date('2026-10-29T06:30:00Z')),
    ).toBeCloseTo(3.5 / 7);
  });

  it('shows first name and last initial only', () => {
    expect(publicName('Asha Krishnan')).toBe('Asha K.');
    expect(publicName('  ravi  ')).toBe('ravi');
    expect(publicName('A B Chandra')).toBe('A C.');
    expect(publicName('   ')).toBe('Learner');
  });

  it('makes the same practice players for a group, more XP later in the week', () => {
    const early = practicePlayers('cohort-1', 1, 28, 0.2);
    const again = practicePlayers('cohort-1', 1, 28, 0.2);
    expect(again).toEqual(early);
    expect(early).toHaveLength(28);
    expect(new Set(early.map((p) => p.name)).size).toBe(28);
    const late = practicePlayers('cohort-1', 1, 28, 1);
    expect(late.reduce((n, p) => n + p.xp, 0)).toBeGreaterThan(
      early.reduce((n, p) => n + p.xp, 0),
    );
    expect(practicePlayers('cohort-1', 1, 0, 1)).toEqual([]);
  });
});
