# Developer Smoke-Test Cleanup

This cleanup flow is for removing private ChatGPT Action smoke-test data before returning to frontend work. It is developer tooling only, not product functionality.

The cleanup script uses the normal FastLog REST API with a user bearer token. It does not connect directly to Supabase, does not use a service-role key, and does not bypass RLS.

## Required Environment

```sh
export FASTLOG_API_BASE_URL=https://fastlog-production-9626.up.railway.app
export FASTLOG_TEST_JWT=<temporary-user-jwt>
```

Do not paste the JWT into docs, GitHub, terminal transcripts, issue comments, or Codex. Refresh the temporary Supabase JWT locally through your usual authenticated test-user flow, store it in an environment variable, and avoid commands that echo it.

## Dry Run First

Dry run is the default. The script prints the records it would delete and exits without mutating data.

```sh
npm run cleanup:smoke -- --today
```

Clean a specific date:

```sh
npm run cleanup:smoke -- --date 2026-06-10
```

Add extra log filters:

```sh
npm run cleanup:smoke -- --today --label-contains "Test"
npm run cleanup:smoke -- --today --raw-input-contains "Log"
```

By default, food-log cleanup targets obvious smoke-test entries for the selected date:

- `label` or `raw_input` containing `Test`
- `label` or `raw_input` containing `protein yogurt`
- `label` or `raw_input` containing `generic food entry`
- `label` or `raw_input` containing `GB + Potato`
- food logs with `source="chatgpt"`

The script prints a warning before deleting `source="chatgpt"` logs because some AI-created entries may be intentional.

## Confirmed Delete

Re-run with `--confirm-delete` only after reviewing the dry-run output.

```sh
npm run cleanup:smoke -- --today --confirm-delete
```

Specific date:

```sh
npm run cleanup:smoke -- --date 2026-06-10 --confirm-delete
```

The script refuses to run without `FASTLOG_API_BASE_URL`, `FASTLOG_TEST_JWT`, and either `--today` or `--date YYYY-MM-DD`. It does not provide an all-data delete mode.

## Saved Meals

Saved meal cleanup is opt-in. Saved meals are not deleted by default.

Dry run for an exact saved meal name:

```sh
npm run cleanup:smoke -- --today --include-saved-meals --saved-meal-name "GB + Potato"
```

Confirmed delete for an exact saved meal name:

```sh
npm run cleanup:smoke -- --today --include-saved-meals --saved-meal-name "GB + Potato" --confirm-delete
```

Use contains matching only for clearly test-only names:

```sh
npm run cleanup:smoke -- --today --include-saved-meals --saved-meal-name-contains "Remote Smoke" --confirm-delete
```

## Warnings

- Do not use `SUPABASE_SERVICE_ROLE_KEY` for cleanup.
- Do not commit JWTs or put them in shell history intentionally.
- Do not run destructive cleanup against a real production user.
- Do not expose cleanup routes in `openapi/chatgpt-action.yaml`.
- This is dev/test tooling for the authenticated owner account, not a user-facing feature.
