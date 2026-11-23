// Read-only WAL scanner for segment 5 (post-checkpoint records). Usage: node wal.mjs <cluster-root>
import fs from 'node:fs';

const PAGE = 8192, SEGSZ = 16 * 1024 * 1024;
// CRC32C (Castagnoli), reflected
const T = new Uint32Array(256);
for (let i = 0; i < 256; i++) { let c = i; for (let k = 0; k < 8; k++) c = c & 1 ? (c >>> 1) ^ 0x82f63b78 : c >>> 1; T[i] = c >>> 0; }
export function crc32c(buf, crc = 0xffffffff) { for (let i = 0; i < buf.length; i++) crc = T[(crc ^ buf[i]) & 0xff] ^ (crc >>> 8); return crc >>> 0; }

export function loadSegment(root, segName, segStartLsn) {
  const b = fs.readFileSync(`${root}/pg_wal/${segName}`);
  // logical stream: concatenate valid pages' payloads; map stream offset -> lsn
  const parts = [], map = []; let streamOff = 0, validPages = 0;
  for (let p = 0; p < SEGSZ; p += PAGE) {
    const magic = b.readUInt16LE(p), addr = b.readBigUInt64LE(p + 8);
    if (magic !== 0xd118 || addr !== segStartLsn + BigInt(p)) break;
    validPages++;
    const hdr = p === 0 ? 40 : 24; const info = b.readUInt16LE(p + 2); const remLen = b.readUInt32LE(p + 16);
    map.push({ streamOff, lsn: segStartLsn + BigInt(p) + BigInt(hdr), len: PAGE - hdr, contRem: info & 1 ? remLen : 0, pageIdx: p / PAGE });
    parts.push(b.subarray(p + hdr, p + PAGE)); streamOff += PAGE - hdr;
  }
  return { stream: Buffer.concat(parts), map, validPages };
}
export function lsnToStream(seg, lsn, segStartLsn) {
  const off = Number(lsn - segStartLsn); const pi = Math.floor(off / PAGE); const m = seg.map[pi];
  return m.streamOff + (off % PAGE) - (pi === 0 ? 40 : 24);
}
export function streamToLsn(seg, so, segStartLsn) {
  let lo = 0; for (let i = 0; i < seg.map.length; i++) if (seg.map[i].streamOff <= so) lo = i;
  return seg.map[lo].lsn + BigInt(so - seg.map[lo].streamOff);
}

export function parseRecords(seg, startLsn, segStartLsn) {
  const s = seg.stream; let o = lsnToStream(seg, startLsn, segStartLsn); const recs = []; let end = 'stream end';
  while (o + 24 <= s.length) {
    const tot = s.readUInt32LE(o);
    if (tot < 24 || o + tot > s.length) { end = `incomplete/invalid at stream ${o} tot=${tot}`; break; }
    const rec = s.subarray(o, o + tot);
    const crcStored = rec.readUInt32LE(20);
    let crc = crc32c(rec.subarray(24)); crc = crc32c(rec.subarray(0, 20), crc); crc = (crc ^ 0xffffffff) >>> 0;
    const lsn = streamToLsn(seg, o, segStartLsn);
    const r = { lsn, endLsn: streamToLsn(seg, o + tot, segStartLsn), tot, xid: rec.readUInt32LE(4), info: rec[16], rmid: rec[17], crcOk: crc === crcStored, rec };
    recs.push(r);
    if (!r.crcOk) { end = `CRC mismatch at lsn ${lsn.toString(16)}`; break; }
    o += (tot + 7) & ~7;
  }
  return { recs, end };
}

/** Decode block references and data areas of a record body */
export function decodeBody(r) {
  const b = r.rec; let p = 24; const blocks = []; let mainLen = 0; let origin = null; let datatotal = 0;
  while (b.length - p > datatotal) {
    const id = b[p++];
    if (id === 255) { mainLen = b[p++]; datatotal += mainLen; continue; }
    if (id === 254) { mainLen = b.readUInt32LE(p); p += 4; datatotal += mainLen; continue; }
    if (id === 253) { origin = b.readUInt16LE(p); p += 2; continue; }
    if (id === 252) { p += 4; continue; }
    const forkFlags = b[p++]; const dlen = b.readUInt16LE(p); p += 2;
    const blk = { id, fork: forkFlags & 0xf, hasImage: !!(forkFlags & 0x10), hasData: !!(forkFlags & 0x20), sameRel: !!(forkFlags & 0x80), dlen };
    if (blk.hasImage) {
      blk.imgLen = b.readUInt16LE(p); blk.holeOff = b.readUInt16LE(p + 2); blk.imgInfo = b[p + 4]; p += 5;
      blk.compressed = !!(blk.imgInfo & 0x1c); blk.hasHole = !!(blk.imgInfo & 0x01);
      blk.holeLen = (blk.hasHole && blk.compressed) ? (p += 2, b.readUInt16LE(p - 2)) : (blk.hasHole ? PAGE - blk.imgLen : 0);
      blk.apply = !!(blk.imgInfo & 0x02);
    }
    if (!blk.sameRel) { blk.spc = b.readUInt32LE(p); blk.db = b.readUInt32LE(p + 4); blk.rel = b.readUInt32LE(p + 8); p += 12; }
    blk.blkno = b.readUInt32LE(p); p += 4;
    datatotal += (blk.imgLen || 0) + blk.dlen; blocks.push(blk);
  }
  for (const k of blocks) {
    if (k.hasImage) { k.img = b.subarray(p, p + k.imgLen); p += k.imgLen; }
    if (k.hasData) { k.data = b.subarray(p, p + k.dlen); p += k.dlen; }
    if (k.sameRel) { const prev = blocks[blocks.indexOf(k) - 1]; k.spc = prev.spc; k.db = prev.db; k.rel = prev.rel; }
  }
  r.main = b.subarray(p, p + mainLen); p += mainLen;
  r.blocks = blocks; r.origin = origin; r.bodyEnd = p; return r;
}

if (process.argv[1].endsWith('wal.mjs')) {
  const root = process.argv[2]; const segStart = 0x5000000n;
  const seg = loadSegment(root, '000000010000000000000005', segStart);
  console.log('valid pages', seg.validPages);
  const { recs, end } = parseRecords(seg, 0x510abc8n, segStart);
  console.log('records', recs.length, 'stop:', end, 'crcOk all:', recs.every(r => r.crcOk));
  const names = { 0: 'XLOG', 1: 'Transaction', 2: 'Storage', 3: 'CLOG', 4: 'Database', 5: 'Tablespace', 6: 'MultiXact', 7: 'RelMap', 8: 'Standby', 9: 'Heap2', 10: 'Heap', 11: 'Btree', 12: 'Hash', 13: 'Gin', 14: 'Gist', 15: 'Seq', 16: 'SPGist', 17: 'BRIN', 18: 'CommitTs', 19: 'ReplOrigin', 20: 'Generic', 21: 'LogicalMsg' };
  const h = {}; for (const r of recs) { const k = `${names[r.rmid] || r.rmid}/0x${(r.info & 0xf0).toString(16)}`; h[k] = (h[k] || 0) + 1; }
  console.log(h);
  const last = recs[recs.length - 1]; console.log('last record lsn', last?.lsn.toString(16), 'end', last?.endLsn.toString(16));
}
