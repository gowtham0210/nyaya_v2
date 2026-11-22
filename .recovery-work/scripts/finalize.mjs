// Builds recovered/ (live rows + confidence), diff/ vs Nov-19 backup, and REPORT.md. READ-ONLY on sources.
import fs from 'node:fs';
const R = '../extracted/redo', REF = '../extracted/ref1119', CK_NEXT_XID = 7157;
const sum = JSON.parse(fs.readFileSync(R + '/_summary.json'));
const integrity = JSON.parse(fs.readFileSync(R + '/_integrity.json'));
const load = (d, t) => JSON.parse(fs.readFileSync(`${d}/${t}.json`));
const meta = (r) => { const o = {}; for (const [k, v] of Object.entries(r)) if (k[0] !== '_') o[k] = v; return o; };
const key = (t, r) => r.id !== undefined ? r.id : sum[t].columns.slice(0, 2).map(c => JSON.stringify(r[c])).join('|');
fs.mkdirSync('../recovered', { recursive: true }); fs.mkdirSync('../diff', { recursive: true });

const rows = []; const tot = { live: 0, high: 0, medium: 0, partial: 0, fromWal: 0, newRows: 0, modRows: 0 };
const modDetail = {};
for (const t of Object.keys(sum)) {
  const refRows = new Map(load(REF, t).filter(r => r._vis?.state === 'live').map(r => [key(t, r), r]));
  const rec = load(R, t).filter(r => r._vis?.state === 'live');
  const out = []; const nw = [], mod = []; let high = 0, medium = 0, partial = 0, wal = 0;
  const gone = [...refRows.keys()];
  const seen = new Set();
  for (const r of rec) {
    const fromWal = r._loc.xmin >= CK_NEXT_XID; // created by a transaction after the last checkpoint => known only via WAL
    let conf = 'high', notes = [];
    if (fromWal) { conf = 'medium'; notes.push('row version created after last checkpoint; reconstructed from WAL redo'); wal++; }
    if (r._vis.conf !== 'high') { conf = 'medium'; notes.push('visibility: ' + r._vis.why); }
    if (r._partial) { conf = 'partial'; notes.push('unreadable columns: ' + Object.entries(r).filter(([k, v]) => v && typeof v === 'object' && v._unreadable).map(([k]) => k).join(',')); }
    if (r._fastDefault) notes.push('column(s) ' + r._fastDefault.join(',') + ' not stored in tuple; value = ADD COLUMN default from migration');
    const k = key(t, r); seen.add(k);
    const o = { ...meta(r), _confidence: conf, _source: fromWal ? 'wal-redo' : 'heap-file', _notes: notes.length ? notes : undefined, _loc: r._loc };
    out.push(o);
    if (conf === 'high') high++; else if (conf === 'medium') medium++; else partial++;
    const before = refRows.get(k);
    if (!before) nw.push(o);
    else if (JSON.stringify(meta(before)) !== JSON.stringify(meta(r))) {
      const fields = Object.keys(meta(r)).filter(f => JSON.stringify(before[f]) !== JSON.stringify(r[f]));
      mod.push({ key: k, changedFields: fields, before: meta(before), after: o });
      for (const f of fields) { const d = (modDetail[t] ??= {}); d[f] = (d[f] || 0) + 1; }
    }
  }
  const removed = gone.filter(k => !seen.has(k)).map(k => meta(refRows.get(k)));
  fs.writeFileSync(`../recovered/${t}.json`, JSON.stringify(out, null, 1));
  fs.writeFileSync(`../diff/${t}.json`, JSON.stringify({ new: nw, modified: mod, removedSinceNov19: removed }, null, 1));
  rows.push({ t, ref: refRows.size, rec: rec.length, nw: nw.length, mod: mod.length, rem: removed.length, high, medium, partial, wal });
  tot.live += rec.length; tot.high += high; tot.medium += medium; tot.partial += partial; tot.fromWal += wal; tot.newRows += nw.length; tot.modRows += mod.length;
}
fs.writeFileSync('../diff/_summary.json', JSON.stringify(rows, null, 1));

const md = [];
md.push('# PGlite raw-page salvage report', '', 'Source: copy of `backend/.data/pglite-broken-20261122` (original untouched). Reference: Nov 19 backup `pglite-backup-20261119-pre-practice-timer`. Nothing was imported into the live DB or CMS.', '');
md.push('## 1. Method', '',
  '- Parsed 8 KB heap pages directly (no Postgres started, no `pg_resetwal`): `pg_class`/`pg_attribute`/`pg_type`/`pg_enum` first, then every public table, including TOAST (pglz) values, jsonb, numeric, arrays, enums.',
  '- Row visibility from hint bits + `pg_xact` (commit log).',
  '- **Decoder validated against ground truth**: the same extractor run on the Nov 19 backup matches `SELECT` output from PGlite for all 48 tables (every live row identical; vector embeddings excluded).',
  '- The cluster\'s last checkpoint was 2026-11-22 13:04:55 IST (07:34:55 UTC, xid 7157). The heap files only hold state up to there. The WAL after it was intact (180 records, every CRC32C valid, clean end at LSN 0/512C060). I replayed its heap records (INSERT, UPDATE, HOT_UPDATE, DELETE, PRUNE, full-page images) onto a second copy (`data-redo`) and used the WAL commit/abort records for commit status of xids 7157-7181.',
  '- Not replayed (no effect on row content): index (btree) records, row-lock records, visibility-map bits.', '');
md.push('## 2. Result summary', '',
  `- Tables inspected: **${rows.length}** (all public tables).`,
  `- Live rows recovered: **${tot.live}** (Nov 19 backup had ${rows.reduce((a, r) => a + r.ref, 0)}).`,
  `- New since Nov 19: **${tot.newRows}** rows. Modified since Nov 19: **${tot.modRows}** rows. Removed since Nov 19: **${rows.reduce((a, r) => a + r.rem, 0)}** rows (only \`rate_limits\`, an expiring throttle table).`,
  `- Confidence: **${tot.high} high**, **${tot.medium} medium** (reconstructed from WAL), **${tot.partial} partial**.`,
  `- Referential integrity: ${integrity.fkChecks.length} foreign-key relations checked, **${integrity.fkWithOrphans} with orphans**; duplicate live ids: ${integrity.duplicateLiveIds.length}; question.live_version mismatches: ${integrity.questionLiveVersionMismatch}.`, '');
md.push('## 3. Per-table counts', '', '| table | Nov 19 | recovered | new | modified | removed | high | medium (WAL) | partial |', '|---|--:|--:|--:|--:|--:|--:|--:|--:|');
for (const r of rows) md.push(`| ${r.t} | ${r.ref} | ${r.rec} | ${r.nw} | ${r.mod} | ${r.rem} | ${r.high} | ${r.medium} | ${r.partial} |`);
md.push('', '## 4. Modified rows (what changed since Nov 19)', '');
for (const [t, d] of Object.entries(modDetail)) md.push(`- **${t}**: ` + Object.entries(d).map(([f, n]) => `${f} (${n})`).join(', '));
fs.writeFileSync('../REPORT_body.md', md.join('\n'));
console.log(md.join('\n'));
