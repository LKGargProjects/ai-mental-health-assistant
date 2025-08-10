# Week 0: Quests MVP (Minimal, Local, Deterministic)

This PR ships the smallest working foundation for “Quests” without changing any existing UI widgets. It adds:

- `lib/quests/quests_engine.dart` — single-file QuestsEngine module (selector, telemetry, timers, adapter)
- `assets/quests/quests.json` — 28‑item quest catalog (source of truth for editing)
- Minimal glue (2–3 lines) in `lib/dhiwise/presentation/wellness_dashboard_screen/wellness_dashboard_screen.dart` to initialize and fetch data (no widget changes)

Note: The engine has an embedded fallback copy of the catalog so the app can function even if assets/remote are unavailable in Week 0.

## What changed

- Deterministic daily selection (5–6 items) keyed by date.
- Variety constraints:
  - ≥1 TASK
  - ≥1 from {TIP, RESOURCE}
  - ≥1 from {CHECK‑IN, PROGRESS}
  - ≥1 item with `duration_min ≤ 3`
  - Avoid repeating the same TASK > 2× within a rolling 7 days if alternates exist
- Local telemetry via `shared_preferences` (approved): impressions, starts, completes, elapsed_ms, last_shown_at, last_completed_at, usefulness_rating, control_rating.
- Timer helpers (start/stop/auto-complete). Auto-complete awards elapsed based on `duration_min` when appropriate.
- Progress summary (Steps Left, XP Earned) computed locally.

## File locations

- Engine: `lib/quests/quests_engine.dart`
- Catalog: `assets/quests/quests.json`
- Minimal glue: `lib/dhiwise/presentation/wellness_dashboard_screen/wellness_dashboard_screen.dart` (calls engine, no widget changes)

## How selection works

- A seeded RNG from the calendar date (yyyy-mm-dd) ensures the same list for the same day.
- Ensures category coverage and at least one short (≤3 min) item.
- Attempts to reduce overuse of the same TASK across the last 7 days using lightweight local history.

## XP rules

- TASK: +10 per completion
- CHECK‑IN: +5 per completion
- TIP/RESOURCE: +3 per completion
- PROGRESS: +5 per completion

## Persistence

- Uses `shared_preferences` for cross‑platform local storage.
- Keys:
  - `quests_engine.catalog_v1` — cached catalog JSON
  - `quests_engine.telemetry_v1` — event counters/timestamps
  - `quests_engine.history_v1` — last 7 days of selected tasks
  - `quests_engine.timers_v1` — in‑progress timers

## Local/Remote catalog toggle (Week 0)

- `QuestsEngine.remoteCatalogUrl` (default null) can be set to a tiny static URL to fetch remotely.
- If remote fails or is not configured, the engine falls back to the embedded JSON.
- The `assets/quests/quests.json` is the editable source of truth; embedded fallback should be kept in sync when updated.

## How to update the catalog

1. Edit `assets/quests/quests.json` (valid JSON, no comments).
2. Optionally update the embedded fallback in `lib/quests/quests_engine.dart` to match (search `_embeddedFallbackJson`).
3. Rebuild.

## Minimal glue (no UI changes)

The wellness dashboard state initializes the engine and loads today’s data in `initState()`. No widgets were altered; data is ready for existing components when needed.

## Built‑in checks (selector tests)

The engine exposes a small debug helper `debugRunSelectorChecks()` (assert‑based) to verify:
- Deterministic output per date
- Variety constraints are satisfied
- ≤3‑minute item is present

To run in debug builds, call it from any debug‑only code path.

## Install dependency (approved)

Run:

```
flutter pub add shared_preferences
```

This adds cross‑platform persistence for the telemetry and history tables.

## Future (not in Week 0)

- Week 1: Add tiny REST `/quests` and `/events` endpoints as a drop‑in replacement; keep the selector local.
- Week 2: Server‑assembled “today” lists with simple cohort/user heuristics.
