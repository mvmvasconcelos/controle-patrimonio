# AI Agent Instructions for Controle de Patrimônio Environment

> [!IMPORTANT]
> **READ THIS FIRST**: This environment runs on a Linux remote host using Docker containers. **You DO NOT have direct access to the host's Flutter or Python SDKs.** All commands MUST run inside the appropriate Docker containers.

## 1. Context & Architecture (Context-Driven Development)
We follow a **Context-Driven Development** philosophy.

### 🧠 Project Brain (Source of Truth)
Before starting any task, **read these files** to load the full context:
1.  **[Product Context](docs/context/product.md)**: Goals, Users, and Domain Language.
2.  **[Tech Stack](docs/context/tech_stack.md)**: Architecture, Libraries, and Constraints.
3.  **[Roadmap](../docs/ROADMAP.md)**: Current progress and next steps.

### Server Deployment Info (Quick Ref)
*   **Host**: `128.1.1.49` (Internal) / `ifva.duckdns.org` (External).
*   **Backend**: `http://127.0.0.1:6090/api/v1/`.
*   **Production Build**: Use `docker-compose run --rm flutter ...`.

## 2. Infrastructure & Commands Rules
You **MUST** use the following command patterns.

> [!WARNING]
> **Service Name Discrepancy**: The User's Global Rules might mention a `builder` container. However, in this project's `docker-compose.yml`, the service is named **`flutter`**. Always use `flutter` unless you verify `builder` exists.

### Flutter (Frontend)
To run ANY Flutter command (`flutter pub get`, `flutter test`, `dart analyze`):
```bash
docker-compose run --rm -w /app flutter sh -c "<YOUR COMMAND HERE>"
```
**Examples:**
*   `docker-compose run --rm -w /app flutter sh -c "flutter pub get"`
*   `docker-compose run --rm -w /app flutter sh -c "flutter test"`

### Backend (Python)
To run ANY Backend command:
```bash
docker-compose run --rm -w /backend backend sh -c "<YOUR COMMAND HERE>"
```

### General
*   **Never** try to run `flutter` or `python` directly in the shell.
*   **Pathing**: Always use absolute paths for file edits.
*   **Git**: You can run `git` commands directly on the host (e.g., `git status`, `git add`).

## 3. Workflow Protocol

### Phase 1: Planning (Context Establishment)
1.  **Explore**: Read `task.md` (create if missing) to understand the current work queue.
2.  **Analyze**: Read `docker-compose.yml` and key files before proposing a plan.
3.  **Plan**: Create/Update `implementation_plan.md` with:
    *   **Goal**: Clear objective.
    *   **Proposed Changes**: Specific files to touch.
    *   **Verification**: Exact `docker-compose` commands to verify the fix.

### Phase 2: Execution (Implementation)
1.  **Atomic Steps**: Edit one file at a time or logically grouped files.
2.  **Lint Check**: Run `dart analyze` (via Docker) frequently to catch syntactical errors early.
    *   Command: `docker-compose run --rm -w /app flutter sh -c "flutter analyze"`

### Phase 3: Verification
1.  **Test**: Run existing tests relevant to your changes.
2.  **Build**: Verify the app builds (if applicable to the task).
    *   Command: `docker-compose run --rm -w /app flutter sh -c "flutter build apk --debug"` (or similar).
3.  **Walkthrough**: Create `walkthrough.md` if the change was significant, documenting what was done.

## 4. Communication Style
*   **Be Proactive**: If you see a missing dependency or configuration, fix it (or plan to fix it), don't just complain.
*   **Be Precise**: When asking the user to review, point to specific lines or files.
*   **Portuguese/English**: The user communicates in Portuguese. Respond in the language most appropriate or requested, but code/docs are usually in English.
