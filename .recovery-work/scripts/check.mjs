// Referential-integrity checks on recovered (live) rows. Usage: node check.mjs <extractedDir>
import fs from 'node:fs';
const D = process.argv[2];
const live = (t) => fs.existsSync(`${D}/${t}.json`) ? JSON.parse(fs.readFileSync(`${D}/${t}.json`)).filter(r => r._vis?.state === 'live') : [];
const ids = (t) => new Set(live(t).map(r => r.id));
const U = ids('users');
// [table, column, referenced table]  (mapped from schema.ts column names)
const FK = [
  ['questions', 'live_version_id', 'question_versions'], ['questions', 'created_by', 'users'],
  ['question_versions', 'question_id', 'questions'], ['question_versions', 'topic_id', 'topics'], ['question_versions', 'created_by', 'users'], ['question_versions', 'reviewer_id', 'users'], ['question_versions', 'published_by', 'users'], ['question_versions', 'content_source_id', 'content_sources'],
  ['review_decisions', 'version_id', 'question_versions'], ['review_decisions', 'reviewer_id', 'users'],
  ['question_version_acts', 'version_id', 'question_versions'], ['question_version_acts', 'act_id', 'acts'],
  ['topics', 'subject_id', 'subjects'], ['topics', 'act_id', 'acts'],
  ['daily_tips', 'created_by', 'users'], ['daily_tips', 'updated_by', 'users'], ['daily_tips', 'reviewer_id', 'users'], ['daily_tips', 'published_by', 'users'],
  ['news_articles', 'created_by', 'users'], ['news_articles', 'reviewer_id', 'users'],
  ['import_jobs', 'created_by', 'users'], ['import_jobs', 'content_source_id', 'content_sources'],
  ['import_job_rows', 'job_id', 'import_jobs'], ['import_job_rows', 'question_id', 'questions'], ['import_row_problems', 'job_id', 'import_jobs'],
  ['quiz_sessions', 'user_id', 'users'], ['quiz_session_questions', 'session_id', 'quiz_sessions'], ['quiz_session_questions', 'question_version_id', 'question_versions'], ['quiz_session_topics', 'session_id', 'quiz_sessions'], ['quiz_session_topics', 'topic_id', 'topics'],
  ['refresh_tokens', 'user_id', 'users'], ['coin_ledger', 'user_id', 'users'], ['energy_ledger', 'user_id', 'users'], ['learner_settings', 'user_id', 'users'], ['app_opens', 'user_id', 'users'], ['chat_usage', 'user_id', 'users'],
  ['exam_blueprints', 'exam_id', 'exams'], ['exam_sections', 'blueprint_id', 'exam_blueprints'], ['exam_section_topics', 'section_id', 'exam_sections'], ['exam_section_topics', 'topic_id', 'topics'],
  ['exam_question_tags', 'question_id', 'questions'], ['exam_question_tags', 'exam_id', 'exams'],
  ['exam_papers', 'exam_id', 'exams'], ['exam_papers', 'blueprint_id', 'exam_blueprints'], ['exam_paper_questions', 'paper_id', 'exam_papers'], ['exam_paper_questions', 'question_id', 'questions'], ['exam_paper_questions', 'question_version_id', 'question_versions'],
  ['exam_paper_key_history', 'paper_id', 'exam_papers'], ['exam_paper_key_history', 'paper_question_id', 'exam_paper_questions'],
  ['exam_attempts', 'user_id', 'users'], ['exam_attempts', 'paper_id', 'exam_papers'], ['exam_attempt_questions', 'attempt_id', 'exam_attempts'], ['exam_attempt_questions', 'question_version_id', 'question_versions'],
  ['legal_chunks', 'document_id', 'legal_documents'],
];
const cache = {}; const idsOf = (t) => (cache[t] ??= ids(t));
const out = []; let bad = 0;
for (const [t, c, rt] of FK) {
  const rows = live(t); if (!rows.length) continue;
  const ref = idsOf(rt); let orphan = 0, nonnull = 0; const ex = [];
  for (const r of rows) { const v = r[c]; if (v === null || v === undefined) continue; nonnull++; if (!ref.has(v)) { orphan++; if (ex.length < 3) ex.push(v); } }
  if (orphan) bad++;
  out.push({ fk: `${t}.${c} -> ${rt}`, checked: nonnull, orphans: orphan, examples: ex });
}
// uniqueness of ids (duplicate live versions = broken visibility)
const dups = [];
for (const f of fs.readdirSync(D)) { if (f.startsWith('_')) continue; const t = f.replace('.json', ''); const rows = live(t); if (!rows.length || rows[0].id === undefined) continue; const seen = new Set(); let d = 0; for (const r of rows) { if (seen.has(r.id)) d++; seen.add(r.id); } if (d) dups.push({ table: t, duplicateLiveIds: d }); }
// questions <-> versions: live_version must belong to the question
let mism = 0; const qv = new Map(live('question_versions').map(v => [v.id, v]));
for (const q of live('questions')) { const v = qv.get(q.live_version_id); if (v && v.question_id !== q.id) mism++; }
const res = { fkChecks: out, fkWithOrphans: bad, duplicateLiveIds: dups, questionLiveVersionMismatch: mism };
fs.writeFileSync(`${D}/_integrity.json`, JSON.stringify(res, null, 1));
console.log(`FK checks: ${out.length}, with orphans: ${bad}`); for (const o of out.filter(o => o.orphans)) console.log(' ORPHANS', o.fk, o.orphans, '/', o.checked, o.examples.join(','));
console.log('duplicate live ids:', JSON.stringify(dups)); console.log('question.live_version mismatches:', mism);
