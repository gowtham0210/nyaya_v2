# Dry-run report (scratch copies only; live DB untouched)

Run on 2026-11-22. Backend processes were stopped and verified before the run (no `node` backend process; ports 4000/5432/5174 belong to an unrelated Docker project). Both runs used the repo's own drizzle migrator and the recovery data; only copies under `.recovery-work/dryrun/work/` were opened.

## 1. Result

| scenario | starting database | rows before | rows after | failures |
|---|---|--:|--:|--:|
| **A** (as requested) | scratch copy of the Nov 19 backup `pglite-backup-20261119-pre-practice-timer` | 7187 | 17701 | **0** |
| **B** (extra) | scratch copy of the *current* live DB (has rows created after the restore) | 7196 | 17710 | **0** |

**Both dry runs completed with 0 failures.**

### Finding: the live DB is not the Nov 19 backup any more

- The backend was running against the live DB after my earlier restore. It auto-applied migrations 0023 and 0024 (live had 26 migrations when I copied it) and recorded new activity (about 13:46 IST): **1 user, 3 refresh tokens, 2 audit events, 1 coin-ledger row, 1 app-open, 1 learner-settings row**.
- None of those ids or the new email exist in the recovered data, so there is no conflict. Scenario B proves they are kept untouched and the 17,701-row recovery lands around them (7,196 + 10,514 = 17,710 = recovered 17,701 + 9 live-only rows).
- Consequence for the real restore: step 1 (migrations) is already done in live; the restore is steps 2-3 only.

## 2. Migrations (scenario A, which started at 24 applied)

- PASS migrations: 26 applied (0000-0024 + legal row) `(was 24, now 26)`
- PASS migration 0023: exam_papers.practice_timer_seconds exists `(applied by dry run)`
- PASS migration 0024: import_outcome has 'withdrawn' `(applied by dry run)`
- PASS migration 0023: deadline check constraint present `CHECK (((mode <> 'timed'::exam_attempt_mode) OR (deadline_at IS NOT NULL)))`
- Scenario B: already applied in the starting copy, and the migrator was a no-op (26 -> 26).

## 3. Load tiers (A and B)

| tier | A | B |
|---|---|---|
| migrations | PASS | PASS |
| A users | PASS | PASS |
| B subjects, acts, content_sources, exams | PASS | PASS |
| C topics, exam_blueprints | PASS | PASS |
| D questions (live_version_id NULL: circular FK) | PASS | PASS |
| E question_versions | PASS | PASS |
| F questions.live_version_id, review_decisions, version_acts | PASS | PASS |
| G import_jobs, import_job_rows, import_row_problems | PASS | PASS |
| H exam_question_tags, exam_sections, exam_section_topics | PASS | PASS |
| I exam_papers (update then insert), paper questions, key history | PASS | PASS |
| J daily_tips (3 guarded updates), news_articles | PASS | PASS |
| K learner data | PASS | PASS |
| L exam_attempts, exam_attempt_questions | PASS | PASS |
| M refresh_tokens (new + revocation update), reset/setup tokens | PASS | PASS |
| N audit_log | PASS | PASS |

## 4. Exam papers (all 11, A / B)

| paper | status | rows / total | keyed + withdrawn | timer (s) | A | B | issues |
|---|---|--:|--:|--:|---|---|---|
| aibe-18-set-a r1 | retired | 100/100 | 100 + 0 | - | PASS | PASS | - |
| aibe-19-set-a r1 | published | 100/100 | 89 + 11 | 10800 | PASS | PASS | - |
| aibe-20-set-a r1 | published | 100/100 | 94 + 6 | 10800 | PASS | PASS | - |
| aibe-18-set-a r2 | retired | 100/100 | 100 + 0 | 10800 | PASS | PASS | - |
| aibe-18-set-a r3 | published | 100/100 | 100 + 0 | 10800 | PASS | PASS | - |
| aibe-21-set-a r1 | published | 100/100 | 100 + 0 | 10800 | PASS | PASS | - |
| clat-2026-ug-set-a r1 | published | 120/120 | 119 + 1 | 7200 | PASS | PASS | - |
| clat-ug-2023 r1 | published | 150/150 | 149 + 1 | 7200 | PASS | PASS | - |
| clat-2025-ug-set-a r1 | retired | 120/120 | 116 + 4 | - | PASS | PASS | - |
| clat-2024-ug-set-b r1 | published | 120/120 | 120 + 0 | 7200 | PASS | PASS | - |
| clat-2025-ug-set-a r2 | published | 120/120 | 116 + 4 | 7200 | PASS | PASS | - |

Per paper, "PASS" means: the paper row (status, frozen_at, timer, revision, supersedes), all paper-question rows (positions 1..N, answer status, keys, notes), every pinned question version (stem, options, correct and alternate answers, explanation, status published, key inside options), key-history rows, attempt count and exam tag count equal the recovered data exactly. 8 published and 3 retired confirmed in both runs.

Papers covered: AIBE-18 (r1, r2 retired; r3 published), AIBE-19, AIBE-20, AIBE-21, CLAT 2026, CLAT 2025 (r1 retired, r2 published), CLAT 2024 Set B, CLAT 2023.

## 5. Every table (A / B)

Counts: pre → expected → actual. Content: every recovered row present and identical (to_jsonb vs recovered, normalised); extra rows in DB must be rows that existed before the dry run.

| table | A pre | A expected | A actual | A inserted/updated | A | B pre | B expected | B actual | B inserted/updated | B extra live rows kept | B |
|---|--:|--:|--:|--:|---|--:|--:|--:|--:|--:|---|
| acts | 6 | 6 | 6 | 0/0 | PASS | 6 | 6 | 6 | 0/0 | 0 | PASS |
| app_opens | 49 | 58 | 58 | 9/0 | PASS | 50 | 59 | 59 | 9/0 | 1 | PASS |
| audit_log | 2169 | 5641 | 5641 | 3472/0 | PASS | 2171 | 5643 | 5643 | 3472/0 | 2 | PASS |
| chat_usage | 19 | 20 | 20 | 1/0 | PASS | 19 | 20 | 20 | 1/0 | 0 | PASS |
| chest_openings | 2 | 2 | 2 | 0/0 | PASS | 2 | 2 | 2 | 0/0 | 0 | PASS |
| coin_ledger | 60 | 68 | 68 | 8/0 | PASS | 61 | 69 | 69 | 8/0 | 1 | PASS |
| content_reports | 0 | 0 | 0 | 0/0 | PASS | 0 | 0 | 0 | 0/0 | 0 | PASS |
| content_sources | 3 | 4 | 4 | 1/0 | PASS | 3 | 4 | 4 | 1/0 | 0 | PASS |
| daily_tips | 101 | 101 | 101 | 0/3 | PASS | 101 | 101 | 101 | 0/3 | 0 | PASS |
| duel_matches | 0 | 1 | 1 | 1/0 | PASS | 0 | 1 | 1 | 1/0 | 0 | PASS |
| energy_ledger | 28 | 33 | 33 | 5/0 | PASS | 28 | 33 | 33 | 5/0 | 0 | PASS |
| exam_attempt_questions | 100 | 1790 | 1790 | 1690/0 | PASS | 100 | 1790 | 1790 | 1690/0 | 0 | PASS |
| exam_attempts | 1 | 17 | 17 | 16/0 | PASS | 1 | 17 | 17 | 16/0 | 0 | PASS |
| exam_blueprints | 1 | 2 | 2 | 1/0 | PASS | 1 | 2 | 2 | 1/0 | 0 | PASS |
| exam_paper_key_history | 4 | 6 | 6 | 2/0 | PASS | 4 | 6 | 6 | 2/0 | 0 | PASS |
| exam_paper_questions | 200 | 1230 | 1230 | 1030/0 | PASS | 200 | 1230 | 1230 | 1030/0 | 0 | PASS |
| exam_papers | 4 | 11 | 11 | 7/4 | PASS | 4 | 11 | 11 | 7/4 | 0 | PASS |
| exam_question_tags | 298 | 1051 | 1051 | 753/0 | PASS | 298 | 1051 | 1051 | 753/0 | 0 | PASS |
| exam_section_topics | 24 | 29 | 29 | 5/0 | PASS | 24 | 29 | 29 | 5/0 | 0 | PASS |
| exam_sections | 19 | 24 | 24 | 5/0 | PASS | 19 | 24 | 24 | 5/0 | 0 | PASS |
| exams | 1 | 3 | 3 | 2/0 | PASS | 1 | 3 | 3 | 2/0 | 0 | PASS |
| import_job_rows | 298 | 1058 | 1058 | 760/0 | PASS | 298 | 1058 | 1058 | 760/0 | 0 | PASS |
| import_jobs | 3 | 9 | 9 | 6/0 | PASS | 3 | 9 | 9 | 6/0 | 0 | PASS |
| import_row_problems | 298 | 624 | 624 | 326/0 | PASS | 298 | 624 | 624 | 326/0 | 0 | PASS |
| league_cohorts | 1 | 1 | 1 | 0/0 | PASS | 1 | 1 | 1 | 0/0 | 0 | PASS |
| league_memberships | 3 | 4 | 4 | 1/0 | PASS | 3 | 4 | 4 | 1/0 | 0 | PASS |
| learner_settings | 46 | 52 | 52 | 6/0 | PASS | 47 | 53 | 53 | 6/0 | 1 | PASS |
| legal_chunks | 1852 | 1852 | 1852 | 0/0 | PASS | 1852 | 1852 | 1852 | 0/0 | 0 | PASS |
| legal_documents | 10 | 10 | 10 | 0/0 | PASS | 10 | 10 | 10 | 0/0 | 0 | PASS |
| legal_sync_runs | 0 | 0 | 0 | 0/0 | PASS | 0 | 0 | 0 | 0/0 | 0 | PASS |
| news_articles | 15 | 15 | 15 | 0/0 | PASS | 15 | 15 | 15 | 0/0 | 0 | PASS |
| news_images | 0 | 0 | 0 | 0/0 | PASS | 0 | 0 | 0 | 0/0 | 0 | PASS |
| password_reset_codes | 0 | 0 | 0 | 0/0 | PASS | 0 | 0 | 0 | 0/0 | 0 | PASS |
| premium_memberships | 0 | 0 | 0 | 0/0 | PASS | 0 | 0 | 0 | 0/0 | 0 | PASS |
| question_bookmarks | 0 | 0 | 0 | 0/0 | PASS | 0 | 0 | 0 | 0/0 | 0 | PASS |
| question_version_acts | 0 | 0 | 0 | 0/0 | PASS | 0 | 0 | 0 | 0/0 | 0 | PASS |
| question_versions | 406 | 1159 | 1159 | 753/4 | PASS | 406 | 1159 | 1159 | 753/4 | 0 | PASS |
| questions | 406 | 1159 | 1159 | 753/757 | PASS | 406 | 1159 | 1159 | 753/757 | 0 | PASS |
| quiz_session_questions | 124 | 163 | 163 | 39/0 | PASS | 124 | 163 | 163 | 39/0 | 0 | PASS |
| quiz_session_topics | 19 | 21 | 21 | 2/0 | PASS | 19 | 21 | 21 | 2/0 | 0 | PASS |
| quiz_sessions | 21 | 26 | 26 | 5/0 | PASS | 21 | 26 | 26 | 5/0 | 0 | PASS |
| rate_limits | 9 | 9 | 9 | 0/0 | PASS | 9 | 9 | 9 | 0/0 | 0 | PASS |
| refresh_tokens | 206 | 292 | 292 | 86/1 | PASS | 209 | 295 | 295 | 86/1 | 3 | PASS |
| review_decisions | 294 | 1051 | 1051 | 757/0 | PASS | 294 | 1051 | 1051 | 757/0 | 0 | PASS |
| staff_setup_tokens | 0 | 0 | 0 | 0/0 | PASS | 0 | 0 | 0 | 0/0 | 0 | PASS |
| subjects | 7 | 8 | 8 | 1/0 | PASS | 7 | 8 | 8 | 1/0 | 0 | PASS |
| topics | 29 | 34 | 34 | 5/0 | PASS | 29 | 34 | 34 | 5/0 | 0 | PASS |
| users | 51 | 57 | 57 | 6/1 | PASS | 52 | 58 | 58 | 6/1 | 1 | PASS |

Not restored by design: `rate_limits` (ephemeral), `legal_documents`, `legal_chunks`, `legal_sync_runs` (unchanged since Nov 19). Verified as unchanged.

## 6. Integrity and specific checks (A / B)

| check | A | B |
|---|---|---|
| foreign keys: 90 constraints, orphans `(0 constraints with orphans, 0 not validated)` | PASS | PASS |
| indexes: all valid (unique indexes enforce no duplicate ids) `[]` | PASS | PASS |
| duplicate ids across all id tables `(0)` | PASS | PASS |
| circular FK: no question left without live_version_id `(0)` | PASS | PASS |
| circular FK: every live_version belongs to its question `(0)` | PASS | PASS |
| refresh token revocation restored (previously live=active) `(token 01a1f1da: revoked=true; revoked tokens recovered=190, in db=190)` | PASS | PASS |
| no recovered-revoked token is active `(0)` | PASS | PASS |
| daily tip 01a1e805-6942 published 2027-02-16 `(status=published, published_at=2026-11-22T07:42:46.215Z, audit events=5)` | PASS | PASS |
| daily tip 01a1e805-6933 published 2027-01-27 `(status=published, published_at=2026-11-22T07:38:53.470Z, audit events=5)` | PASS | PASS |
| daily tip 01a1e805-6946 published 2027-02-23 `(status=published, published_at=2026-11-22T07:41:33.378Z, audit events=6)` | PASS | PASS |
| daily tips: one published tip per day+language `(0 collisions)` | PASS | PASS |
| daily tips: 11 published, 90 draft expected `(published=11)` | PASS | PASS |
| import rows with outcome 'withdrawn' restored (needs 0024) `(7)` | PASS | PASS |
| import_jobs = 9 (AIBE 18-21, UG 2026, CLAT 2023 x2, 2025, 2024) `(9)` | PASS | PASS |
| questions: 1159 total, 1051 exam-only `{"n":1159,"eo":1051}` | PASS | PASS |
| question_versions: 1159, all published `{"n":1159,"p":1159}` | PASS | PASS |
| review_decisions = 1051 (all approved) `(1051)` | PASS | PASS |
| exam mapping table exams matches recovered `(3 rows)` | PASS | PASS |
| exam mapping table exam_blueprints matches recovered `(2 rows)` | PASS | PASS |
| exam mapping table exam_sections matches recovered `(24 rows)` | PASS | PASS |
| exam mapping table exam_section_topics matches recovered `(29 rows)` | PASS | PASS |
| papers: 8 published, 3 retired `(published=8, retired=3)` | PASS | PASS |
| grand total rows = pre + new (rate_limits skipped) `(7187 -> 17701, expected 17701)` | PASS | PASS |

- Foreign keys: all 90 constraints in the schema are validated and have 0 orphans after the load. Questions are inserted with a null `live_version_id` and fixed after their versions exist (757 rows: 753 new + 4 existing drafts now published); none is left null.
- Refresh tokens: the previously active token whose revocation was recorded is revoked after the load, and all 190 recovered-revoked tokens are revoked in the database.
- UPDATE guards: in each scenario 13 guarded row updates (1 user, 4 question versions, 4 exam papers, 3 daily tips, 1 refresh token) plus the 4 existing questions live-version fixes (17 modified rows) all applied; none was skipped by a guard.

## 7. What the dry run does not prove

- It restores what was recovered. Anything written after 13:12:46 IST on Nov 22 is still missing, and page checksums of the broken files were never verified (see `REPORT.md`).
- The 22 medium-confidence rows (14 audit, 3 daily tips, 3 refresh tokens, 2 rate limits) depend on my WAL replay. The 3 daily tips are corroborated by their audit entries (checked above); rate limits are not restored.
- It ran in PGlite on copies, not through the CMS or the backend API. No paper was published or activated through any workflow.

## 8. Files

- `dryrun/dryrun.mjs`, `dryrun/gen_report.mjs`: the scripts.
- `dryrun/work/A-nov19-backup/db`, `dryrun/work/B-current-live/db`: the restored scratch databases (can be deleted).
- `dryrun/work/*.results.json`: raw results.

## 9. Next step

Awaiting your separate approval. A live restore would: stop all backend processes again, back up `.data/pglite` as `pglite-backup-20261122-pre-restore`, then run tiers A-N (without the migration step, already applied) with the same script against the live directory, with the same verification.