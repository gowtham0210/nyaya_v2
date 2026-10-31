import type { NewsCategory } from '@/lib/api';

/** What the news form edits; every value is a string so inputs stay controlled. */
export interface NewsInput {
  category: NewsCategory;
  title: string;
  summary: string;
  key_points: string[];
  why_it_matters: string;
  source: string;
  source_url: string;
  event_date: string;
  read_minutes: string;
}

export const MAX_KEY_POINTS = 6;

export const EMPTY_NEWS: NewsInput = {
  category: 'supreme_court',
  title: '',
  summary: '',
  key_points: ['', '', ''],
  why_it_matters: '',
  source: '',
  source_url: '',
  event_date: '',
  read_minutes: '3',
};
