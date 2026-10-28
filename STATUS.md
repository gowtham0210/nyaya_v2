# Nyaya — Project Status (handoff file)

> **Read this first.** This file is the offline context for any AI assistant or developer
> picking up the project. Keep it updated after every meaningful step.
> Last updated: 2026-10-27 (Flutter app on the backend, Claude Opus 5.5)

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

## 3. IN PROGRESS / NEXT STEPS
Session 1 core build is COMPLETE. Candidate next steps (await user's priority):
1. Platform (P1) still to do: CI on push (backend tests + CMS build + Flutter tests), a staging deploy
   (managed Postgres, API, CMS, real secrets incl. `JWT_SECRET`), and route AI chat through the backend.
   Then P3: M08 bookmarks/mistake review, M12 report-a-question, server-side progress and exam marking.
2. Dark-mode visual pass on simulator (Terracotta dark theme exists, not yet eyeballed).
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
  Cohort is simulated deterministically (`LeagueSimulator`) until a backend exists.
- **Streak:** 1 quiz/day; up to 2 freezes (100 coins, or free at 7/30/100-day milestones; premium gets 2).
  Milestones 3/7/14/30/50/100/365 give coins.
- **Palette (2026-10-26, user-finalised): "Terracotta × Sand"** — Terracotta #873F2B primary, Burnt Clay
  #B96243 accents/streak, Sand #D9B994 borders/surfaces, Warm Cream #F5EBDD background, Deep Earth #302923 text.
  Mix 60/20/15/5. No purple, neon, metallic or decorative gradients (all fills flat). Ochre #C28A2C for
  XP/stars (fills only), Moss/Brick for success/error. Full table in docs/DESIGN.md §3; tokens in
  `core/theme/app_colors.dart`. Native launch screens use Warm Cream. Fonts: Plus Jakarta Sans + DM Serif Display.
- **AI:** Claude Messages API via HTTP, model `claude-opus-5-5`, effort medium, `fallbacks: "default"`
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
