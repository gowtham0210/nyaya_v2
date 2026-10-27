# Nyaya Content Management Portal

Next.js 16 portal where editors write questions, legal reviewers approve them and publishers put them
live. It talks only to the Nyaya API in [`../backend`](../backend); all rules (roles, the question
lifecycle, required source details) are enforced there and this app only reflects them.

## Run it

Start the API first (see `../backend/README.md`), then:

```bash
npm install
cp .env.example .env.local   # API_URL, defaults to http://localhost:3000
npm run dev                  # http://localhost:3001
```

Sign in with a seeded dev account (`editor@`, `reviewer@`, `publisher@`, `admin@nyaya.local`, password =
`SEED_PASSWORD` from `backend/.env`).

## What is here

| Screen | Who | What |
|---|---|---|
| `/login` | everyone | Email + password sign-in |
| `/questions` | all staff | Every question with its latest version; search, status and topic filters, paging |
| `/questions?status=in_review` | reviewers | Review queue |
| `/questions?status=approved` | publishers | Ready to publish |
| `/questions/new` | editors | New draft |
| `/questions/[id]` | all staff | Edit (draft / changes requested), read-only view otherwise, the actions your role allows now, version and review history |

## How it works

- **Sessions.** The API's access and refresh tokens are kept in httpOnly cookies; browser scripts never
  see them. `src/proxy.ts` swaps an expired access token for a new pair before a page renders, and shares
  one refresh between parallel requests (refresh tokens are single-use).
- **Data.** Server Components and Server Actions call the API with the user's token through a typed
  client (`src/lib/api.ts`), generated from the API contract: run `npm run gen:api` after
  `npm run openapi` in the backend.
- **Cache Components** is on: anything that reads the session renders inside `<Suspense>`, so each page's
  frame is static and the signed-in content streams in.

## Scripts

`npm run dev` · `npm run build` · `npm run lint` · `npm run typecheck` · `npm run gen:api`
