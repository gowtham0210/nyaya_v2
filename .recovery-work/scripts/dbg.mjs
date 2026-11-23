import { openCluster, readCatalog, visibility } from './lib.mjs';
import { readRelPages, pageTuples, decodeTuple, pglzDecompress } from './heap.mjs';
const cl = openCluster('../data'); const { classes, attrs } = readCatalog(cl);
const c = classes.find(x => x.relname === 'question_versions' && x.ns === 2200);
const cols = attrs.filter(a => a.relid === c.oid && a.attnum > 0).sort((a, b) => a.attnum - b.attnum);
let shown = 0;
readRelPages(cl.dbdir, c.relfilenode).forEach((p, blk) => { for (const tp of pageTuples(p, blk)) {
  // decode column by column
  for (let k = 1; k <= cols.length; k++) {
    try { decodeTuple(tp, cols.slice(0, k).map(a => a.dropped ? { ...a, name: 'd' + a.attnum } : a), () => null); } catch (e) { if (shown++ < 4) console.log(blk, tp.offnum, 'fails at col', cols[k-1].name, cols[k-1].len, e.message); break; }
  }
} });
