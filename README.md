# FastLog

A minimal, AI-native macro-tracking API. FastLog is deliberately **not** a food
database or a diet coach — it answers one question, *"what numbers do you want
to log?"*, and exposes a small, safe surface for an AI assistant (or an iOS app)
to log them.

The interesting part is the **ChatGPT Custom GPT integration**: a GPT can write
food logs, update targets, and resolve saved meals through a deliberately narrow,
tamper-resistant API. The rest of this README shows how that path is kept safe —
and how to run the whole thing locally in about 30 seconds, with no database and
no keys.

## Headline: a ChatGPT Action that can't lie about who it is

A ChatGPT Custom GPT talks to FastLog through an OpenAPI **subset**, not the full
backend. The design goal: *let an AI write to a user's log without letting any
client forge an AI-origin write or reach beyond what an assistant should touch.*
Four properties enforce that:

- **Action-safe route subset.** [`openapi/chatgpt-action.yaml`](openapi/chatgpt-action.yaml)
  exposes only seven operations — `logFood`, `getTodayDashboard`, `updateTargets`,
  `resolveSavedMeal`, `logSavedMeal`, `createSavedMeal`, `listSavedMeals`. No
  deletes, no broad edits, no weight writes, no date-range reads.
- **Server-derived provenance.** A client cannot claim "this write came from
  ChatGPT." The `source`/`provider` fields are *not in the request schema* — the
  server stamps them itself from deployment context. A normal API write is
  `source=manual`; a write on the ChatGPT-facing deployment is `source=chatgpt`.
  Spoofed `source`/`provider` in a request body are ignored.
- **AI audit log.** Every AI-origin write records an `ai_audit_log` row (provider,
  operation, user), so AI-created data stays attributable after the fact.
- **Per-user isolation via RLS.** The Supabase-backed store uses user-scoped
  bearer tokens plus the anon key, so Postgres Row Level Security — not app code —
  blocks one user from reading or writing another user's data.

You don't have to take my word for any of it: there's an executable test that
exercises this exact path (below).

## Quickstart (≈30 seconds, no database, no keys)

**Requires Node 22+.** The API layer is dependency-free — there is nothing to
`npm install`.

```sh
git clone https://github.com/jacobwolf-1/FastLog.git
cd FastLog
npm run dev          # in-memory mode, listening on http://localhost:8787
```

In another terminal:

```sh
# read current targets (null for a fresh user)
curl -s http://localhost:8787/v1/targets/current \
  -H 'Authorization: Bearer dev:user-a:user-a@example.test'

# log a one-off entry
curl -s -X POST http://localhost:8787/v1/food-logs \
  -H 'Authorization: Bearer dev:user-a:user-a@example.test' \
  -H 'Content-Type: application/json' \
  -d '{"calories":500,"protein_g":40,"carbs_g":45,"fat_g":15,"label":"lunch"}'
```

In memory mode only, auth is a dev token of the form `Bearer dev:<user-id>[:email]`
— no real JWT needed.

## See the AI write path yourself

The ChatGPT Action flow is backed by an executable smoke test that needs **no
hosting, no ChatGPT account, and no credentials**. It boots the API in memory
mode and drives the exact Action-safe routes a GPT would call:

```sh
npm run test:ai-action
```

It verifies saved-meal resolution, 1.5× saved-meal logging, one-off logging,
target updates, the **server-derived `source`/`provider`** behavior (including
ignoring spoofed values), and that AI audit rows get written.

The full integration suite covers the rest — dashboard math, saved-meal alias
cascades, history preservation on saved-meal delete, and user-isolation
assumptions:

```sh
npm test
```

Both pass with no setup.

## How it fits together

```text
src/
  server.ts          # tiny dependency-free HTTP layer
  app.ts             # routing + request handling
  domain.ts          # core domain logic (macros, dashboard totals, saved meals)
  store.ts           # store interface
  memory-store.ts    # in-memory store (dev + tests)
  supabase-store.ts  # Supabase/Postgres store (RLS-enforced)
openapi/
  chatgpt-action.yaml  # the restricted ChatGPT Action subset
supabase/
  migrations/          # schema + Row Level Security policies
docs/                  # API reference, AI behavior rules, setup guides
ios/                   # SwiftUI MVP client (drives the same API)
```

- **Full API vs. Action subset** — the backend also serves food-log edits,
  deletes, weight entries, and weight trends. Those are intentionally *not* in
  the ChatGPT Action surface. See [`docs/api.md`](docs/api.md).
- **iOS app** — a SwiftUI MVP that drives the same API and can read body mass
  from HealthKit locally (optional; the app works without it). See
  [`ios/README.md`](ios/README.md).
- **AI behavior rules** — [`docs/ai-behavior.md`](docs/ai-behavior.md); ChatGPT
  wiring in [`docs/chatgpt-action-setup.md`](docs/chatgpt-action-setup.md).

## Deploy anywhere (optional)

Nothing above needs a server. To run against real data instead of memory mode,
point it at a Supabase project and start it on any Node host:

```sh
FASTLOG_STORE=supabase \
SUPABASE_URL=<your project url> \
SUPABASE_ANON_KEY=<your anon/publishable key> \
npm start
```

`SUPABASE_SERVICE_ROLE_KEY` is server-side only and is never needed by the API
layer, iOS, or the ChatGPT Action — the design relies on user bearer tokens plus
the anon key so RLS enforces ownership. For a ChatGPT-facing deployment, also set
`FASTLOG_INTEGRATION_PROVIDER=chatgpt` so writes are stamped server-side.

## License

MIT — see [LICENSE](LICENSE).
