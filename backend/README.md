# Nyaya backend

The single write path for every client (Flutter app, Content Management Portal), as set out in
`../docs/planning/`. NestJS 12 on Node 24, Drizzle ORM, PostgreSQL. The contract is
[`openapi.json`](openapi.json); browse it at `http://localhost:3000/docs` while the server runs.

## Run it

```bash
npm install
cp .env.example .env     # then set SEED_PASSWORD to a password of your choice
npm run seed             # taxonomy + the app's 108 questions as drafts + dev staff accounts
npm run start:dev        # http://localhost:3000/v1
```

Without `DATABASE_URL` the server uses an embedded Postgres (PGlite) stored in `.data/pglite`, so no
install is needed. For a real Postgres: `docker compose up -d`, then set
`DATABASE_URL=postgres://nyaya:nyaya@localhost:5432/nyaya` in `.env`. Migrations run on start.

Seeded dev accounts (password = `SEED_PASSWORD`): `admin@`, `editor@`, `reviewer@`, `publisher@nyaya.local`.

## Scripts

| Script | What it does |
|---|---|
| `npm test` / `npm run test:e2e` | Unit tests / API tests on an in-memory database |
| `npm run openapi` | Regenerates `openapi.json` |
| `npm run db:generate` | Writes a SQL migration in `drizzle/` after editing `src/db/schema.ts` |
| `npm run seed` | Re-runnable dev seed |
| `npm run lint` / `npm run format` | oxlint / Prettier |

## What exists (plan modules)

- **M01 Identity & access** — email + password sign-in for staff, 15-minute access tokens, single-use
  refresh tokens (a reuse more than 30 s after rotation is treated as theft and revokes every session), sign-out, `GET /v1/me`, roles checked from the
  database on every request, sign-in rate limit. Learner sign-in method (OTP?) is still open.
- **M02 Taxonomy** — `GET /v1/taxonomy`: active subjects, topics and acts (read-only; editing comes with
  the admin views).
- **M03 Question lifecycle** — `/v1/editor/questions`: create, edit, submit, request changes, approve,
  publish, revise, retire. Draft → In review → Changes requested / Approved → Published →
  Superseded / Retired, enforced on the server. Published versions never change; a correction is a new
  version and the old one stays live until the new one is published. Reviewers cannot approve their own
  work. Every step is in the append-only `audit_log`.
- **M04 Sources** — source title/URL/citation, provision reference, valid-from/to, verified-at and
  reviewer on every version; required before review and publishing.

All errors are `{ code, message, details, request_id }`. Lists are `{ items, next_cursor }`.

The Content Management Portal in [`../cms`](../cms) is the first client.

## Not yet

Learner APIs (published content, quiz sessions, server scoring, progress, bookmarks), CSV import,
admin user/taxonomy management, content reports, translations of questions, analytics, CI/CD.
