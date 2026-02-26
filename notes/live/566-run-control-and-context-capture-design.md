# 566 — Run Control & Context Capture Design

**Date:** 2026-02-25
**Status:** Design discussion (not yet implemented)
**Scope:** run control strategy, automatic context capture, and the composable context engine architecture

---

## Problem

Simuleos needs to support multiple ways of parameterizing and running simulation scripts while keeping full provenance of what influenced each computation. Two intertwined concerns:

1. **Run control** — how parameters reach a script (hardcoded, CLI args, config files, env vars)
2. **Context capture** — how the system records everything that influenced a computation

---

## Run Control

### Injection modes

All parameter injection modes map to existing settings stack layers:

| Mode | Layer | Good for | Tradeoff |
|---|---|---|---|
| Hardcoded in script | `:bootstrap` / `:script` | Reproducibility, self-documenting | Must edit source per run |
| CLI args (`ARGS`) | `:cli` (new) | Batch sweeps, parallel runs | Parameters not in source |
| Config file (`--config`) | `:json_file` (exists) | Prepared parameter sets | Extra file to manage |
| Env vars | `:env` (exists) | CI/CD, containers | Verbose, no nesting |

These are complementary, not competing. The settings stack resolves by priority — a script hardcodes defaults and CLI args override them cleanly.

### Layer priority (proposed)

```
:home < :project < :json_file < :env < :cli < :bootstrap < :script < :session
```

CLI sits above env but below bootstrap. Mental model: CLI is what the **user** said at launch time; bootstrap is what the **script author** hardcoded at init.

### CLI args interface

One-line opt-in for any script:

```julia
@simos settings.source.add_args(ARGS; after = :env)
```

Supports `--set key=value` and `--config path.json` flags. Value coercion: `true`/`false` → Bool, integers → Int, floats → Float64, `json:...` → parsed JSON.

---

## Context Capture

### Design philosophy

Simuleos is a **composable context-aware recording toolkit**. Scope recording is one workflow built on top of general-purpose context primitives.

### Context sources (exhaustive)

| Source | What it captures | Collection method | Cache frequency |
|---|---|---|---|
| **Julia scope** | Variables staged by user (`stage.blob/hash/inline`) | Explicit (user stages) | Per scope |
| **User meta** | Annotations (`stage.meta`) | Explicit (user writes) | Per scope |
| **Settings** | Any `get_setting` call between captures | Auto-tracked access log | Per scope |
| **Source code** | Git commit hash + dirty flag | Auto at session init | Per session |
| **Environment** | Julia version, package versions, OS | Auto at system init | Per init |
| **Execution** | Script path, hostname, timestamp | Auto at capture time | Per capture |

### Automatic settings tracking

`get_setting` is instrumented with a read tracker on the `WorkSession`. Between two scope captures, every accessed key+value pair is logged. On `scope.capture`, the log is flushed into the scope context and cleared for the next interval. On by default, opt-out via setting.

### Storage: record once, reference many times

Context records are **content-addressed and deduplicated**:

- Stable context (git hash, Julia version) → recorded once per session/init, referenced by every scope
- Changing context (settings accessed) → new record per scope, but deduplicated if identical
- The scope record itself stays small — just refs to context records plus scope-specific data

```
commit
  ├── scope "snapshot-1"
  │     ├── staged data
  │     ├── meta
  │     └── refs → [settings_ctx_001, source_ctx_001, env_ctx_001]
  ├── scope "snapshot-2"
  │     ├── staged data
  │     ├── meta
  │     └── refs → [settings_ctx_002, source_ctx_001, env_ctx_001]
```

---

## The Context Engine (core abstraction)

### One primitive: capture context, get back an ID

```julia
ctx = @simos context.capture()  # → ContextRef("a7f3")
```

Returns a short content-addressed hash (like git short SHA, auto-extends on ambiguity). Same context → same hash.

### Usage: universal provenance stamps

```julia
# File naming with provenance
savefig("loss_$(ctx).png")

# Logging
@info "checkpoint" context = ctx

# Later: full resolution
@simos context.resolve("a7f3")
# → settings, source, environment, execution, ...
```

### Architecture

```
┌─────────────────────────────────────────┐
│  Workflows                              │
│  scope.capture, session.commit,         │
│  cache.remember, user scripts           │
├─────────────────────────────────────────┤
│  Context Engine                         │
│  context.capture → collect + record     │
│  context.resolve → lookup by short ID   │
│  context.diff    → compare two captures │
├─────────────────────────────────────────┤
│  Collectors (pluggable)                 │
│  settings, source, environment,         │
│  execution, staged-data, custom         │
├─────────────────────────────────────────┤
│  Storage (tape + content-addressing)    │
│  deduplicated records, short hash index │
└─────────────────────────────────────────┘
```

### Two user-facing modes

- **`stage.*` + `scope.capture`** — "record data with context" (structured workflow)
- **`context.capture`** — "just give me a provenance stamp" (lightweight, universal)

Both feed from the same collectors. Both store to the same tape. Both queryable through the same read-back API.

### ContextRef type

```julia
struct ContextRef
    hash::String      # full content hash
    short::String     # display-friendly short hash
end
Base.string(c::ContextRef) = c.short  # string interpolation uses short hash
```

---

## Implementation order (proposed)

1. **Settings access tracking** — instrument `get_setting`, flush on `scope.capture`
2. **`context.capture` + `context.resolve`** — the core primitive with short-hash IDs
3. **Source context** — git hash + dirty at `session.init`
4. **Environment context** — Julia + packages at `system.init`
5. **Execution context** — script path, hostname, timestamp
6. **CLI args layer** — `settings.source.add_args(ARGS)`
7. **`context.diff`** — compare two context captures

---

## Key design principles

1. **Auto-capture by default, explicit staging for data** — collectors run silently; user only stages computation I/O
2. **Per-scope atom** — each scope is self-contained and self-describing
3. **Record once, reference many** — deduplicate stable context across scopes
4. **Composable primitives** — workflows are compositions of context + staging + persistence tools
5. **Minimal friction** — one line for a provenance stamp, zero config for auto-tracking
