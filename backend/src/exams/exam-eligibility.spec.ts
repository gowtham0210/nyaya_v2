import { allowedRegimes, lawRegimeVerdict } from './exam-eligibility.js';
import { LAW_REGIME_FILTERS } from '../db/schema.js';

describe('lawRegimeVerdict in a randomised mock', () => {
  it('lets questions that are not purely old-code through under every rule', () => {
    for (const filter of LAW_REGIME_FILTERS)
      for (const regime of ['new_codes', 'both', 'neutral'] as const)
        expect(lawRegimeVerdict(filter, regime)).toEqual({ allowed: true });
  });

  it('leaves old-code-only questions out by default and under every rule but include_all', () => {
    for (const filter of ['any', 'exclude_old', 'prefer_new'] as const)
      expect(lawRegimeVerdict(filter, 'old_codes')).toEqual({
        allowed: false,
        code: 'law_regime_excluded',
      });
  });

  it('does not treat prefer_new as permission to include old-code questions', () => {
    expect(lawRegimeVerdict('prefer_new', 'old_codes')).toMatchObject({
      allowed: false,
    });
  });

  it('includes old-code questions only when the rule is include_all', () => {
    expect(lawRegimeVerdict('include_all', 'old_codes')).toEqual({
      allowed: true,
    });
  });
});

describe('lawRegimeVerdict in a fixed historical paper', () => {
  it('never filters: the paper keeps the questions it was set with', () => {
    for (const filter of LAW_REGIME_FILTERS)
      for (const regime of [
        'old_codes',
        'new_codes',
        'both',
        'neutral',
      ] as const)
        expect(lawRegimeVerdict(filter, regime, 'fixed_paper')).toEqual({
          allowed: true,
        });
  });
});

describe('allowedRegimes', () => {
  it('lists what a randomised pool may hold under each rule', () => {
    const current = ['both', 'neutral', 'new_codes'];
    expect(allowedRegimes('any').sort()).toEqual(current);
    expect(allowedRegimes('exclude_old').sort()).toEqual(current);
    expect(allowedRegimes('prefer_new').sort()).toEqual(current);
    expect(allowedRegimes('include_all').sort()).toEqual([
      'both',
      'neutral',
      'new_codes',
      'old_codes',
    ]);
  });
});
