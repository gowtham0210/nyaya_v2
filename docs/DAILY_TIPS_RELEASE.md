# Daily Tips: from CMS to the release APK

Every step below that changes a server needs a person's go-ahead. Nothing here
verifies a tip, approves it or publishes it for anyone.

## How a tip reaches a learner

```
CMS (editor)  ->  API  ->  database  ->  GET /v1/daily-tips/today  ->  Flutter Home card
draft            checks   published      the tip whose "Shown on"       (the API address is
                          + approved     day is today (India time)       fixed when the APK is built)
```

A tip is shown only when all of these are true: it is **published**, it passed
a legal reviewer's **approval**, it has a **last-verified date** recorded by a
person, and its **Shown on** day is today. The app never bundles tips.

## Where things stand

- Only **staging** exists (`https://staging-api.deepwebstudio.dev`). There is no production server.
- Staging does not have the Daily Tips code or migrations (0018 to 0024) yet, so the
  endpoint answers 404 there and the app shows its "Couldn't load today's tip" retry card.
- The 100 drafted tips are on the local database only. Staging has none.

## Steps (each needs your approval where marked)

1. **Deploy the backend to staging.** *Needs approval.* From the repo root in a bash
   shell: `./deploy/staging/deploy.sh`. It applies migrations 0018 to 0024 and ships
   all uncommitted backend and CMS work, not only Daily Tips. It backs nothing up by
   itself, so run `/opt/nyaya-v2/backup.sh` on the server first.
2. **Create the drafts on staging.** *Needs approval.* With an editor account:
   `NYAYA_API_URL=https://staging-api.deepwebstudio.dev NYAYA_EMAIL=... NYAYA_PASSWORD=... node tool/daily_tips_sync.mjs import`
   First run is a dry run; add `--apply` to create. They are created as drafts, with no
   verification date.
3. **Confirm source links (human).** Open `docs/daily-tips-draft/verification_worksheet.csv`.
   Each row has a suggested Act-level link and the provisions to check. A person opens
   the link, finds the provision, and writes the confirmed exact link in
   `exact_source_url_checked`. Then `node tool/daily_tips_sync.mjs links --apply`
   saves only those confirmed links on the drafts.
4. **Record the check (human).** In the CMS, open each tip, check it against the
   source and click **I checked this today**. The API records who and when.
5. **Review and approve (legal reviewer).** An editor submits each tip, and a legal
   reviewer who did not write or check it approves it.
6. **Publish (publisher or admin).** *Needs approval.* **Publish all approved** on the
   Daily tips page publishes only approved tips, each on its own Shown on day.
7. **Build the APK.** `.\tool\build_release_apk.ps1 -ApiUrl https://staging-api.deepwebstudio.dev`
   The script refuses a localhost address and checks the server serves Daily Tips.
   On a machine that runs out of threads while building, add `--no-tree-shake-icons`
   to the `flutter build apk` line.
8. **Replace the APK.** `adb install -r build\app\outputs\flutter-apk\app-release.apk`
   (or uninstall the old one first). It is signed with the debug key: fine for test
   phones, not for the Play Store.

## What the 7 test-published tips are

They exist only on the local database, with a placeholder last-verified date
(2026-11-17) that nobody checked. They are listed in
`docs/daily-tips-draft/test_published_NOT_LEGALLY_VERIFIED.json`. They are not on
staging and will not reach the APK unless someone creates and publishes them there
through steps 2 to 6.
