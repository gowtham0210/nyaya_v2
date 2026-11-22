import fs from 'node:fs';
import path from 'node:path';
import { readRelPages, pageTuples, decodeTuple } from './heap.mjs';

export function openCluster(root) {
  const dbdir = path.join(root, 'base', '5');
  const clog = fs.readFileSync(path.join(root, 'pg_xact', '0000'));
  const ctl = fs.readFileSync(path.join(root, 'global', 'pg_control'));
  const nextXid = Number(ctl.readBigUInt64LE(64 + 0) & 0xffffffffn); // fallback, overridden below
  const wf = path.join(root, 'wal_xact.json'); const wal = new Map();
  if (fs.existsSync(wf)) { const j = JSON.parse(fs.readFileSync(wf, 'utf8')); j.committed.forEach(x => wal.set(x, 1)); j.aborted.forEach(x => wal.set(x, 2)); }
  return { root, dbdir, clog, nextXid: 7157, wal };
}
export function clogStatus(cl, xid) { // 0 inprogress/unknown,1 commit,2 abort,3 subcommit
  const byte = Math.floor(xid / 4); let s = 0;
  if (byte < cl.clog.length) s = (cl.clog[byte] >> ((xid % 4) * 2)) & 3;
  if (s === 0 && cl.wal?.has(xid)) return cl.wal.get(xid); // commit/abort recorded in WAL only
  return s;
}
/** Returns {state:'live'|'dead'|'aborted'|'unknown', conf:'high'|'medium'|'low', why} */
export function visibility(cl, tp) {
  const im = tp.infomask;
  let xminOk, why = [];
  if ((im & 0x0300) === 0x0300) xminOk = 'c';
  else if (im & 0x0100) xminOk = 'c';
  else if (im & 0x0200) xminOk = 'a';
  else { const s = clogStatus(cl, tp.xmin); xminOk = s === 1 ? 'cc' : s === 2 ? 'a' : 'u'; }
  if (xminOk === 'a') return { state: 'aborted', conf: 'high', why: 'xmin aborted' };
  let conf = xminOk === 'c' ? 'high' : xminOk === 'cc' ? 'high' : 'low';
  if (xminOk === 'u') why.push(`xmin ${tp.xmin} not marked committed on disk (beyond checkpoint?)`);
  let deleted = false;
  if (tp.xmax !== 0 && !(im & 0x0080) && !(im & 0x0800)) {
    if (im & 0x1000) { why.push('xmax multixact'); }
    else if (im & 0x0400) deleted = true;
    else { const s = clogStatus(cl, tp.xmax); if (s === 1) deleted = true; else if (s === 2) {} else { why.push(`xmax ${tp.xmax} status unknown`); conf = conf === 'high' ? 'medium' : 'low'; } }
  }
  if (deleted) return { state: 'dead', conf, why: why.join('; ') };
  return { state: xminOk === 'u' ? 'unknown' : 'live', conf, why: why.join('; ') };
}

const rd = (b, o, n) => b.subarray(o, o + n);
const nm = (b) => { const s = b.subarray(0, 64); const e = s.indexOf(0); return s.subarray(0, e < 0 ? 64 : e).toString('utf8'); };

/** Parses pg_class + pg_attribute (live rows only) */
export function readCatalog(cl) {
  const classes = [], attrs = [];
  for (const [fn, kind] of [[1259, 'class'], [1249, 'attr']]) {
    const pages = readRelPages(cl.dbdir, fn);
    pages.forEach((p, blk) => { for (const tp of pageTuples(p, blk)) {
      if (tp.bad) continue; const v = visibility(cl, tp); if (v.state !== 'live') continue;
      const d = tp.raw.subarray(tp.hoff);
      if (kind === 'class') classes.push({ oid: d.readUInt32LE(0), relname: nm(d.subarray(4, 68)), ns: d.readUInt32LE(68), relfilenode: d.readUInt32LE(88), toast: d.readUInt32LE(112), relkind: String.fromCharCode(d[119]) });
      else attrs.push({ relid: d.readUInt32LE(0), name: nm(d.subarray(4, 68)), typid: d.readUInt32LE(68), len: d.readInt16LE(72), attnum: d.readInt16LE(74), byval: !!d[82], align: String.fromCharCode(d[83]), dropped: !!d[(4+64+4+2+2+4+2+1+1+1+1+1+1+1+1+1)-1+0] });
    } });
  }
  return { classes, attrs };
}
