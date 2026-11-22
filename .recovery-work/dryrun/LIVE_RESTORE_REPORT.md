# Live restoration report

Completed 2026-11-22. Procedure: the tested Scenario B load (`liverestore.mjs`), applied to the live database as one transaction (all tiers A-N, with per-table count assertions before commit). Migrations 0023/0024 were already applied and were not re-run.

## Result: SUCCESS, 0 failures

- Backup before restore: `backend/.data/pglite-backup-20261122-pre-restore` (sha256 of all 1,236 files identical to the live directory at that moment, and still identical afterwards).
- Live rows: **7196 -> 17710** (expected 17,710 = 7,196 + 10,514 new).
- Post-restore activity preserved: the 13:46 IST user, 3 refresh tokens, 2 audit events, coin-ledger, app-open and learner-settings rows are present and unchanged (independently confirmed by decoding the restored files: 0 pre-restore rows lost or changed, other than the 17 intended modifications).
- 24/24 checks PASS, 11/11 papers PASS, 48/48 tables PASS.

## Exam papers (live)

| paper | status | rows / total | keyed + withdrawn | practice timer (s) | frozen_at | result |
|---|---|--:|--:|--:|---|---|
| aibe-18-set-a r1 | retired | 100/100 | 100 + 0 | - | 2026-11-19T03:04 | PASS |
| aibe-19-set-a r1 | published | 100/100 | 89 + 11 | 10800 | 2026-11-19T04:59 | PASS |
| aibe-20-set-a r1 | published | 100/100 | 94 + 6 | 10800 | 2026-11-19T04:57 | PASS |
| aibe-18-set-a r2 | retired | 100/100 | 100 + 0 | 10800 | 2026-11-19T04:08 | PASS |
| aibe-18-set-a r3 | published | 100/100 | 100 + 0 | 10800 | 2026-11-19T04:47 | PASS |
| aibe-21-set-a r1 | published | 100/100 | 100 + 0 | 10800 | 2026-11-19T06:34 | PASS |
| clat-2026-ug-set-a r1 | published | 120/120 | 119 + 1 | 7200 | 2026-11-20T08:52 | PASS |
| clat-ug-2023 r1 | published | 150/150 | 149 + 1 | 7200 | 2026-11-20T09:46 | PASS |
| clat-2025-ug-set-a r1 | retired | 120/120 | 116 + 4 | - | 2026-11-20T09:51 | PASS |
| clat-2024-ug-set-b r1 | published | 120/120 | 120 + 0 | 7200 | 2026-11-20T09:56 | PASS |
| clat-2025-ug-set-a r2 | published | 120/120 | 116 + 4 | 7200 | 2026-11-20T10:00 | PASS |

8 published, 3 retired, matching the Nov 22 state.

## Every table (live)

| table | before | expected | actual | inserted | updated | result |
|---|--:|--:|--:|--:|--:|---|
| acts | 6 | 6 | 6 | 0 | 0 | PASS |
| app_opens | 50 | 59 | 59 | 9 | 0 | PASS |
| audit_log | 2171 | 5643 | 5643 | 3472 | 0 | PASS |
| chat_usage | 19 | 20 | 20 | 1 | 0 | PASS |
| chest_openings | 2 | 2 | 2 | 0 | 0 | PASS |
| coin_ledger | 61 | 69 | 69 | 8 | 0 | PASS |
| content_reports | 0 | 0 | 0 | 0 | 0 | PASS |
| content_sources | 3 | 4 | 4 | 1 | 0 | PASS |
| daily_tips | 101 | 101 | 101 | 0 | 3 | PASS |
| duel_matches | 0 | 1 | 1 | 1 | 0 | PASS |
| energy_ledger | 28 | 33 | 33 | 5 | 0 | PASS |
| exam_attempt_questions | 100 | 1790 | 1790 | 1690 | 0 | PASS |
| exam_attempts | 1 | 17 | 17 | 16 | 0 | PASS |
| exam_blueprints | 1 | 2 | 2 | 1 | 0 | PASS |
| exam_paper_key_history | 4 | 6 | 6 | 2 | 0 | PASS |
| exam_paper_questions | 200 | 1230 | 1230 | 1030 | 0 | PASS |
| exam_papers | 4 | 11 | 11 | 7 | 4 | PASS |
| exam_question_tags | 298 | 1051 | 1051 | 753 | 0 | PASS |
| exam_section_topics | 24 | 29 | 29 | 5 | 0 | PASS |
| exam_sections | 19 | 24 | 24 | 5 | 0 | PASS |
| exams | 1 | 3 | 3 | 2 | 0 | PASS |
| import_job_rows | 298 | 1058 | 1058 | 760 | 0 | PASS |
| import_jobs | 3 | 9 | 9 | 6 | 0 | PASS |
| import_row_problems | 298 | 624 | 624 | 326 | 0 | PASS |
| league_cohorts | 1 | 1 | 1 | 0 | 0 | PASS |
| league_memberships | 3 | 4 | 4 | 1 | 0 | PASS |
| learner_settings | 47 | 53 | 53 | 6 | 0 | PASS |
| legal_chunks | 1852 | 1852 | 1852 | 0 | 0 | PASS |
| legal_documents | 10 | 10 | 10 | 0 | 0 | PASS |
| legal_sync_runs | 0 | 0 | 0 | 0 | 0 | PASS |
| news_articles | 15 | 15 | 15 | 0 | 0 | PASS |
| news_images | 0 | 0 | 0 | 0 | 0 | PASS |
| password_reset_codes | 0 | 0 | 0 | 0 | 0 | PASS |
| premium_memberships | 0 | 0 | 0 | 0 | 0 | PASS |
| question_bookmarks | 0 | 0 | 0 | 0 | 0 | PASS |
| question_version_acts | 0 | 0 | 0 | 0 | 0 | PASS |
| question_versions | 406 | 1159 | 1159 | 753 | 4 | PASS |
| questions | 406 | 1159 | 1159 | 753 | 757 | PASS |
| quiz_session_questions | 124 | 163 | 163 | 39 | 0 | PASS |
| quiz_session_topics | 19 | 21 | 21 | 2 | 0 | PASS |
| quiz_sessions | 21 | 26 | 26 | 5 | 0 | PASS |
| rate_limits | 9 | 9 | 9 | 0 | 0 | PASS |
| refresh_tokens | 209 | 295 | 295 | 86 | 1 | PASS |
| review_decisions | 294 | 1051 | 1051 | 757 | 0 | PASS |
| staff_setup_tokens | 0 | 0 | 0 | 0 | 0 | PASS |
| subjects | 7 | 8 | 8 | 1 | 0 | PASS |
| topics | 29 | 34 | 34 | 5 | 0 | PASS |
| users | 52 | 58 | 58 | 6 | 1 | PASS |

Not restored by design: `rate_limits` (ephemeral), `legal_*` (unchanged).

## Checks

- PASS migrations already applied (26), not re-run `(26)`
- PASS foreign keys: 90 constraints, orphans `(0 constraints with orphans, 0 not validated)`
- PASS indexes: all valid (unique indexes enforce no duplicate ids) `[]`
- PASS duplicate ids across all id tables `(0)`
- PASS circular FK: no question left without live_version_id `(0)`
- PASS circular FK: every live_version belongs to its question `(0)`
- PASS refresh token revocation restored (previously live=active) `(token 01a1f1da: revoked=true; revoked tokens recovered=190, in db=191)`
- PASS no recovered-revoked token is active `(0)`
- PASS daily tip 01a1e805-6942 published 2027-02-16 `(status=published, published_at=2026-11-22T07:42:46.215Z, audit events=5)`
- PASS daily tip 01a1e805-6933 published 2027-01-27 `(status=published, published_at=2026-11-22T07:38:53.470Z, audit events=5)`
- PASS daily tip 01a1e805-6946 published 2027-02-23 `(status=published, published_at=2026-11-22T07:41:33.378Z, audit events=6)`
- PASS daily tips: one published tip per day+language `(0 collisions)`
- PASS daily tips: 11 published, 90 draft expected `(published=11)`
- PASS import rows with outcome 'withdrawn' restored (needs 0024) `(7)`
- PASS import_jobs = 9 (AIBE 18-21, UG 2026, CLAT 2023 x2, 2025, 2024) `(9)`
- PASS questions: 1159 total, 1051 exam-only `{"n":1159,"eo":1051}`
- PASS question_versions: 1159, all published `{"n":1159,"p":1159}`
- PASS review_decisions = 1051 (all approved) `(1051)`
- PASS exam mapping table exams matches recovered `(3 rows)`
- PASS exam mapping table exam_blueprints matches recovered `(2 rows)`
- PASS exam mapping table exam_sections matches recovered `(24 rows)`
- PASS exam mapping table exam_section_topics matches recovered `(29 rows)`
- PASS papers: 8 published, 3 retired `(published=8, retired=3)`
- PASS grand total rows = pre + new (rate_limits skipped) `(7196 -> 17710, expected 17710)`

Note: revoked tokens in db = 191 vs 190 recovered: the extra one is a token that was revoked in live after the restore (e.g. a sign-out); it was preserved.