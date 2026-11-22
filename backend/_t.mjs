import { PGlite } from './node_modules/@electric-sql/pglite/dist/index.js';
try { const c = new PGlite(process.argv[2]); await c.waitReady; const r=await c.query("select (select count(*) from information_schema.tables where table_schema='public') t"); console.log('ok', r.rows); await c.close(); } catch(e){ console.log('FAIL', e.message); }
