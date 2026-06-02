# Test Plan

This first pass defines the backend contract and database foundation. The next pass should add executable integration tests around these cases.

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

## RLS And User Isolation

Verify:

- User A cannot select User B's targets, logs, saved meals, aliases, weight entries, or audit logs.
- User A cannot insert rows with User B's `user_id`.
- User A cannot update or delete User B's rows.
- Service-role backend operations remain possible for trusted server code.

Document that Supabase service-role keys must never be exposed to public clients.
