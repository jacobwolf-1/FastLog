# Saved Meal Resolution

Saved meals live in the FastLog backend database. They should not live inside ChatGPT, Claude, or a local prompt.

## Match Priority

Resolution should evaluate candidates in this order:

1. Exact name match.
2. Exact alias match.
3. Normalized name match.
4. Normalized alias match.
5. Fuzzy match only if high confidence.

## Normalization

Normalization should make user phrasing less brittle while preserving meaning.

Recommended normalization:

- Trim whitespace.
- Lowercase.
- Replace punctuation and repeated whitespace with single spaces for display-style comparison.
- Use a compact alphanumeric key for database matching.

Examples:

```text
GB + Potato     -> gbpotato
gb potato       -> gbpotato
Ground-beef potato -> groundbeefpotato
```

## Fuzzy Matching

Fuzzy matching is allowed only when confidence is high. Suggested threshold:

```text
similarity >= 0.72
```

If multiple fuzzy candidates are close, return `not_found` or an ambiguous result instead of guessing.

## Found Response

```json
{
  "match_status": "found",
  "match_type": "exact_alias",
  "confidence": 1,
  "saved_meal": {
    "id": "uuid",
    "name": "GB + Potato",
    "default_meal_type": "unspecified",
    "calories": 610,
    "protein_g": 50,
    "carbs_g": 56,
    "fat_g": 18
  }
}
```

## Not Found Response

```json
{
  "match_status": "not_found",
  "message": "No saved meal template found."
}
```

AI-facing response to the user:

```text
I do not see a saved meal template named “GB + Potato.” Do you want me to estimate macros for it and log it as a one-off entry?
```

## Product Rule

If no confident saved meal match exists, do not invent macros and do not create a saved meal silently.
