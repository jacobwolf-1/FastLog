# FastLog Backend

FastLog is a minimal AI-native macro dashboard backend. It is the shared API and data layer for the future iOS app, ChatGPT Actions, Claude tools, Apple Shortcuts, and other clients.

This pass includes the Supabase/Postgres schema, Row Level Security policies, seed data, a dependency-free TypeScript REST API, executable integration tests, API documentation, AI behavior rules, and a ChatGPT Action OpenAPI subset.

## Project Structure

```text
src/
  app.ts
  server.ts
  domain.ts
  store.ts
  memory-store.ts
  supabase-store.ts
scripts/
  verify-migration.ts
tests/
  integration.ts
supabase/
  migrations/
    20260602120000_initial_schema.sql
  seed.sql
  functions/
    README.md
openapi/
  chatgpt-action.yaml
docs/
  PRODUCT_PLAN.md
  api.md
  ai-behavior.md
  saved-meal-resolution.md
  test-plan.md
README.md
.env.example
package.json
```

## Setup

No npm dependencies are required for the current API layer. Node 22+ is required because scripts use native TypeScript type stripping.

1. Copy `.env.example` to `.env` and fill in values.
2. For local in-memory API development:

   ```sh
   FASTLOG_STORE=memory npm run dev
   ```

3. For Supabase-backed API development, set:

   ```text
   FASTLOG_STORE=supabase
   SUPABASE_URL=
   SUPABASE_ANON_KEY=
   ```

   Then run:

   ```sh
   npm start
   ```

The API expects `Authorization: Bearer <user jwt>`. In memory mode only, use `Bearer dev:<user-id>[:email]`.

## Supabase Setup

Install the Supabase CLI if you want local database verification:

```sh
npm install -g supabase
```

Apply migrations in a Supabase project:

```sh
supabase db push
```

Seed data requires at least one local `auth.users` row. The seed attaches demo data to the first auth user found:

```sh
supabase db seed
```

## Environment Variables

```text
SUPABASE_URL=
SUPABASE_ANON_KEY=
SUPABASE_SERVICE_ROLE_KEY=
FASTLOG_API_BASE_URL=
FASTLOG_STORE=supabase|memory
FASTLOG_INTEGRATION_PROVIDER=chatgpt|claude
PORT=8787
```

`SUPABASE_SERVICE_ROLE_KEY` is server-side only. Do not expose it to iOS clients, ChatGPT Actions, browsers, or public frontend bundles. The implemented REST layer uses user bearer tokens plus the anon key so Supabase RLS enforces user isolation.

## Local Backend/API

Run an in-memory local server:

```sh
FASTLOG_STORE=memory npm run dev
```

Example request:

```sh
curl -s http://localhost:8787/v1/targets/current   -H 'Authorization: Bearer dev:user-a:user-a@example.test'
```

Run a Supabase-backed server:

```sh
FASTLOG_STORE=supabase npm start
```

Run a ChatGPT Action-facing deployment by setting server-side integration context:

```sh
FASTLOG_INTEGRATION_PROVIDER=chatgpt npm start
```

Do not expose `source` or `provider` in the ChatGPT Action request schema. The server derives both as `chatgpt` for that deployment and ignores spoofed request-body metadata.

## Tests

Run migration verification:

```sh
npm run verify:migration
```

Run executable API integration tests:

```sh
npm test
```

The test suite starts a local HTTP API server and exercises targets, food logs, dashboard totals, saved meals, saved meal resolution, serving multipliers, saved meal deletion preserving historical logs, AI audit logging, and user isolation assumptions.

## Full Backend API vs ChatGPT Action Subset

The full backend API includes food logs, dashboard, targets, saved meals, weight entries, and weight trends. See `docs/api.md`.

The ChatGPT Action schema in `openapi/chatgpt-action.yaml` intentionally exposes only Action-safe operations:

- `logFood`
- `getTodayDashboard`
- `updateTargets`
- `listSavedMeals`
- `resolveSavedMeal`
- `logSavedMeal`
- `createSavedMeal`

Weight writes, weight trends, deletes, and broad edit operations are backend API concerns, not part of the first Action subset.

## Current Status

Implemented:

- Supabase schema and RLS migration.
- Saved meal alias cascade and food log history preservation on saved meal delete.
- Dependency-free TypeScript REST API.
- Supabase-backed store using user-scoped RLS.
- In-memory store for local development and tests.
- Saved meal resolution with exact, normalized, and high-confidence fuzzy matching.
- AI audit logging for server-derived AI-origin writes.
- ChatGPT Action writes derive `provider=chatgpt` and `source=chatgpt` server-side.
- Executable integration tests.
- OpenAPI schema for the restricted ChatGPT Action subset.

Remaining before frontend work:

- Install/run Supabase CLI locally and apply the migration from scratch against a real local database.
- Deploy the API or convert it to Supabase Edge Functions if that becomes preferable.
- Validate the ChatGPT Action schema against the deployed API URL.
- Decide production auth/token exchange for ChatGPT and Claude connections.
