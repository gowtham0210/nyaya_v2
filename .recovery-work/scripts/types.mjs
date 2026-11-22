import { openCluster, readCatalog } from './lib.mjs';
const cl = openCluster(process.argv[2]);
const { classes, attrs } = readCatalog(cl);
const pub = classes.filter(c => c.relkind === 'r' && c.ns === 2200);
const h = {};
for (const c of pub) for (const a of attrs.filter(a=>a.relid===c.oid&&a.attnum>0&&!a.dropped)) { const k=`${a.typid}/len${a.len}/${a.align}`; (h[k] ||= new Set()).add(c.relname+'.'+a.name); }
for (const [k,v] of Object.entries(h)) console.log(k, v.size, [...v].slice(0,3).join(','));
