#!/usr/bin/env node
/**
 * Prepares Daily Tips on a Nyaya API (staging, or local) through its normal
 * editor endpoints, so every change is an audited API call made as a real
 * signed-in editor. It never verifies, submits, approves or publishes a tip,
 * and never sends a verification date.
 *
 *   node tool/daily_tips_sync.mjs import  [--apply] [--with-schedule]
 *   node tool/daily_tips_sync.mjs links   [--apply]
 *
 * Environment:
 *   NYAYA_API_URL   e.g. https://staging-api.deepwebstudio.dev
 *   NYAYA_EMAIL     an account with the content_editor role
 *   NYAYA_PASSWORD  its password (read from the environment, never printed)
 *
 * Without --apply nothing is changed: the script only says what it would do.
 *
 * import          Creates, as DRAFTS, the tips in docs/daily-tips-draft that the
 *                 server does not have yet (matched by title). --with-schedule also
 *                 sets "Show on" from schedule_plan.json; a show-on day is not a
 *                 verification date.
 * links           Reads docs/daily-tips-draft/verification_worksheet.csv and, for each
 *                 row where a human filled `exact_source_url_checked`, saves that link
 *                 as the tip's source link (drafts only). The suggested links are not
 *                 used: only a link a person confirmed.
 */
import { readFileSync } from 'node:fs';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';

const root = join(dirname(fileURLToPath(import.meta.url)), '..');
const draftDir = join(root, 'docs', 'daily-tips-draft');
const [cmd, ...flags] = process.argv.slice(2);
const apply = flags.includes('--apply');

const API = (process.env.NYAYA_API_URL ?? '').replace(/\/+$/, '');
const EMAIL = process.env.NYAYA_EMAIL;
const PASSWORD = process.env.NYAYA_PASSWORD;
if (!['import', 'links'].includes(cmd ?? '') || !API || !EMAIL || !PASSWORD) {
  console.error('Usage: NYAYA_API_URL=… NYAYA_EMAIL=… NYAYA_PASSWORD=… node tool/daily_tips_sync.mjs <import|links> [--apply]');
  process.exit(2);
}

/** Minimal CSV reader (quoted fields, doubled quotes, newlines inside quotes). */
function parseCsv(text) {
  const rows = [];
  let row = [];
  let field = '';
  let quoted = false;
  for (let i = 0; i < text.length; i++) {
    const c = text[i];
    if (quoted) {
      if (c === '"' && text[i + 1] === '"') { field += '"'; i++; }
      else if (c === '"') quoted = false;
      else field += c;
    } else if (c === '"') quoted = true;
    else if (c === ',') { row.push(field); field = ''; }
    else if (c === '\n' || c === '\r') {
      if (c === '\r' && text[i + 1] === '\n') i++;
      row.push(field); field = '';
      if (row.some((x) => x !== '')) rows.push(row);
      row = [];
    } else field += c;
  }
  if (field !== '' || row.length) { row.push(field); rows.push(row); }
  const [head, ...body] = rows;
  return body.map((r) => Object.fromEntries(head.map((h, i) => [h.replace(/^﻿/, ''), r[i] ?? ''])));
}

async function call(method, path, token, body) {
  const res = await fetch(`${API}${path}`, {
    method,
    headers: { 'content-type': 'application/json', ...(token ? { authorization: `Bearer ${token}` } : {}) },
    body: body ? JSON.stringify(body) : undefined,
  });
  const text = await res.text();
  let json = null;
  try { json = text ? JSON.parse(text) : null; } catch { /* not JSON */ }
  if (!res.ok) throw new Error(`${method} ${path} -> ${res.status} ${json?.message ?? text.slice(0, 200)}`);
  return json;
}

async function allTips(token) {
  const tips = [];
  let cursor;
  do {
    const q = new URLSearchParams({ limit: '100', ...(cursor ? { cursor } : {}) });
    const page = await call('GET', `/v1/editor/daily-tips?${q}`, token);
    tips.push(...page.items);
    cursor = page.next_cursor;
  } while (cursor);
  return tips;
}

const isExact = (u) => {
  try {
    const x = new URL(u);
    return x.protocol === 'https:' && (x.pathname.replace(/\/+$/, '') !== '' || x.search !== '');
  } catch { return false; }
};

const session = await call('POST', '/v1/auth/session', null, { email: EMAIL, password: PASSWORD });
const token = session.access_token;
console.log(`${apply ? 'APPLYING' : 'DRY RUN (add --apply to change anything)'} against ${API}`);
const existing = await allTips(token);
const byTitle = new Map(existing.map((t) => [t.title.trim().toLowerCase(), t]));
console.log(`The server has ${existing.length} tips.`);

if (cmd === 'import') {
  const tips = JSON.parse(readFileSync(join(draftDir, 'daily_tips_draft.json'), 'utf8')).tips;
  const plan = new Map(JSON.parse(readFileSync(join(draftDir, 'schedule_plan.json'), 'utf8')).map((p) => [p.external_id, p.show_on]));
  let created = 0;
  let skipped = 0;
  for (const { external_id, ...tip } of tips) {
    if (byTitle.has(tip.title.trim().toLowerCase())) { skipped++; continue; }
    const body = { ...tip, last_verified_on: null, publish_date: flags.includes('--with-schedule') ? (plan.get(external_id) ?? null) : null };
    console.log(`  ${apply ? 'create' : 'would create'} draft ${external_id}: ${tip.title}`);
    if (apply) await call('POST', '/v1/editor/daily-tips', token, body);
    created++;
  }
  console.log(`${created} ${apply ? 'created' : 'to create'} as drafts, ${skipped} already on the server.`);
} else {
  const rows = parseCsv(readFileSync(join(draftDir, 'verification_worksheet.csv'), 'utf8'));
  let changed = 0;
  let waiting = 0;
  for (const r of rows) {
    const link = r.exact_source_url_checked.trim();
    if (!link) { waiting++; continue; }
    const tip = byTitle.get(r.title.trim().toLowerCase());
    if (!tip) { console.log(`  skip ${r.tip_id}: not on the server (run import first)`); continue; }
    if (!isExact(link)) { console.log(`  skip ${r.tip_id}: not an exact https link to the provision`); continue; }
    if (!['draft', 'changes_requested'].includes(tip.status)) { console.log(`  skip ${r.tip_id}: is ${tip.status}, only drafts can be edited`); continue; }
    if (tip.source_url === link) continue;
    console.log(`  ${apply ? 'set' : 'would set'} source link on ${r.tip_id}`);
    if (apply) await call('PATCH', `/v1/editor/daily-tips/${tip.id}`, token, { source_url: link });
    changed++;
  }
  console.log(`${changed} ${apply ? 'updated' : 'to update'}; ${waiting} rows have no confirmed link yet.`);
}
console.log('No tip was verified, submitted, approved or published.');
