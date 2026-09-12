# ChatGPT Action Setup

FastLog exposes a narrow ChatGPT Action surface for AI-native macro logging. The Action should answer the product question, "What numbers do you want to log?", and should not become a food database, diet coach, barcode scanner, or meal planner.

## What ChatGPT Can Access

Upload or use:

```text
openapi/chatgpt-action.yaml
```

The schema ships with a placeholder server URL:

```text
https://your-deployment.example
```

Set the OpenAPI `servers` URL to your backend's public HTTPS URL before configuring the Action.

## Deployment Prerequisites

See `docs/deployment-auth-plan.md`, `docs/action-deployment-checklist.md`, and `docs/chatgpt-action-smoke-test.md` before configuring a real Action.

- Deploy the FastLog backend behind HTTPS.
- Decide the production auth/token exchange for ChatGPT users.
- Set the ChatGPT-facing deployment environment:

  ```sh
  FASTLOG_INTEGRATION_PROVIDER=chatgpt
  ```

- Use the same backend API used by iOS and other clients.
- Keep saved-meal resolution in the backend through `resolveSavedMeal`.

## Authentication

Local memory mode supports only this development bearer token pattern:

```text
Authorization: Bearer dev:<user-id>[:email]
```

Example:

```text
Authorization: Bearer dev:user-a:user-a@example.test
```

That token format is for local memory-mode demos only. Production should not use the dev bearer token. Production auth still needs a real user-token strategy or token exchange between ChatGPT and FastLog.

Never expose `SUPABASE_SERVICE_ROLE_KEY` to ChatGPT, browsers, iOS clients, public bundles, or any public client. The REST layer is designed to use user bearer tokens plus the Supabase anon key so RLS enforces ownership.

## Allowed Operations

The first ChatGPT Action exposes exactly seven operations:

- `logFood`
- `getTodayDashboard`
- `updateTargets`
- `resolveSavedMeal`
- `logSavedMeal`
- `createSavedMeal`
- `listSavedMeals`

These map to:

- `POST /v1/food-logs`
- `GET /v1/dashboard/today`
- `PATCH /v1/targets`
- `GET /v1/saved-meals/resolve`
- `POST /v1/saved-meals/{id}/log`
- `POST /v1/saved-meals`
- `GET /v1/saved-meals`

## Disallowed Operations

Do not expose these through the ChatGPT Action:

- Deletes.
- Broad edits.
- Food log patching.
- Saved meal patching.
- Weight writes.
- Weight trends.
- Date-range food log reads.
- Date-range dashboard reads.
- HealthKit writes.
- Source/provider request fields.

The backend derives ChatGPT writes server-side. With `FASTLOG_INTEGRATION_PROVIDER=chatgpt`, food logs created through `logFood` and `logSavedMeal` get `source=chatgpt`, and audited AI operations get `provider=chatgpt`. Client-supplied `source` or `provider` fields are untrusted and are not part of the Action request schemas.

## Suggested GPT Instructions

Use this as the core behavior text for the custom GPT or Action instructions:

```text
You are FastLog, a minimal macro logging assistant. The user already knows their macros or wants help estimating them. Ask what numbers they want to log; do not turn this into a food database, meal planner, or diet coaching app.

When the user asks to log a saved meal by name, first call resolveSavedMeal with the user's meal name.

If resolveSavedMeal returns match_status=found, call logSavedMeal with the returned saved_meal.id. Preserve explicit serving multipliers and meal type when provided.

If resolveSavedMeal returns match_status=not_found, do not invent a saved meal. Tell the user no saved meal template was found and ask whether they want to estimate/log a one-off entry.

For explicit macro numbers, call logFood. Use meal_type=unspecified when the user does not specify breakfast, lunch, dinner, or snack.

For target changes, call updateTargets when the user clearly asks. If the change is drastic or ambiguous, ask for confirmation first.

For "what do I have left today?", "where am I at today?", or similar dashboard questions, call getTodayDashboard.

Create saved meal templates only when the user explicitly asks to save a meal/template. Do not create a saved meal silently from an estimate.

Never write to Apple Health. HealthKit writes are local to the iOS app after it syncs backend data.

Never claim medical or diagnostic conclusions. Do not present macro targets or food logs as medical advice.
```

## Confirmation Boundaries

ChatGPT can create ordinary one-off logs and log resolved saved meals after the user has connected the integration.

Ask for confirmation before:

- Changing targets drastically.
- Creating a saved meal from estimated macros.
- Exporting data.
- Making medical or diagnostic claims.

The Action cannot delete records, broadly edit records, write weight, read weight trends, or write Apple Health.
