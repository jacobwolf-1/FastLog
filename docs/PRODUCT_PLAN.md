# FastLog Product Summary

FastLog is for people who already know their macros or use ChatGPT to estimate them and want a fast, trustworthy place to log those numbers. It is a nutrition and weight-tracking dashboard, not a food database, meal planner, or diet coach.

## Core workflow

A user saves a breakfast template with known macros and the alias “usual breakfast.” They ask ChatGPT, “Log my usual breakfast, 1.5 servings.” The Action resolves that name through the backend, then logs the returned saved meal with a 1.5 serving multiplier. The backend copies and scales the stored macros, assigns `source=chatgpt` on the ChatGPT-facing deployment, and records an AI audit row. Opening or refreshing the iPhone Today screen fetches the updated totals and food log.

If the backend cannot confidently resolve a saved meal, the assistant should explain that no template was found and ask whether to estimate and log a one-off entry. It must not silently invent a saved meal.

## Current scope

- SwiftUI screens for the daily dashboard, manual food logging, saved meals, nutrition targets, and weight trends.
- A REST API with an in-memory development store and a Supabase/Postgres store using user-scoped tokens and row-level security.
- Saved meal names and aliases, backend resolution, serving multipliers, and historical logs that preserve copied macros when a template changes.
- A ChatGPT Action contract restricted to seven operations for logging, saved meals, today's dashboard, and target updates; AI-origin writes receive server-derived provenance and audit records.
- Optional on-device HealthKit body-mass reading. A user can prefill a weight entry from Apple Health and save it to FastLog; the app does not write back to Apple Health.
