# Nyaya — Project Status (handoff file)

> **Read this first.** This file is the offline context for any AI assistant or developer
> picking up the project. Keep it updated after every meaningful step.
> Last updated: 2026-10-22 22:45 (end of session 1, Claude Opus 5.5)

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

## 3. IN PROGRESS / NEXT STEPS
Session 1 core build is COMPLETE. Candidate next steps (await user's priority):
1. Git: repo initialised on `main`, first commit `196495a` ("Initial commit: Nyaya…"). Repo-local identity
   Gowtham <gowtham.s@bigtapp.ai>. No remote yet. User rule: review with the **openqodex** skill before any push.
2. Dark-mode visual pass on simulator (theme exists, not yet eyeballed).
3. Note: a debug build launched via `simctl launch` without `flutter run` can show a blank screen —
   use `flutter run -d <device>` (or a release/profile build) when testing.
4. Nice-to-have later: real backend (Firebase) for leaderboard/profile sync, real IAP (RevenueCat /
   `in_app_purchase`), push reminders (`flutter_local_notifications`), live legal-news CMS,
   more chapters/questions, sound effects (setting exists, no audio yet).
5. Before any `git push`: user's global rule = review with the **openqodex** skill. (Repo not yet a git repo.)

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
    home/         header (stats + leaderboard + settings icons), hero "continue", goal+streak week strip,
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
- **Palette:** Indigo #1E2A78 primary, Saffron Gold #F2A900 (fills only, never text on light),
  Saffron #FF7A1A streak, Green #15803D success, Red #C62828 error, Parchment #FAF7F0 bg,
  Ink #14182B text; dark bg #0B1026. Fonts: Plus Jakarta Sans (UI) + DM Serif Display (display).
- **AI:** Claude Messages API via HTTP, model `claude-opus-5-5`, effort medium, `fallbacks: "default"`
  (beta header `server-side-fallback-2026-07-01`), handles `stop_reason: refusal`, re-sends raw assistant
  content blocks (append-only history). Config via `--dart-define=NYAYA_AI_KEY=... NYAYA_AI_BASE_URL=...`.
  **Production must use a backend proxy** — never ship a raw key. No key → offline canned answers.
  Free users: 5 AI answers/day; premium unlimited.

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
