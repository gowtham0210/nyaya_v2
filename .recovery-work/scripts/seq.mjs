import fs from 'node:fs';
import { openCluster, readCatalog, visibility } from './lib.mjs';
import { readRelPages, pageTuples } from './heap.mjs';
const out = {};
for (const [name, root] of [['redo', '../data-redo'], ['nov19', '../ref1119']]) {
  const cl = openCluster(root); const { classes } = readCatalog(cl);
  const seqs = classes.filter(c => c.relkind === 'S' && c.ns === 2200);
  const mig = classes.find(c => c.relname === '__drizzle_migrations' && c.relkind === 'r');
  const res = { sequences: [], migrations: [] };
  for (const s of seqs) for (const p of readRelPages(cl.dbdir, s.relfilenode)) for (const tp of pageTuples(p, 0)) { const d = tp.raw.subarray(tp.hoff); res.sequences.push({ name: s.relname, last_value: d.readBigInt64LE(0).toString(), log_cnt: d.readBigInt64LE(8).toString(), is_called: !!d[16] }); }
  if (mig) { const pages = readRelPages(cl.dbdir, mig.relfilenode); pages.forEach((p, b) => { for (const tp of pageTuples(p, b)) { if (visibility(cl, tp).state !== 'live') continue; const d = tp.raw.subarray(tp.hoff); /* id int4, hash text, created_at int8 */ const id = d.readInt32LE(0); let o = 4; const h = d[o]; let hash; if (h & 1) { const len = h >> 1; hash = d.subarray(o + 1, o + len).toString(); o += len; } else { hash = '(4B-header)'; o += 4; } o = (o + 7) & ~7; res.migrations.push({ id, hash: hash.slice(0, 12), created_at: new Date(Number(d.readBigInt64LE(o))).toISOString() }); } }); }
  out[name] = res;
}
fs.writeFileSync('../recovered/_sequences_and_migrations.json', JSON.stringify(out, null, 1));
console.log('nov19 sequences', out.nov19.sequences.length, 'redo sequences', out.redo.sequences.length);
console.log('migrations nov19', out.nov19.migrations.length, 'redo', out.redo.migrations.length);
console.log(out.redo.sequences.slice(0, 10)); console.log(out.redo.migrations.slice(-4));
