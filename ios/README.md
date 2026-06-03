# FastLog iOS (SwiftUI MVP)

Minimal, API-driven macro dashboard. The backend in this repo is the source of
truth; this app holds no nutrition logic of its own (no food database, no local
saved-meal fuzzy matching).

## Requirements

- Xcode 16+ (the project uses a file-system-synchronized group, objectVersion 77)
- iOS 17+ deployment target (Observation, Charts)

## Run it

1. Start the backend in memory mode from the repo root:

   ```sh
   cd /Users/jacobwolf/FastLog
   FASTLOG_STORE=memory npm run dev   # listens on http://localhost:8787
   ```

2. Open `ios/FastLog.xcodeproj` in Xcode, pick an iPhone Simulator, Run.

3. The app defaults to `http://localhost:8787` and the dev token
   `dev:user-a:user-a@example.test`. Change either in the **Settings** tab; use
   **Test connection** to confirm reachability.

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
| Saved Meals   | `GET/POST /v1/saved-meals`, `PATCH/DELETE /v1/saved-meals/{id}`, `POST /v1/saved-meals/{id}/log` |
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
