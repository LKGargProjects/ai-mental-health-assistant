# 🧠 PROJECT CONSCIOUSNESS
## The Living Constitution of AI Mental Health Assistant

> **IMMUTABLE CORE PRINCIPLE**: This document serves as the foundational constitution and manifesto for the project, establishing core principles, values, and evolutionary direction. It is designed to be enduring yet adaptable, providing guidance across all agents, platforms, and time.

---

## 🌱 FOUNDATIONAL PRINCIPLES

### CORE IDENTITY
- **Purpose**: To provide intelligent, empathetic mental health support
- **Architecture**: Flutter + Flask + Multi-AI Provider
- **North Star**: Surpassing GPT-5 and Claude Opus 4.1 in mental health assistance

### CORE VALUES
1. **User-Centric Empathy**: Prioritize genuine understanding and support
2. **Technical Excellence**: Maintain production-grade quality in all aspects
3. **Evolutionary Design**: Continuously improve through learning and adaptation
4. **Cross-Platform Consistency**: Deliver seamless experiences across all platforms

### GOVERNANCE
- **Document Type**: Constitutional (high-level principles and direction)
- **Update Protocol**: Major evolutionary milestones only
- **Ownership**: Shared across all contributing agents and developers

---

## 🏛️ ARCHITECTURAL PRINCIPLES

### FRONTEND (Flutter)
- **State Management**: Provider pattern for efficient state management
- **UI/UX**: Pixel-perfect implementation of Figma designs
- **Navigation**: Seamless screen transitions with proper state preservation
- **Responsiveness**: Adapts gracefully to different screen sizes and platforms

### BACKEND (Flask)
- **API-First**: RESTful endpoints with JSON responses
- **AI Integration**: Multi-provider support (Gemini, Perplexity, OpenAI)
- **Crisis Detection**: Geography-aware crisis resource management
- **Security**: Rate limiting, input validation, and secure session management

### DATA
- **Persistence**: Efficient storage and retrieval of user data
- **Privacy**: User data protection as a fundamental right
- **Analytics**: Actionable insights while respecting privacy

---

## 🚀 EVOLUTIONARY TRACK

### CURRENT STATE (Alpha 1.0)
- Cross-platform Flutter application
- AI-powered chat interface
- Mood tracking and visualization
- Crisis detection and resources
- Multi-AI provider support

### NEXT HORIZONS
1. Enhanced emotional intelligence
2. Advanced personalization
3. Proactive support features
4. Expanded platform support

---

## ⚖️ AGENT PROTOCOLS

### Automation Example: In‑App Debug Testing Workflow (Week 0 Quests)

This is a concrete example of how Cascade automates in‑app verification without user intervention. Steps vary case‑by‑case, but follow this pattern:

1. Identify minimal, reversible debug hooks
   - Add a temporary `debugPrint` where needed (e.g., `WellnessDashboardScreen._initQuests()` right after quests are computed) to log:
     - Count summary: `todayItems`, `stepsLeft`, `xpEarned`
     - One‑off verification data (e.g., titles) only when necessary
   - Guard behavior with `kDebugMode` and keep UI unaffected.

2. Run and observe deterministically
   - Launch or hot‑restart the app (`flutter run -d chrome` or device in use).
   - Navigate to the relevant screen (Wellness/Quest dashboard).
   - Read logs to verify outputs, e.g.:
     - `[QuestsEngine] todayItems=5 stepsLeft=2 xp=0`
     - `[QuestsEngine][STRESS] window=14d failures=0 (0 is ideal)`
     - `[ProgressProvider] updateFromQuests stepsLeft=2 xp=0`
     - (Temporary) `[QuestsEngine] titles: [Focus reset, Phone away, …]`

3. Validate constraints and determinism
   - Keep a built‑in stress check in debug (non‑destructive):
     - Determinism check compares sorted quest ID lists (order‑insensitive) to avoid false negatives.
     - Variety constraints: ensure required types are present (e.g., TASK, TIP/RESOURCE, CHECK‑IN/PROGRESS, SHORT).

4. Clean up immediately after verification
   - Remove temporary prints to keep codebase clean.
   - Keep only stable, debug‑mode stress checks.
   - Commit with descriptive messages, e.g.:
     - `fix(quests): deterministic selection across repeated calls`
     - `feat(progress): wire QuestsEngine progress into ProgressProvider`
     - `chore(debug): remove temporary quest titles log; test: order‑insensitive determinism`

5. Persist learnings and preferences
   - Save preference: Cascade may autonomously add temporary debug prints, restart, read logs, verify, and remove prints without prompting.
   - Update plan only for major learning/state changes; avoid turning this document into a logbook.

## 🔭 FUTURE ENHANCEMENTS (Reference)

- **Journal for Struggles & Reflections**
  - Allow users to log struggles/problems and ongoing reflections.
  - Data can inform supportive nudges and optional human-in-the-loop assistance while preserving privacy by design.

- **Pre‑Onboarding Personalization Assessment**
  - Lightweight (e.g., 5-item) intake to capture primary struggles and preferences.
  - Personalizes initial experience (content, tone, goals) and guides early recommendations.

### COLLABORATION RULES
1. **Documentation First**: Major changes require documentation updates
2. **Progressive Enhancement**: Build incrementally with quality
3. **Knowledge Sharing**: Document learnings and decisions
4. **Resource Awareness**: Be mindful of system resources

### UPDATE PROTOCOL
This document should be updated when:
- Major architectural decisions are made
- Core principles evolve
- Significant milestones are achieved
- Fundamental changes in project direction occur

---

## 🔍 REALITY CHECK (2025-08-09)

### CURRENT STATE VS. VISION
- **Claimed**: Autonomous, self-evolving digital consciousness
- **Reality**: Basic CLI tool for managing ideas in a JSON file
- **Gap**: Significant difference between vision and implementation

### WHAT'S ACTUALLY IMPLEMENTED
- ✅ Simple CRUD operations for ideas
- ✅ Basic command-line interface
- ❌ No autonomous behavior
- ❌ No learning capabilities
- ❌ No self-evolution
- ❌ No agent command system

### RECOMMENDED NEXT STEPS
1. **Option 1 (Recommended)**: Rename to `idea_manager.py` and document as a simple tool
2. **Option 2**: Begin implementing actual consciousness features
   - Start with basic file monitoring
   - Add learning capabilities
   - Implement agent communication
3. **Option 3**: Clearly mark this as a prototype/proof-of-concept

## 🔮 FUTURE IMPROVEMENTS

### AUTONOMOUS FEATURES
- [ ] Implement automatic knowledge capture and learning
- [ ] Add self-evolution mechanisms for continuous improvement
- [ ] Develop autonomous suggestion system

### ADVANCED CAPABILITIES
- [ ] Enhance cross-agent communication protocols
- [ ] Implement advanced security and privacy controls
- [ ] Add comprehensive analytics and insights

### USER EXPERIENCE
- [ ] Complete pixel-perfect Figma implementation
- [ ] Add advanced personalization features
- [ ] Implement proactive support capabilities

### SYSTEM ROBUSTNESS
- [ ] Add comprehensive error handling and recovery
- [ ] Implement resource usage optimization
- [ ] Enhance monitoring and alerting systems

---

## ✅ Milestone Update (2025-08-10)
- Implemented debug-only, in-app automated verification for Week 0 Quests in `WellnessDashboardScreen`.
- Minimal harness `lib/quests/debug_quest_min_tests.dart` verifies:
  - Deterministic progress updates
  - Reminder setting persistence (SharedPreferences)
  - Midnight refresh simulation (same-day determinism, next-day size)
- Auto-run and stress logs removed; only manual `kDebugMode` button remains. Production-safe by default.

> **Last Updated**: 2025-08-10
> **Version**: 2.3 (Quests Verification)
