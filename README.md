# FastLog Backend

FastLog is a minimal AI-native macro dashboard backend. It is designed as the shared API and data layer for the future iOS app, ChatGPT Actions, Claude tools, Apple Shortcuts, and other clients.

The first milestone is backend readiness, not frontend polish. This repository starts with a Supabase/Postgres schema, Row Level Security policies, seed data, API documentation, AI behavior rules, and an OpenAPI schema for a ChatGPT Action.

## Project Structure

```text
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
```

## Setup

1. Create a Supabase project.
2. Install the Supabase CLI if you want local development:

   ```sh
   npm install -g supabase
   ```

3. Copy `.env.example` to `.env` and fill in project values.
4. Apply migrations:

   ```sh
   supabase db push
   ```

5. Load development seed data after creating the matching local auth users, or adapt `supabase/seed.sql` to the UUIDs in your local environment.

## Environment Variables

```text
SUPABASE_URL=
SUPABASE_ANON_KEY=
SUPABASE_SERVICE_ROLE_KEY=
FASTLOG_API_BASE_URL=
```

`SUPABASE_SERVICE_ROLE_KEY` is for trusted backend/server-side code only. Do not expose it to iOS clients, ChatGPT Actions, browsers, or public frontend bundles.

## Local Development Workflow

Recommended first pass:

1. Run Supabase locally.
2. Apply `supabase/migrations/20260602120000_initial_schema.sql`.
3. Review `docs/api.md` and implement API routes or Edge Functions against that contract.
4. Use `openapi/chatgpt-action.yaml` as the ChatGPT Action schema once the REST endpoints exist.
5. Use `docs/test-plan.md` to verify targets, logging, dashboard totals, saved meal resolution, serving multipliers, and RLS assumptions.

## Supabase Notes

- Tables use `auth.uid()` in RLS policies so users can only access their own records.
- `profiles.id` references `auth.users(id)` and is created automatically by a trigger.
- Service-role backend code can bypass RLS in Supabase, but public clients should use user-scoped JWTs.
- Health and nutrition data is sensitive. Keep auth boundaries explicit and avoid public unauthenticated write paths.

## Testing Notes

This pass includes a test plan rather than a full application test harness. See `docs/test-plan.md`.

Core cases:

- Create and update daily targets.
- Create food logs.
- Compute dashboard totals.
- Create saved meals and aliases.
- Resolve saved meals by alias.
- Log saved meals with serving multipliers.
- Confirm user isolation assumptions under RLS.

## Current Status

Implemented:

- Supabase schema and RLS migration.
- Seed data scaffold.
- Product plan document.
- API design documentation.
- AI behavior and saved meal resolution specification.
- OpenAPI schema for the first ChatGPT Action operations.

Remaining for the next pass:

- Implement REST API routes or Supabase Edge Functions.
- Add executable integration tests.
- Add auth token strategy for ChatGPT Actions.
- Deploy to Supabase and validate the OpenAPI schema against the live API.
