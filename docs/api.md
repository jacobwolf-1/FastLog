# API Design

FastLog is API-first. The iOS app, ChatGPT Actions, Claude tools, Apple Shortcuts, and future clients should use the same authenticated backend operations.

All endpoints are under `/v1`. All requests require a user-scoped bearer token unless explicitly implemented as trusted service-role backend operations. Do not add public unauthenticated write paths.

## Conventions

- Dates use `YYYY-MM-DD`.
- Timestamps use ISO 8601.
- Meal type is optional and defaults to `unspecified`.
- Nutrition values must be non-negative.
- `source` identifies the client path: `manual`, `shortcut`, `chatgpt`, `claude`, or `import`.
- Health and nutrition data is sensitive. Responses should expose only the authenticated user's records.

## Food Logs

### `POST /v1/food-logs`

Creates a one-off food log.

Request:

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
  "source": "manual",
  "raw_input": "Log chicken and potatoes for lunch"
}
```

Response: `201 Created` with the created food log.

### `GET /v1/food-logs?date=YYYY-MM-DD`

Returns food logs for the authenticated user on the requested local date. API implementation should decide and document the user's timezone handling before production.

### `PATCH /v1/food-logs/{id}`

Updates one food log owned by the authenticated user.

### `DELETE /v1/food-logs/{id}`

Deletes one food log owned by the authenticated user. AI clients should ask confirmation before deletion.

## Dashboard

### `GET /v1/dashboard/today`

Returns today's totals and current targets.

### `GET /v1/dashboard?date=YYYY-MM-DD`

Returns totals for a specific date.

Response shape:

```json
{
  "date": "2026-06-02",
  "targets": {
    "calories": 2300,
    "protein_g": 180,
    "carbs_g": 220,
    "fat_g": 70,
    "fiber_g": 35,
    "sodium_mg": 2300,
    "sugar_g": 75,
    "potassium_mg": 4700
  },
  "totals": {
    "calories": 1520,
    "protein_g": 125,
    "carbs_g": 145,
    "fat_g": 48,
    "fiber_g": 24,
    "sodium_mg": 1700,
    "sugar_g": 32,
    "potassium_mg": 2100
  },
  "remaining": {
    "calories": 780,
    "protein_g": 55,
    "carbs_g": 75,
    "fat_g": 22,
    "fiber_g": 11,
    "sodium_mg": 600,
    "sugar_g": 43,
    "potassium_mg": 2600
  },
  "logs": []
}
```

## Targets

### `GET /v1/targets/current`

Returns the latest target row whose `effective_date` is on or before today.

### `PATCH /v1/targets`

Creates a new effective target row or updates today's target, depending on final API implementation. Prefer preserving target history by creating a new row when values change.

Request:

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

## Saved Meals

### `GET /v1/saved-meals`

Lists saved meals and aliases for the authenticated user.

### `GET /v1/saved-meals/resolve?query=GB%20%2B%20Potato`

Resolves a saved meal name or alias.

Match priority:

1. Exact name match.
2. Exact alias match.
3. Normalized name match.
4. Normalized alias match.
5. Fuzzy match only if high confidence.

Not found response:

```json
{
  "match_status": "not_found",
  "message": "No saved meal template found."
}
```

### `POST /v1/saved-meals`

Creates a saved meal template and optional aliases.

### `PATCH /v1/saved-meals/{id}`

Updates a saved meal template. Alias updates can be implemented either in this endpoint or with dedicated alias endpoints later.

### `DELETE /v1/saved-meals/{id}`

Deletes a saved meal template. AI clients should ask confirmation before deletion.

### `POST /v1/saved-meals/{id}/log`

Logs a saved meal with optional serving multiplier and meal type override.

Request:

```json
{
  "logged_at": "2026-06-02T12:00:00Z",
  "meal_type": "dinner",
  "serving_multiplier": 1.5,
  "source": "chatgpt",
  "raw_input": "Log 1.5x GB + Potato for dinner"
}
```

The created `food_logs` row stores copied macro values multiplied by `serving_multiplier` and references `saved_meal_id`.

## Weight

### `POST /v1/weight-entries`

Creates a manual, Apple Health, or imported weight record.

Request:

```json
{
  "measured_at": "2026-06-02T12:00:00Z",
  "weight_lb": 178.4,
  "source": "manual"
}
```

### `GET /v1/weight-trend?range=week`

Supported ranges:

- `week`
- `month`
- `year`

Returns points, average weight, and period change.

## AI Audit

API routes used by AI clients should insert an `ai_audit_log` row containing provider, action, raw user text when available, request payload, response payload, and any created resource reference.
