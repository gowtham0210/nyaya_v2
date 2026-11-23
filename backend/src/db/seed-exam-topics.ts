import { existsSync } from 'node:fs';
import { loadConfig } from '../core/config.js';
import { openDb } from '../core/db.js';
import { seedClatTopics } from '../exams/exam-topic-seed.js';

/**
 * Creates the five CLAT section topics (under an inactive subject) that are
 * missing. Safe to re-run and safe in production: nothing that exists is
 * changed, and no question or exam is created. Uses the same
 * database as the other seeds (DATABASE_URL, or the local dev database).
 */
if (existsSync('.env')) process.loadEnvFile('.env');
if (!process.env.DATABASE_URL) process.env.PGLITE_DIR ??= '.data/pglite';
const { db, close } = await openDb(loadConfig());
const { created, existing } = await seedClatTopics(db);
console.log(
  `CLAT topics created: ${created.join(', ') || 'none'}. Already present: ${existing.join(', ') || 'none'}.`,
);
await close();
