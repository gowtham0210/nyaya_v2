import { HttpStatus } from '@nestjs/common';
import { ApiError } from './errors.js';

export interface Page<T> {
  items: T[];
  next_cursor: string | null;
}

/** Cursors are opaque to clients: the last item's id, base64url-encoded. */
export function decodeCursor(cursor?: string): string | undefined {
  if (!cursor) return undefined;
  const id = Buffer.from(cursor, 'base64url').toString();
  if (!/^[0-9a-f-]{36}$/.test(id)) {
    throw new ApiError(
      HttpStatus.BAD_REQUEST,
      'bad_cursor',
      'The cursor is not valid',
    );
  }
  return id;
}

/** [rows] holds up to limit + 1 rows; the extra one only signals a next page. */
export function toPage<R extends { id: string }, T>(
  rows: R[],
  limit: number,
  map: (r: R) => T,
): Page<T> {
  const items = rows.slice(0, limit);
  const more = rows.length > limit;
  return {
    items: items.map(map),
    next_cursor: more
      ? Buffer.from(items[items.length - 1].id).toString('base64url')
      : null,
  };
}
