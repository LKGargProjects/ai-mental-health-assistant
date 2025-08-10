# CONTEXT.md (LLM One-Pager)

## 0. Snapshot
- Repo: ai-mvp-backend
- Git rev: db2739f
- Last updated: 2025-08-10T15:09:04.798048

## 0.1 Sources freshness
- docs/ARCHITECTURE.md (modified: 2025-08-10T15:02:44.061137)
- docs/ADRS.md (modified: 2025-08-10T15:03:04.957457)
- docs/TESTING.md (modified: 2025-08-10T15:03:15.764642)
- docs/frontend/QUESTS_ENGINE.md (modified: 2025-08-10T15:03:36.184771)
- docs/schemas/quests.schema.json (modified: 2025-08-10T15:00:29.368977)

## 1. Architecture (TL;DR)
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

## 2. ADRs (Decisions)
# Architecture Decision Records (Index)

- ADR-001: Single codebase with environment detection — see `SINGLE_CODEBASE_GUIDE.md`
- ADR-002: Single-container deployment — see `SINGLE_CONTAINER_PLAN.md` / `DEPLOYMENT.md`
- ADR-003: Crisis detection parsing fix + env diffs — see `CRISIS_DETECTION_ANALYSIS.md`
- ADR-004: In-app quests verification is debug-only (prod-safe) — anchored in `ai_buddy_web/lib/dhiwise/presentation/wellness_dashboard_screen/wellness_dashboard_screen.dart`

Notes:
- This index links to canonical sources to avoid duplication.
- When making consequential changes, add a bullet here with a short title and the source file link.

## 3. Current Status
version: 0.1
frontend:
  app: ai_buddy_web
backend:
  app: flask
last_updated: 2025-08-10T15:09:04.796982

## 4. Quests Engine
# Quests Engine

Authoritative contract and update flow for the quests system.

- Engine: `ai_buddy_web/lib/quests/quests_engine.dart`
- Catalog (source of truth): `ai_buddy_web/assets/quests/quests.json`
- Schema: `docs/schemas/quests.schema.json`

For Week 0 details and behavior, see `WEEK0.md`.

## 5. Key Interfaces (excerpts)
### quests_engine.dart
QuestTag _tagFromString(String s) {
String _tagToString(QuestTag t) {
class Quest {
class TodayProgressSummary {
class QuestsEngine {
  Random _rngForDate(DateTime date) {
  List<Quest> selectToday(DateTime date, Map<String, dynamic> userState) {
    Quest? pickOne(List<Quest> pool, bool Function(Quest) filter) {
    void addIfNotNull(Quest? q) {
    Quest? pickTask() {
  TodayProgressSummary computeProgress(List<Quest> today) {
  void _ensureQuestStats(String questId) {
  void debugRunSelectorChecks() {

### app.py routes (partial)
452:     @app.route("/", methods=["GET"])
462:     @app.route("/<path:filename>")
471:     @app.route("/api/health", methods=["GET"])
515:     @app.route("/api/chat", methods=["POST"])
1019:     @app.route("/api/get_or_create_session", methods=['GET'])
1025:     @app.route('/api/chat_history', methods=['GET'])
1059:     @app.route('/api/mood_history', methods=['GET'])
1094:     @app.route('/api/mood_entry', methods=['POST'])
1150:     @app.route('/api/crisis_detection', methods=['POST'])
1187:     @app.route('/api/mood_analytics', methods=['GET'])
1266:     @app.route('/api/wellness_recommendations', methods=['GET'])
1309:     @app.route('/api/metrics', methods=['GET'])
1367:     @app.route('/api/self_assessment', methods=['POST'])

## 6. Quests sample (redacted)
[
  {
    "quest_id": "task_focus_reset_v1",
    "tag": "TASK",
    "title": "Focus reset",
    "subtitle": "Quick breathing + desk tidy",
    "duration_min": 2,
    "url": null,
    "checklist": [
      "Open window",
      "4\u00d7 box breaths",
      "Clear top 3 items"
    ],
    "timer_suggested": true,
    "active": true
  },
  {
    "quest_id": "task_study_sprint_v1",
    "tag": "TASK",
    "title": "Study sprint",
    "subtitle": "Timer + no\u2011phone rule",
    "duration_min": 10,
    "url": null,
    "checklist": [
      "Set 10\u2011min timer",
      "Phone away",
      "Single task only"
    ],
    "timer_suggested": true,
    "active": true
  },
  {
    "quest_id": "checkin_quick_v1",
    "tag": "CHECK-IN",
    "title": "Quick check\u2011in",
    "subtitle": "Mood, Energy, Stress chips",
    "duration_min": 2,
    "url": null,
    "checklist": [],
    "timer_suggested": false,
    "active": true
  }
]
## 7. Recent LLM Insights (tail)
timestamp: 2025-08-10T15:07:53.141029
source: windsurf
content:

Summarize Quests MVP constraints and propose CI validation for quests.json against docs/schemas/quests.schema.json. Also add make context target for easier triggers.

timestamp: 2025-08-10T15:08:17.771231
source: windsurf
content:

Summarize Quests MVP constraints and propose CI validation for quests.json against docs/schemas/quests.schema.json. Also add make context target for easier triggers.

