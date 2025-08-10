# Testing Overview

- Strategy: unit + in-app debug harness + manual E2E where needed.
- Comprehensive plans: see `COMPREHENSIVE_TESTING_PLAN.md` and `LOCAL_TESTING_CHECKLIST.md`.
- Test results: see `TEST_RESULTS_SUMMARY.md` and `GEOGRAPHY_CRISIS_DETECTION_TEST_REPORT.md` (appendices).

## In-app Quests Debug Harness
- Trigger lives inside `ai_buddy_web/lib/dhiwise/presentation/wellness_dashboard_screen/wellness_dashboard_screen.dart` (debug-only path).
- Verifies: deterministic selection, variety constraints, ≤3-minute item presence, progress/reminder persistence, midnight refresh.

## Crisis Detection
- Backend tests and analysis: `CRISIS_DETECTION_ANALYSIS.md`, `COMPREHENSIVE_CRISIS_TESTING.md`, `CRISIS_DETECTION_TEST_CASES.md`.
