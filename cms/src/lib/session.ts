import 'server-only';
import { cache } from 'react';
import { api, must, type Me } from './api';

/** The signed-in user, fetched once per request. */
export const getMe = cache(async (): Promise<Me> => must(await (await api()).GET('/v1/me')));

export const getTaxonomy = cache(async () => must(await (await api()).GET('/v1/taxonomy')));

/** "Subject › Topic" for every topic id. */
export async function getTopicNames(): Promise<Map<string, string>> {
  const { subjects } = await getTaxonomy();
  return new Map(subjects.flatMap((s) => s.topics.map((t) => [t.id, `${s.name} › ${t.name}`] as const)));
}
