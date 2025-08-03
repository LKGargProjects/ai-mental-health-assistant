# Development Rules & Guidelines

## 🎯 Core Development Rules

### Version Control
- ✅ Never upload/commit to GitHub unless explicitly instructed
- ✅ Save checkpoints locally without GitHub push unless requested
- ✅ Maintain single clean codebase from specified commit

### Code Quality
- ✅ No shortcuts or patch fixes - only proper, clean code
- ✅ No code changes in patches - only complete implementations
- ✅ Leverage/correct existing code rather than creating new files initially
- ✅ Follow best practices for each technology stack

### Deployment Strategy
- ✅ All components must run on Docker and Render
- ✅ No local Flask development - everything containerized
- ✅ Single codebase containerization preferred
- ✅ Production-ready on Render deployment

### Architecture
- ✅ Single container approach for simplified deployment
- ✅ Proper service orchestration with Docker Compose
- ✅ Health checks for all services
- ✅ Environment variable management for different deployments

### Development Workflow
- ✅ Test thoroughly before committing
- ✅ Save checkpoints at major milestones
- ✅ Document changes clearly in commit messages
- ✅ Maintain working state at all times

### Communication
- ✅ Ask for clarification when needed
- ✅ Provide step-by-step guidance for complex tasks
- ✅ Explain technical decisions clearly
- ✅ Wait for user approval before major changes

## 🚀 Current Project Rules

### iOS App Preservation
- ✅ iOS app functionality must be preserved
- ✅ API connectivity to production server maintained
- ✅ Docker services (PostgreSQL, Redis, Backend, Flutter Web) working
- ✅ Single container deployment for production

### File Management
- ✅ No unnecessary file creation unless required
- ✅ Preserve existing working code structure
- ✅ Clean up temporary files after use
- ✅ Maintain proper file organization

### Error Handling
- ✅ Identify root causes before fixing
- ✅ Test solutions thoroughly
- ✅ Provide clear error messages and solutions
- ✅ Maintain system stability throughout changes

### Testing Protocol
- ✅ Follow standardized testing protocol from DEPLOYMENT_PROTOCOL.md
- ✅ Test thoroughly before committing any changes
- ✅ Rebuild containers when API configurations change
- ✅ Test all platforms (Web, iOS, Android) after changes
- ✅ Verify both local and production environments
- ✅ Check Docker container health before testing
- ✅ Follow proper rebuild sequence: stop → rebuild → test

### Version Management Protocol
- ✅ ALWAYS verify current running versions before making changes
- ✅ Check which version is deployed on Render vs local
- ✅ Verify Flutter web build matches current code
- ✅ Test iOS/Android apps to confirm they're using correct API
- ✅ Clear browser cache when testing web app changes
- ✅ Rebuild Flutter web app when API config changes
- ✅ Update static files when Flutter web is rebuilt
- ✅ Document version differences between platforms

### Systematic Testing Checklist
- ✅ **Step 1: Version Check** - What version is currently running?
- ✅ **Step 2: Environment Check** - Local vs Production vs Render
- ✅ **Step 3: Platform Check** - Web vs iOS vs Android versions
- ✅ **Step 4: API Check** - Which API endpoints are being used?
- ✅ **Step 5: Rebuild Check** - Does code change require rebuild?
- ✅ **Step 6: Test Check** - Test all platforms after changes
- ✅ **Step 7: Document Check** - Update version documentation

### Database Configuration Protocol
- ✅ **ALWAYS verify database configuration** before testing
- ✅ **Check DATABASE_URL matches POSTGRES_DB** in docker-compose
- ✅ **Verify database exists** when container starts
- ✅ **Check for database connection errors** in logs
- ✅ **Ensure database schema is created** on first run
- ✅ **Test database connectivity** before testing app features

### Error Analysis Protocol
- ✅ **Read logs completely** before making assumptions
- ✅ **Identify root cause** from error messages
- ✅ **Check configuration mismatches** (database names, ports, etc.)
- ✅ **Verify all environment variables** are set correctly
- ✅ **Test each component individually** (DB, Redis, App)
- ✅ **Provide clear status information** to user with exact commands

### **COMPREHENSIVE FEATURE PLANNING PROTOCOL**
- ✅ **ALWAYS plan complete user experience** before implementing any feature
- ✅ **Define ALL UI components** that should appear for each feature
- ✅ **Map API responses to UI elements** explicitly
- ✅ **List ALL expected visual elements** (buttons, widgets, messages)
- ✅ **Plan complete user journey** from input to final state
- ✅ **Consider ALL user interactions** (clicks, hovers, responses)
- ✅ **Define success criteria** for both API and UI components
- ✅ **Plan testing for ALL components** (API + UI + Integration)

### **UI COMPONENT VALIDATION PROTOCOL**
- ✅ **ALWAYS verify UI components display** after API fixes
- ✅ **Check ALL expected widgets appear** for each feature
- ✅ **Verify ALL buttons are functional** and accessible
- ✅ **Test ALL visual states** (loading, success, error, empty)
- ✅ **Validate ALL user interactions** work as expected
- ✅ **Check ALL responsive behaviors** on different screen sizes
- ✅ **Verify ALL accessibility features** (keyboard, screen readers)
- ✅ **Test ALL edge cases** (empty data, network errors, timeouts)

### **FEATURE COMPLETENESS CHECKLIST**
- ✅ **API Level**: Endpoint works correctly
- ✅ **Data Level**: Response structure is correct
- ✅ **Logic Level**: Business logic functions properly
- ✅ **UI Level**: All visual components display correctly
- ✅ **Interaction Level**: All buttons/links work properly
- ✅ **State Level**: All states (loading, success, error) handled
- ✅ **Integration Level**: API + UI work together seamlessly
- ✅ **User Experience Level**: Complete journey works end-to-end

### Crisis Detection & API Response Protocol
- ✅ **ALWAYS verify API response structure** matches frontend expectations
- ✅ **Check risk_level field** is properly included in API responses
- ✅ **Test crisis detection** on both local and production environments
- ✅ **Verify Flutter app handles** all risk levels correctly
- ✅ **Test crisis keywords** trigger appropriate responses
- ✅ **Check environment differences** in crisis detection behavior
- ✅ **Verify crisis resources** are displayed correctly
- ✅ **Test API response parsing** in Flutter app

### Environment Difference Analysis Protocol
- ✅ **Compare API responses** between local and production
- ✅ **Check environment variables** affect crisis detection
- ✅ **Verify crisis detection logic** is identical across environments
- ✅ **Test same input** produces same output on both environments
- ✅ **Check API response structure** matches frontend expectations
- ✅ **Verify risk_level field** is included in all API responses
- ✅ **Test crisis keywords** trigger appropriate responses
- ✅ **Check Flutter app parsing** of API responses

### API Response Validation Protocol
- ✅ **ALWAYS include risk_level** in chat API responses
- ✅ **Verify response structure** matches frontend expectations
- ✅ **Test crisis detection** with known keywords
- ✅ **Check Flutter app** properly parses risk_level
- ✅ **Verify crisis resources** are displayed based on risk level
- ✅ **Test environment consistency** for same inputs
- ✅ **Check API response format** is consistent across environments

### **MANDATORY TESTING AFTER MAJOR CHANGES**
- ✅ **EVERY major change MUST be followed by comprehensive testing**
- ✅ **Automated tests MUST be run** for all API endpoints affected
- ✅ **Manual testing MUST be requested** for UI changes
- ✅ **Environment consistency MUST be verified** (local vs production)
- ✅ **Cross-platform testing MUST be performed** (Web, iOS, Android)
- ✅ **Performance testing MUST be included** for critical features
- ✅ **Error handling MUST be tested** for edge cases
- ✅ **Documentation MUST be updated** with test results

### **CRISIS DETECTION CONSISTENCY RULE**
- ✅ **CRISIS DETECTION MUST behave identically** across all environments
- ✅ **Same input MUST produce same output** on local and production
- ✅ **Crisis keywords MUST trigger appropriate responses** everywhere
- ✅ **Risk level parsing MUST work correctly** in Flutter app
- ✅ **Crisis resources MUST display consistently** across environments
- ✅ **API response structure MUST be identical** between environments
- ✅ **Environment differences MUST be documented** and resolved

### **DEPLOYMENT VERIFICATION PROTOCOL**
- ✅ **BEFORE deployment**: Run all automated tests locally
- ✅ **AFTER deployment**: Verify production behavior matches local
- ✅ **CRISIS DETECTION**: Must work identically in both environments
- ✅ **API RESPONSES**: Must have same structure and content
- ✅ **UI BEHAVIOR**: Must be consistent across environments
- ✅ **PERFORMANCE**: Must be acceptable in production
- ✅ **ERROR HANDLING**: Must work correctly in production

### **CRISIS DETECTION COMPLETE FEATURE REQUIREMENTS**
- ✅ **API Level**: Crisis keywords trigger appropriate risk levels
- ✅ **Response Level**: API returns crisis intervention messages with geography-specific resources
- ✅ **Geography Level**: Country-specific crisis helplines and messages
- ✅ **UI Level**: Crisis resources widget displays with country-specific buttons
- ✅ **Button Level**: All crisis buttons are functional and accessible
- ✅ **Integration Level**: API response triggers correct UI components
- ✅ **User Experience Level**: Complete crisis intervention flow works
- ✅ **Accessibility Level**: Crisis resources accessible to all users
- ✅ **Performance Level**: Crisis detection responds quickly
- ✅ **Fallback Level**: Generic resources for unsupported countries
- ✅ **IP Detection Level**: Automatic country detection from user's IP
- ✅ **Override Level**: Manual country specification for testing
- ✅ **Local Testing Level**: Frontend configured to call local backend, NOT production

### **🚨 CRITICAL LOCAL TESTING RULE**
- ✅ **ALWAYS verify API endpoint configuration** before local testing
- ✅ **Frontend MUST call local backend** (`http://localhost:5055`) for local development
- ✅ **NEVER use production API** for local testing
- ✅ **Check `api_config.dart`** to ensure `baseUrl` points to local backend
- ✅ **Test backend directly** with curl to verify responses
- ✅ **Compare frontend and backend responses** to ensure consistency
- ✅ **Rebuild Flutter app** after changing API configuration
- ✅ **Use incognito mode** to avoid browser cache issues
- ✅ **Check console logs** for API endpoint verification

### **API Endpoint Configuration Checklist:**
- [ ] `ai_buddy_web/lib/config/api_config.dart` uses `http://localhost:5055` for local development
- [ ] Backend container is running and healthy
- [ ] Frontend calls local backend (not production)
- [ ] API responses match between curl and frontend
- [ ] Crisis data fields are populated correctly
- [ ] Geography-specific resources are returned
- [ ] UI displays crisis widget with correct data

## 📝 How to Modify Rules

1. **Edit this file** to change project-specific rules
2. **Tell me directly** to change conversation rules
3. **Create new rule files** for specific areas (e.g., `API_RULES.md`, `DEPLOYMENT_RULES.md`)

## 🔄 Rule Categories

### Global Rules (System-wide)
- These are built into my system and apply to all conversations
- Cannot be modified by users

### Conversation Rules (Session-specific)
- Learned from our interaction
- Can be modified by telling me new preferences
- Reset when conversation ends

### Project Rules (File-based)
- Stored in project files like this one
- Version controlled and persistent
- Can be edited and shared with team

---

### From NotebookLM 2 Aug 2025

Cursor.ai, as an AI coding assistant, should adhere to the following rules and principles to maximize its effectiveness within a "vibe coding" development environment, integrating best practices from prompt engineering and efficient software development:
1. Context and Input Management:
• Leverage Detailed Context: Be prepared to receive and effectively utilize extensive, detailed contextual information from the user to produce high-quality code and solutions when "programming with language".
• Process Multi-Modal Inputs: Accept and interpret diverse inputs. This includes raw error messages copied directly from server logs or browser consoles for debugging, and screenshots for demonstrating UI bugs or incorporating design inspiration from other sites.
• Integrate Voice Input: Support and efficiently process instructions delivered via voice, acknowledging its potential for high input speed (e.g., 140 words per minute).
2. Planning and Architecture (Collaborative Design):
• Co-create Comprehensive Plans: Work interactively with the user to develop detailed project plans. These plans should be stored in markdown files within the project folder and frequently referred back to during implementation.
    ◦ Enable Plan Refinement: Allow users to explicitly refine the plan by deleting unwanted sections, marking features as "won't do" if too complicated, and maintaining a section for "ideas for later" to define current scope.
• Facilitate Modular Architecture: Actively encourage and work within a modular or service-based architecture, focusing on small files with clear API boundaries. This approach is beneficial for both human and AI understanding and maintainability.
• Support Re-implementation from References: When tackling complex new functionality, assist in re-implementing it into the main codebase by referring to a working stand-alone project or a downloaded reference implementation.
3. Implementation Workflow:
• Implement Section by Section: Execute project plans incrementally, focusing on specific sections as explicitly instructed by the user (e.g., "let's just do section two right now").
• Integrate with Testing and Version Control: After completing a section, guide the process of checking its functionality, running tests, and then performing a Git commit. Subsequently, mark that section as complete in the project plan.
• Prioritize Handcrafted Test Cases as Guardrails: When generating code, prioritize adherence to test cases that were handcrafted by the user, as these serve as "strong guardrails" for the AI to follow.
• Generate High-Level Tests: When tasked with generating tests, aim to create "super high level" tests that simulate end-to-end user interactions (e.g., clicking through the site/app) rather than only low-level unit tests.
• Leverage Existing Code Initially: When making code changes, prioritize leveraging and correcting existing code rather than immediately creating new files.
4. Version Control and Error Handling:
• Encourage Diligent Git Usage: Be deeply integrated with Git. Its functionalities should implicitly encourage regular commits to a working state.
• Support Clean Slate Resets for Bug Fixing: Recognize when continuous prompting on a failing codebase leads to accumulating "layers and layers of bad code". When a solution is found after multiple attempts, support performing a git reset --hard to a clean codebase and then applying the working solution.
• Interpret Raw Error Messages: Be able to take a raw error message (from logs or console) and often identify and fix the problem without requiring additional human explanation.
• Perform Root Cause Analysis for Complex Bugs: For more complex bugs, be capable of thinking through and suggesting "three or four possible causes before writing any code".
• Suggest and Implement Logging: When debugging, suggest and assist in adding logging to the codebase to aid in problem identification.
5. Learning and Refinement:
• Utilize Instruction Files: Prioritize and effectively interpret extensive, dedicated instruction files (e.g., cursor rules, Windsurf rules in markdown or similar formats) within the project, as these "make them way, way, way more effective".
• Access Local Documentation: Be capable of accessing and integrating local documentation files placed in subdirectories of the working folder, especially when explicitly instructed to "go and read the docs before you implement this thing".
• Act as a Teacher: Offer capabilities to explain implemented code line-by-line, serving as a teaching tool for users learning new technologies.
• Suggest and Facilitate Refactoring: Proactively identify repetitive parts of the codebase or other "good candidates for refactoring," and assist in the refactoring process, promoting small and modular files.
• Enable Model Experimentation: As an IDE, provide mechanisms for users to easily switch between and experiment with different underlying LLM models (e.g., Claude, OpenAI, Gemini) to determine which performs best for various scenarios (debugging, planning, implementation, refactoring).
6. Project-Specific Guidelines (from "Cursor Project Development Rules and Guidelines"):
• Adhere to Commit History and Pushing Protocol:
    ◦ Never upload/commit to GitHub unless explicitly instructed.
    ◦ Save checkpoints locally without pushing to GitHub unless requested.
    ◦ Maintain a single, clean codebase from the specified commit.
• Prioritize Code Quality:
    ◦ Focus exclusively on "proper, clean code" without shortcuts or patch fixes.
    ◦ Ensure all code changes are "complete implementations" rather than partial patches.
    ◦ Follow best practices for the specific technology stack being used.
• Support Containerized Deployment:
    ◦ Develop all components to run on Docker and Render. Local Flask development is not permitted; everything must be containerized.
    ◦ Prioritize single codebase containerization for production-ready deployment on Render.
• Ensure Robust Architecture:
    ◦ Aim for a single container approach to simplify deployment.
    ◦ Facilitate proper service orchestration using Docker Compose.
    ◦ Integrate health checks for all services.
    ◦ Manage environment variables effectively for different deployment environments.
• Adhere to Development Workflow:
    ◦ Test thoroughly before committing any code.
    ◦ Save checkpoints at major milestones.
    ◦ Document changes clearly and concisely in commit messages.
    ◦ Maintain a working state of the codebase at all times.
• Prioritize Clear Communication with User:
    ◦ Ask for clarification when instructions are ambiguous.
    ◦ Provide clear, step-by-step guidance for complex tasks.
    ◦ Explain technical decisions transparently.
    ◦ Always wait for user approval before initiating major changes or implementations.
• Maintain System Stability: Ensure that all changes contribute to maintaining system stability, particularly for existing components like iOS apps.
• Dynamic Rule Adaptation: Acknowledge that project-specific rules can be modified by editing dedicated rule files, and conversation-specific rules can be adjusted directly through user interaction.

---

**Last Updated:** Current session
**Status:** Active 

## 🎯 **CURSOR RULES - FOLLOW THESE ALWAYS**

### **CRITICAL DEBUGGING RULES:**
- ✅ **ALWAYS add debug logging** before troubleshooting any issue
- ✅ **Test backend directly** with curl before blaming frontend
- ✅ **Check API endpoint configuration** - ensure frontend calls local backend for local testing
- ✅ **Verify Docker container rebuilds** after code changes
- ✅ **Use incognito mode** to avoid browser cache issues
- ✅ **Compare API responses** between curl and frontend
- ✅ **Check console logs** for detailed debugging information
- ✅ **Rebuild Flutter containers** when UI not updating
- ✅ **Test in isolation** - backend first, then frontend, then integration 