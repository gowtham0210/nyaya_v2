import { PGlite } from '@electric-sql/pglite';
const c = new PGlite(process.argv[2]);
try {
 const t = await c.query("select table_name from information_schema.tables where table_schema='public' order by 1");
 console.log(t.rows.length,'tables');
 for (const r of t.rows.slice(0,60)) { try { const n=await c.query(`select count(*)::int n from "${r.table_name}"`); console.log(r.table_name,n.rows[0].n);} catch(e){console.log(r.table_name,'READFAIL',String(e.message).slice(0,60));} }
 console.log((await c.query('select count(*) from drizzle.__drizzle_migrations')).rows);
} catch(e){ console.log('FAIL', String(e.message).slice(0,120)); }
