# FastLog Product Plan

FastLog is a minimalist nutrition and weight-tracking dashboard for users who already know their macros, or already use chatbots like ChatGPT or Claude to estimate macros, and want a fast way to log them, visualize progress, and use AI assistants to update their data.

The core idea is not to rebuild MyFitnessPal. The app should avoid bloated food search, social features, meal plans, recipes, ads, and generic diet coaching. Instead, it should focus on fast macro logging, a clean daily dashboard, Apple Health weight trends, manual weight input, simple calorie and macro targets, selected micronutrient progress bars, saved meal templates, AI-assisted logging, and future Apple Shortcuts/Siri support.

## Status And Review

The revised direction is:

- The app is for users who either already know their macros or use AI assistants to estimate them.
- Saved meal templates live in the app/backend database, not inside a ChatGPT or Claude prompt.
- Assistants resolve saved meal names by querying the backend.
- If no saved meal template exists, the assistant must not invent one silently.
- Weight should be read from Apple Health when available, with manual weight input as a fallback.
- Apple Shortcuts and Siri are future input paths, not required for the first backend milestone.
- Meal type remains in the data model but is optional in the UI/API.

Meal type should use:

```text
breakfast | lunch | dinner | snack | unspecified
```

Default:

```text
unspecified
```

## Product Summary

FastLog assumes the user already knows the numbers, or can get the numbers from an AI assistant. A user should be able to enter:

```text
650 calories, 45g protein, 70g carbs, 18g fat, lunch
```

and immediately see the dashboard update.

Users should also be able to store saved meal templates:

```text
GB + Potato = 610 calories, 50g protein, 56g carbs, 18g fat
```

Then the user can tell ChatGPT or Claude:

```text
Log GB + Potato
```

If `GB + Potato` exists, the assistant logs it. If not, it reports no template was found and asks whether to estimate and log a one-off entry.

## Positioning

Working product description:

```text
A minimalist nutrition dashboard for people who already know their macros or want quick and easy AI-assisted macro logging.
```

FastLog should have no bloated food database, no social feed, no unnecessary coaching, and no streak spam. It should provide fast macro logging, Apple Health weight trends, micronutrient goals, saved meals, and AI-assisted updates.

The core wedge:

```text
I know the macros, or AI knows the macros. I just want to log them instantly and see how they affect my day.
```

## MVP Goal

The MVP should prove:

```text
A user can quickly log macros and see a clean nutrition dashboard that updates immediately.
```

The MVP does not need food discovery, recipe parsing, barcode scanning, meal planning, or carb cycling.

MVP success criteria:

- Set daily targets for calories, protein, carbs, fat, and selected micros.
- Pull weight from Apple Health.
- Manually input weight if Apple Health data is unavailable.
- View weight by week, month, and year.
- Log a food entry manually.
- See calories consumed, calories left, macro rings, and micro bars update.
- Store logged food in an app-owned database.
- Create and use saved meal templates.
- Expose the same write operations to ChatGPT/Claude later.

## App Structure

```text
App
├── Dashboard
│   ├── Calories consumed / calories left
│   ├── Macro rings: protein, carbs, fat
│   ├── Micronutrient bars: fiber, sodium, sugar, potassium
│   └── Today's food log
├── Weight
│   ├── Week tab
│   ├── Month tab
│   ├── Year tab
│   └── Manual weight input
├── Log
│   ├── Quick macro entry
│   ├── Optional meal type selector
│   ├── Optional label
│   ├── Optional micronutrient fields
│   └── Saved meal picker
├── Saved Meals
│   ├── Meal templates
│   ├── Aliases
│   ├── Default serving size
│   └── Log / edit / duplicate
├── Targets
│   ├── Calories
│   ├── Protein
│   ├── Carbs
│   ├── Fat
│   └── Micronutrient targets
└── Settings
    ├── Apple Health permissions
    ├── Units
    ├── AI integration status
    ├── Apple Shortcuts/Siri integration later
    └── Data/export/privacy
```

## Dashboard UX

The dashboard should answer:

- How many calories have I eaten?
- How many calories do I have left?
- How much protein, carbs, and fat have I eaten?
- Which macro is lagging?
- Which micronutrient goals have I hit?
- What is my current weight trend?

Example:

```text
Today
2,300 cal goal
1,520 eaten · 780 left

Protein 125 / 180g
Carbs   145 / 220g
Fat      48 / 70g

Micros
Fiber     24 / 35g
Sodium    1,700 / 2,300mg
Sugar     32 / 75g
Potassium 2,100 / 4,700mg

Today's Logs
Lunch · GB + Potato · 610 cal · 50P / 56C / 18F
Snack · Protein yogurt · 220 cal · 25P / 15C / 7F
```

## Weight UX

The weight view should include Week, Month, and Year tabs. Each tab shows a line chart, average weight, change over the period, and an optional trend line.

Weight should be read from Apple Health using HealthKit when available. Manual input should be supported for users who do not grant permissions or need to correct data.

## Manual Logging UX

Logging should be extremely fast.

Fields:

- Meal type, optional.
- Label, optional.
- Calories.
- Protein.
- Carbs.
- Fat.
- Fiber, sodium, sugar, potassium as optional micros.

Meal type is kept because it makes logs easier to scan, enables usual meal workflows, supports future analytics, helps future carb cycling, and gives AI commands more specificity. It should not be mandatory because required fields slow down macro-only logging.

## Saved Meal UX

Saved meal example:

```text
Name: GB + Potato
Aliases:
- ground beef potato
- beef potato
- gb potato

Calories: 610
Protein: 50g
Carbs: 56g
Fat: 18g
Fiber: 5g
Sodium: 850mg
```

AI flow for `Log GB + Potato`:

1. Assistant calls saved meal resolution endpoint.
2. Backend finds exact or high-confidence alias match.
3. Backend logs the saved meal.
4. Dashboard updates.

If no match is found:

```text
No saved meal template found for “GB + Potato.” Do you want me to estimate the macros and log it as a one-off entry?
```

The assistant should not silently invent saved meal templates.

## Targets

The user can set:

- Daily calories.
- Protein target.
- Carbohydrate target.
- Fat target.
- Fiber target.
- Sodium target.
- Sugar target.
- Potassium target.

Targets can be static in the MVP. Carb cycling is postponed.

## Technical Architecture

Recommended stack:

- iOS app with SwiftUI, HealthKit, and Apple Charts.
- Supabase/Postgres backend.
- Row Level Security.
- Supabase Edge Functions or lightweight REST API.
- Sign in with Apple and Google.
- REST API first.
- OpenAPI schema for ChatGPT Actions.
- Future MCP server for ChatGPT/Claude-style tool access.
- Future Apple Shortcuts and Siri/App Intents.

Design principle:

```text
The app should be API-first.
```

Manual logging, Apple Shortcuts, ChatGPT, Claude, and future integrations should all write through the same backend operations.

## Apple Health

Apple Health is useful for standardized health samples, especially weight and nutrition totals. It is not ideal as the primary app database for meal type, labels, AI-created logs, confidence scores, raw natural language input, saved meals, custom targets, or audit history.

Therefore:

```text
Backend database = source of truth for app-specific entries
Apple Health = sync/read/write layer for standard health data
```

MVP reads body mass / weight from Apple Health. Later reads may include body fat percentage, resting energy, active energy, workouts, sleep, and steps.

The app may write nutrition samples to Apple Health after user permission. ChatGPT/Claude must not write directly to Apple Health from the cloud. HealthKit access happens locally on the iPhone.

Correct AI-created entry flow:

```text
User tells ChatGPT/Claude to log food
  ↓
AI calls backend API
  ↓
Backend saves food log
  ↓
iOS app syncs new food log
  ↓
iOS app writes nutrition samples to Apple Health if enabled
  ↓
Dashboard updates
```

## Backend Data Model

Core tables:

- `profiles`
- `daily_targets`
- `food_logs`
- `saved_meals`
- `saved_meal_aliases`
- `weight_entries`
- `ai_audit_log`

Saved meals should support aliases and serving multipliers. Food logs should support source labels such as `manual`, `shortcut`, `chatgpt`, `claude`, and `import`.

## API Surface

Food logs:

```http
POST /v1/food-logs
GET /v1/food-logs?date=YYYY-MM-DD
PATCH /v1/food-logs/{id}
DELETE /v1/food-logs/{id}
```

Dashboard:

```http
GET /v1/dashboard/today
GET /v1/dashboard?date=YYYY-MM-DD
```

Targets:

```http
GET /v1/targets/current
PATCH /v1/targets
```

Saved meals:

```http
GET /v1/saved-meals
GET /v1/saved-meals/resolve?query=GB%20%2B%20Potato
POST /v1/saved-meals
PATCH /v1/saved-meals/{id}
DELETE /v1/saved-meals/{id}
POST /v1/saved-meals/{id}/log
```

Weight:

```http
POST /v1/weight-entries
GET /v1/weight-trend?range=week
GET /v1/weight-trend?range=month
GET /v1/weight-trend?range=year
```

## AI Integration

First AI tool set:

- `log_food`
- `get_today_dashboard`
- `update_targets`
- `resolve_saved_meal`
- `log_saved_meal`
- `create_saved_meal`
- `list_saved_meals`

AI can create ordinary food logs and saved meal logs without confirmation after the user has connected the integration.

AI should ask confirmation before deleting logs, editing many logs, changing targets drastically, creating a saved meal from an estimate, exporting data, or writing anything involving medical/diagnostic claims.

## Roadmap

Version 0.1, Core MVP:

- SwiftUI app shell.
- Sign in with Apple/Google.
- Supabase backend.
- User targets.
- Manual macro logging.
- Optional meal type selector.
- Daily dashboard.
- Macro rings and micronutrient bars.
- Apple Health weight read.
- Manual weight input.
- Weight trend tabs.
- Basic saved meal templates if feasible.

Version 0.2, AI Write Access:

- REST API for logging, saved meal resolution, saved meal logging, dashboard readout, and targets.
- AI audit log.
- Source labels for AI-created entries.
- OpenAPI schema for ChatGPT Action.
- Claude-compatible tool description.
- App syncs AI-created food logs from backend.

Version 0.3, Speed And Reuse:

- Polished saved meals.
- Usual meal shortcuts.
- Recent meals.
- Duplicate previous meal.
- Favorite meals.
- Natural language macro parser inside the app.
- Optional Apple Shortcuts integration.
- Siri/App Intents exploration.
- Basic CSV export.

Version 0.4, Carb Cycling:

- Carb cycling mode toggle.
- Day types such as high-carb, moderate-carb, low-carb, training day, and rest day.
- Different macro targets per day type.
- Weekly schedule.
- Manual override for today.
- AI command support for day type.

## Build Process

Planned build process:

```text
1. Build backend + ChatGPT skill/action with Codex.
2. Build frontend + Claude skill/tooling with Claude Code.
3. Go live / beta.
```

Recommended sequencing:

1. Backend foundation: Supabase schema, RLS policies, API routes, seed/dev data, tests, OpenAPI spec.
2. ChatGPT Action: tool contract, saved meal resolution behavior, food log creation, dashboard query, target update.
3. Frontend: SwiftUI dashboard, manual log screen, saved meals screen, HealthKit weight read, manual weight input.
4. Claude/tool parity: Claude-compatible tool descriptions, same backend API, no duplicated business logic.
5. Beta: TestFlight, privacy policy, HealthKit permission copy, logging/error monitoring.

## Core Thesis

The first version should not try to know what the user ate. It should assume the user already knows, or that the user is willing to use AI to estimate.

Instead of asking:

```text
What food did you eat?
```

the app asks:

```text
What numbers do you want to log?
```

Once a meal has been saved, the app lets the user say:

```text
Log GB + Potato.
```

The strongest MVP demo:

```text
User tells ChatGPT:
“Log GB + Potato for lunch.”

Backend resolves the saved meal.
Backend saves the entry.
User opens app.
Dashboard already reflects the update.
```
