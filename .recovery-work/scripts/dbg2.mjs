import { openCluster, readCatalog, visibility } from './lib.mjs';
import { readRelPages, pageTuples, pglzDecompress } from './heap.mjs';
const cl = openCluster('../data'); const { classes } = readCatalog(cl);
const c = classes.find(x => x.relname === 'question_versions' && x.ns === 2200);
const t = classes.find(x => x.oid === c.toast);
const m = new Map(); let n=0;
readRelPages(cl.dbdir, t.relfilenode).forEach((p, blk) => { for (const tp of pageTuples(p, blk)) { if (tp.bad||visibility(cl,tp).state!=='live') continue; const d=tp.raw.subarray(tp.hoff); const id=d.readUInt32LE(0), seq=d.readInt32LE(4); let o=8,h=d[o],data; if(h&1) data=d.subarray(o+1,o+(h>>1)); else {o=(o+3)&~3; data=d.subarray(o+4,o+(d.readUInt32LE(o)>>2));} if(!m.has(id))m.set(id,[]); m.get(id)[seq]=data; n++; } });
console.log('toast chunks', n, 'values', m.size);
let ok=0,bad=0,shown=0;
// find toast pointers in main rel
readRelPages(cl.dbdir, c.relfilenode).forEach((p) => { for (const tp of pageTuples(p, 0)) { const r=tp.raw; for (let i=tp.hoff;i<r.length-18;i++){ if(r[i]===1&&r[i+1]===18&&r.readUInt32LE(i+14)===c.toast){ const raw=r.readInt32LE(i+2), ext=r.readUInt32LE(i+6), id=r.readUInt32LE(i+10); const ch=m.get(id); if(!ch){bad++; if(shown++<3)console.log('no chunks',id);continue;} const buf=Buffer.concat(ch); const e=ext&0x3fffffff, meth=ext>>>30; try{ if(e<raw-4){ pglzDecompress(buf,raw-4); ok++; } else ok++; }catch(err){ bad++; if(shown++<5)console.log('fail', raw, e, meth, buf.length, ch.length, err.message);} } } } });
console.log({ok,bad});
