import 'server-only';
import { cache } from 'react';
import { api, must, type Me } from './api';

/** The signed-in user, fetched once per request. */
export const getMe = cache(async (): Promise<Me> => must(await (await api()).GET('/v1/me')));

export const getTaxonomy = cache(async () => must(await (await api()).GET('/v1/taxonomy')));

/** Every subject, topic and act, hidden ones included, with question counts (staff only). */
export const getAllTaxonomy = cache(async () => must(await (await api()).GET('/v1/admin/taxonomy')));

/** "Subject › Topic" for every topic id, hidden ones marked. */
export async function getTopicNames(): Promise<Map<string, string>> {
  const { subjects } = await getAllTaxonomy();
  return new Map(
    subjects.flatMap((s) =>
      s.topics.map((t) => [t.id, `${s.name} › ${t.name}${s.is_active && t.is_active ? '' : ' (hidden)'}`] as const),
    ),
  );
}
