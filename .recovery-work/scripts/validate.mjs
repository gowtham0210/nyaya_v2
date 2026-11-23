// Validates decoder against ground truth: PGlite SQL on a COPY of the Nov-19 backup.
import fs from 'node:fs';
import { PGlite } from '../../backend/node_modules/@electric-sql/pglite/dist/index.js';
const db = new PGlite('../ref1119-sql');
const ex = '../extracted/ref1119';
const norm = (v) => {
  if (v === null || v === undefined) return 'N';
  if (typeof v === 'string') { if (/^\d{4}-\d\d-\d\dT\d\d:\d\d:\d\d(\.\d+)?(Z|[+-]\d\d(:\d\d)?)$/.test(v)) { const m = v.match(/\.(\d+)/); const base = Date.parse(v.replace(/(\.\d+)/, '').replace(/([+-]\d\d)$/, '$1:00')); return 'T' + base + (m ? m[1].padEnd(6,'0').slice(0,6) : '000000'); } return 'S' + v; }
  if (typeof v === 'number') return 'D' + Number(v);
  if (typeof v === 'boolean') return 'B' + v;
  if (Array.isArray(v)) return 'A[' + v.map(norm).join(',') + ']';
  return 'O{' + Object.keys(v).sort().map(k => k + ':' + norm(v[k])).join(',') + '}';
};
const summary = JSON.parse(fs.readFileSync(ex + '/_summary.json'));
let allok = true;
for (const t of Object.keys(summary)) {
  const rows = fs.existsSync(`${ex}/${t}.json`) ? JSON.parse(fs.readFileSync(`${ex}/${t}.json`)) : [];
  const live = rows.filter(r => r._vis?.state === 'live');
  const cols = summary[t].columns.filter(c => !['embedding', 'data'].includes(c) || t === 'audit_log' && c === 'data');
  const skip = new Set(['embedding']); if (t === 'news_images') skip.add('data');
  const sql = await db.query(`select to_jsonb(x) j from "${t}" x`);
  const nv = (c, v) => (/marks|percent/.test(c) && v !== null && v !== undefined) ? 'D' + Number(v) : norm(v); const sig = (o) => cols.filter(c => !skip.has(c)).map(c => c + '=' + nv(c, o[c])).join('|');
  const A = new Map(); for (const r of sql.rows) { const k = sig(r.j); A.set(k, (A.get(k) || 0) + 1); }
  let miss = 0, extra = 0; const B = new Map(); for (const r of live) { const k = sig(r); B.set(k, (B.get(k) || 0) + 1); }
  for (const [k, n] of A) if ((B.get(k) || 0) < n) miss += n - (B.get(k) || 0);
  for (const [k, n] of B) if ((A.get(k) || 0) < n) extra += n - (A.get(k) || 0);
  const ok = miss === 0 && extra === 0; allok &&= ok;
  console.log(t.padEnd(26), `sql=${sql.rows.length} extracted=${live.length}`, ok ? 'MATCH' : `MISMATCH sqlOnly=${miss} extractedOnly=${extra}`);
  if (!ok && process.env.SHOW) { const k = [...A.keys()].find(k => (B.get(k)||0) < A.get(k)); console.log(' sql:', k?.slice(0, 400)); const k2 = [...B.keys()].find(k => (A.get(k)||0) < B.get(k)); console.log(' ext:', k2?.slice(0, 400)); }
}
console.log(allok ? 'ALL TABLES MATCH' : 'SOME MISMATCH');
await db.close();
