import fs from 'node:fs';
import { loadSegment, parseRecords, decodeBody } from './wal.mjs';
import { openCluster, readCatalog } from './lib.mjs';
const root = process.argv[2]; const S = 0x5000000n;
const seg = loadSegment(root, '000000010000000000000005', S);
const { recs } = parseRecords(seg, 0x510abc8n, S);
const cl = openCluster(root); const { classes } = readCatalog(cl);
const relname = new Map(classes.map(c => [c.relfilenode, c.relname]));
const HEAP = { 0x00: 'INSERT', 0x10: 'DELETE', 0x20: 'UPDATE', 0x40: 'HOT_UPDATE', 0x60: 'LOCK', 0x50: 'CONFIRM', 0x70: 'INPLACE' };
const rows = [];
for (const r of recs) {
  try { decodeBody(r); } catch (e) { rows.push(`${r.lsn.toString(16)} rmid=${r.rmid} info=${r.info.toString(16)} DECODE-FAIL ${e.message}`); continue; }
  if (r.rmid === 10 || r.rmid === 9 || (r.rmid === 0 && (r.info & 0xf0) === 0xa0)) {
    const kind = r.rmid === 10 ? HEAP[r.info & 0x70] || (r.info & 0xf0).toString(16) : r.rmid === 9 ? 'HEAP2_0x' + (r.info & 0xf0).toString(16) : 'FPI';
    for (const b of r.blocks) {
      let pagelsn = '-'; if (b.db === 5 && b.fork === 0) { const f = `${cl.dbdir}/${b.rel}`; if (fs.existsSync(f)) { const fd = fs.openSync(f, 'r'); const buf = Buffer.alloc(8); try { fs.readSync(fd, buf, 0, 8, b.blkno * 8192); pagelsn = ((BigInt(buf.readUInt32LE(4)) << 32n) | BigInt(buf.readUInt32LE(0))).toString(16); } catch {} fs.closeSync(fd); } }
      rows.push(`${r.lsn.toString(16)} xid=${r.xid} ${kind.padEnd(10)} ${String(relname.get(b.rel) ?? b.rel).padEnd(24)} blk=${b.blkno} img=${b.hasImage ? 'Y' : 'n'} data=${b.hasData ? b.dlen : 0} diskPageLsn=${pagelsn}`);
    }
  }
  if (r.rmid === 1) rows.push(`${r.lsn.toString(16)} xid=${r.xid} XACT ${(r.info & 0x70) === 0 ? 'COMMIT' : (r.info & 0x70) === 0x20 ? 'ABORT' : r.info.toString(16)}`);
}
console.log(rows.join('\n'));
