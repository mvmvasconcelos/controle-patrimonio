# Tech Stack Context

## Architecture Overview
The system follows a classic **Client-Server** model but with a heavy "Thick Client" approach due to the offline-first requirement.

### Frontend (Mobile App)
*   **Framework**: Flutter (Dart).
*   **State Management**: `Provider` (Simple, scoped access).
*   **Local Database**: `Hive` (NoSQL, key-value, extremely fast for read-heavy workloads).
*   **Architecture Pattern**:
    *   **Screens**: UI Components.
    *   **Providers**: Business Logic & State glue.
    *   **Services/Repositories**: Data fetching (API/Hive).
    *   **Models**: Data transfer objects (`.dart` classes with `fromJson`).

### Backend (API)
*   **Framework**: FastAPI (Python).
*   **Database**: SQLite (Stored locally on the server filesystem).
*   **Role**:
    *   Serve the master list of assets (`GET /patrimonio`).
    *   Receive updates (`POST /patrimonio/update`).
    *   Host the static files for the Web version of the app.

### Infrastructure
*   **Containerization**: Docker Compose.
*   **Services**:
    *   `flutter`: Wrapper for Flutter SDK commands.
    *   `backend`: Python environment for FastAPI.
*   **Host**: Remote Linux Server (`IFVA`).

## Coding Standards
*   **Linting**: strict Flutter lints (`flutter_lints`).
*   **Testing**: Unit tests for logic (`flutter test`), Integration tests for Hive.
*   **Formatting**: Standard Dart format.

## Key constraints
1.  **No Direct Host Access**: All commands must run via `docker-compose`.
2.  **Versioning**: API mismatches must be handled gracefully or avoided.
