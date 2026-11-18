import type { DailyTipCategory, DailyTipLanguage } from '@/lib/api';

/** What the daily tip form edits; every value is a string so inputs stay controlled. */
export interface TipInput {
  category: DailyTipCategory;
  language: DailyTipLanguage;
  title: string;
  summary: string;
  explanation: string;
  legal_reference: string;
  source_url: string;
  publish_date: string;
  last_verified_on: string;
}

export const EMPTY_TIP: TipInput = {
  category: 'general',
  language: 'en',
  title: '',
  summary: '',
  explanation: '',
  legal_reference: '',
  source_url: '',
  publish_date: '',
  last_verified_on: '',
};
