# Product Context

> "Measure twice, code once."

## Vision
The **Controle Patrimonial** app is a "Digital Clipboard" designed to replace manual paper spreadsheets for inventory management at IFSUL. It prioritizes **speed**, **offline reliability**, and **error minimization** during field work.

## Core Value Proposition
1.  **Speed**: Batch scanning allows checking hundreds of items quickly.
2.  **Reliability**: Works 100% offline. Syncs only when the user explicitly actions it.
3.  **Precision**: Focuses on identifying *differences* (inconsistencies) rather than just listing assets.

## User Persona
*   **Role**: Servidor do IFSUL (Patrimony/Inventory Staff).
*   **Context**: Walking through classrooms, labs, and offices. Potentially weak or no Wi-Fi.
*   **Pain Points**:
    *   Paper lists are outdated the moment they are printed.
    *   Manual data entry back into SUAP is error-prone.
    *   Hard to visually check if an item belongs to the current room.

## Key Features
1.  **Offline-First**: Download full DB -> Work Offline -> Upload Differences.
2.  **Smart Scanning**:
    *   **Individual**: Detailed check/edit of a single item.
    *   **Batch**: Rapid fire scanning to validate presence in a room.
3.  **Inconsistency Highlighting**:
    *   Alerts if an item is scanning in "Room A" but registered in "Room B".
    *   Alerts if an item is not found in the local DB.
4.  **Delta Sync**: The system captures *modifications* (`original` vs `current`) to generate a precise change report.

## Domain Language (Ubiquitous Language)
*   **Patrimônio**: An asset with a unique barcode (number), description, state, and location.
*   **Sessão de Escaneamento**: A period of work (e.g., "Scanning Lab 3").
*   **Inconsistência**: A mismatch between physical reality and the database (e.g., Wrong Room).
*   **Sincronização**: The act of pulling the latest DB snapshot or pushing queued changes.
