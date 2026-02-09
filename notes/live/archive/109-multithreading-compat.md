# Simuleos Multithreading/Multiprocessing Compatibility

This document summarizes the challenges and proposed solutions for making Simuleos compatible with concurrent execution models.

### Identified Problems

1.  **Global Session State:** The single global `__SIM_SESSION__` variable is a point of contention. In a multithreaded or multiprocessing environment, each worker needs its own isolated state (scopes, stage, etc.) to prevent interference.

2.  **Disk Race Conditions:** Concurrent calls to functions that perform disk I/O (`@sim_commit`, `@sim_store`) can lead to race conditions, resulting in corrupted tape files or blobs if multiple threads/processes attempt to write to the same file simultaneously.

### Proposed Solutions

1.  **Explicit Session Passing (Process-Safe):**
    *   **Concept:** Remove the global session. `@sim_session` returns a `Session` object that the user must explicitly pass to all other macros (e.g., `@sim_capture(session, "label")`).
    *   **Recommendation:** This is the most robust architectural solution for **multiprocessing**, as it enforces clear state management and avoids shared memory issues. However, it represents a significant breaking change to the user API.

2.  **Per-Thread Sessions with a Master Lock (Thread-Safe):**
    *   **Concept:** Replace the single global session with a thread-local storage system (e.g., a vector of sessions indexed by `Threads.threadid()`). This gives each thread its own session state. A single global `ReentrantLock` is used to serialize all disk write operations, preventing race conditions.
    *   **Recommendation:** This is the recommended solution for **multithreading**. It effectively isolates thread states and protects shared resources with minimal changes to the existing user-facing API.

### Summary of Recommendations

*   For **multithreading**, adopt the **Per-Thread Sessions with a Master Lock** approach. It is the most practical and least disruptive path forward.
*   For **multiprocessing**, the ideal long-term solution is **Explicit Session Passing**, though it requires a major version change due to its impact on the API.
