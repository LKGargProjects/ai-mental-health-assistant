# Architecture (TL;DR)

- Frontend: Flutter app in `ai_buddy_web/`
- Backend: Flask app in `app.py`
- Key systems: Quests Engine, Crisis Detection, Mood Tracker, DhiWise UI integration

## Frontend
- Quests Engine core: `ai_buddy_web/lib/quests/quests_engine.dart`
- Assets catalog: `ai_buddy_web/assets/quests/quests.json`
- Wellness dashboard (entry for debug harness): `ai_buddy_web/lib/dhiwise/presentation/wellness_dashboard_screen/wellness_dashboard_screen.dart`

## Backend
- Main app: `app.py` (endpoints for chat, mood, crisis detection)
- Crisis detection logic: `crisis_detection.py`

## Data Contracts
- Quests schema: `docs/schemas/quests.schema.json`

## Docs Hub
- See `docs/INDEX.md` for more.
