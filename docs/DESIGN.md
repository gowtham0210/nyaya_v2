# Nyaya — Product & UX Design

This document records the research behind Nyaya's design and the decisions taken from it. All
tunable numbers live in `lib/core/config/game_rules.dart`.

## 1. Audience
| Persona | Need | How the app adapts |
|---|---|---|
| **Advocate** | Sharpen recall of sections, procedure, landmark cases | Docket/Exam pull medium–hard questions; AI answers are precise with citations |
| **Law aspirant** (CLAT, AIBE, judiciary) | Exam practice, consistency | Exam Chamber with +1/−0.25 marking; AI adds exam tips |
| **Citizen** | Know rights, everyday law | Easier pools, Exam without negative marking ("Know your rights"); AI uses plain language |

## 2. Quiz modes (max 4)
Researched: Duolingo (path + timed challenges), Kahoot (Classic speed scoring / Accuracy /
Confidence), Trivia Crack (Classic / Survival / Triviathon), QuizUp (real-time topic battles), and
CLAT prep apps (mocks, daily current-affairs quizzes, percentile reports).

| Mode | Rules | Energy | Why |
|---|---|---|---|
| **Case Path** | Level map, 6 questions, no timer, instant feedback, pass ≥50%, stars at 50/80/100% | 1 ⚡ | Core progression loop (Duolingo/Candy Crush). Every 3rd level is a gold-framed "Landmark". |
| **Daily Docket** | 5 questions, 30 s each, same set for everyone today, once a day, ×1.25 XP, shareable 🟩🟥 grid | **Free** | Habit anchor; guarantees the streak can never be blocked by energy. |
| **Moot Court Duel** | 1v1, 7 questions, 15 s each, Kahoot points `1000 × (1 − t/2T)`; hidden Elo matchmaking | 1 ⚡ | Social competition and speed. Opponent is simulated until a backend exists. |
| **Exam Chamber** | 20 questions / 20 min, +1 / −0.25 (none for citizens), review at end | 2 ⚡ | Exam realism for aspirants and advocates. |

Lightning/Survival rounds are better as limited-time events than as a 5th mode.

## 3. Visual design
**Palette: "Nyaya Indigo + Saffron Gold".** Navy is the dominant trust/authority colour. Gold used
sparingly raises perceived value. Saffron and green echo the tricolour.

| Token | Hex | Contrast |
|---|---|---|
| Primary (Indigo) | `#1E2A78` | white text 12.67:1 |
| Accent (Saffron Gold), **fills only** | `#F2A900` | ink text 8.74:1; gold text on light fails (3.04:1), so it is never used for text |
| Streak/energy (Saffron) | `#FF7A1A` / `#F59E0B` | |
| Success | `#15803D` | white 5.02:1 |
| Error | `#C62828` | white 5.62:1 |
| Background (Parchment) | `#FAF7F0` | ink 16.42:1 |
| Text secondary | `#5A6178` | 5.75:1 |
| Dark bg / surface | `#0B1026` / `#151C3B` | dark text 16.5:1 |

- Typography: Plus Jakarta Sans (UI) + DM Serif Display (headlines). The serif gives a "legal" feel.
  Indic scripts fall back to system fonts.
- Game feel: 3D "chunky" buttons, press-scale, glossy progress bars, elastic star pops, confetti only
  for 3 stars, wins and milestones (rare celebrations stay meaningful), haptics on every answer.
- Wrong answers: brief red, shake, then always the explanation and citation. Mistakes teach; they
  don't punish.

## 4. UX principles applied
- **Hook loop** (trigger → action → variable reward → investment): daily reminder and Docket
  (trigger), one-tap Play on Home (action), stars, chests, combos and league jumps (variable reward),
  streaks, stars and progress (investment).
- **Time-to-value under 60 s**: language → 3 value slides → persona → daily goal → name → soft paywall
  (skippable) → Home with a single primary action.
- **Streaks**: one quiz a day keeps it. Up to 2 freezes. Milestones at 3/7/14/30/50/100/365 days give
  coins, and free freezes at 7/30/100. "Commit to my goal" copy.
- **No flow breakage**:
  - Energy is charged at quiz start, never mid-quiz, and refunded if you quit before answering or the
    quiz fails to load.
  - The paywall never appears mid-quiz.
  - The out-of-energy sheet always offers free paths: Daily Docket, AI chat, updates, or a midnight
    countdown.
  - Unknown deep links land on Home. Missing translations fall back to English per question.
  - The quiz and its results share one route, so Back can't return to a finished quiz.
- **Anti-discouragement leagues**: you join only after earning XP that week. There is no demotion in
  the two entry tiers. Ties go to the user. Promotion and demotion zones are shown clearly.
- **Premium placement**: a soft paywall after onboarding (converts about 2× better than in-app
  placement, per Adapty data). Contextual paywalls appear at energy-out and the AI limit. Premium never
  boosts XP, which keeps leagues fair.

## 5. Economy
- **Energy**: 5 a day (resets at local midnight). Costs: Case Path 1, Duel 1, Exam 2, Docket 0.
  A 3-star clear refunds 1. Refill 1 energy for 30 coins. Premium is unlimited.
- **XP per question**: `(10 + speed 0–5 + combo) × difficulty`.
  - Speed bonus = `round(5 × max(0, 1 − t/T))`.
  - Combo: +2 per step from the 3rd consecutive correct, capped at +6.
  - Difficulty multiplier: 1 / 1.25 / 1.5 / 2.
- **XP per session**: `(Σ question XP + 10 completion + 10 perfect) × streak multiplier`.
  - Streak multiplier: 1.0 / 1.1 / 1.2 / 1.3 at 0 / 3 / 7 / 30 days.
  - Daily Docket ×1.25. A replay of a 3-star level pays ×0.5. A duel win adds +15.
  - XP is never negative.
- **Coins**: 5 per new star, chest +30, Docket +10, daily goal +15, duel win +10, top 3 in a league week +50.
- **Duel rating**: hidden Elo, K = 32 for the first 20 duels and 16 after. It is kept separate from XP
  (skill vs effort).

## 6. Leagues (weekly, 30-person cohorts, Monday 00:00 to Sunday 23:59)
| # | Tier | Promote | Demote |
|---|---|---|---|
| 1 | Nyaya Panchayat 🌿 | top 15 | – |
| 2 | Gram Nyayalaya 🏡 | top 12 | – |
| 3 | Munsiff Court 📜 | top 10 | bottom 5 |
| 4 | Magistrate Court 🔨 | top 10 | bottom 5 |
| 5 | District Court 🏛️ | top 7 | bottom 5 |
| 6 | Sessions Court ⚖️ | top 7 | bottom 5 |
| 7 | High Court 🦁 | top 5 | bottom 5 |
| 8 | Supreme Court 👑 | – | bottom 5 |

## 7. AI assistant
- Calls the Claude Messages API (`claude-opus-5-5`, effort `medium`) with a persona- and
  language-aware system prompt. The prompt says to cite BNS/BNSS/BSA with old IPC/CrPC equivalents,
  stay concise, give no legal advice, refer to NALSA 15100 and 112, and refuse unlawful requests.
- Server-side refusal fallback is on (`fallbacks: "default"`), and `stop_reason: refusal` is handled.
- History is append-only: raw assistant content blocks are sent back unchanged.
- Free users get 5 answers a day; Premium is unlimited. With no key configured, an offline answer set
  covers common topics.
- **Production:** route requests through your own backend proxy that holds the key. Never ship a key
  inside the app.

## 8. Sources
- Duolingo: streak habit research, Energy, and Leagues design (via the Duolingo blog, Lenny's
  Newsletter and the Deconstructor of Fun teardown).
- Kahoot game modes (support.kahoot.com). Candy Crush lives (King patent 9873050).
- *Hooked* model (fs.blog/hooked). RevenueCat 2026 subscription benchmarks. Adapty and Airbridge paywall
  studies.
- Leaderboard discouragement research (Internet Research 33(7); LMU Munich; ICCE).
- WCAG 2.1 contrast minimums (w3.org).
