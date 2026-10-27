import { v7 } from 'uuid';

/** Time-ordered UUIDv7, so ordering by id follows creation order. */
export const newId = (): string => v7();
