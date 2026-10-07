# Deployment/Auth Plan

FastLog v0.2C is a planning pass for deploying the existing safe AI Action/tool surface. It does not add product features, expand the OpenAPI schema, implement OAuth, implement MCP, or change iOS.

## 1. Current Backend/Auth State

The backend is a dependency-free Node/TypeScript REST API with two storage modes:

- `FASTLOG_STORE=memory`: local development and tests only.
- `FASTLOG_STORE=supabase`: production-shaped mode using Supabase REST with the caller's user bearer token and Supabase RLS.

The API currently expects:

```text
Authorization: Bearer <user jwt>
```

Memory mode accepts only local development tokens:

```text
Authorization: Bearer dev:<user-id>[:email]
```

The dev token is not production auth and must not be presented as safe for a hosted Action or shared Claude tool.

The current safe ChatGPT Action surface exposes exactly:

- `logFood`
- `getTodayDashboard`
- `updateTargets`
- `resolveSavedMeal`
- `logSavedMeal`
- `createSavedMeal`
- `listSavedMeals`

Claude parity should keep the same backend behavior with snake_case tool names:

- `log_food`
- `get_today_dashboard`
- `update_targets`
- `resolve_saved_meal`
- `log_saved_meal`
- `create_saved_meal`
- `list_saved_meals`

Saved-meal resolution lives in the backend at `GET /v1/saved-meals/resolve`. ChatGPT, Claude, and a future MCP wrapper must not duplicate fuzzy matching or maintain their own saved-meal database.

## 2. Deployment Target Options

### Lightweight Node API Deployment

This is the recommended first deployment path because it matches the current repo with the least code churn.

Good fits include a small Node service on a platform such as Fly.io, Render, Railway, a container host, or any HTTPS-capable Node runtime that can run:

```sh
npm start
```

Advantages:

- Preserves the current `src/server.ts` and `src/app.ts` shape.
- Keeps the same test surface already covered by `npm test` and `npm run test:ai-action`.
- Makes `FASTLOG_INTEGRATION_PROVIDER=chatgpt` or `claude` a deployment environment decision.
- Avoids converting routing/auth/store code during this planning pass.

Tradeoffs:

- The owner must manage HTTPS domain, environment variables, logs, uptime, and deployment secrets.
- Production auth still needs a real per-user token exchange before broad use.
- If a private smoke test uses a controlled static credential, the isolation risk is operational rather than solved by the current code.

### Supabase Edge Functions Option

Supabase Edge Functions remain a plausible later path because the database and RLS already live in Supabase.

Advantages:

- Hosting, database, auth, and RLS can live closer together.
- Supabase Auth integration may be simpler if the Action/tool flow uses Supabase-issued JWTs.
- Operational surface may be smaller for a Supabase-centered product.

Tradeoffs:

- The current Node `http` server shape would need an adapter or rewrite for the Edge Functions runtime.
- Tests may need an additional harness for deployed/function behavior.
- A conversion should be treated as a deployment migration, not as part of v0.2C planning.

Recommendation: deploy the existing Node API first. Consider Supabase Edge Functions only after the private Action auth path is proven.

## 3. ChatGPT Action Auth Options

### Private/Local Development Token

Use `Bearer dev:<user-id>[:email]` only with `FASTLOG_STORE=memory` for local demos and smoke tests.

This is acceptable for:

- Local `npm run test:ai-action`.
- A temporary local demo using `docs/local-ai-demo.md`.
- A private no-real-data smoke test if a local memory server is exposed temporarily over HTTPS and the risk is understood.

This is not acceptable for:

- Production.
- Real user data.
- Multi-user Action use.
- Public docs or config that imply it is safe outside memory mode.

### Static API Key

A static API key can be acceptable only for a narrow private/internal smoke test with one controlled user mapping, short lifetime, and no expectation of multi-user isolation.

The current backend does not implement a static API-key-to-user mapping. If this path is chosen, it should be a small explicit auth adapter with these constraints:

- It maps one configured secret to one FastLog user.
- It is deployed only for a private test surface.
- It does not accept `user_id` from the client.
- It is removed or disabled before multi-user use.
- It never uses or exposes the Supabase service-role key to ChatGPT.

Static API keys are not recommended for production multi-user ChatGPT Actions because every request authenticates as the same user unless extra server-side mapping is added.

### OAuth/Per-User Auth

OAuth-compatible per-user auth is the recommended production direction.

The production Action should authenticate each ChatGPT user as a specific FastLog user, then pass a user-scoped token to the backend. The backend should continue to rely on server-side user scoping and Supabase RLS or equivalent authorization. ChatGPT must never send `user_id`.

Open design choices:

- Whether to use Supabase Auth directly or a small FastLog auth broker.
- Whether the token passed to the API is a Supabase user JWT or an app-issued token exchanged server-side for user context.
- How refresh, revocation, account linking, and disconnect are handled.

## 4. Domain Constraints

The ChatGPT Action API must be served over HTTPS.

The final OpenAPI server URL must replace:

```text
https://api.example.com
```

with the deployed base URL, for example:

```text
https://api.fastlog.example
```

The exact domain is an owner decision.

OAuth domain alignment must be planned before production. The Action API domain, authorization URL domain, token URL domain, callback/redirect configuration, and Supabase/Auth provider domains must be compatible with the way ChatGPT and Claude expect OAuth flows to work.

Do not assume a Supabase-hosted auth domain is automatically compatible if the primary API domain differs. If the API is hosted at `api.fastlog.example` but auth is hosted at a Supabase project domain, validate that the Action/tool provider accepts that split and that redirect URIs are configured exactly.

## 5. Recommended FastLog Path

Short-term:

- Deploy the existing Node API behind HTTPS.
- Keep `openapi/chatgpt-action.yaml` at the same seven-operation surface.
- Replace the OpenAPI server URL with the deployed HTTPS base URL only when ready to configure the private Action.
- Run a private Action smoke test with a controlled token only if user-isolation risk is understood.
- Prefer no-real-data or a dedicated test user for the first private Action test.

Production:

- Implement real per-user auth/token exchange before broader use.
- Prefer OAuth-compatible account linking for ChatGPT Actions.
- Keep Claude parity on the same auth model or a deliberately equivalent per-user token exchange.
- Preserve backend-only saved-meal resolution.
- Preserve server-derived `source` and `provider`.

## 6. User Isolation Model

Every request must authenticate as exactly one FastLog user.

Rules:

- Clients must not send `user_id`.
- OpenAPI/tool schemas must not expose `user_id`.
- The backend must derive the user from auth.
- Supabase RLS or equivalent server-side user scoping must remain authoritative.
- The Supabase anon key may be used by trusted backend code with user bearer tokens.
- The Supabase service-role key must not be used by public clients or AI tools.

For a private single-user smoke test, isolation is only acceptable if all requests intentionally map to one test user and no other user data is reachable. That is not a production model.

## 7. Source/Provider Model

Clients never send `source` or `provider`.

ChatGPT deployment:

```sh
FASTLOG_INTEGRATION_PROVIDER=chatgpt
```

The backend derives:

```text
source=chatgpt
provider=chatgpt
```

Claude deployment:

```sh
FASTLOG_INTEGRATION_PROVIDER=claude
```

The backend derives:

```text
source=claude
provider=claude
```

Non-AI/default deployments should keep manual/default behavior. Spoofed `source` and `provider` request fields are untrusted and must continue to be ignored or stripped from audit payloads.

## 8. Secret Handling

Secrets must stay server-side.

Do not put secrets in:

- `openapi/chatgpt-action.yaml`
- ChatGPT Action public schema text.
- Claude tool descriptions.
- iOS source.
- Browser bundles.
- Public frontend config.
- README examples.
- Screenshots or support docs.

`SUPABASE_SERVICE_ROLE_KEY` is server-only and must never be exposed to iOS, ChatGPT Actions, Claude tools, browsers, or public clients.

For production, prefer user bearer tokens plus Supabase anon key/RLS, or an app auth layer that still scopes every request to one authenticated user.

## 9. Minimal Deployment Checklist

Minimum path to a private single-user Action test:

1. Choose a temporary HTTPS API URL.
2. Deploy the current Node API with `FASTLOG_STORE=supabase` for real backend data or `FASTLOG_STORE=memory` for no-real-data testing.
3. Set `FASTLOG_INTEGRATION_PROVIDER=chatgpt`.
4. Use a dedicated test FastLog user.
5. Decide the temporary auth approach:
   - For no-real-data local memory testing, use the dev bearer token only in memory mode.
   - For a Supabase-backed test, use a user-scoped token or a short-lived controlled adapter, not a service-role key.
6. Replace `https://api.example.com` in a private copy of the Action schema with the HTTPS base URL.
7. Configure a private ChatGPT Action with the same seven operations.
8. Run the saved-meal flow: create target, create `GB + Potato`, resolve it, log `1.5x`, and fetch today's dashboard.
9. Verify logs have `source=chatgpt` and audit rows have `provider=chatgpt`.
10. Tear down or rotate temporary credentials after the test.

Do not use this private smoke-test setup for multiple users.

## 10. Open Questions Requiring Owner Decision

- What production domain should host the API and replace `https://api.example.com`?
- Should the first deployment target be Fly.io, Render, Railway, another Node host, or a Supabase Edge Functions migration?
- Will production auth use Supabase Auth directly, a FastLog OAuth broker, or another identity provider?
- Should private Action testing use memory mode/no real data, a dedicated Supabase test user, or a temporary single-user auth adapter?
- What is the acceptable lifetime and rotation policy for any private smoke-test credential?
- Should ChatGPT and Claude use separate deployments with separate `FASTLOG_INTEGRATION_PROVIDER` values, or one deployment selected by route/host?
- What is the account disconnect/revocation story for production users?
- Which monitoring/logging platform should capture Action/tool errors without leaking sensitive payloads?

## 11. Implementation Steps After This Planning Pass

1. Owner chooses the deployment host and final HTTPS base URL.
2. Owner chooses the private smoke-test auth approach.
3. Implement only the minimal auth adapter needed for that chosen private test, if the existing bearer-token path is insufficient.
4. Deploy the Node API with production environment variables.
5. Verify Supabase migration against a real Supabase project.
6. Update a private Action schema copy or later the committed OpenAPI server URL once the deployment is stable.
7. Configure the private ChatGPT Action.
8. Run `npm test`, `npm run verify:migration`, `npm run test:ai-action`, then run the manual private Action smoke flow.
9. Inspect database rows for user isolation, `source=chatgpt`, and `provider=chatgpt`.
10. Plan the production OAuth/per-user auth implementation before any broader release.
