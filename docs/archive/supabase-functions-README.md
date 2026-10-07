# Supabase Edge Functions

The current executable API is implemented as a small dependency-free TypeScript REST server in `src/`.

Edge Functions are not implemented in this pass. If the backend is later moved into Supabase Edge Functions, keep the same route contract documented in `docs/api.md` and the same ChatGPT Action subset in `openapi/chatgpt-action.yaml`.

Do not expose public unauthenticated write paths. Do not expose `SUPABASE_SERVICE_ROLE_KEY` to iOS, ChatGPT Actions, browsers, or public clients.
