# Restoration plan (read-only audit; nothing has been restored)

Audit date: 2026-11-22. Sources: `.recovery-work/recovered/*.json`, `diff/*.json`, `REPORT.md`, repo `backend/drizzle`. The live DB (`backend/.data/pglite`) was only read, via a scratch copy.

**Live DB check:** a copy of the live DB, extracted with the same decoder, is identical to the Nov 19 backup in all 48 tables. Nothing newer exists in live, so no recovered row can be older than a live row.

---

## 1. Bottom line

| question | answer |
|---|---|
| Can every previously published exam paper be restored to its Nov 22 state? | **Yes.** 11 papers existed (8 published, 3 retired). All paper, question, key, tag, blueprint and import rows are **high confidence** (read from heap files at the 13:04:55 IST checkpoint). No paper depends on a WAL-reconstructed row. |
| Anything missing? | Only what was written after 13:12:46 IST on Nov 22 (not in any file), and page checksums are unverified (see section 11). |
| What blocks a restore today? | The live DB is two migrations behind (0023, 0024). Both are additive and must be applied first; 7 recovered rows use the enum value 0024 creates. |

---

## 2. Exam papers that existed or changed between Nov 19 and Nov 22

Live (Nov 19) had 4 papers, none published. The recovered state has 11.

| # | code / revision | live (Nov 19) | recovered (Nov 22) | questions | change | confidence |
|---|---|---|---|---|---|---|
| 1 | aibe-18-set-a r1 | retired | retired | 100 | `practice_timer_seconds` column only | high |
| 2 | aibe-18-set-a r2 | draft | **retired** (frozen 11-19 04:08 UTC, timer 10800) | 100 | status, frozen_at, updated_at, timer | high |
| 3 | aibe-18-set-a r3 | not in live | **published** (11-19 04:47) | 100 | new | high |
| 4 | aibe-19-set-a r1 | draft | **published** (11-19 04:59) | 100 (88 keyed, 11 withdrawn, 1 multi-accepted) | status, frozen_at, updated_at, timer | high |
| 5 | aibe-20-set-a r1 | draft | **published** (11-19 04:57) | 100 (92 keyed, 6 withdrawn, 2 multi-accepted) | status, frozen_at, updated_at, timer | high |
| 6 | aibe-21-set-a r1 | not in live | **published** (11-19 06:34) | 100 | new | high |
| 7 | clat-2026-ug-set-a r1 | not in live | **published** (11-20 08:52) | 120 (119 keyed, 1 withdrawn) | new | high |
| 8 | clat-ug-2023 r1 | not in live | **published** (11-20 09:46) | 150 (149 keyed, 1 withdrawn) | new | high |
| 9 | clat-2025-ug-set-a r1 | not in live | retired (11-20 09:51) | 120 | new | high |
| 10 | clat-2025-ug-set-a r2 | not in live | **published** (11-20 10:00) | 120 (116 keyed, 4 withdrawn) | new | high |
| 11 | clat-2024-ug-set-b r1 | not in live | **published** (11-20 09:56) | 120 | new | high |

Published at Nov 22: **8** (aibe-18 r3, aibe-19, aibe-20, aibe-21, clat-2026, clat-ug-2023, clat-2025 r2, clat-2024 set B). Retired: 3. `practice_timer_seconds` is 10800 (AIBE) or 7200 (CLAT) on every published paper; null on 2 retired ones.

## 3. Verification of paper records (all from the recovered data)

Checked for each of the 11 papers:

- **Question rows:** `total_questions` equals the number of `exam_paper_questions` rows in every paper (100/100/120/150 as listed).
- **Ordering:** positions are contiguous 1..N, with no gaps and no duplicates, in all 11 papers (unique index `exam_paper_questions_position_idx` is satisfied).
- **Withdrawn rows:** the withdrawn paper rows (AIBE-19: 11, AIBE-20: 6, CLAT 2026: 1, CLAT 2023: 1, CLAT 2025 r1 and r2: 4 each) have no question or version (null), as designed. The "missing version" count equals the withdrawn count in every paper. (Only 7 import rows carry the `withdrawn` outcome, because the AIBE papers were imported before that outcome existed.)
- **Pinned versions:** every non-withdrawn row points to a version that exists, is `published`, belongs to the same question, and is that question's current live version.
- **Options and keys:** all 1,159 versions have `correct_option_ids` and `alternate_correct_option_ids` inside their own option ids. The 6 key-history rows reference existing options. `option_order` is null everywhere (no custom option shuffling was stored), so option order is the stored order in each version's `options` array.
- **Exam mappings:** 3 exams (AIBE; two CLAT/law-entrance exams) and 2 blueprints (`aibe-standard` v1, `clat-ug-2026` v1, both published, `is_current = false`, `config_status = unverified`, as recorded). Every paper has `blueprint_id` null, as recorded. 1,051 `exam_question_tags` (AIBE 398, CLAT 653) all resolve to a question and an exam.
- **Attempts:** 17 attempts (13 submitted, 3 in progress, 1 expired), all practice mode, all pointing to existing papers; no timed attempt lacks a deadline, so the CHECK constraint changed by 0023 is satisfied.
- **Where each paper's questions come from:** AIBE-18 (r1, r2, r3), AIBE-19, AIBE-20: all 100/94/88 questions already exist in live. AIBE-19 needs 1 question version that is a draft in live and published in the recovered state. AIBE-21 and all CLAT papers use new questions (new: 100, 119, 149, 120, 116).

## 4. Questions, versions, review decisions, imports

| item | live | recovered | new | modified |
|---|--:|--:|--:|--:|
| questions | 406 | 1,159 | 753 | 4 |
| question_versions | 406 | 1,159 | 753 | 4 |
| review_decisions | 294 | 1,051 | 757 | 0 |
| import_jobs | 3 | 9 | 6 | 0 |
| import_job_rows | 298 | 1,058 | 760 | 0 |
| import_row_problems | 298 | 624 | 326 | 0 |

- All 1,159 versions are `published`, one version per question; 1,051 questions are exam-only, 108 are the original bundled bank (no review decision, same as live). Review decisions: 1,051, all `approved` (= 1,159 - 108).
- The 4 modified questions: in live they are drafts with no live version; recovered they are published (version draft → published, `live_version_id` set). Their versions also gain reviewer, approval and publish fields (and one explanation edit).
- Integrity: no duplicate `external_ref`, no identical stem+options pairs, no orphan foreign keys (52 + 24 further relations checked).
- Import jobs, including the 6 new: AIBE-21 (Nov 19), and five Excel imports on Nov 20 (UG 2026; CLAT 2023 twice, `..._Import.xlsx` then `..._with_passages_v2.xlsx`; CLAT 2025 Set A; CLAT 2024 Set B). The two CLAT 2023 jobs each created 149 questions, so there are 149 extra exam-only questions from the first CLAT 2023 import that no published paper uses. This is how the data was; it is restored as is (not deduplicated).
- 7 import rows have outcome `withdrawn`; this needs migration 0024.

## 5. Confidence classes

| class | rows | tables |
|---|--:|---|
| high | 15,825 | everything not listed below |
| medium (rebuilt from WAL redo) | 22 | audit_log 14, daily_tips 3, refresh_tokens 3, rate_limits 2 |
| partial | 1,852 | legal_chunks (embedding vector not decoded; text identical to live; not restored) |

No exam, question, import, review or paper row is medium or partial.

## 6. Migration compatibility with the live DB

- Live applied migrations: 24 rows = journal 0000-0022 + one non-journal row (id 34, 2026-11-12, legal library). All 23 hashes match the repo files.
- Recovered applied migrations: 26 rows = 0000-0024 + id 34.
- **Missing in live: 0023 and 0024.**
  - `0023_paper_practice_timer`: drops and re-adds `exam_attempts_deadline_check`, adds `exam_papers.practice_timer_seconds`. Needed before any paper row is restored (the recovered rows carry that column).
  - `0024_import_withdrawn_outcome`: `ALTER TYPE import_outcome ADD VALUE 'withdrawn'`. Needed before 7 import rows. It must be committed before they are inserted (PostgreSQL rule); drizzle runs it as its own migration, so this holds.
- Column check: after 0024, every recovered column exists in the repo schema (0024 snapshot) for all drizzle-managed tables. Two harmless items: `quiz_sessions` JSON carries 8 junk keys named `........pg.dropped.N........` (always null; ignored by the load), and the 3 legal tables are not in drizzle's snapshot (unchanged, not restored).
- Caveat: `drizzle/0019`-`0024` SQL files, snapshots and the modified `_journal.json` are **uncommitted** in git. They must stay in the working tree (or be committed) for the migration to run; commit them before restoring.
- Applying them to a copy first is required (step 0b below).

## 7. Restoration plan, foreign-key dependency order

Nothing below has been run.

**Step 0: preparation (no data change)**
- 0a. Stop every process that can open `backend/.data/pglite` (the `nest start --watch` terminal and any `node.exe` running the backend). Concurrent opens are the likely cause of the original corruption.
- 0b. Dry run on a copy: copy `.data/pglite` to a scratch dir, run steps 1-3 there, verify (section 10), discard. Only then repeat on the live dir.
- 0c. Back up live: `cp -r .data/pglite .data/pglite-backup-20261122-pre-restore` (keeps the current Nov 19 state).
- 0d. Commit or keep the uncommitted migration files (section 6).

**Step 1: migrations.** Apply 0023, then 0024 with the repo's drizzle migrator (same code as `openDb`), against the dry-run copy and then live. Expect `__drizzle_migrations` 24 → 26 rows.

**Step 2: data, in one transaction per tier, in this order.** Load method: `INSERT INTO t SELECT * FROM jsonb_populate_recordset(NULL::t, $json)` from `diff/<table>.json` `.new` (ids, timestamps, enums, arrays and jsonb convert by type, and `_`-prefixed metadata keys are ignored). Each insert uses `ON CONFLICT DO NOTHING`, and the transaction aborts if inserted rows differ from the expected count.

| tier | tables (new rows) | notes |
|---|---|---|
| A | users (6) | UPDATE 1 existing user (password_hash, updated_at) |
| B | subjects (1), acts (0), content_sources (1), exams (2) | |
| C | topics (5), exam_blueprints (1) | |
| D | questions (753) | insert with `live_version_id = NULL` (circular FK with question_versions, not deferrable) |
| E | question_versions (753) | UPDATE the 4 draft versions to their published state |
| F | UPDATE questions SET live_version_id (753 new + 4 modified), review_decisions (757) | |
| G | import_jobs (6), import_job_rows (760), import_row_problems (326) | `withdrawn` rows need 0024 |
| H | exam_question_tags (753), exam_sections (5), exam_section_topics (5) | |
| I | exam_papers: UPDATE 4 existing, INSERT 7, in `created_at` order; then exam_paper_questions (1,030), exam_paper_key_history (2) | no paper is published by a workflow; rows are inserted in their recorded state, so no CMS publish action or notification is triggered |
| J | daily_tips (UPDATE 3, section 9), news_articles (0) | |
| K | learner data: learner_settings (6), league_memberships (1), quiz_sessions (5), quiz_session_topics (2), quiz_session_questions (39), coin_ledger (8), energy_ledger (5), chat_usage (1), app_opens (9), duel_matches (1) | |
| L | exam_attempts (16), exam_attempt_questions (1,690) | |
| M | refresh_tokens (86 new + 1 UPDATE `revoked_at`) | the revocation must be restored, or a revoked session becomes valid again |
| N | audit_log (3,472) | last, includes the 14 medium rows |

Skipped by design: `rate_limits` (ephemeral throttle counters; recovered 7 rows vs live 9, with 3 new, 4 changed, 5 removed because they expired), `legal_*` (unchanged; embeddings undecoded).

**Step 3: UPDATE rules** (17 modified rows: 3 daily_tips, 4 exam_papers, 4 question_versions, 4 questions, 1 user, 1 refresh token). Each UPDATE sets only the `changedFields` from `diff/<table>.json` and has two guards: the live row must still equal the recorded "before" state, and the recovered `updated_at` must be >= the live one. A row failing a guard is skipped and listed, not overwritten.

## 8. ID conflicts, duplicates, and rows that must not overwrite live data

- **New-row ids:** by construction none exist in live (the diff keys on primary key). The unique indexes that matter (`questions.external_ref`, `users.email`, `exam_papers (exam, code, revision)`, `import_jobs.file_sha256`, `exam_blueprints (code, version)`, `daily_tips_live_day_idx`, `exam_papers_published_idx`, `exam_attempts_open_idx`) are already satisfied inside the recovered set, and live is a strict subset of it, so no conflict is expected. The dry run proves it.
- **Published-paper index:** at most one published paper per (exam, code). Live has none published, so applying the 4 UPDATEs before the 7 INSERTs cannot collide.
- **Must not overwrite:** (1) any live row that changed after the audit (guard in step 3); (2) `rate_limits` (skipped); (3) nothing else is newer, because live equals the Nov 19 backup.
- **Duplicates:** none among recovered ids; 149 unused exam-only CLAT 2023 questions are a data-history artifact, not a duplicate (different text).
- **Sensitive data:** `users.password_hash` and `refresh_tokens.token_hash` are restored as stored; they are not printed in any report.

## 9. The three recovered daily-tip publications (medium confidence)

| tip (id prefix) | publish_date | before (live) | after |
|---|---|---|---|
| 01a1e805-6933 | 2027-01-27 | draft | published 07:38:53 UTC |
| 01a1e805-6946 | 2027-02-23 | draft | published 07:41:33 UTC |
| 01a1e805-6942 | 2027-02-16 | draft | published 07:42:46 UTC |

- Source: they were written after the last checkpoint, so they exist only in the WAL; I replayed them onto a copy. They are corroborated: audit entries `daily_tip.updated / submitted / approved / published` exist for each, with timestamps within 15 ms of `approved_at` / `published_at`.
- Restore method: 3 guarded UPDATEs by primary key, changing only `status`, `last_verified_on` (→ 2026-11-22), `updated_by`, `reviewer_id`, `approved_at`, `published_by`, `published_at`, `updated_at`. Title, summary, explanation, reference, source URL and category are unchanged from live.
- Uniqueness: publish dates are in 2027 and collide with none of the 8 other published tips (one live tip per day and language holds). They will not show on the Home screen until their dates.
- The 13 matching audit rows (4 updated, 3 submitted, 3 approved, 3 published) plus 1 `auth.signed_in` come with the audit_log load, with original timestamps and ids.
- Residual risk: medium = rebuilt by my replay. The audit-log cross-check is the independent evidence. After the dry run, the 3 rows can be compared to the audit `data.fields` lists and the numbers above.

## 10. Expected row counts

| step | tables | rows |
|---|--:|--:|
| live now (= Nov 19) | 48 | 7,187 |
| + new rows (excl. rate_limits) | | +10,514 |
| = after restore | 48 | **17,701** |
| recovered total (incl. rate_limits 7 vs live 9) | | 17,699 |
| UPDATEs (no count change) | | 17 |

Per table (order = load order). Columns: live → new → modified → expected after; last column is the recovered confidence split high/medium/partial.

| # | table | live | new | modified | after | conf (h/m/p) |
|--:|---|--:|--:|--:|--:|---|
| 1 | users | 51 | +6 | 1 | 57 | 57/0/0 |
| 2 | subjects | 7 | +1 | 0 | 8 | 8/0/0 |
| 3 | acts | 6 | +0 | 0 | 6 | 6/0/0 |
| 4 | content_sources | 3 | +1 | 0 | 4 | 4/0/0 |
| 5 | exams | 1 | +2 | 0 | 3 | 3/0/0 |
| 6 | topics | 29 | +5 | 0 | 34 | 34/0/0 |
| 7 | exam_blueprints | 1 | +1 | 0 | 2 | 2/0/0 |
| 8 | questions | 406 | +753 | 4 | 1159 | 1159/0/0 |
| 9 | question_versions | 406 | +753 | 4 | 1159 | 1159/0/0 |
| 10 | review_decisions | 294 | +757 | 0 | 1051 | 1051/0/0 |
| 11 | question_version_acts | 0 | +0 | 0 | 0 | 0/0/0 |
| 12 | import_jobs | 3 | +6 | 0 | 9 | 9/0/0 |
| 13 | import_job_rows | 298 | +760 | 0 | 1058 | 1058/0/0 |
| 14 | import_row_problems | 298 | +326 | 0 | 624 | 624/0/0 |
| 15 | exam_question_tags | 298 | +753 | 0 | 1051 | 1051/0/0 |
| 16 | exam_sections | 19 | +5 | 0 | 24 | 24/0/0 |
| 17 | exam_section_topics | 24 | +5 | 0 | 29 | 29/0/0 |
| 18 | exam_papers | 4 | +7 | 4 | 11 | 11/0/0 |
| 19 | exam_paper_questions | 200 | +1030 | 0 | 1230 | 1230/0/0 |
| 20 | exam_paper_key_history | 4 | +2 | 0 | 6 | 6/0/0 |
| 21 | daily_tips | 101 | +0 | 3 | 101 | 98/3/0 |
| 22 | news_articles | 15 | +0 | 0 | 15 | 15/0/0 |
| 23 | news_images | 0 | +0 | 0 | 0 | 0/0/0 |
| 24 | content_reports | 0 | +0 | 0 | 0 | 0/0/0 |
| 25 | question_bookmarks | 0 | +0 | 0 | 0 | 0/0/0 |
| 26 | learner_settings | 46 | +6 | 0 | 52 | 52/0/0 |
| 27 | premium_memberships | 0 | +0 | 0 | 0 | 0/0/0 |
| 28 | league_cohorts | 1 | +0 | 0 | 1 | 1/0/0 |
| 29 | league_memberships | 3 | +1 | 0 | 4 | 4/0/0 |
| 30 | quiz_sessions | 21 | +5 | 0 | 26 | 26/0/0 |
| 31 | quiz_session_topics | 19 | +2 | 0 | 21 | 21/0/0 |
| 32 | quiz_session_questions | 124 | +39 | 0 | 163 | 163/0/0 |
| 33 | coin_ledger | 60 | +8 | 0 | 68 | 68/0/0 |
| 34 | energy_ledger | 28 | +5 | 0 | 33 | 33/0/0 |
| 35 | chest_openings | 2 | +0 | 0 | 2 | 2/0/0 |
| 36 | chat_usage | 19 | +1 | 0 | 20 | 20/0/0 |
| 37 | app_opens | 49 | +9 | 0 | 58 | 58/0/0 |
| 38 | duel_matches | 0 | +1 | 0 | 1 | 1/0/0 |
| 39 | exam_attempts | 1 | +16 | 0 | 17 | 17/0/0 |
| 40 | exam_attempt_questions | 100 | +1690 | 0 | 1790 | 1790/0/0 |
| 41 | refresh_tokens | 206 | +86 | 1 | 292 | 289/3/0 |
| 42 | password_reset_codes | 0 | +0 | 0 | 0 | 0/0/0 |
| 43 | staff_setup_tokens | 0 | +0 | 0 | 0 | 0/0/0 |
| 44 | audit_log | 2169 | +3472 | 0 | 5641 | 5627/14/0 |
| 45 | rate_limits | 9 | skipped (3) | skipped (4) | 9 | 5/2/0 |
| 46 | legal_documents | 10 | +0 | 0 | 10 | 10/0/0 |
| 47 | legal_chunks | 1852 | +0 | 0 | 1852 | 0/0/1852 |
| 48 | legal_sync_runs | 0 | +0 | 0 | 0 | 0/0/0 |

**Post-restore verification (run on the dry-run copy, then on live):** (1) count every table and match the "after" column exactly; (2) re-run the extractor on the restored DB and diff it against `recovered/` (must be identical except the skipped `rate_limits` and `legal_*`); (3) check the 8 published papers (status, `frozen_at`, `practice_timer_seconds`, paper-question rows of 100 (AIBE-18 r3, 19, 20, 21), 120 (CLAT 2026, 2025 r2, 2024 B) and 150 (CLAT 2023), positions 1..N); (4) foreign-key and unique-index validity (no errors on load); (5) the 3 daily tips against section 9; (6) start the backend once and open the CMS.

## 11. Residual risks

1. Anything written after 13:12:46 IST on Nov 22 is not recoverable.
2. Page checksums were not verified. All pages and all rows decoded, and referential integrity is perfect, but a damaged page that still looks valid cannot be ruled out. The dry-run verification in section 10 (step 2) covers decoding, not disk integrity.
3. The 22 medium rows depend on my WAL replay (corroborated by the audit log for the daily tips; the 14 audit rows are the corroboration itself).
4. Restoring writes rows directly, not through the CMS workflows. That is intended (exact state), but means no side effects (e.g. no new audit rows for the restore itself).
5. The 3 in-progress attempts return as in progress, and the 86 refresh tokens return; users with those tokens will be signed in again.

## 12. Approval needed

Nothing runs until you say so. Suggested approval: "Run the dry run on a copy and show me the verification", which changes nothing in live. A separate "Restore live" approval would follow.
