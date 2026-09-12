# ChatGPT Action Smoke Test

This is the private smoke-test flow for a deployed FastLog API:

```text
https://your-deployment.example
```

This uses a temporary Supabase user JWT as an API-key bearer token in a private GPT. It is not production auth. Do not use this for real user-facing distribution. Production still needs OAuth or another per-user token exchange before broader use.

Do not paste JWTs into logs, docs, GitHub, screenshots, Codex, or support threads.

## Before You Start

- Confirm your backend is deployed with `FASTLOG_INTEGRATION_PROVIDER=chatgpt`.
- Confirm `openapi/chatgpt-action.yaml` has your deployment's server URL.
- Confirm the test user already exists in Supabase.
- Refresh a temporary Supabase JWT locally using your normal private/local auth flow.
- Keep the JWT outside Git and outside docs.

## Configure The Private GPT

1. Open ChatGPT GPT Builder.
2. Create or edit a private GPT.
3. Go to **Actions**.
4. Create a new action.
5. Paste or import `openapi/chatgpt-action.yaml`.
6. Set **Authentication**:
   - Type: `API Key`
   - Auth type: `Bearer`
   - Token: your temporary Supabase JWT
7. Save the private GPT.

The token expires. Refresh it and update the Action auth token for future smoke tests.

## Preview Test Prompts

Run these in GPT Builder Preview:

```text
What do I have left today?
```

```text
List my saved meals.
```

```text
Resolve GB + Potato.
```

```text
Log GB + Potato for lunch.
```

```text
Log 220 calories, 25 protein, 15 carbs, 7 fat as Test protein yogurt.
```

After each write, ask:

```text
What do I have left today?
```

Confirm the dashboard updates.

## Expected Behavior

- `getTodayDashboard` should return today's targets, totals, remaining, and logs.
- `listSavedMeals` should return the saved meals for the authenticated test user.
- `resolveSavedMeal` with `GB + Potato` should return `match_status="found"` when that saved meal exists.
- `logSavedMeal` should create a food log with `source="chatgpt"`.
- `logFood` should create a one-off food log with `source="chatgpt"`.
- The dashboard should update after `logSavedMeal` and `logFood`.

## Safety Boundaries

- This private JWT flow is temporary smoke-test auth only.
- Do not expose or commit JWTs, Supabase keys, Railway tokens, database passwords, or ChatGPT Action secrets.
- Do not add `user_id`, `source`, or `provider` to Action request schemas.
- Do not add delete, edit, weight, date-range read, or HealthKit-write actions.
- Saved-meal resolution must go through the backend `resolveSavedMeal` action.
- HealthKit writes remain local to iOS; ChatGPT must not write to Apple Health.

## If It Fails

`401 Unable to authenticate Supabase user.`

Refresh the JWT. Confirm your deployment's `SUPABASE_URL` and `SUPABASE_ANON_KEY` match the same Supabase project used to issue the JWT. Do not paste the JWT or keys into logs, docs, GitHub, or Codex.

`400` schema validation error in GPT Builder.

Inspect `openapi/chatgpt-action.yaml` for a path, method, parameter, or request schema mismatch with the backend route.

Action calls the wrong endpoint.

Check that the OpenAPI `servers` URL exactly matches your deployed backend:

```text
https://your-deployment.example
```

Saved meal not found.

Create the saved meal first, or ask the GPT to list saved meals and then resolve the exact saved-meal name. Do not let the GPT invent saved-meal templates silently.

JWT expired.

Refresh the token locally and update the private Action auth token.

Unexpected source value.

Confirm your deployment has:

```text
FASTLOG_INTEGRATION_PROVIDER=chatgpt
```

Food logs created through `logFood` and `logSavedMeal` should return `source="chatgpt"`.
