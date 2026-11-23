import fs from 'node:fs';
const A = '../extracted/ref1119', B = '../extracted/broken';
const sumB = JSON.parse(fs.readFileSync(B + '/_summary.json'));
const strip = (r) => { const o = {}; for (const [k, v] of Object.entries(r)) if (!k.startsWith('_')) o[k] = v; return o; };
const key = (t, r) => r.id !== undefined ? r.id : sumB[t].columns.slice(0, 2).map(c => r[c]).join('|');
const out = {};
for (const t of Object.keys(sumB)) {
  const live = (f) => JSON.parse(fs.readFileSync(`${f}/${t}.json`)).filter(r => r._vis?.state === 'live');
  const a = live(A), b = live(B);
  const am = new Map(a.map(r => [key(t, r), r])), bm = new Map(b.map(r => [key(t, r), r]));
  const nw = [], mod = [], gone = [];
  for (const [k, r] of bm) { if (!am.has(k)) nw.push(r); else { const x = JSON.stringify(strip(am.get(k))), y = JSON.stringify(strip(r)); if (x !== y) mod.push({ key: k, before: am.get(k), after: r }); } }
  for (const [k, r] of am) if (!bm.has(k)) gone.push(r);
  out[t] = { ref: a.length, recovered: b.length, new: nw.length, modified: mod.length, removed: gone.length };
  fs.mkdirSync('../diff', { recursive: true });
  fs.writeFileSync(`../diff/${t}.json`, JSON.stringify({ new: nw, modified: mod, removed: gone }, null, 1));
}
fs.writeFileSync('../diff/_summary.json', JSON.stringify(out, null, 1));
console.log('table'.padEnd(26), 'nov19 recovered new modified removed');
for (const [t, s] of Object.entries(out)) console.log(t.padEnd(26), String(s.ref).padStart(5), String(s.recovered).padStart(9), String(s.new).padStart(4), String(s.modified).padStart(8), String(s.removed).padStart(7));
