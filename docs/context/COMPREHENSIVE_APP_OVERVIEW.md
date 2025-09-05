# Comprehensive App Overview (Past → Present → Future)

Purpose: A 360° view of the AI Mental Health Assistant app to support brand and domain ideation. No naming recommendations included.

---

## Past: Genesis, Constraints, Early Decisions

- **Mission & Audience**
  - Support the emotional well-being of high school students with an AI assistant focused on empathy, coping strategies, and safety-first escalation.

- **MVP Constraints**
  - Cost efficiency and privacy-first operations.
  - Single developer device (Mac) + iPhone for testing.
  - iOS: Individual Apple Developer account, manual IPA upload via Transporter to TestFlight.
  - Android: Use brand identity for developer name and support email to preserve personal privacy.

- **Architecture Choices**
  - Single codebase for backend + frontend with Docker and Compose for local parity.
  - Flutter for cross-platform (web + mobile).
  - Flask API with Postgres + Redis, deployed on Render and containerized for portability.
  - Multi-provider AI (Gemini, OpenAI, Perplexity) with fallback and key rotation.
  - Lightweight crisis detection via rule-based keyword analysis.

- **Foundational Artifacts**
  - Deployment, single-container, and single-codebase docs: `SINGLE_CONTAINER_PLAN.md`, `SINGLE_CODEBASE_GUIDE.md`, `DEPLOYMENT.md`, `PRODUCTION_DEPLOYMENT_GUIDE.md`.
  - MVP scripts and infra: `Dockerfile`, `docker-compose.yml`, `render.yaml`, `start.sh`, `start_local.sh`, `startup.sh`.
  - App orchestration and release workflows: `.github/workflows/ci.yml`, `.github/workflows/mobile_release.yml`, `scripts/`.

---

## Present: System Overview

### Product & User Experience

- **Core Experiences**
  - Chat-based support with empathetic, age-appropriate tone targeting high school students.
  - Crisis sensitivity and escalation messaging guided by country resources.
  - Journaling/mood/self-assessment data capture for reflection and analytics.

- **Frontend (Flutter)**
  - Codebase: `ai_buddy_web/lib/`
  - Structure: `config/`, `core/`, `models/`, `providers/`, `quests/`, `routes/`, `screens/`, `services/`, `theme/`, `widgets/`, entrypoint `main.dart`.
  - Platforms: Web, iOS, Android.
  - Static assets and web support: `static/`, `static/canvaskit/`, `ai_buddy_web/web/`.

- **Backend (Flask)**
  - Entrypoint: `app.py`
  - Capabilities:
    - Env detection, configuration, and health checks.
    - Session management (Redis-backed fallback), request ID tracing, CORS.
    - Rate limiting for abuse prevention.
    - Sentry integration for error tracking.
    - AI provider failover and tracing.
    - Crisis detection integrated with messaging tone and resource hints.
  - Data models: `models.py`
    - `UserSession`, `Message`, `ConversationLog`, `CrisisEvent`, `SelfAssessmentEntry` (JSONB).
  - Crisis detection: `crisis_detection.py` (keyword/risk levels).
  - AI providers: `providers/`
    - `gemini.py`: multi-key rotation, round-robin, model fallback, session-scoped memory cleanup, risk-aware prompts, robust logging.
    - `openai.py`: GPT-based empathetic responses tuned for high school audience with a supportive system prompt.
    - `perplexity.py`: supportive prompt strategy, key fallback, network/API error handling.

### Data, Security, Observability, and Ops

- **Data Models (`models.py`)**
  - `UserSession`: session linkage, metadata.
  - `Message`: user/assistant turns, timestamps.
  - `ConversationLog`: normalized history + computed `risk_level`.
  - `CrisisEvent`: triggers, escalation artifacts, resource messaging.
  - `SelfAssessmentEntry`: JSONB payload, flexible structure for mood or journaling.

- **Crisis Detection (`crisis_detection.py`)**
  - Keyword/rule-based classifier → `low | medium | high | crisis`.
  - Integrated into prompt tone and escalation messaging in `app.py`.

- **Security & Safety**
  - Rate limiting in `app.py`.
  - Session storage with Redis fallback; CS/trace via request IDs.
  - CORS configured; reverse proxy hardening via `nginx.conf`.
  - Sentry for error telemetry; secrets via env (`render.yaml`, `env.example`).
  - Admin/maintenance pathways guarded via admin token (in `app.py`).

- **Deployment & Infra**
  - Render service config: `render.yaml` (env vars, secrets, retention, health checks).
  - Dockerized backend + services: `Dockerfile`, `docker-compose.yml` (API, Postgres, Redis, Flutter web).
  - Nginx reverse proxy: `nginx/nginx.conf` and root `nginx.conf` (SSE, security headers, rate limit, upstreams).
  - Static assets: `static/` (web canvaskit, icons, fonts, assets).

- **Observability & Monitoring**
  - App tracing/errors: Sentry (DSN in env).
  - Infra metrics: Prometheus config `monitoring/prometheus.yml` for backend, DB, Redis, Nginx.

- **CI/CD & Release**
  - Web CI: `.github/workflows/ci.yml` (Flutter setup, analyze, asset checks, build web).
  - Mobile release orchestration:
    - `.github/workflows/mobile_release.yml` (Android + iOS matrix, artifacts, optional upload, Slack notify).
    - `.github/workflows/android_release.yml` (Android-specific release flow).
    - `.github/workflows/release_one_button.yml` (one-button pipeline).
  - Scripts: `scripts/` (Android/iOS signing env examples, keystore encoding, release helpers).

- **Mobile Publishing (MVP constraints)**
  - iOS: Individual Apple Developer account, manual IPA to TestFlight via Transporter.
  - Android: Brand-facing developer identity and support email to protect personal identity.

### User Journey, Content, and Safety

- **User Journey**
  - Landing → Chat assistant → Periodic self-assessment/mood logs → Crisis-aware support when needed.
  - Frontend routes and screens in `ai_buddy_web/lib/` (e.g., `routes/`, `screens/`, `widgets/`).

- **Tone & Guidance**
  - Empathetic, age-appropriate system prompts in all providers.
  - Avoids clinical diagnosis; focuses on healthy coping strategies and resource direction.

- **Geo/Safety Context**
  - Country-specific crisis resources and messaging integrated in `app.py`.
  - Geography crisis docs: `GEOGRAPHY_CRISIS_DETECTION_IMPLEMENTATION_SUMMARY.md`, `GEOGRAPHY_CRISIS_DETECTION_TEST_REPORT.md`.

### Testing and Quality

- **Automated Tests**
  - Backend tests include:
    - `test_backend_mvp.py` (core flows, health).
    - `test_single_codebase.py` (integrity of combined repo).
    - `test_geography_crisis_detection.py` (geo/risk logic).
    - Shell suites: `test_complete_system.sh`, `comprehensive_feature_test.sh`.
  - Crisis-specific analysis artifacts: `CRISIS_DETECTION_ANALYSIS.md`, `CRISIS_DETECTION_TEST_CASES.md`, `CRISIS_WIDGET_DEBUG.md`.

### Compliance, Privacy, Data Governance

- **Principles**
  - Minimize PII; store only necessary session and conversation data.
  - Use `JSONB` for self-assessments to avoid rigid schema and limit over-collection.
  - Session IDs and request IDs for traceability without personal identity.

- **Regulatory Direction**
  - Prepare for COPPA-adjacent youth concerns, FERPA-adjacent school contexts, HIPAA-non-applicable unless clinical claims introduced.
  - Clear disclaimers: not medical advice, crisis-first routing.

- **Data Lifecycle**
  - Retention and purge strategy configurable via env and documented in `render.yaml` and deployment guides.

### Performance, Cost, and Reliability

- **Performance**
  - Nginx offloading, HTTP/2 and keep-alive, SSE support.
  - Redis-backed sessions for low-latency checks.
  - AI provider fallback keeps perceived latency bounded during provider outages.

- **Cost Control**
  - Multi-provider keys and fallback to spread quota/load.
  - Render free/low-tier services for MVP.
  - Build artifacts cached in CI; selective workflows.

- **Reliability**
  - Health checks in `render.yaml` and `docker-compose.yml`.
  - Basic autoscaling via Render (service-dependent); rate limits guard against abuse.

---

## Future: Technical Roadmap

- **AI & Safety**
  - Add safety classifiers beyond keywords:
    - Zero-shot safety LLM filter or lightweight on-device classifier for triage.
    - Fine-tuned risk detection on anonymized logs.
  - RAG for psychoeducation snippets (curated, clinician-reviewed content).
  - Provider orchestration:
    - Dynamic routing by cost-latency-quality profiles.
    - Cached responses for common psychoeducational FAQs.

- **Data & Personalization**
  - Consent-driven personalization and longitudinal trends.
  - On-device encryption for sensitive mobile data (keychain/keystore).
  - Export/erase tools (user data rights, admin console).

- **Architecture**
  - Feature-flag system for experiments.
  - Background jobs (RQ/Celery) for analysis, summaries, trend reports.
  - WebSockets as optional upgrade to SSE for richer presence/typing indicators.

- **Security & Compliance**
  - Security headers hardening in `nginx.conf` (CSP, COOP/COEP).
  - Automated DPA logs, audit trails for admin actions.
  - Privacy reviews and DPIA; kid-safety UX checks.

- **DevEx & QA**
  - E2E tests with Flutter integration tests and Playwright for web.
  - Synthetic monitoring + golden-signature latency SLOs via Prometheus.
  - One-button release improvements with guarded toggles.

- **Mobile**
  - Gradual expansion to public stores when org account is ready.
  - In-app announcements, version gating, and forced-upgrade paths for critical patches.

---

## Future: Product Roadmap

- **Core Experiences**
  - Daily check-ins and streak mechanics with supportive nudges.
  - Reflective prompts and “guided journaling” quests (`ai_buddy_web/lib/quests/`).
  - Crisis “Are you safe?” flows with adaptive grounding exercises.

- **School & Guardian Mode**
  - Opt-in guardian summary emails (Privacy-first, aggregated, consent-based).
  - School partnerships for anonymous, aggregate well-being trends.

- **Community & Content**
  - Curated, evidence-based modules authored with clinician guidance.
  - Localization and multilingual support where feasible.

- **Monetization (Exploratory)**
  - Freemium + premium coping modules.
  - School/organization licenses.
  - Sponsorships for psychoeducation, with strict safety/ethics guardrails.

---

## Future: Analytics and Success Metrics

- **User Outcomes**
  - Self-reported relief post-conversation.
  - Reduction in repeated crisis escalations over time.
  - Engagement with coping strategies.

- **Quality and Safety**
  - Safe completion rate in high-risk sessions.
  - Time-to-escalation detection and resource display.
  - False negative and false positive risk detection rates.

- **Product Health**
  - DAU/WAU, retention cohorts, session length.
  - LLM cost per active user, p95 latency, provider failover frequency.

---

## Future: Risks and Mitigations

- **Model Hallucinations**
  - Safety filters, retrieval-grounded psychoeducation, coach-style language.

- **Crisis Under/Over-Detection**
  - Hybrid classifier (rules + ML), continuous calibration with expert input.

- **Data Sensitivity**
  - Pseudonymization, strict access roles, encrypted at rest and in transit.

- **Provider Dependencies**
  - Multi-provider routing, cached fallback snippets, user feedback loops.

---

## Brand Vectors (No Naming Recommendations)

- **Attributes**
  - Safe, empathetic, youth-centered, non-judgmental.
  - Practical coping, small steps, daily progress.
  - Trustworthy, privacy-protective, transparent.
  - Calm, hopeful, grounded; not clinical or diagnostic.

- **Tone**
  - Warm, simple language; avoids jargon.
  - Encouraging autonomy; promotes healthy routines.

- **Visual Themes**
  - Soft gradients, approachable typography, high contrast for accessibility.
  - Gentle motion, minimal distractions.

---

## Key Files and Paths (for Reference)

- Backend: `app.py`, `models.py`, `crisis_detection.py`, `providers/`
- Frontend: `ai_buddy_web/lib/` (entry: `main.dart`)
- Static/Web: `static/`, `ai_buddy_web/web/`
- Infra/Deploy: `Dockerfile`, `docker-compose.yml`, `render.yaml`, `nginx/nginx.conf`
- CI/CD: `.github/workflows/ci.yml`, `.github/workflows/mobile_release.yml`, `.github/workflows/android_release.yml`, `.github/workflows/release_one_button.yml`
- Monitoring: `monitoring/prometheus.yml`
- Docs: `DEPLOYMENT.md`, `PRODUCTION_DEPLOYMENT_GUIDE.md`, `SINGLE_CONTAINER_PLAN.md`, `SINGLE_CODEBASE_GUIDE.md`, crisis and geography analysis/test docs.
