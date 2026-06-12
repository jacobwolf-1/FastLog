# FastLog iOS (SwiftUI MVP)

Minimal, API-driven macro dashboard. The backend in this repo is the source of
truth; this app holds no nutrition logic of its own (no food database, no local
saved-meal fuzzy matching).

## Requirements

- Xcode 16+ (the project uses a file-system-synchronized group, objectVersion 77)
- iOS 17+ deployment target (Observation, Charts)

## Auth setup (primary path)

The app signs in through Supabase Auth (email/password) and sends the user's
Supabase JWT as `Authorization: Bearer <token>` to the deployed backend
(`https://fastlog-production-9626.up.railway.app` by default).

1. Copy `FastLog/FastLogConfig.example.plist` to `FastLog/FastLogConfig.plist`
   (it is gitignored — never commit the real file).
2. Fill in `SUPABASE_URL` and `SUPABASE_ANON_KEY` from your Supabase project's
   Dashboard → Settings → API. The anon key is the public key — **never** the
   service role key.
3. In Supabase Dashboard → Authentication → Providers, make sure **Email** is
   enabled. If "Confirm email" is on, new sign-ups must confirm via email
   before signing in (the app surfaces this).
4. Run the app: sign up / sign in on the auth screen. The session is stored in
   the Keychain and restored (with automatic token refresh) on launch.

Auth is implemented as a small dependency-free client against Supabase's GoTrue
REST endpoints (`AuthManager.swift`). Migrating to the official supabase-swift
SDK (and adding Sign in with Apple + magic links) is a documented follow-up.

## Local development (developer mode)

For the local memory-mode backend, no Supabase setup is needed:

1. Start the backend from the repo root:

   ```sh
   cd /Users/jacobwolf/FastLog
   FASTLOG_STORE=memory npm run dev   # listens on http://localhost:8787
   ```

2. In the app, open **Developer options** (footer link on the auth screen, or
   Settings → Developer options), enable **Use manual token**, set the base URL
   to `http://localhost:8787` ("Use local dev server" button), and keep the
   default token `dev:user-a:user-a@example.test`.

   - Simulator reaches your Mac at `localhost`.
   - A physical device must use your Mac's LAN IP (e.g. `http://192.168.1.10:8787`)
     and be on the same network.

### Regenerating the project (optional)

```sh
brew install xcodegen
cd ios && xcodegen generate
```

## Screens → endpoints

| Screen        | Endpoints |
| ------------- | --------- |
| Today         | `GET /v1/dashboard/today` |
| Manual log    | `POST /v1/food-logs` |
| Edit/Delete   | `PATCH` / `DELETE /v1/food-logs/{id}` |
| Saved Meals   | `GET/POST /v1/saved-meals`, `PATCH/DELETE /v1/saved-meals/{id}`, `POST /v1/saved-meals/{id}/log`, `GET /v1/saved-meals/resolve` (search) |
| Targets       | `GET /v1/targets/current`, `PATCH /v1/targets` |
| Weight        | `GET /v1/weight-trend?range=…`, `POST /v1/weight-entries` |

## HealthKit

Body-mass **read** only, on-device. Optional: the app works fully without it.
The Weight entry sheet can prefill from Apple Health, but the value is saved to
the FastLog backend as a normal `manual` weight entry — nothing is written back
to Apple Health. HealthKit does not run on the Simulator.

## Notes / not yet done

- No app icon / asset catalog yet (not required for Simulator; required for TestFlight).
- Source declaration is server-derived; the app never claims `source`/`provider`.
- Sign in with Apple, magic links, and the official supabase-swift SDK are follow-ups.
