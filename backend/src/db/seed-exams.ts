import { existsSync } from 'node:fs';
import { loadConfig } from '../core/config.js';
import { openDb } from '../core/db.js';
import { seedExams } from '../exams/exam-seed.js';

/**
 * Creates the AIBE, CLAT and AILET exam rows, switched off. Safe to re-run and
 * safe in production: it creates nothing else (no blueprints, no questions)
 * and leaves existing exams untouched. Uses the same database as the dev seed
 * (DATABASE_URL, or the local dev database).
 */
if (existsSync('.env')) process.loadEnvFile('.env');
if (!process.env.DATABASE_URL) process.env.PGLITE_DIR ??= '.data/pglite';
const { db, close } = await openDb(loadConfig());
const { created, existing } = await seedExams(db);
console.log(
  `Exams created (inactive): ${created.join(', ') || 'none'}. Already present: ${existing.join(', ') || 'none'}.`,
);
await close();
