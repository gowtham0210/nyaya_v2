import { openCluster, readCatalog } from './lib.mjs';
const cl = openCluster(process.argv[2]);
const { classes, attrs } = readCatalog(cl);
const pub = classes.filter(c => c.relkind === 'r' && c.ns === 2200);
console.log('live pg_class rows', classes.length, 'public tables', pub.length);
for (const c of pub.sort((a,b)=>a.relname.localeCompare(b.relname))) console.log(c.relname, c.oid, c.relfilenode, 'toast', c.toast, 'natts', attrs.filter(a=>a.relid===c.oid&&a.attnum>0).length);
