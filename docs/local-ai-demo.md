# Local AI Action Demo

This is the local v0.2 demo flow for the ChatGPT Action-safe API surface. It uses memory mode and the development bearer token only.

Do not use the dev bearer token in production.

## 1. Start The Memory Backend In ChatGPT Mode

In one terminal:

```sh
FASTLOG_STORE=memory FASTLOG_INTEGRATION_PROVIDER=chatgpt npm run dev
```

The default local API URL is:

```text
http://localhost:8787
```

In another terminal:

```sh
BASE_URL=http://localhost:8787
TOKEN='dev:user-a:user-a@example.test'
AUTH="Authorization: Bearer $TOKEN"
```

## 2. Create Or Update Targets

```sh
curl -s -X PATCH "$BASE_URL/v1/targets" \
  -H "$AUTH" \
  -H 'Content-Type: application/json' \
  -d '{
    "calories": 2400,
    "protein_g": 180,
    "carbs_g": 250,
    "fat_g": 75,
    "raw_input": "Set my targets to 2400 calories, 180 protein, 250 carbs, 75 fat"
  }'
```

## 3. Create Saved Meal GB + Potato

```sh
curl -s -X POST "$BASE_URL/v1/saved-meals" \
  -H "$AUTH" \
  -H 'Content-Type: application/json' \
  -d '{
    "name": "GB + Potato",
    "aliases": ["ground beef potato", "beef potato", "gb potato"],
    "default_meal_type": "dinner",
    "calories": 610,
    "protein_g": 50,
    "carbs_g": 56,
    "fat_g": 18,
    "raw_input": "Save GB + Potato"
  }'
```

Copy the returned `id` for step 5.

## 4. Resolve GB + Potato

```sh
curl -s "$BASE_URL/v1/saved-meals/resolve?query=GB%20%2B%20Potato" \
  -H "$AUTH"
```

Expected result:

```json
{
  "match_status": "found"
}
```

Use the returned `saved_meal.id` in the next request.

## 5. Log 1.5x Saved Meal

Replace `<saved-meal-id>` with the ID returned by step 3 or step 4.

```sh
curl -s -X POST "$BASE_URL/v1/saved-meals/<saved-meal-id>/log" \
  -H "$AUTH" \
  -H 'Content-Type: application/json' \
  -d '{
    "meal_type": "dinner",
    "serving_multiplier": 1.5,
    "raw_input": "Log 1.5x GB + Potato for dinner"
  }'
```

Expected logged macros:

```text
915 calories
75 protein_g
84 carbs_g
27 fat_g
source=chatgpt
```

## 6. Fetch Dashboard

```sh
curl -s "$BASE_URL/v1/dashboard/today" \
  -H "$AUTH"
```

## 7. Confirm Totals

With only the 1.5x saved meal logged, expected dashboard totals are:

```text
calories: 915
protein_g: 75
carbs_g: 84
fat_g: 27
```

Expected remaining values against the targets above are:

```text
calories: 1485
protein_g: 105
carbs_g: 166
fat_g: 48
```

This flow exercises only the Action-safe endpoints. It does not call deletes, broad edits, weight endpoints, date-range reads, or HealthKit writes.
