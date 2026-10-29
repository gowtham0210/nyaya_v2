# Nyaya ⚖️ — Learn Indian law, one case a day

A gamified Flutter quiz app on Indian law for advocates, law aspirants and citizens. It has a
Candy-Crush-style level map, four quiz modes, daily energy, streaks, weekly court-themed leagues, an
AI legal assistant and a legal-updates feed. It is available in English, हिन्दी, தமிழ், తెలుగు, ಕನ್ನಡ
and മലയാളം.

> **Picking this project up?** Read [`STATUS.md`](STATUS.md) first. Design rationale is in
> [`docs/DESIGN.md`](docs/DESIGN.md).

## Run
```bash
flutter pub get
flutter gen-l10n
flutter run
```

### AI assistant (Ask AI)
Answers come from the Nyaya API (`POST /v1/chat`), which calls an Azure OpenAI deployment and keeps
the key on the server; the app holds no AI key. Asking needs an account. Without a reachable API, or
when the API has no AI configured, the app answers common topics from built-in offline answers.
Server settings: `AZURE_OPENAI_ENDPOINT`, `AZURE_OPENAI_API_KEY`, `AZURE_OPENAI_CHAT_DEPLOYMENT`
(default `gpt-5.4-mini`) and `CHAT_DAILY_LIMIT` (answers per learner per day, default 50).

## Test
```bash
flutter test
```
The suite runs 34 tests:
- Unit tests for the economy (XP, streaks, leagues, Elo, dates).
- Content checks on the question bank and all 5 translations.
- End-to-end widget flows: onboarding, playing a full level, and running out of energy.

## Structure
The code is organised by feature, and each feature has layers: `domain/` holds pure models and rules,
`data/` holds repositories, `application/` holds Riverpod controllers and `presentation/` holds widgets.

```
lib/app       router, bottom-nav shell, MaterialApp
lib/core      theme, game rules, storage, l10n helpers, shared widgets
lib/features  onboarding · home · journey · quiz · gamification · profile · chat · legal_updates ·
              leaderboard · premium · settings
assets/questions/<lang>.json   question bank (en is authoritative, other languages overlay the text)
lib/l10n/app_<lang>.arb        UI strings
```

Every external dependency sits behind an interface, so production versions can be swapped in without
touching the UI:

| Interface | Current implementation | Production replacement |
|---|---|---|
| `QuestionRepository` | bundled JSON | CMS |
| `ChatRepository` | Claude, or offline answers | — |
| `LegalUpdatesRepository` | curated list | news API |
| `PurchaseService` | demo | RevenueCat or in_app_purchase |
| League cohort | `LeagueSimulator` | backend |

## Adding questions
1. Add entries to `assets/questions/en.json`, using ids like `<prefix>_<level>_<nn>`.
2. Add the same ids to each `<lang>.json`, with the options in the **same order**. Answers always
   come from English.
3. Run `flutter test`. The content tests check structure and translation parity.

## Disclaimer
Nyaya is educational and does not give legal advice. Laws change, so verify with the official Gazette
or consult an advocate.
