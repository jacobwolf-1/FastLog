# Action Deployment Checklist

Use this checklist before configuring a real ChatGPT Action or Claude tool integration. It is intentionally scoped to the v0.2 safe AI surface.

## 1. Before Deployment

- [ ] Confirm this pass does not modify `ios/`.
- [ ] Confirm this pass does not modify `src/`.
- [ ] Confirm this pass does not modify `openapi/chatgpt-action.yaml` unless the owner explicitly approves it.
- [ ] Confirm this pass does not modify `supabase/migrations/`.
- [ ] Confirm no MCP server has been implemented.
- [ ] Confirm no OAuth server has been implemented without owner approval.
- [ ] Confirm no product features were added.
- [ ] Confirm saved-meal resolution remains backend-only through `/v1/saved-meals/resolve`.

## 2. Backend Deployment

- [ ] Choose the first deployment target.
- [ ] Prefer a lightweight Node API deployment for the first private Action test.
- [ ] Ensure the API is served over HTTPS.
- [ ] Set `FASTLOG_STORE=supabase` for real backend data.
- [ ] Set `FASTLOG_INTEGRATION_PROVIDER=chatgpt` for the ChatGPT-facing deployment.
- [ ] Set `FASTLOG_INTEGRATION_PROVIDER=claude` for a Claude-facing deployment.
- [ ] Set `SUPABASE_URL` server-side.
- [ ] Set `SUPABASE_ANON_KEY` server-side.
- [ ] Keep `SUPABASE_SERVICE_ROLE_KEY` server-side only if it is present at all.
- [ ] Do not expose service-role credentials to iOS, ChatGPT, Claude, browsers, public bundles, or OpenAPI files.

## 3. Supabase/Database Verification

- [ ] Verify the target Supabase project has the initial schema applied.
- [ ] Verify RLS is enabled for user-owned tables.
- [ ] Verify saved meal aliases cascade when a saved meal is deleted.
- [ ] Verify food log history is preserved when a saved meal is deleted.
- [ ] Verify `ai_audit_log` exists and is user-scoped.
- [ ] Run `npm run verify:migration`.
- [ ] If Supabase CLI is unavailable, record that only static migration verification ran.
- [ ] Before production, run a true Supabase migration apply/reset against a real local or staging database.

## 4. Auth/Token Decision

- [ ] Choose the private smoke-test auth approach.
- [ ] Confirm `Bearer dev:<user-id>[:email]` is used only for local memory mode.
- [ ] Confirm the dev bearer token is not documented or configured as production auth.
- [ ] For a static/private token test, confirm it maps to one dedicated test user only.
- [ ] For a static/private token test, confirm the credential is short-lived and rotated after testing.
- [ ] For production, plan OAuth-compatible per-user auth.
- [ ] Confirm clients cannot supply `user_id`.
- [ ] Confirm clients cannot supply `source`.
- [ ] Confirm clients cannot supply `provider`.
- [ ] Confirm each request authenticates as exactly one FastLog user.

## 5. ChatGPT Action Configuration

- [ ] Confirm `openapi/chatgpt-action.yaml` exposes exactly seven operations.
- [ ] Confirm the operations are `logFood`, `getTodayDashboard`, `updateTargets`, `resolveSavedMeal`, `logSavedMeal`, `createSavedMeal`, and `listSavedMeals`.
- [ ] Confirm no `DELETE` endpoints are exposed.
- [ ] Confirm no food-log `PATCH` endpoint is exposed.
- [ ] Confirm no saved-meal `PATCH` endpoint is exposed.
- [ ] Confirm no weight endpoints are exposed.
- [ ] Confirm no date-range food-log reads are exposed.
- [ ] Confirm no date-range dashboard reads are exposed.
- [ ] Confirm `GET /v1/targets/current` is not exposed.
- [ ] Confirm no `source`, `provider`, or `user_id` request fields are exposed.
- [ ] Confirm saved-meal logging by name still requires `resolveSavedMeal` before `logSavedMeal`.
- [ ] Confirm the private Action configuration uses your deployment's public HTTPS URL as the OpenAPI server URL.
- [ ] Keep the suggested GPT instructions aligned with `docs/chatgpt-action-setup.md` and run the private checklist in `docs/chatgpt-action-smoke-test.md`.

## 6. Claude Parity Configuration

- [ ] Confirm Claude tools mirror the same seven backend operations.
- [ ] Confirm Claude tool names are `log_food`, `get_today_dashboard`, `update_targets`, `resolve_saved_meal`, `log_saved_meal`, `create_saved_meal`, and `list_saved_meals`.
- [ ] Confirm Claude tools do not include deletes, broad edits, weight endpoints, date-range reads, or HealthKit writes.
- [ ] Confirm Claude tools do not accept `source`, `provider`, or `user_id`.
- [ ] Confirm Claude saved-meal logging by name calls `resolve_saved_meal` first.
- [ ] Confirm Claude does not duplicate saved-meal fuzzy matching locally.
- [ ] Confirm Claude uses the same backend auth/user isolation model as ChatGPT.

## 7. Smoke Tests

- [ ] Run `npm test`.
- [ ] Run `npm run verify:migration`.
- [ ] Run `npm run test:ai-action`.
- [ ] Start the deployed backend and confirm `/v1/dashboard/today` requires auth.
- [ ] Create or update targets for a dedicated test user.
- [ ] Create saved meal `GB + Potato`.
- [ ] Resolve `GB + Potato` through the backend endpoint.
- [ ] Log `1.5x GB + Potato`.
- [ ] Fetch today's dashboard.
- [ ] Confirm totals: 915 calories, 75g protein, 84g carbs, 27g fat for the saved-meal log.
- [ ] Confirm the logged saved meal has `source=chatgpt` on ChatGPT deployment.
- [ ] Confirm AI audit rows have `provider=chatgpt` on ChatGPT deployment.
- [ ] Repeat source/provider checks with `claude` before enabling Claude tools.

## 8. Security Checks

- [ ] Confirm HTTPS is required for the Action API.
- [ ] Confirm no service-role key appears in OpenAPI, docs examples, iOS files, browser bundles, or tool configuration.
- [ ] Confirm no public config contains production secrets.
- [ ] Confirm the Supabase anon key is used only with user-scoped bearer auth.
- [ ] Confirm RLS or equivalent server-side user scoping blocks cross-user reads/writes.
- [ ] Confirm Action/tool clients cannot write directly to Apple Health.
- [ ] Confirm HealthKit writes remain local to iOS after backend sync.
- [ ] Confirm no food database, barcode scanning, meal planning, or diet coaching behavior was added.
- [ ] Confirm temporary private-test credentials are rotated or revoked after testing.

## 9. Criteria To Move From v0.2 To v0.3

- [ ] The v0.2 safe Action/tool surface remains exactly seven operations.
- [ ] Private ChatGPT Action smoke test has passed against a deployed HTTPS backend.
- [ ] User isolation has been verified with a real or staging backend.
- [ ] Server-derived `source=chatgpt` and `provider=chatgpt` have been verified.
- [ ] Claude parity contract remains aligned with the same seven backend operations.
- [ ] Production auth direction is decided.
- [ ] OAuth/per-user auth is planned before any broader multi-user release.
- [ ] Supabase service-role key handling is confirmed safe.
- [ ] HealthKit boundary is unchanged.
- [ ] Owner explicitly approves moving to v0.3 scope.
