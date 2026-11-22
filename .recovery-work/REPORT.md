# PGlite raw-page salvage report

Source: copy of `backend/.data/pglite-broken-20261122` (original untouched). Reference: Nov 19 backup `pglite-backup-20261119-pre-practice-timer`. Nothing was imported into the live DB or CMS.

## 1. Method

- Parsed 8 KB heap pages directly (no Postgres started, no `pg_resetwal`): `pg_class`/`pg_attribute`/`pg_type`/`pg_enum` first, then every public table, including TOAST (pglz) values, jsonb, numeric, arrays, enums.
- Row visibility from hint bits + `pg_xact` (commit log).
- **Decoder validated against ground truth**: the same extractor run on the Nov 19 backup matches `SELECT` output from PGlite for all 48 tables (every live row identical; vector embeddings excluded).
- The cluster's last checkpoint was 2026-11-22 13:04:55 IST (07:34:55 UTC, xid 7157). The heap files only hold state up to there. The WAL after it was intact (180 records, every CRC32C valid, clean end at LSN 0/512C060). I replayed its heap records (INSERT, UPDATE, HOT_UPDATE, DELETE, PRUNE, full-page images) onto a second copy (`data-redo`) and used the WAL commit/abort records for commit status of xids 7157-7181.
- Not replayed (no effect on row content): index (btree) records, row-lock records, visibility-map bits.

## 2. Result summary

- Tables inspected: **48** (all public tables).
- Live rows recovered: **17699** (Nov 19 backup had 7187).
- New since Nov 19: **10517** rows. Modified since Nov 19: **21** rows. Removed since Nov 19: **5** rows (only `rate_limits`, an expiring throttle table).
- Confidence: **15825 high**, **22 medium** (reconstructed from WAL), **1852 partial**.
- Referential integrity: 52 foreign-key relations checked, **0 with orphans**; duplicate live ids: 0; question.live_version mismatches: 0.

## 3. Per-table counts

| table | Nov 19 | recovered | new | modified | removed | high | medium (WAL) | partial |
|---|--:|--:|--:|--:|--:|--:|--:|--:|
| acts | 6 | 6 | 0 | 0 | 0 | 6 | 0 | 0 |
| app_opens | 49 | 58 | 9 | 0 | 0 | 58 | 0 | 0 |
| audit_log | 2169 | 5641 | 3472 | 0 | 0 | 5627 | 14 | 0 |
| chat_usage | 19 | 20 | 1 | 0 | 0 | 20 | 0 | 0 |
| chest_openings | 2 | 2 | 0 | 0 | 0 | 2 | 0 | 0 |
| coin_ledger | 60 | 68 | 8 | 0 | 0 | 68 | 0 | 0 |
| content_reports | 0 | 0 | 0 | 0 | 0 | 0 | 0 | 0 |
| content_sources | 3 | 4 | 1 | 0 | 0 | 4 | 0 | 0 |
| daily_tips | 101 | 101 | 0 | 3 | 0 | 98 | 3 | 0 |
| duel_matches | 0 | 1 | 1 | 0 | 0 | 1 | 0 | 0 |
| energy_ledger | 28 | 33 | 5 | 0 | 0 | 33 | 0 | 0 |
| exam_attempt_questions | 100 | 1790 | 1690 | 0 | 0 | 1790 | 0 | 0 |
| exam_attempts | 1 | 17 | 16 | 0 | 0 | 17 | 0 | 0 |
| exam_blueprints | 1 | 2 | 1 | 0 | 0 | 2 | 0 | 0 |
| exam_paper_key_history | 4 | 6 | 2 | 0 | 0 | 6 | 0 | 0 |
| exam_paper_questions | 200 | 1230 | 1030 | 0 | 0 | 1230 | 0 | 0 |
| exam_papers | 4 | 11 | 7 | 4 | 0 | 11 | 0 | 0 |
| exam_question_tags | 298 | 1051 | 753 | 0 | 0 | 1051 | 0 | 0 |
| exam_section_topics | 24 | 29 | 5 | 0 | 0 | 29 | 0 | 0 |
| exam_sections | 19 | 24 | 5 | 0 | 0 | 24 | 0 | 0 |
| exams | 1 | 3 | 2 | 0 | 0 | 3 | 0 | 0 |
| import_job_rows | 298 | 1058 | 760 | 0 | 0 | 1058 | 0 | 0 |
| import_jobs | 3 | 9 | 6 | 0 | 0 | 9 | 0 | 0 |
| import_row_problems | 298 | 624 | 326 | 0 | 0 | 624 | 0 | 0 |
| league_cohorts | 1 | 1 | 0 | 0 | 0 | 1 | 0 | 0 |
| league_memberships | 3 | 4 | 1 | 0 | 0 | 4 | 0 | 0 |
| learner_settings | 46 | 52 | 6 | 0 | 0 | 52 | 0 | 0 |
| legal_chunks | 1852 | 1852 | 0 | 0 | 0 | 0 | 0 | 1852 |
| legal_documents | 10 | 10 | 0 | 0 | 0 | 10 | 0 | 0 |
| legal_sync_runs | 0 | 0 | 0 | 0 | 0 | 0 | 0 | 0 |
| news_articles | 15 | 15 | 0 | 0 | 0 | 15 | 0 | 0 |
| news_images | 0 | 0 | 0 | 0 | 0 | 0 | 0 | 0 |
| password_reset_codes | 0 | 0 | 0 | 0 | 0 | 0 | 0 | 0 |
| premium_memberships | 0 | 0 | 0 | 0 | 0 | 0 | 0 | 0 |
| question_bookmarks | 0 | 0 | 0 | 0 | 0 | 0 | 0 | 0 |
| question_version_acts | 0 | 0 | 0 | 0 | 0 | 0 | 0 | 0 |
| question_versions | 406 | 1159 | 753 | 4 | 0 | 1159 | 0 | 0 |
| questions | 406 | 1159 | 753 | 4 | 0 | 1159 | 0 | 0 |
| quiz_session_questions | 124 | 163 | 39 | 0 | 0 | 163 | 0 | 0 |
| quiz_session_topics | 19 | 21 | 2 | 0 | 0 | 21 | 0 | 0 |
| quiz_sessions | 21 | 26 | 5 | 0 | 0 | 26 | 0 | 0 |
| rate_limits | 9 | 7 | 3 | 4 | 5 | 5 | 2 | 0 |
| refresh_tokens | 206 | 292 | 86 | 1 | 0 | 289 | 3 | 0 |
| review_decisions | 294 | 1051 | 757 | 0 | 0 | 1051 | 0 | 0 |
| staff_setup_tokens | 0 | 0 | 0 | 0 | 0 | 0 | 0 | 0 |
| subjects | 7 | 8 | 1 | 0 | 0 | 8 | 0 | 0 |
| topics | 29 | 34 | 5 | 0 | 0 | 34 | 0 | 0 |
| users | 51 | 57 | 6 | 1 | 0 | 57 | 0 | 0 |

## 4. Modified rows (what changed since Nov 19)

- **daily_tips**: status (3), last_verified_on (3), updated_by (3), reviewer_id (3), approved_at (3), published_by (3), published_at (3), updated_at (3)
- **exam_papers**: practice_timer_seconds (4), status (3), frozen_at (3), updated_at (3)
- **question_versions**: status (4), valid_from (3), verified_at (4), reviewer_id (4), submitted_at (4), approved_at (4), published_at (4), published_by (4), updated_at (4), explanation (1)
- **questions**: live_version_id (4), updated_at (4)
- **rate_limits**: reset_at (4)
- **refresh_tokens**: revoked_at (1)
- **users**: password_hash (1), updated_at (1)
## 5. Partially recovered records

- **legal_chunks (1,852 rows)**: all text/metadata columns decoded; the `embedding` (pgvector) column was **not decoded**. These rows are byte-for-byte equivalent to the Nov 19 backup (0 new, 0 modified), so the embeddings are still in the live Nov 19 DB. Nothing is lost here.
- No other row has an unreadable column.
- Dead intermediate row versions (older versions kept inside heap pages, e.g. rows replaced by updates) are present in `extracted/redo/*.json` with `_vis.state = dead`. They are not part of `recovered/`.

## 6. Unrecoverable / not verified

- **Anything committed after WAL LSN 0/512C060.** That is the last valid WAL record (xid 7181, last audit event `daily_tip.published` at 2026-11-22 13:12:46 IST, last data-file write 13:12:55 IST). No file in the broken directory contains later data. The crash time is not known, so I can't say whether the app wrote anything later.
- **Page checksums were not verified** (the cluster has data checksums on). I did not re-implement PostgreSQL's page checksum. Every page header parsed sanely (0 bad pages), every row decoded, and all 52 foreign-key relations are consistent, so there is no sign of torn pages, but a corrupted page that still looks structurally valid cannot be ruled out. The decoder's correctness was independently proven on the Nov 19 backup (all 48 tables match SQL output).
- **Why PGlite aborted** was not determined. WAL CRCs are all valid, so the WAL itself is not the corruption.
- **Row-level locks and index pages** were not replayed. Neither carries row content.

## 7. Confidence levels

| level | meaning | rows |
|---|---|--:|
| high | Row version already on disk at the last checkpoint (13:04:55 IST); fully decoded; commit status from hint bits or `pg_xact`. Same decoder reproduced the Nov 19 backup exactly. | 15,825 |
| medium | Row version created after the last checkpoint (xid >= 7157), reconstructed by my WAL replay. Commit status from WAL commit records. Cross-checked: the 3 recovered daily-tip publishes match audit-log events to the millisecond. | 22 |
| partial | Row decoded except one column (legal_chunks.embedding), see section 5. | 1,852 |

Columns added later with a default (`questions.exam_only`, `question_versions.alternate_correct_option_ids / lock_option_order / law_regime`, `exam_blueprints.is_current`, `quiz_sessions.topic_ids`) are not stored in older tuples. Their value is the migration's `DEFAULT`. This was verified against SQL output on the Nov 19 backup. Affected rows carry a `_notes` entry.

Sequences: the schema has none (ids are UUIDs). Applied migrations in the recovered DB: 26 rows, latest 2026-11-20 06:07 UTC; the Nov 19 backup has 24. See `recovered/_sequences_and_migrations.json`.

## 8. Files (all under `.recovery-work/`)

- `REPORT.md` this report
- `recovered/<table>.json` live rows with `_confidence`, `_source` (`heap-file` or `wal-redo`), `_notes`, `_loc`
- `diff/<table>.json` `new`, `modified` (with before/after and changed fields), `removedSinceNov19`
- `extracted/redo/` every row version (live, dead) per table, plus `_summary.json`, `_integrity.json`
- `scripts/` extractor, WAL parser, redo, validator, integrity checker
- `data/` untouched fresh copy of the broken dir; `data-redo/` same copy patched with WAL redo; `ref1119/`, `ref1119-sql/` copies of the Nov 19 backup

## 9. Next step (needs your approval)

Nothing has been restored. If you approve, the safest restore path would be: take the Nov 19 live DB, apply migrations through the recovered level, insert `recovered/` rows (and update the modified ones) in FK order, then compare row counts with this report. I will not start that until you say so.
