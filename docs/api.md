# API Design

FastLog is API-first. The iOS app, ChatGPT Actions, Claude tools, Apple Shortcuts, and future clients should use the same authenticated backend operations.

This document describes the full backend API. The restricted ChatGPT Action subset is in `openapi/chatgpt-action.yaml`.

## Auth And Runtime

All routes are under `/v1` and require `Authorization: Bearer <token>`.

Runtime modes:

- `FASTLOG_STORE=supabase`: uses `SUPABASE_URL` and `SUPABASE_ANON_KEY`; the caller's user JWT is passed through to Supabase so RLS enforces ownership.
- `FASTLOG_STORE=memory`: local development/test mode; tokens use `Bearer dev:<user-id>[:email]`.

Do not expose `SUPABASE_SERVICE_ROLE_KEY` to public clients. The service-role key is not required by the implemented REST layer.

## Conventions

- Dates use `YYYY-MM-DD`.
- Timestamps use ISO 8601.
- Meal type is optional and defaults to `unspecified`.
- Nutrition values must be non-negative; calories must be positive.
- `source` identifies the trusted server/integration path: `manual`, `shortcut`, `chatgpt`, `claude`, or `import`.
- Public clients must not be trusted to declare `source` or `provider` in request bodies.
- The REST layer ignores/overrides untrusted `source` and `provider` fields based on server-side integration context.
- AI-origin writes are audited when the server-side integration context is `chatgpt` or `claude`.

## Full Backend API

### Food Logs

```http
POST /v1/food-logs
GET /v1/food-logs?date=YYYY-MM-DD
```

`POST /v1/food-logs` creates a one-off food log.

```json
{
  "logged_at": "2026-06-02T12:00:00Z",
  "meal_type": "lunch",
  "label": "Chicken + potatoes",
  "calories": 610,
  "protein_g": 55,
  "carbs_g": 58,
  "fat_g": 12,
  "fiber_g": 6,
  "sodium_mg": 850,
  "raw_input": "Log chicken and potatoes for lunch"
}
```

### Dashboard

```http
GET /v1/dashboard/today
GET /v1/dashboard?date=YYYY-MM-DD
```

Returns targets, totals, remaining values, and logs for the requested date.

### Targets

```http
GET /v1/targets/current
PATCH /v1/targets
```

`PATCH /v1/targets` upserts targets by `effective_date`.

```json
{
  "calories": 2300,
  "protein_g": 180,
  "carbs_g": 220,
  "fat_g": 70,
  "fiber_g": 35,
  "sodium_mg": 2300,
  "sugar_g": 75,
  "potassium_mg": 4700,
  "effective_date": "2026-06-02"
}
```

### Saved Meals

```http
GET /v1/saved-meals
GET /v1/saved-meals/resolve?query=GB%20%2B%20Potato
POST /v1/saved-meals
POST /v1/saved-meals/{id}/log
DELETE /v1/saved-meals/{id}
```

`POST /v1/saved-meals` creates a saved meal and aliases.

```json
{
  "name": "GB + Potato",
  "aliases": ["ground beef potato", "beef potato", "gb potato"],
  "calories": 610,
  "protein_g": 50,
  "carbs_g": 56,
  "fat_g": 18,
  "fiber_g": 5,
  "sodium_mg": 850
}
```

Resolution priority:

1. Exact name match.
2. Exact alias match.
3. Normalized name match.
4. Normalized alias match.
5. Fuzzy match only if high confidence.

If no confident match exists:

```json
{
  "match_status": "not_found",
  "message": "No saved meal template found."
}
```

`POST /v1/saved-meals/{id}/log` copies stored macros into a historical food log and applies `serving_multiplier`.

Deleting a saved meal cascades its aliases, but does not delete historical food logs. Historical logs keep copied macro values and set `saved_meal_id` to null.

### Weight

```http
POST /v1/weight-entries
GET /v1/weight-trend?range=week
GET /v1/weight-trend?range=month
GET /v1/weight-trend?range=year
```

Weight is stored in the backend as app data. ChatGPT/Claude must not write directly to Apple Health.

## ChatGPT Action Subset

The first Action schema intentionally includes only:

- `logFood`
- `getTodayDashboard`
- `updateTargets`
- `listSavedMeals`
- `resolveSavedMeal`
- `logSavedMeal`
- `createSavedMeal`

Excluded from the first Action subset:

- Weight entry writes.
- Weight trend reads.
- Deletes.
- Broad edits.
- Any direct Apple Health writes.

## AI Audit Behavior

The API writes `ai_audit_log` rows for AI-origin operations when the server is running with a trusted integration context such as `FASTLOG_INTEGRATION_PROVIDER=chatgpt`.

Audited operations:

- `logFood`.
- `logSavedMeal`.
- `createSavedMeal`.
- `updateTargets`.

For a ChatGPT Action deployment, the server sets `provider = chatgpt` and `source = chatgpt`. If a request body attempts to claim `manual`, `claude`, `shortcut`, `import`, or `other`, the server ignores that claim. Claude support should use a separate Claude tool contract or server-side integration context, not a ChatGPT Action request field.
