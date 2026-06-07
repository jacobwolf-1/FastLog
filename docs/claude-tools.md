# Claude Tool Contract

This is the Claude parity artifact for FastLog v0.2B. Claude tools should wrap the same authenticated backend endpoints as the ChatGPT Action and iOS app. Do not add separate Claude-only saved-meal resolution, fuzzy matching, persistence, or product behavior.

Claude-facing tool names use snake_case. The ChatGPT OpenAPI operation IDs remain unchanged in `openapi/chatgpt-action.yaml`.

## Shared Rules

- Use the FastLog backend as the source of truth.
- Pass authentication safely to the backend.
- For a Claude-facing deployment, set server-side integration context with `FASTLOG_INTEGRATION_PROVIDER=claude`.
- Do not include `source` or `provider` as tool arguments.
- Do not maintain a local Claude-side saved-meal cache for matching.
- Do not perform local fuzzy matching in the Claude tool layer.
- When logging a saved meal by name, call `resolve_saved_meal` first.
- If no saved meal is found, do not invent or silently create one.
- Do not expose destructive actions.
- Do not write to Apple Health or HealthKit.
- Do not make medical or diagnostic claims.

## Tools

### `log_food`

Purpose: Log a one-off food macro entry when the user provides explicit macro numbers or asks Claude to log an estimate as a one-off entry.

Backend endpoint: `POST /v1/food-logs`

Required arguments:

- `calories`

Optional arguments:

- `logged_at`
- `meal_type`
- `label`
- `protein_g`
- `carbs_g`
- `fat_g`
- `fiber_g`
- `sodium_mg`
- `sugar_g`
- `potassium_mg`
- `raw_input`

Safety rules:

- Use `meal_type=unspecified` when no meal type is provided.
- Do not send `source` or `provider`.
- Do not use this tool to create a saved meal template.

### `get_today_dashboard`

Purpose: Answer "what do I have left today?", "where am I at today?", and similar same-day target/totals questions.

Backend endpoint: `GET /v1/dashboard/today`

Required arguments: none.

Optional arguments: none.

Safety rules:

- This is the only dashboard read in the first Claude tool surface.
- Do not expose date-range dashboard reads.

### `update_targets`

Purpose: Update the user's daily macro targets when the user clearly asks for target changes.

Backend endpoint: `PATCH /v1/targets`

Required arguments:

- `calories`

Optional arguments:

- `protein_g`
- `carbs_g`
- `fat_g`
- `fiber_g`
- `sodium_mg`
- `sugar_g`
- `potassium_mg`
- `effective_date`

Safety rules:

- Ask for confirmation before drastic or ambiguous target changes.
- Do not send `source` or `provider`.
- Do not present targets as medical advice.

### `resolve_saved_meal`

Purpose: Resolve a user-provided saved meal name or alias using backend exact, normalized, and high-confidence fuzzy matching.

Backend endpoint: `GET /v1/saved-meals/resolve?query=<query>`

Required arguments:

- `query`

Optional arguments: none.

Safety rules:

- Always use this before `log_saved_meal` when the user refers to a saved meal by name.
- Do not duplicate fuzzy matching in Claude instructions, prompts, or local code.
- If the backend returns `match_status=not_found`, tell the user no saved meal template was found and ask whether they want to estimate/log a one-off entry.

### `log_saved_meal`

Purpose: Log an already resolved saved meal template, optionally with a serving multiplier and meal type.

Backend endpoint: `POST /v1/saved-meals/{id}/log`

Required arguments:

- `id`

Optional arguments:

- `logged_at`
- `meal_type`
- `serving_multiplier`
- `raw_input`

Safety rules:

- Call only after `resolve_saved_meal` returns `match_status=found`, or when the user directly provides a trusted saved meal ID from FastLog.
- Preserve explicit serving multipliers such as `1.5x`.
- Do not send `source` or `provider`.

### `create_saved_meal`

Purpose: Create a saved meal template only when the user explicitly asks to save a reusable meal/template.

Backend endpoint: `POST /v1/saved-meals`

Required arguments:

- `name`
- `calories`

Optional arguments:

- `aliases`
- `default_meal_type`
- `protein_g`
- `carbs_g`
- `fat_g`
- `fiber_g`
- `sodium_mg`
- `sugar_g`
- `potassium_mg`

Safety rules:

- Do not create saved meals silently from estimates.
- Confirm before saving an estimated meal as a reusable template.
- Do not use this as a food search or meal-planning feature.

### `list_saved_meals`

Purpose: List the user's saved meal templates when browsing or disambiguating existing templates.

Backend endpoint: `GET /v1/saved-meals`

Required arguments: none.

Optional arguments: none.

Safety rules:

- This is not a substitute for saved-meal resolution.
- For "log <meal name>" flows, still call `resolve_saved_meal` before `log_saved_meal`.

## Explicitly Out Of Scope

The first Claude tool surface must not expose:

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

## MCP Roadmap

The first Claude parity artifact is this tool contract.

A future MCP server can wrap the same backend endpoints, but should stay thin:

- It must not duplicate saved-meal resolution.
- It must not maintain its own database.
- It must pass through auth safely.
- It must preserve server-side source/provider derivation.
- It must expose the same seven safe operations unless a later product pass explicitly expands the surface.

No MCP server is implemented in v0.2B.
