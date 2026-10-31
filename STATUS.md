# Nyaya — Project Status (handoff file)

> **Read this first.** This file is the offline context for any AI assistant or developer
> picking up the project. Keep it updated after every meaningful step.
> Last updated: 2026-10-31 (shared sign-in limits, Claude Opus 5.5)

## 1. What the product is
Flutter mobile quiz app on **Indian law** ("Nyaya") for advocates, law aspirants (CLAT/AIBE/judiciary)
and common citizens. Gamified like Duolingo/Candy Crush: level map, energy, streaks, leagues,
AI legal chatbot, legal updates feed, premium tier. Supports **6 languages**:
English, Hindi, Tamil, Telugu, Kannada, Malayalam.

### Original requirements (from the user)
- Quiz screen: question + 4 options + Next button.
- Max 4 quiz modes (researched) · streaks · level-by-level quizzes.
- Candy-Crush-style road map with nodes for levels (2nd tab).
- AI chatbot that answers legal queries (3rd tab). Legal updates (4th tab).
- Settings at top-right of Home. Bottom nav = 4 tabs: Home · Journey · Ask AI · Updates.
- Onboarding screen + Home page.
- Energy points: each quiz costs energy; resets daily; premium for more.
- Tier/points system + leaderboard (researched).
- Premium UI/UX, no user-flow breakage, motivates daily use. Modular clean code.

## 2. Current state — DONE
- [x] Research (quiz modes, palette, UX, leagues) → summarized in §5.
- [x] Flutter project scaffolded (`ai.bigtapp.nyaya`, iOS + Android). Flutter 3.47.5 / Dart 3.13.4.
- [x] All features implemented (see §4 for file map). `dart analyze lib test` → **No issues**.
- [x] Question bank: 108 verified questions (`assets/questions/en.json`), 6 chapters × 3 levels × 6 Qs.
- [x] Full translations of questions + UI strings for hi, ta, te, kn, ml (validated: ids/options/placeholders match).
- [x] Built and ran on iOS Simulator (iPhone 17 Pro Max): Home, Quiz (feedback states), Results,
      Journey map, AI chat (offline mode) visually verified.
- [x] All 34 tests pass (`flutter test`): unit (XP, streak, leagues, Elo, dates), content (question bank,
      5 translations, QuizBuilder) and 3 end-to-end widget flows (onboarding → home, full Case Path level
      → 3 stars/XP/streak/energy refund, out-of-energy sheet offers free paths).
- [x] Fixed: row overflows on paywall + quiz chapter chip (matter for long Tamil/Malayalam strings);
      "1 days" plural copy. Tests inject a file-based question loader (rootBundle hangs under fake async).

- [x] `docs/DESIGN.md` (research + rationale + sources) and `README.md` written.
- [x] Fixed on-device bugs found in simulator: Settings rendered blank (button theme used
      `Size.fromHeight` → infinite-width buttons in ListTile/dialogs; now `Size(64, h)`), settings groups now
      use `Material` so ListTiles render. Quiz header counter right-aligned.
- [x] Tamil verified on simulator (home, quiz, quit dialog) — no layout exceptions.
- [x] 2026-10-26: Re-themed to the Terracotta × Sand palette (global tokens, ColorScheme, all hardcoded
      colours and gradients removed; avatars/map nodes/progress bars flat). Analyze clean, 34 tests pass,
      Home + Journey eyeballed on simulator (light). Dark mode not yet eyeballed. Committed b8c6824.
- [x] 2026-10-26: Home redesigned as "Explore Law" (user reference, "Screen 1" layout, design only):
      serif header + search (→ Ask AI) + settings; "Start here" carousel (Constitution / BNS / Everyday Law)
      with flat painted illustrations (`home/presentation/widgets/law_illustration.dart`) and dash indicator;
      "Core Laws" list (BNS, BNSS, BSA, Everyday Law) + IPC & CrPC legacy row. Explore → next Case Path level
      if it is in that chapter, else Journey tab; law rows → Ask AI with a prefilled question; View All → Journey.
      Game sections (stats, continue, daily goal, docket, modes, league, premium, fact, updates) are no longer
      on Home; their widgets remain unused in `home_sections.dart` / `home_header.dart` in case they return.
      New strings are English-only (other locales fall back). Tests updated (tap 'Explore' instead of 'PLAY').
- [x] 2026-10-26: Constitution "Start here" card uses a ChatGPT-generated painting
      (`assets/images/explore_constitution.webp`, 1254² webp, bg #F0D5C5 = card colour so there is no seam).
      Image cards keep light-theme text in dark mode (dark path not yet eyeballed). BNS and Everyday Law cards
      now have paintings too (`explore_bns.webp`, `explore_everyday.webp`, prompts in `docs/HOME_ART.md`;
      each card's flat colour matches its painting's left edge). Earlier note: they used painted-in-code art until matching images were generated (prompt style: warm painterly
      editorial, palette colours, subject in right two-thirds, left third fading to flat peach, square, no text).
- [x] 2026-10-27: Onboarding intro redesigned from the user's 3-screen reference (`onboarding/presentation/
      intro_slides.dart`): Skip, swipeable slides, dot indicator, round next button, "Get Started".
      Slide 1 brand "Nyaya / Learn Law. Live It." + hero art; slide 2 "Structured learning" with a tilted
      demo lesson card; slide 3 "Practice & apply" with three staggered demo feature cards. Flow is now
      language → intro → persona → goal → name (5 steps); intro always renders in the light theme.
      Artwork: `assets/images/onboarding_{hero,lessons,practice}.webp` (ChatGPT-generated, added 2026-10-27);
      edges fade into Warm Cream to hide small colour differences; drawn-in-code stand-ins remain as fallbacks. New strings English-only. Old onbSlide* ARB keys
      are now unused. Copy mentions "lessons, notes" and "Real Life Scenarios", which the app doesn't have yet.
- [x] 2026-10-27: Journey (Case Path) restyled from the user's mock: serif "Case Path" header + subtitle,
      wide sand road with dashed centre, raised nodes (terracotta current/completed with serif numeral,
      sand locked discs, cream chest), "You" pill, chapter cards (current chapter = cream card, others =
      burnt clay, both tappable → that chapter's current/first level sheet), a
      handwritten "Keep going!" (Caveat) placed only where `JourneyLayout.freeWidth` finds room beside the
      road, painted edge scenery per chapter (`journey_scenery.dart`). Artwork: all 12 `journey_*.webp` paintings added 2026-10-27 (ChatGPT, transparent PNG → trimmed,
      840 px wide webp, ~2.3 MB total); the scales sit at 50 % opacity; prompts in `docs/JOURNEY_ART.md`.
      The mock's margin quotes were dropped on purpose (user's call: the paintings fill that space).
      Chapter colours are no longer used on the map. New strings English-only. Checked on simulator (light).
- [x] 2026-10-27: Legal Updates restyled from the user's mock: serif "Legal Updates" header over the
      Supreme Court painting (reuses `journey_constitution_landmark.webp`), serif pill filters with icons, news cards (tinted category tag, serif
      headline, calendar + read time, thumbnail with a notched save button). Saved ids persist in
      `savedUpdatesProvider` (`saved_updates_v1`); there is no "Saved" list yet. Supreme Court tags use the new
      muted indigo `AppPalette.ink`. Thumbnails load `assets/images/update_<id>.webp` (none exist yet; cards
      show the category's Journey painting instead); prompts in `docs/UPDATES_ART.md`. New strings English-only. Checked on simulator (light).
      The mock's search button was dropped at the user's request.

- [x] 2026-10-27: Home "Continue where you left off" card below the "Start here" carousel
      (`ContinueLearningCard` in `explore_sections.dart`): chapter title, "Chapter N · Level M", progress bar,
      Continue button that starts the next level (or opens the Journey map for a chest / when all done), and
      the chapter's Journey landmark painting faded in on the right. Hidden until the first level has stars,
      so new users only see "Start here". Old unused `ContinueJourneyCard` in `home_sections.dart` left as is.
      Checked on simulator (light); widget test covers resume.
- [x] 2026-10-27: Home "Latest legal updates" widget between "Continue" and "Core Laws"
      (`LatestUpdatesSection` in `explore_sections.dart`): serif heading + View All (→ Updates tab), then a
      horizontal edge-to-edge strip of the 5 newest updates (painting on top, tinted category, serif headline,
      date · read time); tap opens the update. Hidden while loading / when empty. Home sections now pad
      themselves (the strip needs full width). Shared `_SectionTitle` used by Core Laws too; the private
      `_FallbackArt` in `updates_screen.dart` is now public `UpdateFallbackArt`; the old unused
      `LatestUpdatesSection` in `home_sections.dart` was removed. No new strings (`homeUpdatesTitle` is
      translated). All 38 tests pass, incl. new "Home shows latest updates and opens one";
      checked on simulator (light). Dark mode not eyeballed.

- [x] 2026-10-27: Overall plan received (product name in the plan: "LawLearn"): `docs/planning/`
      01_Product_Roadmap.docx (phases P0–P7, MVP scope), 02_Module_Plans.docx (modules M01–M15),
      03_Integration_Content_Contract.xlsx (API contract, content schema, workflow, events, QA gates).
      Copies there are marked with build status (originals in ~/Downloads untouched). Key gap: the app is
      offline — the plan needs a backend as the only write path, server-side scoring (no answer keys in the
      app), a content lifecycle with review/publishing and source metadata, and a Next.js CMS.
      Empty `backend/` and `cms/` folders created (READMEs only); backend framework not chosen yet.

- [x] 2026-10-27: Backend foundation in `backend/` (user chose Node → **NestJS 12**, ESM, Drizzle ORM,
      Postgres; embedded PGlite in `.data/pglite` when `DATABASE_URL` is unset, in-memory for tests).
      Built plan modules M01–M04: staff email/password auth (JWT 15 min + rotating refresh tokens with
      reuse detection, roles from DB per request, sign-in rate limit), `GET /v1/taxonomy`, and the full
      question lifecycle under `/v1/editor/questions` (draft → in_review → changes_requested/approved →
      published → superseded/retired, immutable published versions, reviewer ≠ author, audit log).
      Seed (`npm run seed`) imports the app's 108 English questions as drafts (`external_ref app:<id>`),
      6 subjects/topics from the chapters, 6 acts, and dev staff accounts using `SEED_PASSWORD` from
      `backend/.env`. Contract in `backend/openapi.json`. 4 unit + 18 API tests pass; lint clean.
      Learner sign-in method still undecided; questions still lack source URL/validity dates, so none can
      be submitted for review until content ops fill them in.

- [x] 2026-10-27: Content Management Portal in `cms/` (Next.js 16.4, App Router, Cache Components on,
      Tailwind 4 with the app's Terracotta × Sand tokens, light + dark). Screens: sign-in, question list
      (search, status/topic filters, cursor paging; "Review queue" = in_review, "Ready to publish" = approved),
      new question, question detail (editable form for draft/changes requested, read-only otherwise, role-based
      actions: submit, request changes, approve, publish, revise, retire; version + review history).
      Tokens live in httpOnly cookies; `src/proxy.ts` (Next 16's renamed middleware) refreshes them and shares
      one refresh across parallel requests. Typed client generated from `backend/openapi.json`
      (`npm run gen:api`). Backend: refresh-token reuse within 30 s of rotation is now just rejected (race),
      not treated as theft; list items' `latest` now documents `stem`/`topic_id`.
      Verified in the browser: editor fills an imported draft's source → submit; reviewer approves; publisher
      publishes; editor creates a new draft; proxy refresh and sign-in redirects checked with curl.
      Dev servers: `.claude/launch.json` (api :3000, cms :3001). Local dev data now has 1 published + 1 extra draft.

- [x] 2026-10-27: Learner quiz API in `backend/src/learn/` (plan M05–M07): `GET /v1/quizzes` (public catalog
      of topics with published, in-force questions; validity uses the India date), `POST /v1/quiz-sessions`
      (server picks + shuffles; no keys/explanations), answers, submit (idempotent), result, `GET /v1/me/attempts`,
      `GET /v1/me/progress`. Modes: `immediate` (answer final, explained at once — matches the app's Case Path)
      and `end` (exam — matches Exam Chamber). Scoring `standard-v1` (+1/0; the app's Exam Chamber −0.25 is not
      modelled yet). Tables `quiz_sessions`, `quiz_session_questions` (migration 0001). Seed adds
      `learner@nyaya.local`. 10 unit + 28 API tests pass; smoke-tested against the dev DB.
      Gotcha: PGlite is single-process — stop the API before `npm run seed`.

- [x] 2026-10-27: **Flutter app now runs every quiz through the backend.** No answer keys on the phone:
      `assets/questions/` moved to `backend/seed/questions/` (backend tests now validate the bank). `Question`
      has no key; the server's `Reveal` (correct option, explanation, reference) arrives after an answer is final
      (practice) or on submit (Exam Chamber, `feedback_mode=end`). `QuizController` is async (starting → active →
      submitting → finished/failed), retries sends, re-sends exam answers before submit, and takes scores from the
      server; XP/stars/streak/leagues still computed on the device from server-verified correctness (Exam Chamber's
      −0.25 marking too — not yet a server scoring policy). `QuizBuilder.plan` maps modes to session requests
      (Case Path = chapter + difficulty=level; Docket = `daily`, persona range; Duel = reached chapters; Exam = all,
      persona range). Chapter names moved into the ARB files (all 6 languages); quiz content is English-only until
      translations are imported server-side.
      Auth: email + password learner sign-up/sign-in (user's choice; `POST /v1/auth/register`), tokens in the
      Keychain (`flutter_secure_storage`), `ApiClient` refreshes once on expiry (offline ≠ signed out). Quizzes need
      an account: `QuizLauncher` opens `/sign-in` first (no energy spent before). Settings has an Account section.
      API URL: `--dart-define=NYAYA_API_URL=...` (default http://localhost:3000; ATS local-networking + Android
      debug cleartext allowed for dev). Backend additions: register, multi-topic/difficulty-range/daily sessions,
      `subject_slug` in the catalog, `topic_id` per session question, migration 0002, dev seed flag
      `SEED_PUBLISH_IMPORTED=true`. Tests: Flutter 35 (fake backend in `test/support/fake_backend.dart`), backend
      17 unit + 31 API. Verified on the iPhone 17 Pro Max simulator against the real local API: sign-up gate,
      practice answers with server verdicts, wrong-answer reveal, submit → attempt stored, sign-out/sign-in.
      Notes: iOS shows a system "Save Password?" alert after sign-up (blocks touches until answered — normal);
      local game progress (XP, stars) is still per device, not per account; Keychain sessions survive app reinstall.

- [x] 2026-10-28: **Pushed to GitHub** — `origin` = https://github.com/gowtham0210/nyaya_v2 (PUBLIC repo),
      `main` tracks `origin/main`. Before the push: history scanned for secrets (none; the AI key is a
      `--dart-define`, never in source), then an OpenQodex whole-repo review (run in agent mode: the CLI reviewer
      can't start because `claude` isn't logged in on the command line). Its 3 findings were fixed in `578df0e`:
      approval now refuses anyone who ever edited the version (audit-log lookup, `hasEdited`); CMS 401s go to
      `/login?ended=1`, where the proxy clears the session cookies (no more /login ↔ /questions loop); unused
      `@nestjs/mau` removed (it pinned a vulnerable undici; backend runtime deps audit clean). Re-review passed
      with no findings. `.openqodex/config.yaml` + `custom-instructions.md` are committed (reports ignored).
      Backend tests now 17 unit + 32 API. OpenQodex 0.15.0 is available (`openqodex update`), not installed.

- [x] 2026-10-28: **CI** — `.github/workflows/ci.yml` (commit `a531c5c`) runs on push to `main` and on PRs:
      backend (oxlint, prettier check, unit + API tests, build, `openapi.json` drift), CMS (`api-schema.d.ts`
      drift vs `backend/openapi.json`, eslint, `next typegen` + tsc, build), Flutter 3.47.5 (`gen-l10n` drift,
      analyze, test). Actions pinned by SHA, read-only token, `persist-credentials: false`. First run green
      (~30 s backend/CMS, ~2 min Flutter). So after changing an API DTO: `npm run openapi` in backend/, then
      `npm run gen:api` in cms/, and commit both; after editing ARB files commit the regenerated `lib/l10n/*.dart`.

- [x] 2026-10-29: **Staging is live** on the shared VPS (`root@200.141.13.65`, Ubuntu 24.04, also hosts yercaud,
      freelance-flow, cal-tracker): API https://staging-api.deepwebstudio.dev, portal https://staging-cms.deepwebstudio.dev.
      Stack `nyaya-v2` in `/opt/nyaya-v2` (`deploy/staging/docker-compose.yml`): own Postgres 17 (not published),
      `nyaya-v2-api`, `nyaya-v2-cms`, joined to `yercaud_default` so the yercaud project's nginx-certbot container
      terminates TLS (`deploy/staging/nginx.conf` → `/opt/yercaud/nginx/user_conf.d/nyaya-v2-staging.conf`; HUP that
      container to get certificates for new names). Redeploy from the repo root: `./deploy/staging/deploy.sh`
      (`--seed` re-imports questions + resets staff passwords). Secrets (POSTGRES_PASSWORD, JWT_SECRET, SEED_PASSWORD)
      are generated once into `/opt/nyaya-v2/.env` on the server and never leave it; staff accounts are the dev ones
      (`admin@/editor@/reviewer@/publisher@nyaya.local`) with that SEED_PASSWORD. Staging = `NODE_ENV=production` +
      `DEPLOY_ENV=staging` (seed may publish the 108 imported questions UNREVIEWED there; refused in real production).
      New `TRUST_PROXY_HOPS=1` so sign-in rate limits are per client behind nginx (verified; backend tests now 19 unit + 33 API). DNS A records were added
      by the user (the domain isn't on the connected Hostinger account). The old Nyaya v1 containers (`nyaya-api`,
      `nyaya-frontend`, `/root/nyaya_backend`, nyayaapi.deepwebstudio.dev) were STOPPED, not removed; their nginx
      site `nyaya.conf` is still installed. Smoke-tested: catalog, staff sign-in, portal /login over HTTPS, other sites up.
      User checked the portal in a browser on 2026-10-29: sign-in and role-based actions work.
      iPhone 15 Plus release build against staging (`--dart-define=NYAYA_API_URL=https://staging-api.deepwebstudio.dev`)
      checked by the user on 2026-10-29: sign-up and a full Case Path level work; the server stored the
      account and a submitted 6-question session.
      DB backups (2026-10-29): `deploy/staging/backup.sh` → `/opt/nyaya-v2/backup.sh`, run nightly at 02:00 IST
      (20:30 UTC) by `/etc/cron.d/nyaya-v2-backup` (`deploy/staging/backup.cron`); `pg_dump --clean` gzip copies in
      `/opt/nyaya-v2/backups/` (root-only, kept 14 days, log in `backups/backup.log`). Same server only — fine for
      staging, production will need an off-server copy. Restore steps are at the top of `backup.sh`; a restore into
      a scratch database was tested and matched the live row counts.

- [x] 2026-10-29: **Ask AI runs through the backend** (Azure OpenAI, deployment `gpt-5.4-mini`). `POST /v1/chat`
      (`backend/src/chat/`): signed-in users only; the server holds the key and the system prompt (moved from the app;
      language + persona as before); Azure v1 chat completions with a 60 s timeout; content-filter blocks return the
      polite "can't help" reply. Daily limit per learner per India date in `chat_usage` (migration 0003): taken before
      the Azure call with a conditional upsert (parallel requests can't pass it), given back when the call fails or is
      filtered; `CHAT_DAILY_LIMIT` default 50 (an abuse guard), invalid values stop startup. Settings:
      `AZURE_OPENAI_ENDPOINT`, `AZURE_OPENAI_API_KEY`, `AZURE_OPENAI_CHAT_DEPLOYMENT` (in `/opt/nyaya-v2/.env` on staging
      only); unset → 503 `chat_unavailable`. Endpoint also has gpt-5.4, gpt-5.4-nano, gpt-5.6-terra, gpt-6-luna, gpt-6-sol
      and text-embedding-3-small deployed (all answered a test question). App: `BackendChatRepository` replaces the
      direct Claude call (no AI key in the app any more, `NYAYA_AI_*` defines removed); asking opens sign-in first;
      when the API can't be reached or answers `chat_unavailable` it falls back to the built-in offline answers.
      Two separate counters for now: the app's free 5/day (premium unlimited, still simulated on the phone) and the
      server's 50/day — move to the server's `remaining_today` once purchases are real. Tests: backend 21 unit + 40 API,
      Flutter 38. Checked by the user on the iPhone against staging.
      The Azure key was pasted in chat on 2026-10-29 — rotate it in the Azure portal and update `/opt/nyaya-v2/.env`.
      Gotchas: `devicectl device install` can fail with "Insufficient storage" while the last output line still looks
      fine — check for "App installed". On a flaky connection rsync to the VPS can drop ("incorrect signature",
      "closed by remote host"); deploy.sh then fails, so retry, or scp the changed files and run
      `docker compose up -d --build` on the server.

- [x] 2026-10-29: **Learning progress lives on the server (Part 1 of 3).** User's choices: every account starts
      fresh (old phone progress is not imported); duels earn XP for correct answers only (win/loss and duel rating stay
      on the phone). On submit the server works out stars (50/80/100 %), XP (`backend/src/learn/rewards.ts`, a copy of
      the app's GameRules/XpCalculator — keep both in step; speed is timed by the server between answers), streak with
      free freezes at 7/30/100 days (`streak.ts`, derived from India dates of finished quizzes), the docket's 1.25× (one
      docket a day: `409 docket_done_today`), half XP for replaying a 3-star level, and exam minus marks
      (`exam-negative-v1`: +1 / −0.25 / 0; `negative_marking: false` for citizens). `POST /v1/quiz-sessions` now needs
      `mode` (case_path | daily_docket | duel | exam; a Case Path level is one subject at one difficulty); the result has
      `rewards`. `GET /v1/me/progress` returns XP, this/last week's XP, streak, best stars per level (`constitution_2`),
      opened chests and totals; `POST /v1/me/chests/:chest_id/open` opens the next chest on the road (subjects by
      sort order × 3 levels + chest). **3NF:** `quiz_sessions` gained `mode` + `xp_awarded`; its topic list moved to
      `quiz_session_topics`; `topic_id`, `topic_ids`, `feedback_mode`, `daily`, `difficulty` (now min = max),
      `expires_at`, `score` and `status` were dropped because they follow from other columns (derived in
      `scoring.ts`); new `chest_openings`. Stars, XP totals and streak are calculated, not stored. Kept on purpose:
      `question_count` / `correct_count` / `answered_count` (summaries of the question rows, not a 3NF break). Still a
      list column, not changed: `quiz_session_questions.selected_option_ids`. Migrations 0004 (add + copy data) and
      0005 (drop) — split so drizzle-kit doesn't ask about renames (it can't prompt here).
      App: `lib/features/progress/` (`ProgressApi`, `ServerProgress`/`ServerRewards`, `ProgressSync`). The profile and
      journey keep a copy of the server's numbers (loaded on start, resume, sign-in, pull-to-refresh and after each
      quiz; cleared on sign-out); coins, energy, premium, settings and duel rating stay local (Part 2). Buying streak
      freezes is off (the server only counts free ones); the Settings reset text says XP/stars/streaks stay on the
      account — **English only, the 5 other languages still have the old wording and need new translations**.
      Old app builds can't start quizzes on this server (no `mode`). Tests: backend 32 unit + 47 API, Flutter 37.
      Staging migrated (backup `nyaya-2026-10-29-0732.sql.gz` taken first); user checked on the iPhone: played a
      level, signed out and in, progress came back. Next: Part 2 (settings, coins, energy, freezes on the server),
      Part 3 (real leagues from the server's weekly XP).

- [x] 2026-10-29: **Coins, energy, freezes, premium and settings live on the server (Part 2 of 3).** User's choices:
      demo premium is turned on by the app (`POST/DELETE /v1/me/premium`, source 'demo', audit-logged; testing only —
      replace with store receipt checks before launch); only learning settings follow the account (name, persona,
      language, daily goal, onboarded) — theme, sound, haptics, reminders stay per phone. **3NF:** `coin_ledger` and
      `energy_ledger` (every movement; balances are sums, never stored; partial unique indexes pay a reward once per
      session / chest / welcome), `learner_settings` (name stays in `users.display_name`; onboarded = onboarded_at set),
      `premium_memberships` (a row = premium). Kept on purpose: the chest payment row and `chest_openings` (money vs
      road progress); ledger amounts are what was paid at the time, like `xp_awarded`. Migration 0006.
      Server rules (`ECONOMY` in `rewards.ts`, same numbers as the app's GameRules): 60 welcome coins; quiz start charges
      energy (case path/duel 1, exam 2, docket free; `409 not_enough_energy`); `POST /quiz-sessions/:id/abandon` before
      the first answer deletes the quiz and refunds; submit pays 5/new star, 10 docket, 15 daily goal (once per India
      day, even if the goal is raised), streak-milestone coins, +1 energy for a first 3-star clear; chests pay 30;
      `POST /v1/me/energy/refill` (30 coins → 1), `POST /v1/me/streak-freezes` (100 coins, max 2; the streak replay
      counts bought freezes from the day bought); `GET/PUT /v1/me/settings`. Progress now includes coins, energy,
      premium, settings and chat use. Chat: 5/day free, 50 premium (`CHAT_FREE_DAILY_LIMIT`, `CHAT_DAILY_LIMIT`).
      Dropped on purpose: duel-win coins (simulated opponent) and the league top-3 bonus (back with real leagues).
      App: profile copies coins/energy/premium/chat use/settings from the server; first sign-in uploads the phone's
      settings (and demo premium) once, then the account wins; progress refreshes right after a quiz starts; freeze shop
      back on; coins shown on the Journey header and in Settings → Store (they had no place since the Home redesign).
      Also fixed: "Play again" reopened the finished quiz (state is per quiz request; now invalidated first).
      Tests: backend 33 unit + 56 API, Flutter 39. Staging migrated (backup `nyaya-2026-10-29-0813.sql.gz`); user
      checked Part 2 on the iPhone. Known: Settings → Reset may not reopen onboarding (account settings come back);
      premium chat stops at the server's 50/day while the app shows unlimited. Next: Part 3 (real leagues).

- [x] 2026-10-29: **Real weekly leagues on the server (Part 3 of 3).** User's choices: small groups are topped up to 30
      with practice players (labelled in the app, generated from the group id and week progress, never stored; ranks,
      zones and the bonus count everyone shown); other learners see first name + last initial ("Asha K."). **3NF:**
      `league_cohorts` (id, ISO week in India time, tier) and `league_memberships` (learner, week, group; PK learner +
      week = one group a week; a composite FK checks the group's week). Weekly XP, ranks, results and tier moves are
      calculated from `quiz_sessions`, not stored; the top-3 bonus is a `coin_ledger` row (`league_top3`, `cohort_id`,
      paid once per group). Migration 0007 (the unique index the composite FK needs was moved above it by hand).
      Rules in `backend/src/learn/league.ts` (copy of the app's league.dart): 8 tiers, promote/demote zones, no demotion
      in tiers 1–2, weeks Monday 00:00 India time. You join with your first submitted quiz of the week (open group at
      your tier, else a new one). The previous week is settled lazily on the next visit (rank, tier move, bonus), so no
      scheduled job. Ties: real learners before practice players; between real learners, earliest to join first (the
      same for every viewer). `GET /v1/me/league`. App: trophy button on Home opens the league (the screen had no entry
      point since the Home redesign); league screen shows the server's group; the results screen's "moved up to #N"
      uses it; last week's result shows once (`leagueResultSeen`); the phone's week close is gone. The All-time tab is
      still simulated on the phone. API test hook timeout raised to 30 s (8 files start their own database in parallel).
      Tests: backend 37 unit + 63 API, Flutter 40. Staging migrated (backup `nyaya-2026-10-29-0915.sql.gz`); user checked
      the league on the iPhone.

- [x] 2026-10-29: **P3 finished: saved questions, mistakes (M08) and report-a-question (M12).** User's choices:
      mistake practice is free, earns XP and counts for the streak; a question leaves the mistakes list when answered
      right later in any quiz; Review lives on a Home card + Review page. **3NF:** `question_bookmarks` (learner,
      question — points at the question, not a version) and `content_reports` (learner, question version, reason,
      comment; outcome / resolved_by / resolved_at / note, with a CHECK that a closed report has all three; one open
      report per learner per version by a partial unique index). Mistakes are not stored: the questions whose latest
      final answer was wrong (exam answers count only after submit); "open" is "no outcome"; the question follows
      from the version. Migration 0008 (adds the `mistake_review` quiz mode). API: `GET /v1/me/mistakes`,
      `GET/POST/DELETE /v1/me/bookmarks` (only answered questions can be saved), mode `mistake_review` (up to 10 of
      your mistakes, 0 energy), `POST /v1/content-reports` (shown versions only; 20 a day), staff
      `GET/PATCH /v1/admin/content-reports` (editor, reviewer, publisher, admin; urgent = wrong answer / outdated
      law first; closing is audit-logged; reports never change content). Saved and mistake lists show the version the
      learner answered (`updated_since` when revised later), so no unanswered version's key leaves the server.
      Session questions now carry `question_id`. App: Save + Report under each explanation and in the results review,
      report sheet, Review card on Home, Review page (Mistakes / Saved tabs, Practise mistakes). Portal: Reports
      page (Open / Closed, close form) and "Open reports" on each question page — checked locally in the browser.
      Not done: notifying reporters (needs M14) and the analytics events (M11). The Save/Report row can sit partly
      under the answer bar (scroll a little). Tests: backend 37 unit + 72 API, Flutter 41. Staging migrated (backup
      `nyaya-2026-10-29-1006.sql.gz`); user checked on the iPhone and in the portal.

- [x] 2026-10-29: **Sources and dates on the 108 starter questions (P2 step 1, M04).** Each question in
      `backend/seed/questions/en.json` now has `source` {title, url, citation, valid_from, valid_to, note}: researched
      on 29 Oct (official Gazette PDFs for BNS/BNSS/BSA, India Code — now **indiacode.gov.in**, the old .nic.in links
      are dead — Legislative Department, PIB, Supreme Court PDFs); every link was opened and checked, and the India
      Code handles checked through its API. 3 have no link (Mohori Bibee, Satish Chander Ahuja, and the CPA
      Jurisdiction Rules page on consumeraffairs.nic.in, which did not open). `valid_from` = when the answer became
      law (amendment commencement or judgment date), e.g. 1979-06-20 for 44th Amendment changes, 2024-07-01 for the
      new criminal laws. `note` says where the date came from, how sure it is, and any problem for the reviewer:
      **eve_2_03 and eve_3_04 (DPDP Act s.9 and the Schedule) are not in force until 2027-05-13**, so learners won't
      see them until then; civ_1_03's "e-Daakhil" option is out of date (now e-Jagriti); pro_3_03's "mandates" is
      only true once each State notifies BNSS s.176(3). Seed (`backend/src/db/seed-sources.ts`): new imports get the
      source; an open draft gets it only where it has none (or the dev placeholders); a version published without
      review gets a **new draft revision** with the source (audit `question.revised`); reviewed / in-review versions
      are left alone. Nothing is published by this. Local dev DB: 107 revisions made, then con_1_01–06 taken through
      submit → approve → publish to test. API: answer feedback has `citation`; saved/mistake items have `source_url`
      and `citation`. App: `SourceLine` (quiz, results review, Review page) shows "Reference: …" and a "Read the
      official text" link (https only, opens in the browser, `url_launcher` added); strings in all 6 languages.
      Checked on the simulator: the link opens the PIB page in Safari. The link sits partly under the answer bar
      until you scroll, like Save/Report. Tests: backend 38 unit + 76 API (new `seed-sources` API test and a bank
      test that every question has a source), Flutter 41. Seed draft fills are audit-logged (`question.updated`,
      `by: seed`). OpenQodex review (agent mode) passed; pushed as `bd6d7d0`, CI green. **Staging deployed** with
      `--seed` (backup `nyaya-2026-10-29-1658.sql.gz` first): 107 draft revisions with sources are waiting in the
      portal; learners still see the old live versions until each is submitted, approved and published (no bulk
      action yet). The 108th, **eve_3_06**, was already revised and reviewed on staging with the placeholder source,
      so the seed left it: an editor must revise it by hand (Motor Vehicles Act, 1988 —
      https://indiacode.gov.in/handle/123456789/619305 — valid from 2019-09-01).

- [x] 2026-10-29: **Bulk submit / approve / publish in the portal.** `POST /v1/editor/questions/bulk`
      {action: submit | approve | publish, question_ids (1–100, unique), note?}: each question runs through the
      same service method as a single request, in its own transaction and in request order, so all checks apply
      (complete content, reviewer ≠ author/editor, publish needs a review) and one failure doesn't stop the rest;
      the response has a result per question (`ok`, new `status` or `error` {code, message, details}) plus counts.
      The route checks the chosen step's roles (403 otherwise). Request changes / revise stay one at a time (they
      need a reason each). Portal question list: checkboxes + "select all on this page" for staff who may run a
      bulk step, buttons with counts ("Approve (25)") that act only on selected rows in the right status, a
      confirm before approve ("you will be recorded as the legal reviewer…") and publish, an optional approval
      note saved on each, a summary listing failures with links and reasons (failed rows stay selected), and a
      new page size choice (25 / 50 / 100, `per=` in the URL). Tests: backend 38 unit + 79 API. Checked in the
      browser as the editor: 99 local drafts submitted in one click, 1 incomplete draft refused with its reasons.
      Approve / publish not clicked through in the browser (API tests cover them). OpenQodex review (agent mode)
      found that the selection carried over to the next page (fixed: the table is keyed by the page cursor too);
      pushed as `8b9d873`, CI green, staging deployed (no seed needed). Staging's 107 source drafts can now be
      reviewed in about 6 batches: All questions → status Draft, 100 a page → select all → Submit; then the
      reviewer approves from Review queue, then the publisher publishes from Ready to publish.

- [x] 2026-10-29: **Question import / export (P2 step 2, M09).** Portal → **Imports** (editors and admins): choose a
      .csv (UTF-8) or .xlsx file → *Check file* (test run, nothing saved: every row's outcome and problems) →
      *Import N questions as drafts* → saved report at `/imports/<id>`; past imports listed. Column guide on the page,
      template at `cms/public/question-import-template.csv`. Rules (`backend/src/imports/format.ts`): one question per
      row; columns external_ref, topic (slug), difficulty, question_type, stem, option_a–f, correct (letter),
      explanation, source_title, source_url, citation, provision_reference, valid_from, valid_to, jurisdiction,
      language; unknown or doubled column names refuse the file; ≤ 500 rows, ≤ 2 MB. **Errors** (unknown/inactive
      topic, bad difficulty/date, non-https link, options out of order, answer not an option, too long…) keep a row
      out; **warnings** (no explanation / source / valid_from yet) still import it as a draft. Duplicates: same
      external_ref or same text in the same topic (any version) → skipped with a link; repeated inside the file →
      failed; the exact same file (SHA-256) can't be imported twice (409 `already_imported`). Imports only ever create
      drafts (created_by = importer, audit `question.imported` + `import.completed`). API: `POST /v1/admin/import-jobs`
      (multipart `file`, `dry_run` default true), `GET /v1/admin/import-jobs[/:id]`, `GET /v1/admin/question-export`
      (csv | xlsx, status/topic filters; staff only — includes answer keys). **3NF:** `import_jobs` (file, sha, format,
      who, when), `import_job_rows` (row number, external_ref, outcome, question), `import_row_problems` (level,
      column, reason) — counts are calculated; test runs aren't stored. Migration 0009. Export = latest version of each
      question in the same columns + question_id, version_no, status, live; CSV has a BOM (Excel reads Indian
      scripts) and cells starting with = + - @ get a leading apostrophe (import takes it off); Excel cells are text.
      Portal: Export CSV / Export Excel on the question list (follows status + topic filter) via
      `cms/src/app/(app)/questions/export/route.ts`. Libraries: csv-parse 7.0.3, read-excel-file 9.3.12,
      write-excel-file 4.1.1 (exceljs was avoided: old, many dependencies); runtime audit still clean. Server action
      upload limit raised to 3 MB (`next.config.ts`). Tests: backend 65 unit + 83 API. Checked in the browser as the
      editor: test run, real import of a 5-row file (2 drafts, 1 skipped, 2 errors), saved report, past imports, both
      export downloads. Local dev gotcha: the dev API has no fixed JWT_SECRET, so every restart signs everyone out.
      OpenQodex review (agent mode) passed (squawk's lock warnings dropped: new empty tables). Pushed `4c6f59a`, CI
      green; staging deployed (backup `nyaya-2026-10-29-1736.sql.gz` first, migration 0009 applied on start).
      Known limit: a file that was imported once can't be imported again unchanged, even if a topic it needed was
      added since — change the file (e.g. drop the rows already imported) and upload it again.

- [x] 2026-10-29: **Topics page: subjects, topics and acts (P2 step 3, M02 / M10).** Portal → **Topics**: each subject
      with its topics (Shown/Hidden, slug, act, question count linking to the filtered list, live count), edit forms
      under each row, add topic / subject / act. API (`backend/src/taxonomy/admin-taxonomy.*`): `GET /v1/admin/taxonomy`
      (all staff; hidden included, counts), `POST/PATCH /v1/admin/subjects` (**admins only**), `POST/PATCH
      /v1/admin/topics` and `/v1/admin/acts` (editors + admins); every change audit-logged (`taxonomy.*_created/
      _updated`); taken slug → 409 `slug_taken`. Rules, because the app and stored progress refer to them: **slugs
      never change**, **topics never move to another subject**, **new subjects start hidden** (showing one adds a
      chapter to the server's Case Path road — the app still has its 6 chapters built in, so a shown new subject is
      invisible in the app and, if its order is lower, stands in front of later chests). Hiding a topic or subject
      takes its questions out of quizzes at once (the existing eligibility check); the portal's confirm says how
      many live questions. The question list and its topic filter now use the full taxonomy and mark hidden topics;
      question forms still offer only shown topics. Tests: backend 65 unit + 88 API. Checked in the browser as admin:
      add subject (hidden), duplicate slug refused, add topic with act, rename, hide/show with confirms. Local dev DB
      has a hidden test subject "Test Family Law" (test-family-law) with topic test-marriage.
      OpenQodex review (agent mode) found the topics server actions put an unchecked `kind` into the API path (fixed:
      only subjects / topics / acts are accepted). Pushed `fcf6ec9`, CI green, staging deployed (no migration).

- [x] 2026-10-30: **Staff accounts (P2 step 4, M10).** Portal → **Staff** (link in the top-right menu, admins only):
      list (Active / Waiting to set a password / Link expired / Disabled), add a person (name, email, roles) → a
      **one-time setup link** shown once with a Copy button (valid 7 days; the admin sends it themselves — no email
      service), edit name/roles, Disable/Enable, New setup link (old password stops working, signed out everywhere).
      Public page `/setup#token=…` (the token is after `#`, so it never reaches a server log; the proxy lets `/setup`
      through) → choose a password (≥ 12 characters for staff) → `/login?password_set=1`. API
      (`backend/src/staff/`): `GET/POST /v1/admin/staff`, `PATCH /v1/admin/staff/:id`, `POST
      /v1/admin/staff/:id/setup-link` (all admin-only), public `POST /v1/auth/setup-password` (rate-limited like
      sign-in). Rules: you can't remove your own admin role or disable yourself; there's always an active admin
      (row locks cover two admins acting at once); emails that already have an account → 409 `email_taken`; learner
      accounts can't be changed here; disabling revokes refresh tokens, and roles/`is_active` are read on every
      request, so changes apply at once. Invited people get a random unusable password until they use the link.
      **3NF:** `staff_setup_tokens` (user, SHA-256 of the token, who made it, when, expiry, used_at); a newer link
      deletes unused older ones; "waiting" is derived from an unused token. Migration 0010. Audit: staff.invited,
      staff.updated (before/after), staff.setup_link_created, staff.password_set. Tests: backend 65 unit + 93 API.
      Checked in the browser as admin: invite, setup page (mismatch caught), new person signs in via the API with
      the right role, disable/enable, own admin role refused. Local dev DB has a test staff account
      test.reviewer@nyaya.local (legal reviewer). Staging still uses the shared dev staff accounts and SEED_PASSWORD;
      `deploy.sh --seed` resets their passwords — now real staff can be invited instead.
      OpenQodex review (agent mode) found an admin could make a new setup link for themselves and get locked out
      (fixed: refused with `own_account`, button hidden on your own row). Pushed `7cf26b9`, CI green; staging
      deployed (backup `nyaya-2026-10-30-0426.sql.gz` first, migration 0010 applied). Noticed, older than this: the
      portal calls the API from its own server, so the API's sign-in rate limit treats all portal users as one
      client — a few wrong passwords make everyone wait a minute. Fixed 2026-10-31 (shared sign-in limits, below).

- [x] 2026-10-30: **P4 decisions (user):** crash reporting = **Sentry** (app, API, portal; the user creates the
      account and gives the DSNs) + usage analytics as **our own events** in our database with a portal dashboard
      (no learner data to third parties); **premium hidden** in the beta; **production hosting: decide later**;
      **beta audience: citizens**. P4 order (hosting-free first): hide premium [done] → in-app account deletion [done] →
      Sentry [done: app, API, portal] → own analytics (done, calculated from existing records) + dashboard → minimum app version [done] → translations of English-only screens [done] →
      accessibility + dark mode pass [done] → shared sign-in rate limit [done] → rotate the Azure key (user) → store prep.
- [x] 2026-10-30: **Premium hidden for the beta.** App: build switch `Features.premium`
      (`lib/core/config/features.dart`, `--dart-define=NYAYA_PREMIUM=true` to show it) hides the post-onboarding
      paywall, the Settings premium row, the out-of-energy "Get unlimited energy" button and the Ask AI "upgrade"
      button; `/premium` redirects home. Ask AI limit text without premium: `chatLimitReachedToday` (6 languages).
      API: `DEMO_PREMIUM` setting (default off; documented in `backend/.env.example`): off → `POST /v1/me/premium`
      404 `premium_unavailable` and existing demo memberships count for nothing (`isPremium(..., { demo })`), so
      everyone gets the free limits; other sources (future store purchases, tests) still count. Tests: backend 65
      unit + 94 API (economy test runs with demoPremium on; new test for the beta behaviour), Flutter 41. Checked
      on the simulator: Settings → Store shows only Streak freeze. The old unused Home premium banner widget was left.
      Review fix: the first sync after sign-in no longer uploads old local demo premium while premium is hidden.
      Pushed `93a552e`, CI green, staging deployed (DEMO_PREMIUM unset there; the 1 demo membership on staging now
      counts for nothing). The iPhone's current build still shows premium screens until it is rebuilt.

- [x] 2026-10-30: **In-app account deletion (P4; Apple and Google require it).** App: Settings → Account → **Delete
      account** (red, only while signed in) → dialog that says what goes (progress, XP, coins, saved questions,
      league place; can't be undone) and asks for the password; wrong password → "That password is not right." and
      the dialog stays; success → the phone is cleared (profile, journey, chat) and onboarding starts again
      (`lib/features/settings/presentation/delete_account_dialog.dart`, `AuthApi.deleteAccount`). Strings in all 6
      languages. API: `POST /v1/me/delete-account` {password} → 204 (POST so no client or proxy drops the body;
      rate-limited like sign-in; 403 `wrong_password`; 409 `staff_account` — staff are removed by admins). The
      account row goes, and with it (FK cascade) wallet and energy ledgers, settings, premium, bookmarks, chest
      openings, league places, chat counts and refresh tokens; quiz sessions and the learner's own audit entries are
      deleted in the same transaction; **reports they sent stay for editors with the name removed** (user_id set
      null) **and the free-text comment cleared** (review finding: it may hold personal details; reason and
      question stay); one bare `account.deleted` audit entry (no actor, no data) is the only trace. Their
      old access token fails at once (the guard finds no user); the email can be registered again. Tests: backend
      65 unit + 97 API (new `account-deletion.e2e-spec.ts`: everything removed, wrong password changes nothing, staff
      refused, other accounts untouched), Flutter 42 (new flow test). Checked on the iPhone simulator against the
      local API with a throwaway account: dialog, wrong password, deletion → back to "Choose your language", and a
      sign-in with the deleted account → 401. No migration. iOS Simulator gotcha: its "Strong Password" sheet
      swallows typing in sign-up password fields — dismiss it (X), then select-all, delete, type.
      Review fix: report comments are cleared on deletion. Also: the economy test that starts a second API had the
      default 5 s test limit and failed once under load — now 30 s. Pushed `98fb79d`, CI green, staging deployed
      (no migration). The iPhone needs a new build to get the Delete account row.

- [x] 2026-10-30: **Sentry crash reporting in the app (P4).** Sentry org `deepwebstudio`, project `flutter` (the user
      created it; the API and portal projects are not made yet). `sentry_flutter` pinned **10.1.0** (15 days old when
      chosen; pub's newest was 10.2.0, 8 days). Off unless built with `SENTRY_DSN`; `Monitoring`
      (`lib/core/monitoring/monitoring.dart`) wraps `main`. Errors only: no performance traces, screenshots, view
      hierarchy, tap breadcrumbs or personal details (`sendDefaultPii` off, no user set). `worthReporting` drops normal
      life — offline, timeouts, `http` client errors and the API's own refusals (`ApiException` < 500) — and keeps
      server faults (5xx) and anything unexpected. **The key is not in the repo (it is public):** it lives in the
      git-ignored `/.dart-defines.local.json` ({"SENTRY_DSN": …}) and is passed with `--dart-define-from-file=
      .dart-defines.local.json` (add `--dart-define=NYAYA_API_URL=…` for staging; `SENTRY_ENV` defaults to
      release/debug). Debug builds with a key show Settings → About → "Send a test error (debug)" (never shown to
      learners). Also corrected the Privacy text (progress is saved to the account, not the device; AI questions go
      to the provider; crash reports carry no answers or personal details; account deletion is in Settings) in all
      6 languages. Tests: Flutter 44 (new `monitoring_test.dart`), backend unchanged. Checked on the iPhone simulator
      with the key: the test error was sent ("Test error sent"; no errors in the app log). **To confirm in Sentry:**
      Issues → "Nyaya test error: Sentry is connected". Not done: uploading iOS/Android debug symbols so crash
      stack traces are readable (needs a Sentry auth token; do it with store prep), Sentry for the API and portal
      (need their DSNs), alerts.

- [x] 2026-10-30: **Usage analytics and the portal Analytics page (P4, M11).** Almost every event in the plan's
      analytics sheet was already stored as ordinary rows, so the dashboard is **calculated from existing records**
      (no event stream, nothing extra tracked): sign-ups (`users`), onboarding (`learner_settings.onboarded_at`),
      quiz started / finished and score (`quiz_sessions`), answers and correctness (`quiz_session_questions`), AI
      questions (`chat_usage`), reports (`content_reports`). The only new data is **`app_opens`** (user, India
      date; PK on both; cascade-deleted with the account; migration 0011): the app calls `POST /v1/me/app-open`
      on start, resume and sign-in, at most once a day (`ProgressSync.noteOpen`; quiet when signed out/offline).
      API (`backend/src/analytics/`): `GET /v1/admin/analytics/overview?days=7|30|90` (**admin + analyst only**):
      learner totals (total, new, onboarded, finished a quiz), active today / 7 d / 30 d, a daily series (new,
      active, quizzes started / finished, AI answers), D1 / D7 / D30 retention over the last 90 days of sign-ups
      (only people old enough to measure; "active" = opened the app, started a quiz or asked the AI on exactly that
      day), quizzes by mode (started, % finished, average score), and content health (open reports, reports in
      the period, the 10 most-missed questions with ≥ 5 final answers; unsubmitted exam answers don't count).
      Learner accounts only (staff left out); no names or emails anywhere; India dates throughout. Portal →
      **Analytics** (link in the top-right menu for admins and analysts): period tabs, four stat tiles, four
      plain-SVG bar charts (each also a hidden table for screen readers), retention table (shows "—" under 5
      measured people), modes table, and "Questions to look at" linking to each question. Privacy text updated
      (6 languages) to mention the days a learner opens the app. Tests: backend 65 unit + 102 API (new
      `analytics.e2e-spec.ts` with exact expected numbers for retention, activity, modes, the hardest-question
      ranking and the exam rule), Flutter 46. Checked in the browser against a throwaway demo database (48 fake
      learners, 60 days; built outside the project) — all sections, the 7-day view, phone-width layout. Not done:
      funnels by screen, per-topic breakdown, export, error rates (Sentry covers errors), an alert on a sudden drop.
      Pushed `ec11ef2`, CI green; staging deployed (backup `nyaya-2026-10-30-0603.sql.gz` first, migration 0011
      applied; `app_opens` empty until phones on a new build open the app). Not yet looked at on staging with a
      real sign-in (the staging admin password is only on the server). The iPhone needs a new build to send the
      daily app-open.

- [x] 2026-10-30: **Minimum app version check (P4).** The API has a public `GET /v1/app-config` →
      `{ min_app_version, update_url }` (`backend/src/appconfig/`), set by two optional environment values:
      `MIN_APP_VERSION` (three numbers like `0.2.0`; unset = block nobody) and `APP_UPDATE_URL` (an https store
      link); a wrong value stops the API at start with a clear message (`backend/src/core/config.ts`). Both are
      passed through `deploy/staging/docker-compose.yml` (empty by default) and documented in `backend/.env.example`.
      To block old builds: set `MIN_APP_VERSION` in `/opt/nyaya-v2/.env` on the server and restart the API (no new
      migration, no new app build needed). App (`lib/features/update/`): on start and on every resume it asks the
      server, compares with its own version (`package_info_plus`, from the bundle's `version:` in pubspec; the
      `+build` number is ignored) and, if older, shows only a full-screen "Please update Nyaya" page in all 6
      languages with an **Update** button that opens the store link (https only; no button without a link).
      Offline, slow or unreadable replies never block anyone; the last answer stands until a new one arrives.
      Builds made **before** this one don't ask, so they can't be blocked: this protects future builds only.
      Tests: backend 67 unit + 104 API (new `appconfig.e2e-spec.ts`, config checks), Flutter 55 (new
      `update_check_test.dart`: version order incl. 0.9 vs 0.10, unreadable versions, offline, widget screens).
      Not done: a "new version available" nudge for non-blocking updates; setting the minimum from the portal.
      Pushed `1dd6a2e`, CI green, staging deployed (no migration, so no backup; without `--seed`). `/v1/app-config`
      answers `{min_app_version: null, update_url: null}` on staging: nothing is blocked until `MIN_APP_VERSION` is set in
      `/opt/nyaya-v2/.env` and the API restarted.

- [x] 2026-10-30: **Translations of the English-only screens (P4).** 111 texts were missing in each of Hindi, Tamil,
      Telugu, Kannada and Malayalam (onboarding intro and demo cards, sign-in and sign-up, Explore Law home and the
      law names, Review (mistakes and saved), report-a-problem, save/report buttons, quiz error messages, journey,
      leaderboard, updates save). They are now all in `lib/l10n/app_<lang>.arb`, so those screens no longer fall
      back to English. Drafted by Sonnet translators from the existing wording in each file, then checked by script
      (same keys, same placeholders, plural forms kept) and by eye in Tamil on the simulator (home and sign-up
      screens). New test `test/l10n_test.dart` fails if any language lacks a text English has, has an extra one, or
      changes a placeholder, so a new screen can't ship English-only by accident. **These are machine drafts: have a
      native speaker of each language read them before the beta** (the translators were least sure of: "Review"
      as a screen title, the tagline "Learn Law. Live It.", "Practice player", sign in/out wording, and the
      spellings of Bharatiya Sakshya Adhiniyam in each script). Still English: the sample legal-update articles
      (content, due to come from the portal), the questions themselves (the bank is English only), AI answers, and
      the debug-only Sentry test row. Flutter tests: 60.

- [x] 2026-10-30: **Sentry for the API and the portal (P4).** The Sentry plugin was installed for Claude Code and signed
      in; the two projects were created through it in org `deepwebstudio`: **`nyaya-api`** (Node/NestJS) and
      **`nyaya-portal`** (Next.js). Both keys (DSNs) are **not in git**: they go in `/opt/nyaya-v2/.env` on the server
      as `API_SENTRY_DSN` and `PORTAL_SENTRY_DSN` (docker-compose passes them on; empty = nothing reported). Same
      privacy rules as the app: **errors only**: no user, cookies, headers, request bodies, query strings, local
      variables, breadcrumbs, traces, replay or release-health sessions (SDK 11's `dataCollection` switches are all off; the
      session integrations are removed; a test checks that only error events are sent even when a release name is set). **API**
      (`backend/src/core/monitoring.ts`, `@sentry/node` 11.7.0 pinned): started in `main.ts` when `SENTRY_DSN` is set;
      the error filter reports every **unexpected** error (a real fault, not a 4xx and not a 5xx the code throws on purpose
      such as "AI chat not set up" or "AI service did not answer") with the request id as a tag; crashes and unhandled rejections are
      caught too; database error text after `params:` (which holds the query values, e.g. an email) is cut out. **Portal**
      (`cms/src/instrumentation.ts`, `instrumentation-client.ts`, `global-error.tsx`, `lib/monitoring.ts`,
      `@sentry/nextjs` 11.7.0 pinned): server errors through Next's `onRequestError`, browser errors through
      `instrumentation-client`, and a "Something went wrong / Try again" page that reports; the page address is kept
      without its query string and without the part after `#` (the staff setup link's one-time token). The browser key
      is built into the page, so the Dockerfile takes `NEXT_PUBLIC_SENTRY_DSN` / `NEXT_PUBLIC_SENTRY_ENV` as build args
      (compose sets the environment name `staging`). Checked for real: a test error reached `nyaya-api`
      (NYAYA-API-1) and, from a production build with throwaway failing pages (removed), a server error and a browser
      error reached `nyaya-portal` (NYAYA-PORTAL-1 and -2); the email in the query string and the `#token` were gone
      from the stored address. Tests: backend 71 unit (new `monitoring.spec.ts` runs the real reporting path against a
      fake transport: the email inside a database error is removed, no user/request/breadcrumbs, 4xx not sent,
      a deliberate 503 not sent, a plain error sent) + 104 API. **User still to do in Sentry:** switch on **"Prevent Storing of IP Addresses"**
      (Settings → Security & Privacy; Sentry adds a city-level "user.geo" from the sender's IP otherwise) for all
      three projects, and resolve/delete the test issues NYAYA-API-1, NYAYA-PORTAL-1/2 (and the Flutter test event).
      Not done: source maps / debug symbols upload (needs a Sentry auth token; with store prep), alert rules (e.g. email
      on a new issue), staging deploy with the keys (see below once done).

- [x] 2026-10-31: **Sentry keys on staging.** The keys (DSNs) for `nyaya-api` and `nyaya-portal` were read through the
      Sentry tools in Claude Code and added to `/opt/nyaya-v2/.env` as `API_SENTRY_DSN` / `PORTAL_SENTRY_DSN`; staging was
      redeployed (no migration, no `--seed`). Checked: API and portal answer 200, both containers see `SENTRY_DSN`, and the
      portal's browser key is built into its page. No test error was sent from staging (it would only add test issues).
      The Sentry tools can't change "Prevent Storing of IP Addresses": **the user still sets that by hand** for all three
      projects, and deletes the old test issues.

- [x] 2026-10-31: **Accessibility and dark mode pass (P4).** New `test/accessibility_test.dart` opens Home, Journey, Ask AI,
      Updates, Leaderboard, Review, Settings, a quiz (before and after a wrong answer), sign-in and onboarding, in **light and
      dark**, and runs Flutter's checks: tap areas at least 48×48 (Android) / 44×44 (iOS), every tappable thing has a label,
      and text contrast (WCAG). It also opens each screen with very large phone text and fails on any overflow. Fixed:
      **text size** follows the phone up to **1.5×** (`maxTextScale` in `lib/app/app.dart`), the most the game layouts hold;
      the Home "Start here" cards and the Settings stat tiles grow with it (and never shrink below their content at small text). `Pressable` no longer tells screen readers that
      plain stats are buttons; tappable `StatPill`s get a 48-point tap area (same look); Journey's star and energy pills
      are read out ("5 energy left"); the chat notice's close button and the Updates save button are full size; the league
      row reads league names instead of emoji; `ChunkyButton` on the theme's own colour uses its text colour (white text on
      light terracotta in dark mode was 2.7:1); chapter names in the quiz header and level sheet are lightened in dark mode
      (`context.readable`). Seen on the simulator in dark mode (Tamil): Home, Journey, Ask AI, Updates, sign-up all fine.
      Also found and fixed there: Journey's header faded out over its second subtitle line when the title wraps (Tamil),
      so the map showed through the text: the header is now solid behind its text with a short fade below; and the wide
      letter spacing on small capital labels split Tamil words apart: spacing is now English-only (`context.tracking`).
      Flutter tests: 93. Reviewed with OpenQodex (run by the coding agent: the Claude Code CLI is not logged in on this Mac). Not covered: VoiceOver/TalkBack by hand on a real phone, the results screen, the portal (web).

- [x] 2026-10-31: **Shared sign-in limits (P4).** Attempt counts moved from each API copy's memory into Postgres
      (`rate_limits`, migration 0012; keys are hashes, no emails or addresses), so every API copy shares them and a
      restart keeps them (`backend/src/core/rate-limits.ts`: `RateLimitStore`, and `SharedThrottlerStorage` for
      @nestjs/throttler). **Per address:** 20 a minute (was 10; `AUTH_RATE_LIMIT_PER_MINUTE`) on sign-in, register,
      refresh, password setup and account deletion. **Per account (new):** 5 password attempts in 15 minutes from any
      address (`PASSWORD_ATTEMPTS_PER_ACCOUNT`), then `429 rate_limited` "Try again in N minutes" even with the right
      password; a right password resets the count; unknown emails count the same (no hint which accounts exist);
      wrong passwords on account deletion count too. Note: anyone who knows an email can keep that account waiting
      15 minutes at a time; accepted. **Portal:** it calls the API from its own server, so all staff shared one limit
      (and one person's wrong passwords, or many staff refreshing, could block everyone). Now sign-in, refresh and
      password setup pass the browser's address (nginx's `X-Real-IP`) in `X-Nyaya-Client-Ip`, trusted by the API only
      with `X-Nyaya-Proxy-Secret` = `PORTAL_PROXY_SECRET` (32+ characters, set on both; `AuthThrottlerGuard`). Staging:
      `deploy.sh` makes the secret once in `/opt/nyaya-v2/.env`; **production must set it on both and keep nginx
      setting `X-Real-IP`**. The app's "too many attempts" text now says "wait a few minutes" (6 languages) and the
      delete-account dialog shows it too. Tests: backend 74 unit + 115 API (new `rate-limits.e2e-spec.ts`), Flutter 93.
      OpenQodex review (agent mode) found the app's "wait a minute" text (fixed). Pushed `a6328bb`, CI green; staging
      deployed (backup `nyaya-2026-10-31-0846.sql.gz` first, migration 0012 applied) and checked: 6th wrong password for
      one email → 429 "15 minutes"; through the portal's header, browser A blocked on its 21st try while browser B and
      a wrong secret were counted apart.

## 3. IN PROGRESS / NEXT STEPS
Session 1 core build is COMPLETE. Candidate next steps (await user's priority):
1. Platform (P1) is done (CI, staging, backups, AI chat through the backend — see 2026-10-28/29).
   P3 is done (server progress Parts 1–3, M08, M12 — see 2026-10-29). Next-phase plan agreed 2026-10-29:
   finish P2 — (1) sources on the questions [done in code, staging review pending], (2) CSV/Excel import + export
   [done], (3) taxonomy pages [done], (4) staff account pages [done], (5) a real reviewer publishes a sample pack —
   then P4 beta hardening (crash reporting, analytics M11, accessibility, translations of English-only screens,
   security/privacy incl. in-app account deletion and rotating the Azure key, store prep with a separate
   production environment), then P5 controlled launch. Open decisions for the user: who the legal reviewer is,
   crash/analytics tool, launch audience, premium during beta, production hosting. Also open: a real all-time
   leaderboard.
2. Dark-mode visual pass: done 2026-10-31 (see above).
3. Note: a debug build launched via `simctl launch` without `flutter run` can show a blank screen —
   use `flutter run -d <device>` (or a release/profile build) when testing.
4. Nice-to-have later: real backend (Firebase) for leaderboard/profile sync, real IAP (RevenueCat /
   `in_app_purchase`), push reminders (`flutter_local_notifications`), live legal-news CMS,
   more chapters/questions, sound effects (setting exists, no audio yet).
5. Before any `git push`: user's global rule = review with the **openqodex** skill.

## 4. Architecture & file map (feature-first, Riverpod 3, go_router 18)
**Important tech notes**
- Uses **`package:material_ui/material_ui.dart`** instead of `package:flutter/material.dart`
  (Material is decoupled in this Flutter version; google_fonts 9 & go_router 18 depend on it).
  Localization delegates: `GlobalMaterialLocalizations.delegates` from material_ui.
- State: `flutter_riverpod` 3 (`Notifier`, `NotifierProvider.autoDispose.family` with constructor arg).
- Persistence: SharedPreferences via `LocalStore` (JSON). Keys: `profile_v1`, `journey_v1`, `chat_v1`.
- l10n: gen-l10n, ARB files in `lib/l10n/` (template `app_en.arb`). Run `flutter gen-l10n` after ARB edits.
  New English keys fall back to English in other languages until translated.
- `dart fix` may convert constructors to private named params (`{required this._client}`) — valid in Dart 3.13.

```
lib/
  main.dart                      # loads SharedPreferences, ProviderScope
  app/ app.dart router.dart shell.dart   # MaterialApp.router, routes, bottom nav shell
  core/
    config/game_rules.dart       # ALL economy numbers (energy, XP, coins, timers, streak milestones)
    l10n/l10n.dart               # context.l10n, tier/persona name helpers
    services/feedback.dart       # haptics respecting settings
    storage/local_store.dart     # SharedPreferences JSON wrapper + clockProvider (testable time)
    theme/app_colors.dart app_theme.dart   # palette, NyayaColors ThemeExtension, light/dark themes
    utils/day.dart               # day keys, ISO week keys, countdowns
    widgets/                     # ChunkyButton (3D), Pressable, StatPill, NyayaCard, ProgressRing,
                                 # GlossyProgressBar, StarRow, InitialsAvatar, TickingBuilder
  features/
    onboarding/   language → 3 slides → persona → daily goal → name → soft paywall → home
    home/         Explore Law home (explore_sections.dart, law_illustration.dart); older game widgets kept unused:
                  header (stats + leaderboard + settings icons), hero "continue", goal+streak week strip,
                  Daily Docket card, 4 modes grid, league card, premium banner, fact of the day, updates
    journey/      domain (catalog: 6 chapters × 3 levels + chest), controller (stars/chests),
                  presentation (layout math, road painter, map nodes, level/chest sheets)
    quiz/         domain (Question, QuizMode, QuizResult, QuizBuilder), data (asset JSON repo w/ locale overlay),
                  application (QuizController w/ timers + duel sim, QuizCompletionService = rewards),
                  presentation (QuizLauncher energy gate + OutOfEnergySheet, QuizView, ResultView)
    gamification/ xp_calculator, daily_policy (energy reset/streak/freeze/week close), league (tiers,
                  simulated cohort, Elo), reward_summary
    profile/      UserProfile model, repository, ProfileController (single owner of economy)
    chat/         ChatRepository: ClaudeChatRepository (HTTP Messages API) + OfflineChatRepository
    legal_updates/ curated repo (10 real landmark items) + list/detail screens
    leaderboard/  weekly league (zones) + all-time podium
    premium/      PurchaseService (DemoPurchaseService) + paywall
    settings/     profile, stats, store (streak freeze), language/persona/goal, theme, toggles, reset
assets/questions/{en,hi,ta,te,kn,ml}.json   # en = authoritative answers; others overlay text by id
test/  gamification_test.dart content_test.dart app_flow_test.dart
```

## 5. Key product decisions (from research)
- **Quiz modes (4):** Case Path (map, 6 Qs, no timer, pass ≥50%, stars 50/80/100%, 1⚡) ·
  Daily Docket (5 Qs, 30s each, same set for everyone, ALWAYS FREE, 1.25× XP, once/day) ·
  Moot Court Duel (7 Qs, 15s, Kahoot points 500–1000, vs simulated rated opponent, hidden Elo, 1⚡) ·
  Exam Chamber (20 Qs / 20 min, +1/−0.25, no negative marking for citizens, review at end, 2⚡).
- **Energy:** 5/day free, resets local midnight; premium = unlimited. Charged at quiz start, refunded if
  quit before first answer. 3-star clear refunds +1⚡. Refill 1⚡ for 30 coins. Out-of-energy sheet always
  offers free paths (Docket, AI chat, updates) → no dead ends.
- **XP:** qXP = (10 + speed 0–5 + combo +2/step from 3rd correct, cap +6) × difficulty (1/1.25/1.5/2);
  + completion 10 + perfect 10; × streak multiplier (1.0/1.1/1.2/1.3 at 0/3/7/30 days). Never negative.
  Premium never boosts XP (fair leagues).
- **Leagues (weekly, 30-person cohorts, Mon–Sun):** Nyaya Panchayat → Gram Nyayalaya → Munsiff →
  Magistrate → District → Sessions → High Court → Supreme Court. No demotion in 2 entry tiers.
  Real groups on the server since 2026-10-29, topped up with practice players (`LeagueSimulator` in the app is now
  only used by the unused old Home widgets).
- **Streak:** 1 quiz/day; up to 2 freezes (free at 7/30/100-day milestones; buying with 100 coins and premium's 2
  are off until coins move to the server). Worked out by the server since 2026-10-29.
  Milestones 3/7/14/30/50/100/365 give coins.
- **Palette (2026-10-26, user-finalised): "Terracotta × Sand"** — Terracotta #873F2B primary, Burnt Clay
  #B96243 accents/streak, Sand #D9B994 borders/surfaces, Warm Cream #F5EBDD background, Deep Earth #302923 text.
  Mix 60/20/15/5. No purple, neon, metallic or decorative gradients (all fills flat). Ochre #C28A2C for
  XP/stars (fills only), Moss/Brick for success/error. Full table in docs/DESIGN.md §3; tokens in
  `core/theme/app_colors.dart`. Native launch screens use Warm Cream. Fonts: Plus Jakarta Sans + DM Serif Display.
- **AI (before 2026-10-29, replaced by the backend + Azure):** Claude Messages API via HTTP, model `claude-opus-5-5`, effort medium, `fallbacks: "default"`
  (beta header `server-side-fallback-2026-07-01`), handles `stop_reason: refusal`, re-sends raw assistant
  content blocks (append-only history). Config via `--dart-define=NYAYA_AI_KEY=... NYAYA_AI_BASE_URL=...`.
  **Production must use a backend proxy** — never ship a raw key. No key → offline canned answers.
  Free users: 5 AI answers/day; premium unlimited.

## 6a. Running on the user's physical iPhone
- Device: Gowtham's iPhone 15 Plus, iOS 26.6.2, Flutter id `00008120-000A511821E0A01E`.
- Signing: team `2DLQ9MAY76` (in project.pbxproj), cert "Apple Development: yazhinimarimuthu@gmail.com".
- Use **release** builds on device (`flutter run --release -d 00008120-000A511821E0A01E`); debug builds
  won't relaunch without the Flutter tool attached.
- First install requires the user to trust the developer profile on the phone:
  Settings → General → VPN & Device Management → Developer App → Trust. (Done 2026-10-26; app launched OK.)
- Manual install/launch: `xcrun devicectl device install app --device <id> build/ios/iphoneos/Runner.app`
  then `xcrun devicectl device process launch --device <id> ai.bigtapp.nyaya`.
- Web support was requested then cancelled by the user — no web platform added.

## 6. How to run
```bash
flutter pub get && flutter gen-l10n
flutter run                                   # offline AI mode
flutter run --dart-define=NYAYA_AI_KEY=sk-... # live AI (dev only)
flutter test
```
iOS simulator used: iPhone 17 Pro Max (`F7B886EB-4774-42E1-B77B-43FD22DA4455`).

## 7. Known issues / caveats
- Leaderboard, purchases and legal news are local/simulated behind repository interfaces.
- Legal updates content is English-only (labelled "Shown in English" in other locales).
- Question bank notes from author agent: BNS s.106(2) hit-and-run deliberately excluded (in-force status
  unclear); Art. 22(4) answer is "3 months" (44th Amendment change never notified).
- `soundOn` setting has no audio implementation yet.
