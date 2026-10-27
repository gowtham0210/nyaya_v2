import { mkdirSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import { PGlite } from '@electric-sql/pglite';
import type { PgDatabase, PgQueryResultHKT } from 'drizzle-orm/pg-core';
import { drizzle as drizzlePglite } from 'drizzle-orm/pglite';
import { migrate as migratePglite } from 'drizzle-orm/pglite/migrator';
import { drizzle as drizzlePg } from 'drizzle-orm/node-postgres';
import { migrate as migratePg } from 'drizzle-orm/node-postgres/migrator';
import pg from 'pg';
import * as schema from '../db/schema.js';
import type { AppConfig } from './config.js';

export const DB = Symbol('DB');

export type Db = PgDatabase<PgQueryResultHKT, typeof schema>;
/** A database handle or an open transaction. */
export type Tx = Parameters<Parameters<Db['transaction']>[0]>[0] | Db;

// backend/drizzle, from both src/core and dist/core.
const migrationsFolder = fileURLToPath(
  new URL('../../drizzle', import.meta.url),
);

export interface DbHandle {
  db: Db;
  close(): Promise<void>;
}

/** Connects and applies pending migrations. */
export async function openDb(config: AppConfig): Promise<DbHandle> {
  if (config.databaseUrl) {
    const pool = new pg.Pool({ connectionString: config.databaseUrl });
    const db = drizzlePg({ client: pool, schema });
    await migratePg(db, { migrationsFolder });
    return { db: db as unknown as Db, close: () => pool.end() };
  }
  if (config.pgliteDir) mkdirSync(config.pgliteDir, { recursive: true });
  const client = new PGlite(config.pgliteDir);
  const db = drizzlePglite({ client, schema });
  await migratePglite(db, { migrationsFolder });
  return { db: db as unknown as Db, close: () => client.close() };
}
