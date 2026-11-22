// DRY RUN: restores recovered data into a SCRATCH COPY only.
// Usage: node dryrun.mjs <label> <sourceDbDir-to-copy> <workDir>
// Never opens the live DB: the source is copied first and only the copy is opened.
import fs from 'node:fs';
import path from 'node:path';
import crypto from 'node:crypto';

const [label, srcDir, workRoot] = process.argv.slice(2);
if (!workRoot || !workRoot.includes('dryrun')) throw new Error('workRoot must be under a dryrun folder');
const RECOVERY = path.resolve(import.meta.dirname, '..');
const BACKEND = 'D:/DWS/nyaya_v2/backend';
const norm = (p) => 'file:///' + p.replace(/\\/g, '/');
const { PGlite } = await import(norm(`${BACKEND}/node_modules/@electric-sql/pglite/dist/index.js`));
const { drizzle } = await import(norm(`${BACKEND}/node_modules/drizzle-orm/pglite/index.js`));
const { migrate } = await import(norm(`${BACKEND}/node_modules/drizzle-orm/pglite/migrator.js`));

const readJ = (p) => JSON.parse(fs.readFileSync(p, 'utf8'));
const REC = (t) => readJ(`${RECOVERY}/recovered/${t}.json`);
const DIFF = (t) => readJ(`${RECOVERY}/diff/${t}.json`);
const summary = readJ(`${RECOVERY}/diff/_summary.json`);
const tables = summary.map((s) => s.t);
const strip = (r) => { const o = {}; for (const k in r) if (k[0] !== '_') o[k] = r[k]; return o; };

// ---- scratch copy
const dbDir = path.join(workRoot, label, 'db');
fs.rmSync(path.join(workRoot, label), { recursive: true, force: true });
fs.mkdirSync(path.join(workRoot, label), { recursive: true });
fs.cpSync(srcDir, dbDir, { recursive: true });
try { fs.rmSync(path.join(dbDir, 'postmaster.pid')); } catch { /* none */ }

const db = new PGlite(dbDir);
await db.waitReady;
const results = { label, source: srcDir, steps: [], tables: {}, papers: [], checks: [], failures: 0 };
const log = (m) => console.log(m);
const fail = (m) => { results.failures++; log('FAIL ' + m); };
const check = (name, ok, detail = '') => { results.checks.push({ name, ok, detail }); if (!ok) results.failures++; log(`${ok ? 'PASS' : 'FAIL'} ${name} ${detail}`); };
const q = async (sql, params = []) => (await db.query(sql, params)).rows;
const count = async (t) => Number((await q(`select count(*)::int n from "${t}"`))[0].n);

// ---- pre-state
const pre = {}; for (const t of tables) pre[t] = await count(t);
const preIds = {}; const hasId = {};
for (const t of tables) { const cols = (await q(`select column_name from information_schema.columns where table_schema='public' and table_name=$1`, [t])).map((r) => r.column_name); hasId[t] = cols.includes('id'); if (hasId[t]) preIds[t] = new Set((await q(`select id::text id from "${t}"`)).map((r) => r.id)); }
const preMig = await q(`select count(*)::int n from drizzle.__drizzle_migrations`);
log(`[${label}] pre: ${Object.values(pre).reduce((a, b) => a + b, 0)} rows; migrations applied: ${preMig[0].n}`);
const preHasTimer = (await q(`select 1 from information_schema.columns where table_name='exam_papers' and column_name='practice_timer_seconds'`)).length > 0;
const preHasWithdrawn = (await q(`select 1 from pg_enum e join pg_type t on t.oid=e.enumtypid where t.typname='import_outcome' and e.enumlabel='withdrawn'`)).length > 0;
results.pre = { rows: pre, migrations: preMig[0].n, hasTimerColumn: preHasTimer, hasWithdrawnEnum: preHasWithdrawn };

// ---- step 1: migrations (the repo's drizzle migrator, same call as backend openDb)
{
  const d = drizzle({ client: db });
  await migrate(d, { migrationsFolder: `${BACKEND}/drizzle` });
  const mig = await q(`select count(*)::int n from drizzle.__drizzle_migrations`);
  const hasTimer = (await q(`select 1 from information_schema.columns where table_name='exam_papers' and column_name='practice_timer_seconds'`)).length > 0;
  const hasW = (await q(`select 1 from pg_enum e join pg_type t on t.oid=e.enumtypid where t.typname='import_outcome' and e.enumlabel='withdrawn'`)).length > 0;
  const chk = (await q(`select pg_get_constraintdef(oid) d from pg_constraint where conname='exam_attempts_deadline_check'`))[0]?.d ?? '';
  check('migrations: 26 applied (0000-0024 + legal row)', mig[0].n === 26, `(was ${preMig[0].n}, now ${mig[0].n})`);
  check('migration 0023: exam_papers.practice_timer_seconds exists', hasTimer, preHasTimer ? '(already applied before dry run)' : '(applied by dry run)');
  check("migration 0024: import_outcome has 'withdrawn'", hasW, preHasWithdrawn ? '(already applied before dry run)' : '(applied by dry run)');
  check('migration 0023: deadline check constraint present', /mode/.test(chk) && /deadline_at/.test(chk), chk.slice(0, 90));
  results.steps.push({ step: 'migrations', ok: true });
}

// ---- helpers
const cache = {}; const colsOf = async (t) => (cache[t] ??= (await q(`select column_name from information_schema.columns where table_schema='public' and table_name=$1 order by ordinal_position`, [t])).map((r) => r.column_name));
const inserted = {}, updated = {}, skipped = {};
async function insertNew(tx, t, mutate) {
  let rows = DIFF(t).new.map(strip); if (!rows.length) { inserted[t] = 0; return; }
  if (mutate) rows = rows.map(mutate);
  const order = (await colsOf(t)).includes('created_at') ? 'order by created_at' : '';
  const r = await tx.query(`insert into "${t}" select * from jsonb_populate_recordset(NULL::"${t}", $1::jsonb) ${order} on conflict do nothing returning 1`, [JSON.stringify(rows)]);
  inserted[t] = r.rows.length;
  if (r.rows.length !== rows.length) throw new Error(`${t}: inserted ${r.rows.length} of ${rows.length}`);
}
async function applyMods(tx, t) {
  const mods = DIFF(t).modified; updated[t] = 0; skipped[t] = [];
  const cols = await colsOf(t);
  for (const m of mods) {
    const after = strip(m.after), before = strip(m.before);
    const set = m.changedFields.filter((f) => cols.includes(f));
    const guard = set.filter((f) => f in before);
    const sql = `update "${t}" as t set ${set.map((f) => `"${f}" = r."${f}"`).join(', ')}
      from jsonb_populate_record(NULL::"${t}", $1::jsonb) r, jsonb_populate_record(NULL::"${t}", $2::jsonb) b
      where t.id = r.id and t.id = $3::uuid
        ${guard.length ? `and (${guard.map((f) => `t."${f}"`).join(',')}) is not distinct from (${guard.map((f) => `b."${f}"`).join(',')})` : ''}
        ${cols.includes('updated_at') ? 'and r.updated_at >= t.updated_at' : ''}
      returning 1`;
    const r = await tx.query(sql, [JSON.stringify(after), JSON.stringify(before), m.key]);
    if (r.rows.length === 1) updated[t]++; else skipped[t].push({ id: m.key, reason: 'guard failed (live row differs from recorded before-state or is newer)' });
  }
  if (updated[t] !== mods.length) throw new Error(`${t}: updated ${updated[t]} of ${mods.length}`);
}

const TIERS = [
  ['A users', async (tx) => { await insertNew(tx, 'users'); await applyMods(tx, 'users'); }],
  ['B subjects, acts, content_sources, exams', async (tx) => { for (const t of ['subjects', 'acts', 'content_sources', 'exams']) await insertNew(tx, t); }],
  ['C topics, exam_blueprints', async (tx) => { for (const t of ['topics', 'exam_blueprints']) await insertNew(tx, t); }],
  ['D questions (live_version_id NULL: circular FK)', async (tx) => { await insertNew(tx, 'questions', (r) => ({ ...r, live_version_id: null })); }],
  ['E question_versions', async (tx) => { await insertNew(tx, 'question_versions'); await applyMods(tx, 'question_versions'); }],
  ['F questions.live_version_id, review_decisions, version_acts', async (tx) => {
    const want = REC('questions').filter((x) => x.live_version_id).map((x) => ({ id: x.id, live_version_id: x.live_version_id, updated_at: x.updated_at }));
    const r = await tx.query(`update questions qq set live_version_id = x.live_version_id, updated_at = x.updated_at from jsonb_to_recordset($1::jsonb) as x(id uuid, live_version_id uuid, updated_at timestamptz) where qq.id = x.id and qq.live_version_id is distinct from x.live_version_id and (qq.live_version_id is null) returning 1`, [JSON.stringify(want)]);
    updated.questions = r.rows.length; if (r.rows.length !== 753 + 4) throw new Error('questions.live_version_id fixed ' + r.rows.length + ' (expected 757)');
    for (const t of ['review_decisions', 'question_version_acts']) await insertNew(tx, t);
  }],
  ['G import_jobs, import_job_rows, import_row_problems', async (tx) => { for (const t of ['import_jobs', 'import_job_rows', 'import_row_problems']) await insertNew(tx, t); }],
  ['H exam_question_tags, exam_sections, exam_section_topics', async (tx) => { for (const t of ['exam_question_tags', 'exam_sections', 'exam_section_topics']) await insertNew(tx, t); }],
  ['I exam_papers (update then insert), paper questions, key history', async (tx) => { await applyMods(tx, 'exam_papers'); for (const t of ['exam_papers', 'exam_paper_questions', 'exam_paper_key_history']) await insertNew(tx, t); }],
  ['J daily_tips (3 guarded updates), news_articles', async (tx) => { await applyMods(tx, 'daily_tips'); await insertNew(tx, 'news_articles'); }],
  ['K learner data', async (tx) => { for (const t of ['learner_settings', 'premium_memberships', 'league_cohorts', 'league_memberships', 'quiz_sessions', 'quiz_session_topics', 'quiz_session_questions', 'coin_ledger', 'energy_ledger', 'chest_openings', 'chat_usage', 'app_opens', 'duel_matches', 'question_bookmarks', 'content_reports']) await insertNew(tx, t); }],
  ['L exam_attempts, exam_attempt_questions', async (tx) => { await insertNew(tx, 'exam_attempts'); await insertNew(tx, 'exam_attempt_questions'); }],
  ['M refresh_tokens (new + revocation update), reset/setup tokens', async (tx) => { await insertNew(tx, 'refresh_tokens'); await applyMods(tx, 'refresh_tokens'); for (const t of ['password_reset_codes', 'staff_setup_tokens']) await insertNew(tx, t); }],
  ['N audit_log', async (tx) => { await insertNew(tx, 'audit_log'); }],
];
for (const t of tables) await colsOf(t); // pre-cache: db.query would block inside an open transaction
for (const [name, fn] of TIERS) {
  try { await db.transaction(async (tx) => { await fn(tx); }); log(`tier ${name}: committed`); results.steps.push({ step: name, ok: true }); }
  catch (e) { fail(`tier ${name}: ${e.message}`); results.steps.push({ step: name, ok: false, error: e.message }); throw e; }
}
results.inserted = inserted; results.updated = updated; results.skipped = skipped;

// ---- verification
const SKIP_COMPARE = new Set(['rate_limits', 'legal_chunks', 'legal_documents', 'legal_sync_runs']);
const normv = (v) => {
  if (v === null || v === undefined) return 'N';
  if (typeof v === 'string') { if (/^\d{4}-\d\d-\d\dT\d\d:\d\d:\d\d(\.\d+)?(Z|[+-]\d\d(:\d\d)?)$/.test(v)) { const m = v.match(/\.(\d+)/); const base = Date.parse(v.replace(/(\.\d+)/, '').replace(/([+-]\d\d)$/, '$1:00')); return 'T' + base + (m ? m[1].padEnd(6, '0').slice(0, 6) : '000000'); } return 'S' + v; }
  if (typeof v === 'number') return 'D' + Number(v);
  if (typeof v === 'boolean') return 'B' + v;
  if (Array.isArray(v)) return 'A[' + v.map(normv).join(',') + ']';
  return 'O{' + Object.keys(v).sort().map((k) => k + ':' + normv(v[k])).join(',') + '}';
};
const sigOf = (cols) => (o) => cols.map((c) => c + '=' + (/marks|percent/.test(c) && o[c] != null ? 'D' + Number(o[c]) : normv(o[c]))).join('|');

for (const t of tables) {
  const now = await count(t);
  const newN = DIFF(t).new.length; const expect = (t === 'rate_limits') ? pre[t] : pre[t] + newN;
  const entry = { table: t, pre: pre[t], expected: expect, actual: now, inserted: inserted[t] ?? 0, updated: updated[t] ?? 0, countOk: now === expect };
  if (!SKIP_COMPARE.has(t)) {
    const cols = await colsOf(t); const sig = sigOf(cols); const dbRows = (await q(`select to_jsonb(x) j from "${t}" x`)).map((r) => r.j);
    const dbSigs = new Map(); for (const r of dbRows) { const k = sig(r); dbSigs.set(k, (dbSigs.get(k) || 0) + 1); }
    const recRows = REC(t).map(strip); let missing = 0;
    for (const r of recRows) { const k = sig(r); const n = dbSigs.get(k) || 0; if (n === 0) missing++; else dbSigs.set(k, n - 1); }
    const extraRows = [...dbSigs.values()].reduce((a, b) => a + b, 0);
    const expectedExtra = now - (recRows.length - missing); // extras the DB holds beyond recovered
    // extras must be rows that pre-existed in the scratch DB and are not in recovered (e.g. rows created after the crash)
    let extraOk = true;
    if (extraRows) { if (hasId[t]) { const recIds = new Set(recRows.map((r) => r.id)); const dbIds = (await q(`select id::text id from "${t}"`)).map((r) => r.id); const extraIds = dbIds.filter((i) => !recIds.has(i)); extraOk = extraIds.every((i) => preIds[t].has(i)) && extraIds.length === extraRows; } else extraOk = extraRows <= pre[t]; }
    entry.recovered = recRows.length; entry.missingOrDifferent = missing; entry.extraRowsInDb = extraRows; entry.extraOk = extraOk; entry.contentOk = missing === 0 && extraOk;
  } else { entry.contentOk = now === pre[t]; entry.note = t === 'rate_limits' ? 'skipped by design; unchanged' : 'not restored; unchanged'; }
  entry.ok = entry.countOk && entry.contentOk; results.tables[t] = entry; if (!entry.ok) results.failures++;
}

// FK orphans & validity
{
  const fks = await q(`select c.conname, c.conrelid::regclass::text child, c.confrelid::regclass::text parent, c.conkey, c.confkey, c.convalidated,
     (select array_agg(a.attname order by k.ord) from unnest(c.conkey) with ordinality k(attnum, ord) join pg_attribute a on a.attrelid=c.conrelid and a.attnum=k.attnum) ccols,
     (select array_agg(a.attname order by k.ord) from unnest(c.confkey) with ordinality k(attnum, ord) join pg_attribute a on a.attrelid=c.confrelid and a.attnum=k.attnum) pcols
     from pg_constraint c where c.contype='f'`);
  let bad = 0; let unval = 0;
  for (const f of fks) {
    const j = f.ccols.map((c, i) => `p."${f.pcols[i]}" = c."${c}"`).join(' and ');
    const nn = f.ccols.map((c) => `c."${c}" is not null`).join(' and ');
    const n = Number((await q(`select count(*)::int n from ${f.child} c where ${nn} and not exists (select 1 from ${f.parent} p where ${j})`))[0].n);
    if (n) { bad++; log(`ORPHANS ${f.conname}: ${n}`); } if (!f.convalidated) unval++;
  }
  check(`foreign keys: ${fks.length} constraints, orphans`, bad === 0, `(${bad} constraints with orphans, ${unval} not validated)`);
  const badIdx = await q(`select indexrelid::regclass::text i from pg_index where not indisvalid`);
  check('indexes: all valid (unique indexes enforce no duplicate ids)', badIdx.length === 0, JSON.stringify(badIdx));
  let dupAny = 0; for (const t of tables) if (hasId[t]) { const d = await q(`select count(*)::int - count(distinct id)::int n from "${t}"`); dupAny += d[0].n; }
  check('duplicate ids across all id tables', dupAny === 0, `(${dupAny})`);
}

// Specific checks
{
  const nullLive = Number((await q(`select count(*)::int n from questions where live_version_id is null`))[0].n);
  check('circular FK: no question left without live_version_id', nullLive === 0, `(${nullLive})`);
  const wrongPair = Number((await q(`select count(*)::int n from questions qq join question_versions v on v.id=qq.live_version_id where v.question_id<>qq.id`))[0].n);
  check('circular FK: every live_version belongs to its question', wrongPair === 0, `(${wrongPair})`);
  const recRevoked = REC('refresh_tokens').filter((t) => t.revoked_at).length;
  const dbRevoked = Number((await q(`select count(*)::int n from refresh_tokens where revoked_at is not null`))[0].n);
  const modTok = DIFF('refresh_tokens').modified[0];
  const tokRow = (await q(`select revoked_at is not null r from refresh_tokens where id=$1::uuid`, [modTok.key]))[0];
  check('refresh token revocation restored (previously live=active)', tokRow?.r === true, `(token ${modTok.key.slice(0, 8)}: revoked=${tokRow?.r}; revoked tokens recovered=${recRevoked}, in db=${dbRevoked})`);
  const unrevokedExtra = Number((await q(`select count(*)::int n from refresh_tokens t where revoked_at is null and id = any($1::uuid[])`, [REC('refresh_tokens').filter((t) => t.revoked_at).map((t) => t.id)]))[0].n);
  check('no recovered-revoked token is active', unrevokedExtra === 0, `(${unrevokedExtra})`);
  // daily tips
  for (const m of DIFF('daily_tips').modified) {
    const r = (await q(`select status::text s, published_at, approved_at, last_verified_on::text lv, publish_date::text pd, updated_by::text ub, reviewer_id::text rv, published_by::text pb from daily_tips where id=$1::uuid`, [m.key]))[0];
    const ok = r.s === 'published' && new Date(r.published_at).toISOString() === new Date(m.after.published_at).toISOString() && new Date(r.approved_at).toISOString() === new Date(m.after.approved_at).toISOString() && r.lv === m.after.last_verified_on && r.rv === m.after.reviewer_id && r.pb === m.after.published_by && r.ub === m.after.updated_by;
    const audit = Number((await q(`select count(*)::int n from audit_log where entity_id=$1::uuid and action in ('daily_tip.published','daily_tip.approved','daily_tip.submitted','daily_tip.updated')`, [m.key]))[0].n);
    check(`daily tip ${m.key.slice(0, 13)} published ${r.pd}`, ok && audit >= 4, `(status=${r.s}, published_at=${new Date(r.published_at).toISOString()}, audit events=${audit})`);
  }
  const live1 = Number((await q(`select count(*)::int n from (select publish_date, language from daily_tips where status='published' group by 1,2 having count(*)>1) x`))[0].n);
  check('daily tips: one published tip per day+language', live1 === 0, `(${live1} collisions)`);
  const pubTips = Number((await q(`select count(*)::int n from daily_tips where status='published'`))[0].n);
  check('daily tips: 11 published, 90 draft expected', pubTips === 11, `(published=${pubTips})`);
  // import records
  const wd = Number((await q(`select count(*)::int n from import_job_rows where outcome='withdrawn'`))[0].n);
  check("import rows with outcome 'withdrawn' restored (needs 0024)", wd === 7, `(${wd})`);
  const jobs = Number((await q(`select count(*)::int n from import_jobs`))[0].n);
  check('import_jobs = 9 (AIBE 18-21, UG 2026, CLAT 2023 x2, 2025, 2024)', jobs === 9, `(${jobs})`);
  const qs = await q(`select count(*)::int n, count(*) filter (where exam_only)::int eo from questions`);
  check('questions: 1159 total, 1051 exam-only', qs[0].n === 1159 && qs[0].eo === 1051, JSON.stringify(qs[0]));
  const vs = await q(`select count(*)::int n, count(*) filter (where status='published')::int p from question_versions`);
  check('question_versions: 1159, all published', vs[0].n === 1159 && vs[0].p === 1159, JSON.stringify(vs[0]));
  const rd = Number((await q(`select count(*)::int n from review_decisions`))[0].n);
  check('review_decisions = 1051 (all approved)', rd === 1051, `(${rd})`);
}

// Per-paper verification
{
  const papers = REC('exam_papers'); const pqAll = REC('exam_paper_questions'); const vers = new Map(REC('question_versions').map((v) => [v.id, v]));
  const bpCols = await colsOf('exam_papers'); const pqCols = await colsOf('exam_paper_questions'); const vCols = await colsOf('question_versions');
  const sP = sigOf(bpCols), sQ = sigOf(pqCols), sV = sigOf(vCols);
  for (const p of papers.sort((a, b) => (a.created_at < b.created_at ? -1 : 1))) {
    const issues = [];
    const dbP = (await q(`select to_jsonb(x) j from exam_papers x where id=$1::uuid`, [p.id]))[0]?.j;
    if (!dbP) issues.push('paper row missing'); else if (sP(dbP) !== sP(strip(p))) issues.push('paper row differs');
    const dbStatus = dbP?.status; if (dbStatus !== p.status) issues.push(`status ${dbStatus} != ${p.status}`);
    const expRows = pqAll.filter((r) => r.paper_id === p.id).sort((a, b) => a.position - b.position);
    const dbRows = (await q(`select to_jsonb(x) j from exam_paper_questions x where paper_id=$1::uuid order by position`, [p.id])).map((r) => r.j);
    if (dbRows.length !== p.total_questions) issues.push(`paper rows ${dbRows.length} != total_questions ${p.total_questions}`);
    if (dbRows.length !== expRows.length || dbRows.some((r, i) => sQ(r) !== sQ(strip(expRows[i])))) issues.push('paper question rows/positions/keys differ');
    if (!dbRows.every((r, i) => r.position === i + 1)) issues.push('positions not contiguous');
    let vBad = 0, wd = 0, keyBad = 0, optBad = 0;
    for (const r of expRows) {
      if (!r.question_version_id) { wd++; continue; }
      const ev = vers.get(r.question_version_id); const dv = (await q(`select to_jsonb(x) j from question_versions x where id=$1::uuid`, [r.question_version_id]))[0]?.j;
      if (!dv || sV(dv) !== sV(strip(ev))) vBad++;
      if (dv) { const ids = new Set(dv.options.map((o) => o.id)); if (!dv.correct_option_ids.every((c) => ids.has(c))) keyBad++; if (dv.status !== 'published') optBad++; }
    }
    if (vBad) issues.push(`${vBad} pinned question versions differ/missing (stem/options/answers/explanation)`);
    if (keyBad) issues.push(`${keyBad} answer keys outside options`); if (optBad) issues.push(`${optBad} pinned versions not published`);
    const kh = (await q(`select count(*)::int n from exam_paper_key_history where paper_id=$1::uuid`, [p.id]))[0].n; const khExp = REC('exam_paper_key_history').filter((k) => k.paper_id === p.id).length;
    if (kh !== khExp) issues.push(`key history ${kh} != ${khExp}`);
    const att = Number((await q(`select count(*)::int n from exam_attempts where paper_id=$1::uuid`, [p.id]))[0].n); const attExp = REC('exam_attempts').filter((a) => a.paper_id === p.id).length;
    if (att !== attExp) issues.push(`attempts ${att} != ${attExp}`);
    const ex = (await q(`select (select count(*)::int from exam_question_tags t where t.exam_id=$1::uuid) tags`, [p.exam_id]))[0].tags; const exExp = REC('exam_question_tags').filter((t) => t.exam_id === p.exam_id).length;
    if (ex !== exExp) issues.push(`exam tags ${ex} != ${exExp}`);
    results.papers.push({ code: p.code, revision: p.revision, status: p.status, id: p.id, rows: dbRows.length, total: p.total_questions, withdrawn: wd, keyed: dbRows.length - wd, timer: p.practice_timer_seconds, frozen_at: p.frozen_at, ok: issues.length === 0, issues });
    if (issues.length) results.failures++;
    log(`paper ${p.code} r${p.revision} [${p.status}] ${issues.length ? 'FAIL ' + issues.join('; ') : 'PASS'}`);
  }
  // exam-level: blueprints, sections, section topics
  for (const t of ['exams', 'exam_blueprints', 'exam_sections', 'exam_section_topics']) { const e = results.tables[t]; check(`exam mapping table ${t} matches recovered`, e.ok, `(${e.actual} rows)`); }
  const published = papers.filter((p) => p.status === 'published').length, retired = papers.filter((p) => p.status === 'retired').length;
  const dbPub = Number((await q(`select count(*)::int n from exam_papers where status='published'`))[0].n), dbRet = Number((await q(`select count(*)::int n from exam_papers where status='retired'`))[0].n);
  check('papers: 8 published, 3 retired', dbPub === 8 && dbRet === 3 && published === 8 && retired === 3, `(published=${dbPub}, retired=${dbRet})`);
}

const total = await Promise.all(tables.map(count)); results.post = { rows: Object.fromEntries(tables.map((t, i) => [t, total[i]])), total: total.reduce((a, b) => a + b, 0) };
results.preTotal = Object.values(pre).reduce((a, b) => a + b, 0);
const expTotal = tables.reduce((a, t) => a + results.tables[t].expected, 0);
check('grand total rows = pre + new (rate_limits skipped)', results.post.total === expTotal, `(${results.preTotal} -> ${results.post.total}, expected ${expTotal})`);
await db.close();
fs.writeFileSync(path.join(workRoot, `${label}.results.json`), JSON.stringify(results, null, 1));
log(`\n[${label}] DONE failures=${results.failures}`);
