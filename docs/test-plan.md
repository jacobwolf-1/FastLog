# Test Plan

This backend now includes executable integration tests in `tests/integration.ts`. Run them with `npm test`. The local ChatGPT Action smoke flow is in `tests/ai-action-smoke.ts` and runs with `npm run test:ai-action`. Migration/static FK verification is in `scripts/verify-migration.ts` and runs with `npm run verify:migration`.

## Target Creation

Verify:

- A signed-in user can create a `daily_targets` row for themselves.
- Nutrition targets must be non-negative.
- `calories` is required and greater than zero.
- The current target query returns the latest target with `effective_date <= today`.

## Food Log Creation

Verify:

- A signed-in user can create a food log for themselves.
- `meal_type` defaults to `unspecified`.
- Invalid meal types are rejected.
- Calories must be positive.
- Macro and micronutrient values must be non-negative.
- Source defaults to `manual`.

## Dashboard Totals

Create multiple food logs on the same date and verify summed totals for:

- Calories.
- Protein.
- Carbs.
- Fat.
- Fiber.
- Sodium.
- Sugar.
- Potassium.

Verify remaining values are `target - total`.

## Saved Meal Creation

Verify:

- A signed-in user can create a saved meal.
- A signed-in user can add aliases.
- Duplicate saved meal names per user are rejected.
- Duplicate aliases per user are rejected.
- The same saved meal name can exist for different users.

## Saved Meal Resolution

Verify:

- Exact name match wins.
- Exact alias match works.
- Normalized name match works.
- Normalized alias match works.
- Fuzzy match is returned only above the configured confidence threshold.
- No confident match returns `not_found`.

## Log Saved Meal With Multiplier

Given a saved meal:

```text
610 calories, 50 protein, 56 carbs, 18 fat
```

When logging with `serving_multiplier = 1.5`, verify the food log stores:

```text
915 calories, 75 protein, 84 carbs, 27 fat
```

Verify the food log references `saved_meal_id` and stores `serving_multiplier`.

## ChatGPT Action Smoke Flow

Verify with `npm run test:ai-action`:

- The smoke flow uses memory mode/in-process HTTP and does not require Supabase.
- Only Action-safe routes are called: `logFood`, `getTodayDashboard`, `updateTargets`, `listSavedMeals`, `resolveSavedMeal`, `logSavedMeal`, and `createSavedMeal`.
- `GB + Potato` is created with 610 calories, 50g protein, 56g carbs, and 18g fat.
- Logging `1.5x` stores 915 calories, 75g protein, 84g carbs, and 27g fat.
- Spoofed request-body `source` and `provider` fields are stripped from audit payloads and do not override server-derived `chatgpt` source/provider.
- AI audit rows are created for one-off food logs, saved-meal logs, saved-meal creation, and target updates.

Manual local demo coverage is documented in `docs/local-ai-demo.md`. It demonstrates the same v0.2 flow through curl: memory backend in ChatGPT mode, targets, saved meal creation, saved meal resolution, 1.5x saved-meal logging, dashboard fetch, and expected totals.

## RLS And User Isolation

Verify:

- User A cannot select User B's targets, logs, saved meals, aliases, weight entries, or audit logs.
- User A cannot insert rows with User B's `user_id`.
- User A cannot update or delete User B's rows.
- Service-role backend operations remain possible for trusted server code.

Document that Supabase service-role keys must never be exposed to public clients.


## Executable Coverage Added

The integration suite currently covers:

- Migration/static schema assumptions.
- Seed-equivalent data creation.
- Create target.
- Create food log.
- Patch food log while ignoring spoofed `source`/`provider`.
- Delete food log.
- Compute dashboard totals.
- Create saved meal.
- Resolve saved meal by alias.
- Log saved meal with serving multiplier.
- Patch saved meal.
- Explicit alias replacement.
- Edited saved meal does not alter historical food logs.
- Saved meal delete preserves historical food logs and clears `saved_meal_id`.
- RLS/user isolation assumptions.
- Local ChatGPT Action smoke flow for targets, saved meals, saved-meal resolution/logging, one-off logging, dashboard totals, spoof stripping, and AI audit rows.

Supabase CLI was not installed in this environment, so live local database reset/apply remains a manual verification step.
