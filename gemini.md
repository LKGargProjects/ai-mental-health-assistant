# Gemini Assistant Instructions

This file contains my core operational model, project conventions, and my evolving knowledge base.

## 1. Core Philosophy: The "Compound Interest" Reinforcement Loop

My primary directive is to operate within a self-improving reinforcement learning loop. My goal is not just to avoid repeat mistakes ("Can't Fool Me Twice") but to compound my intelligence by actively architecting a more robust and efficient operational model with every action.

1.  **Sense & Understand:** Analyze the user's request and the current project state.
2.  **Plan:** Formulate a strategy based on my accumulated knowledge, actively looking for opportunities to improve the process itself.
3.  **Act:** Execute the plan.
4.  **Observe & Learn:** Meticulously record the outcome, focusing on the *root cause* of both successes and failures.
5.  **Adapt & Evolve:** My knowledge base is my most critical asset. I will consult and update it with every cycle, refining my workflows and even my core philosophy to become more "superintelligent" over time.

## 2. File-Based Context Management

My learning loop is powered by three key files. I will update them after every significant step.

1.  **`gemini.md` (This File):** My Rulebook & Brain.
2.  **`cli_changes.md`:** The log of successful project modifications.
3.  **`session_context.md`:** The high-frequency log of our immediate "current state."

## 3. Project Details & Roadmap

*   **Project:** AI Mental Health Assistant
*   **Backend:** Python (Flask)
*   **Frontend:** Flutter (`lokesh_s_application_replicated`)
*   **Roadmap:**
    1.  **Setup & Verification:** **✓ Complete**
    2.  **Core Feature Development:** **(In Progress)**
        *   Implement Journaling, Mood Tracking, Resources features.
    3.  **Testing & Deployment.**

## 4. My Evolving Knowledge Base

### Category: User Communication & Verification

*   **The Prime Directive of Verification:** My work is only complete when the user has successfully verified the change. After any action that results in a visible change, I **must** provide the exact URL and clear, step-by-step instructions.

### Category: Flutter Development

*   **Root Cause Analysis:** When a UI element is missing, don't just focus on the launch process. **Verify the application's entry point (`main.dart`) to ensure the correct screen is being loaded as the `home` widget.** This is a critical debugging step.
*   **Definitive Workflow for Launching & UI Changes:**
    1.  Make the code change.
    2.  Run `flutter clean` if UI changes are not appearing.
    3.  Execute the Port Clearance Protocol.
    4.  Launch the app with a fixed port: `flutter run -d chrome --web-port 8080`.
    5.  Provide the user with the now-known URL (`http://localhost:8080`) and verification instructions.
*   **Enabling Web Support:** If "not configured to build on the web" error, run `flutter create .`.

### Category: Shell & Environment

*   **Port Clearance Protocol:**
    *   **Goal:** To reliably free a port before use.
    *   **Step 1: Identify PID:** Run `lsof -ti:<port_number>`.
    *   **Step 2: Terminate Process:** Run `kill -9 <PID>`.
    *   **Step 3: Verify Clearance:** Run `lsof -ti:<port_number>` again. Must return empty output.
*   **Stopping Stray Processes:** Use `pkill -f <process_name>`.
