# Simuleos Implementation Summary

## Architecture Overview

```
src/
  Simuleos.jl           # Main module (includes + exports)
  types.jl              # Core type definitions
  globals.jl            # Global session state
  lite.jl               # Lite data detection
  blob.jl               # Blob serialization (SHA1 + Serialization)
  tape.jl               # JSONL tape I/O
  metadata.jl           # Git/Julia/timestamp capture
  macros.jl             # All 4 macro implementations
```

### Core Types

| Type | Description |
|------|-------------|
| `ScopeVariable` | Holds variable name, type string, optional lite value, optional blob_ref |
| `Scope` | Labeled snapshot with timestamp and Dict of ScopeVariables |
| `Stage` | Accumulator for scopes before commit; tracks blob_refs |
| `Session` | Root state: label, root_dir, stage, metadata, blob_set |

### Storage Layout

```
project/
  script.sim.jl
  .simuleos/
    blobs/
      <sha1>.jls       # serialized Julia objects
    tapes/
      <session_label>.jsonl
```

## Macro API

| Macro | Purpose |
|-------|---------|
| `@sim_session label` | Initialize session, capture metadata, create directories |
| `@sim_store vars...` | Mark variables for blob storage (instead of inline) |
| `@sim_capture label` | Snapshot local scope via `Base.@locals()`, add to stage |
| `@sim_commit` | Persist staged scopes to JSONL tape, reset stage |

## Workflow Example: Lotka-Volterra Simulation

```julia
# scripts/Lotka–Volterra-main.sim.jl

function simulate_lv(; X0=30.0, Y0=8.0, α=1.2, β=0.08, ...)
    # ... simulation logic produces X, Y, ts arrays ...

    @sim_store X, Y, ts      # mark arrays for blob storage
    @sim_capture "simulate_lv"  # snapshot all locals
end

let
    @sim_session "Lotka-Volterra Simulation"
    simulate_lv(seed=42, intervention=:predator_death, strength=0.55)
    @sim_commit
end
```

### Event Sequence

#### 1. `@sim_session "Lotka-Volterra Simulation"`

**What happens:**
- `_reset_session!()` clears any previous session
- Creates `.simuleos/` and `.simuleos/blobs/` directories
- `_capture_metadata()` collects:
  - `timestamp`: "2026-02-01T09:16:01.306"
  - `julia_version`: "1.12.4"
  - `hostname`: "pro25.local"
  - `script_path`: full path to the .sim.jl file
  - `git_commit`: "1909e6e563c03..."
  - `git_dirty`: true/false
- Creates global `Session` with empty `Stage`

#### 2. `simulate_lv(...)` executes

The simulation runs, producing:
- `X`: Vector{Float64} of 5001 prey population values
- `Y`: Vector{Float64} of 5001 predator population values
- `ts`: Vector{Float64} of 5001 time points
- Plus all local parameters (α, β, δ, γ, seed, etc.)

#### 3. `@sim_store X, Y, ts`

**What happens:**
- Retrieves current session via `_get_session()`
- Adds symbols `:X`, `:Y`, `:ts` to `session.blob_set`
- These variables are now marked for blob storage instead of inline JSON

#### 4. `@sim_capture "simulate_lv"`

**What happens:**
- Calls `Base.@locals()` to get Dict{Symbol, Any} of all local variables
- For each variable, `_process_scope()` decides storage:

| Variable | Type | Storage Decision |
|----------|------|------------------|
| `X` | Vector{Float64} | In `blob_set` → write blob, store `blob_ref` |
| `Y` | Vector{Float64} | In `blob_set` → write blob, store `blob_ref` |
| `ts` | Vector{Float64} | In `blob_set` → write blob, store `blob_ref` |
| `α` | Float64 | Lite → inline value `1.2` |
| `β` | Float64 | Lite → inline value `0.08` |
| `seed` | Int64 | Lite → inline value `42` |
| `intervention` | Symbol | Lite → inline as string `"predator_death"` |
| `rng` | MersenneTwister | Not lite, not in blob_set → type only |
| `αt` | Vector{Float64} | Not lite, not in blob_set → type only |

- For blob storage:
  - `_blob_hash(value)`: serialize to bytes, compute SHA1
  - `_write_blob(session, value)`: write to `.simuleos/blobs/<sha1>.jls`
- Creates `Scope` with label "simulate_lv", timestamp, and all `ScopeVariable`s
- Pushes scope to `session.stage.scopes`
- Clears `blob_set` for next capture

#### 5. `@sim_commit`

**What happens:**
- Checks `stage.scopes` is not empty
- `_create_commit_record()` builds Dict:
  ```json
  {
    "type": "commit",
    "session_label": "Lotka-Volterra Simulation",
    "metadata": { ... },
    "scopes": [ { "label": "simulate_lv", "variables": {...}, ... } ],
    "blob_refs": ["da13f6...", "c9e03b...", "f0eef2..."]
  }
  ```
- `_append_to_tape()`:
  - Creates `.simuleos/tapes/` directory
  - Sanitizes label for filename: "Lotka-Volterra_Simulation.jsonl"
  - Appends JSON record as single line
- Resets `stage` to empty for next commit cycle

### Final Output

```
scripts/.simuleos/
  blobs/
    c9e03b0fdb431914cf21be2de62893fcfc63587f.jls  # X array (~40KB)
    da13f698f8f868e40d335f96b5d738d5103beddb.jls  # ts array (~40KB)
    f0eef22479f34d159368f3cc8231ab2f4ac67c22.jls  # Y array (~40KB)
  tapes/
    Lotka-Volterra_Simulation.jsonl                # commit record (~2KB)
```

## Data Flow Diagram

```
@sim_session
     │
     ▼
┌─────────────────┐
│ Session created │
│ - metadata      │
│ - empty stage   │
│ - empty blob_set│
└────────┬────────┘
         │
    user code runs
         │
         ▼
@sim_store X, Y, ts
     │
     ▼
┌─────────────────┐
│ blob_set += {X, │
│   Y, ts}        │
└────────┬────────┘
         │
         ▼
@sim_capture "label"
     │
     ├──► Base.@locals() → Dict{Symbol, Any}
     │
     ▼
┌─────────────────────────────────────┐
│ For each local variable:            │
│   if in blob_set → write .jls blob  │
│   elif is_lite   → inline value     │
│   else           → type string only │
└────────┬────────────────────────────┘
         │
         ▼
┌─────────────────┐
│ Scope pushed to │
│ stage.scopes    │
└────────┬────────┘
         │
         ▼
@sim_commit
     │
     ▼
┌─────────────────┐
│ Write JSONL     │
│ tape record     │
│ Reset stage     │
└─────────────────┘
```

## Lite Types

Values of these types are stored inline in JSON:

- `Bool`
- `Int`
- `Float64`
- `String`
- `Nothing`
- `Missing` (stored as string "missing")
- `Symbol` (stored as string)

All other types either require explicit `@sim_store` for blob storage, or are recorded as type-only references.
