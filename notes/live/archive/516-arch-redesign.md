# SimuleOs – Core Design Decisions

## 1. Single Root + Specialized Workflow Handles

We adopt a 3-object model:

- **SimOs** (root runtime):
  Represents project + environment + configuration.
  It is the common entry point for *all* workflows.

- **SessionRecorder** (write model):
  Used exclusively for scope recording (staging, commit).
  Owns mutable recording state.

- **SessionReader** (read model):
  Used for querying data (possibly from multiple sources/projects).
  Read-only, composable, functional.

Rationale:
- Reading and writing have different invariants and lifecycles.
- Mixing them into a single “do-everything” object leads to unclear state,
  optional fields, and hidden coupling.
- Both SessionRecorder and SessionReader are derived from SimOs and may coexist.

---

## 2. sim_init(...) = Minimal, Idempotent Root Initialization

`sim_init(...) -> SimOs`

Responsibilities:
- Detect / resolve project
- Load settings (via UXLayer global, only here)
- Initialize access to `.simuleos/` and `~/.simuleos/`
- Prepare environment + capabilities
- Attach to existing head (snapshot/tape) if present

Rules:
- Idempotent *only if previous init succeeded*
- If init fails: emit warning and do NOT leave partial state
- Auto-run on `using Simuleos` only when a project is detected
- Otherwise, user must call explicitly (or via CLI)

Importantly:
- sim_init does NOT start recording
- sim_init does NOT load data by default
It only establishes the runtime root.

---

## 3. Explicit Start of Recording

Recording is opt-in:

`start_recording(sim::SimOs) -> SessionRecorder`

- Creates a recording session (staging area + head ref)
- Publishes `current_session[]` for macros
- May coexist with active SessionReader/querying

This cleanly separates:
- project initialization
- recording lifecycle

---

## 4. Read and Write Can Coexist

At any time:

- A SessionRecorder may be active (writing)
- One or more Readers may exist (reading/querying)

Queries always operate on persisted refs/snapshots via SessionReader,
never on mutable runtime state.

This enables:
- concurrent read + write
- multi-project queries
- deterministic analysis

---

## 5. Globals Are Allowed — But Only as Ambient Defaults

Permitted globals:

- `current_sim[] :: SimOs`
- `current_session[] :: SessionRecorder` (only during recording)
- optionally `current_store[]`

Purpose:
- ergonomic UX (macros, embedded calls)

Rule:
Every important operation also has an explicit form:

- `record!(session, ...)`
- `query(store, ...)`
- `load_tape(store, ...)`

Macros use globals.
Serious composition/testing uses explicit objects.

Globals are convenience handles, not domain truth.

---

## 6. Kernel vs Runtime Boundary (Relaxed but Intentional)

- Kernel/Core aims to be as pure as possible (State + transitions)
- Runtime/Services may depend on globals (UXLayer, IO, system integration)

UXLayer globals are acceptable for configuration,
but materialized into `sim.config` during init.

Workflows read from SimOs / SessionRecorder / SessionReader,
not directly from UXLayer.

---

## Core Principle

> One root (SimOs), two workflow models (SessionRecorder for writing, SessionReader for reading),
> globals only as ambient defaults, never as the foundation.

This preserves:
- ergonomic recording
- composable querying
- multi-session capability
- architectural clarity.
