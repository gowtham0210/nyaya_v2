// Usage: node extract.mjs <cluster-root> <outDir>   (READ-ONLY on cluster)
import fs from 'node:fs';
import { openCluster, readCatalog, visibility } from './lib.mjs';
import { readTypes, convert } from './lib2.mjs';
import { readRelPages, pageTuples, decodeTuple } from './heap.mjs';
import { fastDefaults } from './fastdef.mjs';
const FD = fastDefaults();

const root = process.argv[2], outDir = process.argv[3];
fs.mkdirSync(outDir, { recursive: true });
const cl = openCluster(root);
const { classes, attrs } = readCatalog(cl);
const ctx = readTypes(cl);
const byOid = new Map(classes.map(c => [c.oid, c]));

const toastCache = new Map();
function loadToast(rel) {
  if (toastCache.has(rel)) return toastCache.get(rel);
  const c = byOid.get(rel), m = new Map(); toastCache.set(rel, m); if (!c) return m;
  readRelPages(cl.dbdir, c.relfilenode).forEach((p, blk) => { for (const tp of pageTuples(p, blk)) {
    if (tp.bad || visibility(cl, tp).state !== 'live') continue;
    const d = tp.raw.subarray(tp.hoff); const id = d.readUInt32LE(0), seq = d.readInt32LE(4);
    let o = 8, data; const h = d[o];
    if (h & 1) data = d.subarray(o + 1, o + (h >> 1)); else { o = (o + 3) & ~3; data = d.subarray(o + 4, o + (d.readUInt32LE(o) >> 2)); }
    if (!m.has(id)) m.set(id, []); m.get(id)[seq] = data;
  } });
  return m;
}
const toastFetch = (rel, id) => { const ch = loadToast(rel).get(id); if (!ch || ch.some(x => !x)) return null; return Buffer.concat(ch); };

const summary = {};
const tables = classes.filter(c => c.relkind === 'r' && c.ns === 2200).sort((a, b) => a.relname.localeCompare(b.relname));
for (const c of tables) {
  const cols = attrs.filter(a => a.relid === c.oid && a.attnum > 0).sort((a, b) => a.attnum - b.attnum);
  const rows = []; const cnt = { live: 0, dead: 0, aborted: 0, unknown: 0, bad_pages: 0, partial: 0 };
  const pages = readRelPages(cl.dbdir, c.relfilenode);
  pages.forEach((p, blk) => { for (const tp of pageTuples(p, blk)) {
    if (tp.bad) { cnt.bad_pages++; rows.push({ _loc: { blk }, _vis: { state: 'bad-page', why: tp.reason } }); continue; }
    const vis = visibility(cl, tp);
    let dec; try { dec = decodeTuple(tp, cols.map(a => a.dropped ? { ...a, name: `__dropped_${a.attnum}` } : a), toastFetch); } catch (e) { dec = { vals: {}, warn: ["decode exception: " + e.message] }; }
    const row = { _loc: { blk: tp.blkno, off: tp.offnum, xmin: tp.xmin, xmax: tp.xmax, ctid: tp.ctid.join(',') }, _vis: vis };
    let partial = dec.warn.length > 0;
    const natts = tp.infomask2 & 0x7ff, fdUsed = [];
    for (const [ai, a] of cols.entries()) {
      if (a.dropped) continue;
      if (ai >= natts && FD[c.relname]?.[a.name]) { row[a.name] = FD[c.relname][a.name].value; fdUsed.push(a.name); continue; }
      const cv = convert(a, dec.vals[a.name], ctx);
      if (cv && typeof cv === 'object' && cv._unreadable) partial = true;
      row[a.name] = cv;
    }
    if (fdUsed.length) row._fastDefault = fdUsed;
    if (partial) { row._partial = dec.warn.concat('some columns unreadable'); cnt.partial++; }
    cnt[vis.state]++; rows.push(row);
  } });
  fs.writeFileSync(`${outDir}/${c.relname}.json`, JSON.stringify(rows, null, 1));
  summary[c.relname] = { pages: pages.length, ...cnt, columns: cols.filter(a => !a.dropped).map(a => a.name) };
}
fs.writeFileSync(`${outDir}/_summary.json`, JSON.stringify(summary, null, 1));
for (const [t, s] of Object.entries(summary)) console.log(t.padEnd(26), `pg${s.pages} live=${s.live} dead=${s.dead} unk=${s.unknown} abort=${s.aborted} partial=${s.partial} bad=${s.bad_pages}`);
