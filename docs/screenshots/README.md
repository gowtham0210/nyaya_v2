# Nyaya app screenshots

Taken on 1 November 2026 on the iPhone 17 Pro Max simulator (1320 × 2868 px), debug build,
light theme unless the folder says otherwise. The app ran against the local API (`backend/`)
with `--dart-define=NYAYA_PREMIUM=true`, so the Premium screens show. Data comes from a
throwaway local test account.

| Folder | What it shows |
|---|---|
| `01-onboarding` | Language, 3 intro slides, "who are you", daily goal, name, Premium offer at the end |
| `02-home` | Home (top, middle, bottom) and Home for a returning learner |
| `03-journey` | Case Path map, level sheet, map after one level, chapter chest |
| `04-quiz` | Question, wrong / correct answer, report sheet, leave dialogs, combo, results, Daily Docket, Moot Court Duel, Exam Chamber |
| `05-ask-ai` | Chat start and an answer |
| `06-legal-updates` | Updates list and one update |
| `07-account` | Create account and sign in |
| `08-leaderboard` | Weekly league and all-time |
| `09-settings` | Settings page, pickers and dialogs |
| `10-review` | Mistakes and Saved tabs |
| `11-premium` | Premium paywall |
| `12-dark-mode` | Main screens in the dark theme |
| `99-bugs-found` | Problems seen while taking these |

## Not captured

- Out-of-energy sheet (needs energy at 0).
- "Update required" screen (needs the server to demand a newer version).

## Problems seen

1. **Fixed: Edit name → Cancel showed a red error screen.** The name box's text controller
   was disposed while the dialog was still closing. Before the fix:
   `99-bugs-found/01-edit-name-cancel-crash.png`.
2. **Fixed: emoji showed as "?" boxes.** Flutter on iOS (Impeller) drew every emoji as a box,
   even with Apple's emoji font named directly, so they are now icons or words.
   `03-journey/02-level-sheet.png` and `08-leaderboard/01-weekly-league.png` were retaken after
   the fix; `01-onboarding/06-daily-goal.png` and `08-leaderboard/02-all-time.png` still show
   the old boxes.
3. **Timer keeps running behind "Leave this quiz?"** in Daily Docket (26 s → 9 s while the
   dialog was open). See `04-quiz/10-leave-before-answering-dialog.png`.
4. **Premium screen status bar** uses dark text on the dark background, so the time is hard to read.
