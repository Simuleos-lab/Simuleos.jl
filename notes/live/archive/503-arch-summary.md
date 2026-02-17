# System Overview

Simuleos is a Julia library for instrumenting scientific simulations. It provides a set of macros to define recording sessions, capture the state of variables at specific points, and persist this data to a structured format on disk. The system distinguishes between lightweight, JSON-serializable data ("lite") and large or complex data types ("blobs"), which are serialized separately and content-addressed by their SHA1 hash.

# Key Components

- **`Simuleos.jl`**: The main module, which exports the public macro API.
- **`macros.jl`**: Implements the user-facing API: `@sim_session`, `@sim_store`, `@sim_context`, `@sim_capture`, and `@sim_commit`.
- **`types.jl`**: Defines the core data structures: `Session`, `Stage`, `Scope`, `ScopeVariable`, and `ScopeContext`.
- **`tape.jl`**: Handles the creation of "commit" records and writing them to a session-specific JSON Lines (`.jsonl`) tape file.
- **`blob.jl`**: Manages the serialization of non-lite Julia objects into `.jls` files stored in a global blob directory.
- **`globals.jl`**: Manages the global `__SIM_SESSION__` state object.
- **`metadata.jl`**: Captures session-level metadata, including Git status, Julia version, and script paths.

# Data / Control Flow

1.  **`@sim_session "label"`**: Initializes a global `Session` object and captures initial system metadata. Directory structure (`.simuleos/sessions/<label>/` and `.simuleos/blobs/`) is created on-demand at write time.
2.  **`@sim_store var1, var2`**: Marks specific variables that should be treated as blobs for the next capture.
3.  **`@sim_context "label" :key=>val`**: Attaches arbitrary labels or key-value data to the context of the next capture.
4.  **`@sim_capture "label"`**: Snapshots all local and global variables. For each variable, it determines if it's a blob (from `@sim_store`), "lite" data, or just a type reference. It packages this into a `Scope` object, which is added to the `Session`'s `stage`. The per-scope context is then reset.
5.  **`@sim_commit "label"`**: Takes all `Scope`s currently on the `stage`, bundles them into a single commit record (including all metadata and blob references), and appends this record as a single line to the `context.tape.jsonl` file. The stage is then cleared for the next set of captures.

# Interfaces & Contracts

- **File System API**:
    - `.simuleos/sessions/<session_label>/tapes/context.tape.jsonl`: The primary output. A JSONL file where each line is a commit record.
    - `.simuleos/blobs/<sha1>.jls`: Content-addressed store for serialized Julia objects (blobs). This store is global and shared across all sessions.
- **Public Macro API**:
    - `@sim_session <label::String>`: Starts a new recording session.
    - `@sim_store <vars...>`: Flags variables for blob storage.
    - `@sim_context <args...>`: Adds descriptive context to a scope.
    - `@sim_capture <label::String>`: Creates a snapshot of the program state.
    - `@sim_commit [label::String]`: Persists the collected snapshots to disk.
- **Data Contracts (JSON Schema high-level)**:
    - **Commit Record**: `{ "type": "commit", "session_label": "...", "metadata": {...}, "scopes": [...], "blob_refs": [...] }`
    - **Scope**: `{ "label": "...", "timestamp": "...", "variables": {...}, "context_labels": [...], "context_data": {...} }`
    - **Variable**: `{ "name": "...", "type": "...", "src": "...", "value": "..." | "blob_ref": "..." }`

# Hot Spots to Re-Read

- **`src/macros.jl`**: The core logic resides here. Understanding the interplay between `@sim_capture`'s use of `Base.@locals()` and how `@sim_store` and `@sim_context` modify the session state is key.
- **`src/types.jl`**: Defines the data hierarchy. `Session` holds the `Stage`, which holds a vector of `Scope`s, which hold dictionaries of `ScopeVariable`s.
- **`src/tape.jl`**: Shows how the final `commit` record is structured and serialized to the JSONL file.
- **`src/blob.jl`**: Contains the simple but important logic for serializing, hashing, and storing complex data types.
- **`scripts/Lotka–Volterra-main.sim.jl`**: The reference implementation showing how the macros are intended to be used in a user's script.
