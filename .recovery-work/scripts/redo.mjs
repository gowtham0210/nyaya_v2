// Minimal heap-only WAL redo onto a COPY of the cluster (never the original).
// Usage: node redo.mjs <source-root(read-only)> <dest-root(copy, will be patched)>
// Applies: full-page images, Heap INSERT/UPDATE/HOT_UPDATE/DELETE. Skips: LOCK, CONFIRM, PRUNE, Btree (indexes), VM.
import fs from 'node:fs';
import { loadSegment, parseRecords, decodeBody } from './wal.mjs';
import { openCluster, readCatalog } from './lib.mjs';

const [src, dst] = process.argv.slice(2);
if (!dst || !dst.includes('redo')) throw new Error('dest must be a dedicated copy path containing "redo"');
const PAGE = 8192, S = 0x5000000n;
const seg = loadSegment(src, '000000010000000000000005', S);
const { recs, end } = parseRecords(seg, 0x510abc8n, S);
const cl = openCluster(src); const { classes } = readCatalog(cl);
const relname = new Map(classes.map(c => [c.relfilenode, c.relname]));
const dbdir = `${dst}/base/5`;

const pages = new Map(); // key rel:blk -> Buffer
const getPage = (rel, blk) => {
  const k = rel + ':' + blk; if (pages.has(k)) return pages.get(k);
  const f = `${dbdir}/${rel}`; let p = Buffer.alloc(PAGE);
  if (fs.existsSync(f)) { const fd = fs.openSync(f, 'r'); const n = fs.readSync(fd, p, 0, PAGE, blk * PAGE); fs.closeSync(fd); if (n < PAGE) p = Buffer.alloc(PAGE); }
  pages.set(k, p); return p;
};
const pageLsn = (p) => (BigInt(p.readUInt32LE(0)) << 32n) | BigInt(p.readUInt32LE(4));
const setLsn = (p, l) => { p.writeUInt32LE(Number(l >> 32n), 0); p.writeUInt32LE(Number(l & 0xffffffffn), 4); };
const initPage = (p) => { p.fill(0); p.writeUInt16LE(24, 12); p.writeUInt16LE(PAGE, 14); p.writeUInt16LE(PAGE, 16); p.writeUInt16LE(0x2004, 18); };
const A8 = (n) => (n + 7) & ~7;
const log = []; const warn = (m) => { log.push('WARN ' + m); };

function addItem(p, offnum, tup) {
  if (p.readUInt16LE(12) === 0) initPage(p);
  const lower = p.readUInt16LE(12), upper = p.readUInt16LE(14); const maxoff = (lower - 24) / 4;
  let newLower = lower;
  if (offnum === maxoff + 1) newLower = lower + 4;
  else if (offnum > maxoff + 1) throw new Error(`offnum ${offnum} beyond maxoff ${maxoff}`);
  else { const lp = p.readUInt32LE(24 + (offnum - 1) * 4); if (((lp >> 15) & 3) !== 0) warn(`slot ${offnum} occupied at insert (prune skipped) - overwritten`); }
  const newUpper = upper - A8(tup.length);
  if (newUpper < newLower) throw new Error('page full');
  tup.copy(p, newUpper);
  p.writeUInt32LE((newUpper | (1 << 15) | (tup.length << 17)) >>> 0, 24 + (offnum - 1) * 4);
  p.writeUInt16LE(newLower, 12); p.writeUInt16LE(newUpper, 14);
}
const getTuple = (p, offnum) => { const lp = p.readUInt32LE(24 + (offnum - 1) * 4); const off = lp & 0x7fff, len = (lp >>> 17) & 0x7fff; return { off, len, buf: p.subarray(off, off + len), flags: (lp >> 15) & 3 }; };
const infoBits = (ib, t) => { // fix_infomask_from_infobits
  let im = t.readUInt16LE(20) & ~(0x0040 | 0x0010 | 0x0080 | 0x1000 | 0x0400 | 0x0800), im2 = t.readUInt16LE(18) & ~0x2000;
  if (ib & 0x02) im |= 0x1000; if (ib & 0x04) im |= 0x0080; if (ib & 0x08) im |= 0x0040; if (ib & 0x10) im |= 0x0010; if (ib & 0x20) im2 |= 0x2000;
  t.writeUInt16LE(im, 20); t.writeUInt16LE(im2, 18);
};
function restoreImage(b) {
  if (b.compressed) throw new Error('compressed image not supported');
  if (b.hasHole && b.holeLen) { const out = Buffer.alloc(PAGE); b.img.copy(out, 0, 0, b.holeOff); b.img.copy(out, b.holeOff + b.holeLen, b.holeOff); return out; }
  return Buffer.from(b.img);
}

function repairFragmentation(p) {
  const lower = p.readUInt16LE(12); const n = (lower - 24) / 4; const special = p.readUInt16LE(16);
  const items = [];
  for (let i = 0; i < n; i++) { const lp = p.readUInt32LE(24 + i * 4); if (((lp >> 15) & 3) === 1) items.push({ i, off: lp & 0x7fff, len: (lp >>> 17) & 0x7fff }); }
  items.sort((a, b) => b.off - a.off);
  const copy = Buffer.from(p); let upper = special;
  for (const it of items) { upper -= A8(it.len); copy.copy(p, upper, it.off, it.off + it.len); p.writeUInt32LE((upper | (1 << 15) | (it.len << 17)) >>> 0, 24 + it.i * 4); }
  p.writeUInt16LE(upper, 14);
}
function pruneRedo(p, r, b) {
  const flags = r.main[1]; if (flags & 0x10) throw new Error('freeze plans in prune not supported');
  const d = b.data; let o = 0; const items = () => { const n = d.readUInt16LE(o); o += 2; const a = []; return { n, read: (k) => { for (let i = 0; i < k; i++) { a.push(d.readUInt16LE(o)); o += 2; } return a; } }; };
  const setLp = (idx, off, fl, len) => p.writeUInt32LE(((off | (fl << 15) | (len << 17)) >>> 0), 24 + (idx - 1) * 4);
  if (flags & 0x20) { const it = items(); const a = it.read(it.n * 2); for (let i = 0; i < it.n; i++) setLp(a[2 * i], a[2 * i + 1], 2, 0); }
  if (flags & 0x40) { const it = items(); const a = it.read(it.n); for (const x of a) setLp(x, 0, 3, 0); }
  if (flags & 0x80) { const it = items(); const a = it.read(it.n); for (const x of a) setLp(x, 0, 0, 0); }
  repairFragmentation(p);
}
const stats = { prune: 0, fpi: 0, insert: 0, update: 0, delete: 0, skippedLsn: 0, skippedKinds: {}, errors: 0 };
const xact = { committed: [], aborted: [] };
const touched = new Set();

for (const r of recs) {
  try { decodeBody(r); } catch (e) { stats.errors++; log.push(`decode fail ${r.lsn.toString(16)} ${e.message}`); continue; }
  const tag = `${r.lsn.toString(16)} xid=${r.xid}`;
  if (r.rmid === 1) { // Transaction
    const kind = r.info & 0x70; if (kind !== 0x00 && kind !== 0x20) continue;
    const m = r.main; const xs = [r.xid]; let o = 8;
    if (r.info & 0x80) { const xinfo = m.readUInt32LE(o); o += 4; if (xinfo & 1) o += 8; if (xinfo & 2) { const n = m.readInt32LE(o); o += 4; for (let i = 0; i < n; i++) xs.push(m.readUInt32LE(o + i * 4)); } }
    (kind === 0x00 ? xact.committed : xact.aborted).push(...xs); continue;
  }
  if (r.rmid === 9 && [0x10, 0x20, 0x30].includes(r.info & 0xf0)) {
    const b = r.blocks[0]; if (!b || b.db !== 5) continue;
    if (b.hasImage && b.apply) { const p = restoreImage(b); setLsn(p, r.endLsn); pages.set(b.rel + ':' + b.blkno, p); touched.add(b.rel); stats.fpi++; continue; }
    try { const p = getPage(b.rel, b.blkno); if (pageLsn(p) < r.endLsn) { if (b.data) pruneRedo(p, r, b); setLsn(p, r.endLsn); touched.add(b.rel); stats.prune++; } else stats.skippedLsn++; }
    catch (e) { stats.errors++; log.push('ERROR prune ' + tag + ' ' + e.message); }
    continue;
  }
  const isHeap = r.rmid === 10, isFpi = r.rmid === 0 && ((r.info & 0xf0) === 0xa0 || (r.info & 0xf0) === 0xb0);
  if (!isHeap && !isFpi) { const k = `rmid${r.rmid}/0x${(r.info & 0xf0).toString(16)}`; stats.skippedKinds[k] = (stats.skippedKinds[k] || 0) + 1; continue; }
  const op = r.info & 0x70;
  // Full page images first
  const imaged = new Set();
  for (const b of r.blocks) if (b.hasImage && b.apply && b.db === 5 && b.fork === 0) {
    const p = restoreImage(b); setLsn(p, r.endLsn); pages.set(b.rel + ':' + b.blkno, p); imaged.add(b.id); touched.add(b.rel); stats.fpi++;
  }
  if (isFpi) continue;
  if (op === 0x60 || op === 0x50 || op === 0x70) { stats.skippedKinds['heap-lock/confirm/inplace'] = (stats.skippedKinds['heap-lock/confirm/inplace'] || 0) + 1; continue; }
  const b0 = r.blocks[0]; if (!b0 || b0.db !== 5) continue;
  const init = !!(r.info & 0x80);
  const needsRedo = (b) => { const p = getPage(b.rel, b.blkno); return pageLsn(p) < r.endLsn; };
  try {
    if (op === 0x00) { // INSERT
      if (imaged.has(0)) continue;
      const p = getPage(b0.rel, b0.blkno); if (init) initPage(p);
      if (!(pageLsn(p) < r.endLsn)) { stats.skippedLsn++; continue; }
      const offnum = r.main.readUInt16LE(0); const d = b0.data; const infomask2 = d.readUInt16LE(0), infomask = d.readUInt16LE(2), hoff = d[4];
      const body = d.subarray(5); const t = Buffer.alloc(23 + body.length); body.copy(t, 23);
      t.writeUInt32LE(r.xid, 0); t.writeUInt32LE(0, 4); t.writeUInt32LE(0, 8);
      t.writeUInt16LE(b0.blkno >>> 16, 12); t.writeUInt16LE(b0.blkno & 0xffff, 14); t.writeUInt16LE(offnum, 16);
      t.writeUInt16LE(infomask2, 18); t.writeUInt16LE(infomask, 20); t[22] = hoff;
      addItem(p, offnum, t); setLsn(p, r.endLsn); touched.add(b0.rel); stats.insert++;
    } else if (op === 0x10) { // DELETE
      if (imaged.has(0)) continue;
      const p = getPage(b0.rel, b0.blkno); if (!(pageLsn(p) < r.endLsn)) { stats.skippedLsn++; continue; }
      const xmax = r.main.readUInt32LE(0), offnum = r.main.readUInt16LE(4), ib = r.main[6];
      const t = getTuple(p, offnum).buf; infoBits(ib, t); t.writeUInt32LE(xmax, 4); t.writeUInt16LE(b0.blkno >>> 16, 12); t.writeUInt16LE(b0.blkno & 0xffff, 14); t.writeUInt16LE(offnum, 16);
      setLsn(p, r.endLsn); touched.add(b0.rel); stats.delete++;
    } else if (op === 0x20 || op === 0x40) { // UPDATE / HOT_UPDATE
      const m = r.main; const oldXmax = m.readUInt32LE(0), oldOff = m.readUInt16LE(4), oldIb = m[6], flags = m[7], newXmax = m.readUInt32LE(8), newOff = m.readUInt16LE(12);
      const newB = r.blocks.find(x => x.id === 0), oldB = r.blocks.find(x => x.id === 1) || newB;
      const oldBlk = oldB.blkno, newBlk = newB.blkno;
      const oldPage = getPage(oldB.rel, oldBlk);
      const oldImaged = imaged.has(oldB.id), newImaged = imaged.has(0);
      // old tuple (must read BEFORE any change; needed for prefix/suffix reconstruction)
      let oldTupCopy = null; if (!oldImaged || !newImaged) { try { oldTupCopy = Buffer.from(getTuple(oldPage, oldOff).buf); } catch { /* may not exist */ } }
      if (!newImaged) {
        const np = getPage(newB.rel, newBlk); if (init) initPage(np);
        if (!(pageLsn(np) < r.endLsn)) { stats.skippedLsn++; } else {
          let d = newB.data, o = 0, prefix = 0, suffix = 0;
          if (flags & 0x20) { prefix = d.readUInt16LE(o); o += 2; } if (flags & 0x40) { suffix = d.readUInt16LE(o); o += 2; }
          const infomask2 = d.readUInt16LE(o), infomask = d.readUInt16LE(o + 2), hoff = d[o + 4]; o += 5;
          const tuplen = d.length - (prefix ? 2 : 0) - (suffix ? 2 : 0) - 5; const rec = d.subarray(o);
          const parts = [];
          if (prefix > 0) {
            if (!oldTupCopy) throw new Error('old tuple unavailable for prefix');
            const bl = hoff - 23; parts.push(rec.subarray(0, bl)); parts.push(oldTupCopy.subarray(oldTupCopy[22], oldTupCopy[22] + prefix)); parts.push(rec.subarray(bl, bl + (tuplen - bl)));
          } else parts.push(rec.subarray(0, tuplen));
          if (suffix > 0) { if (!oldTupCopy) throw new Error('old tuple unavailable for suffix'); parts.push(oldTupCopy.subarray(oldTupCopy.length - suffix)); }
          const body = Buffer.concat(parts); const t = Buffer.alloc(23 + body.length); body.copy(t, 23);
          t.writeUInt32LE(r.xid, 0); t.writeUInt32LE(newXmax, 4); t.writeUInt32LE(0, 8);
          t.writeUInt16LE(newBlk >>> 16, 12); t.writeUInt16LE(newBlk & 0xffff, 14); t.writeUInt16LE(newOff, 16);
          t.writeUInt16LE(infomask2, 18); t.writeUInt16LE(infomask, 20); t[22] = hoff;
          addItem(np, newOff, t); setLsn(np, r.endLsn); touched.add(newB.rel);
        }
      }
      if (!oldImaged) {
        const pp = getPage(oldB.rel, oldBlk);
        if (!(pageLsn(pp) < r.endLsn) && oldB !== newB) { stats.skippedLsn++; }
        else {
          const ot = getTuple(pp, oldOff).buf; infoBits(oldIb, ot); ot.writeUInt32LE(oldXmax, 4);
          if (op === 0x40) ot.writeUInt16LE(ot.readUInt16LE(18) | 0x4000, 18); else ot.writeUInt16LE(ot.readUInt16LE(18) & ~0x4000, 18);
          ot.writeUInt16LE(newBlk >>> 16, 12); ot.writeUInt16LE(newBlk & 0xffff, 14); ot.writeUInt16LE(newOff, 16);
          setLsn(pp, r.endLsn); touched.add(oldB.rel);
        }
      }
      stats.update++;
    }
  } catch (e) { stats.errors++; log.push(`ERROR ${tag} op=0x${op.toString(16)} ${relname.get(b0.rel) ?? b0.rel}: ${e.message}`); }
}

// write patched pages into dest copy
for (const [k, p] of pages) {
  const [rel, blk] = k.split(':').map(Number); if (!touched.has(rel)) continue;
  const f = `${dbdir}/${rel}`; const fd = fs.openSync(f, fs.existsSync(f) ? 'r+' : 'w'); fs.writeSync(fd, p, 0, PAGE, blk * PAGE); fs.closeSync(fd);
}
fs.writeFileSync(`${dst}/wal_xact.json`, JSON.stringify(xact));
console.log('WAL parse stop:', end, '| records', recs.length);
console.log(stats); console.log('committed', xact.committed.join(','), '\naborted', xact.aborted.join(','));
console.log('relations patched:', [...touched].map(r => relname.get(r) ?? r).join(', '));
if (log.length) console.log(log.join('\n'));
