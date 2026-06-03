# AI Behavior

ChatGPT and Claude should use the same authenticated backend API as the iOS app. They should not have special direct access to the app or to Apple Health.

## First Tool Set

- `logFood`
- `getTodayDashboard`
- `updateTargets`
- `listSavedMeals`
- `resolveSavedMeal`
- `logSavedMeal`
- `createSavedMeal`

The first ChatGPT Action schema intentionally excludes destructive operations, broad edit operations, date-range food-log/dashboard reads, weight entry writes, weight trend reads, and direct Apple Health writes.

## Saved Meal Logging

When the user says:

```text
Log GB + Potato.
```

The assistant should:

1. Call `resolveSavedMeal` with query `GB + Potato`.
2. If a confident match is found, call `logSavedMeal`.
3. If no confident match is found, respond with the not-found wording below.

Not-found wording:

```text
I do not see a saved meal template named “GB + Potato.” Do you want me to estimate macros for it and log it as a one-off entry?
```

The assistant must not silently invent a saved meal template.

## One-Off Macro Logging

The assistant may call `logFood` when the user gives clear macros:

```text
Log 650 calories, 45 protein, 70 carbs, 18 fat.
```

Meal type is optional. If omitted, use `unspecified`.

## Serving Multipliers

When the user says:

```text
Log 1.5x GB + Potato for dinner.
```

The assistant should resolve `GB + Potato`, then call `logSavedMeal` with `serving_multiplier: 1.5` and `meal_type: dinner`.

## Targets

The assistant may update targets when the user clearly asks:

```text
Set my calories to 2300 and protein to 180g.
```

Ask confirmation before changing targets drastically or when the user's intent is ambiguous.

## Confirmation Rules

AI can create ordinary food logs and saved meal logs without confirmation after the user has connected the integration.

AI should ask confirmation before:

- Deleting logs.
- Editing many logs.
- Changing targets drastically.
- Creating a saved meal from an estimate.
- Exporting data.
- Writing anything involving medical or diagnostic claims.

## Audit Logging

AI-written operations should create `ai_audit_log` rows. ChatGPT deployments derive `provider=chatgpt` and food-log `source=chatgpt` server-side; Claude deployments derive `provider=claude` and `source=claude`; non-AI/default deployments use `source=manual` and do not create AI audit rows. Client-supplied `source` and `provider` request fields are untrusted and must be ignored or stripped from audit payloads.

Recommended fields:

- `provider`
- `action`
- `raw_user_text`
- `request_payload`
- `response_payload`
- `created_resource_type`
- `created_resource_id`

## HealthKit Constraint

ChatGPT and Claude must not write directly to Apple Health.

Correct flow:

```text
ChatGPT/Claude
  ↓
Backend API
  ↓
iOS app syncs
  ↓
iOS app writes to Apple Health if enabled
```
