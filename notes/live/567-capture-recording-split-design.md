# 567 — Capture / Recording Split & State Model

**Date:** 2026-02-25
**Status:** Design discussion (refinement of 566)
**Predecessor:** 566-run-control-and-context-capture-design.md
**Scope:** separating capture from recording as independent primitive layers; the "computation state" framing

---

## Evolution from 566

Note 566 identified the context engine and the `context.capture()` primitive. This note refines two things:

1. **Capture and recording are separate operations** — capture gathers state in memory; recording persists it to tape. They compose but are independent.
2. **The unifying concept is "computation state"** — not "context", not "scope", not "results". All sources provide facets of the computation state at a point in time.

---

## Framing

Simuleos is an operative system for aiding simulation workflows. One of its core capabilities is a **structured tape recorder for computational workflows**.

The tape recorder operates on **computation state** — the full picture of what is happening at a moment: what data exists, what configuration is active, what code is running, what environment it runs in.

Different collectors observe different **facets** of that state:

| Facet | What it observes | Example |
|---|---|---|
| Computation | Julia variables the user chose to track | staged blobs, hashes, inlines |
| Configuration | Settings values accessed | `run.alpha = 0.5` |
| Code | Source code identity | git hash, dirty flag |
| Environment | Runtime platform | Julia version, packages, OS |
| Execution | When/where this runs | script path, hostname, timestamp |
| User | Manual annotations | notes, labels, metadata |

---

## The split: Capture vs Recording

| | Capture | Recording |
|---|---|---|
| **What** | Gather state facets into a structured object in memory | Persist a capture (or any datum) to the tape |
| **When** | Anytime, cheap, repeatable, no side effects | Explicit decision, creates a permanent tape entry |
| **Returns** | A data structure (in-memory) | A ref/hash (content-addressed, queryable) |
| **Analogy** | Taking a photograph | Putting it in the album |

Key implications:

- You can **capture without recording** — inspect state, use it for decisions, discard it
- You can **record without a full capture** — persist a single datum or a manual note
- You can **capture once, record selectively** — only persist what changed

---

## Primitive layers

### Capture primitives (pure, no side effects)

Collect state facets into in-memory structures.

```
capture.settings()       → SettingsState (keys accessed + values)
capture.source()         → SourceState (git hash, dirty flag)
capture.environment()    → EnvironmentState (julia, packages, OS)
capture.execution()      → ExecutionState (script, host, time)
capture.scope(vars...)   → ScopeState (staged variables)
capture.full()           → FullState (all facets bundled)
```

Each returns a plain data structure. No tape writes. No refs. Just data.

### Recording primitives (writes to tape)

Persist data and return content-addressed references.

```
record.write(state)      → ref    # persist any state/datum to tape
record.attach(ref, to)   → link   # link a ref to another ref
record.tag(ref, label)   → ref    # label a recorded entry
```

`record.write` is content-addressed: same content → same ref. The ref carries a short hash for display (`ref.short`) and a full hash for integrity.

---

## Workflow composition

### Classic scope recording (current workflow, reframed)

```julia
# What @simos scope.capture("snapshot") does internally:
state = capture.full()
ref = record.write(state)
record.tag(ref, "snapshot")
```

### Lightweight provenance stamp (image naming use case)

```julia
ref = record.write(capture.full())
savefig("loss_$(ref.short).png")

# Later:
@simos context.resolve("a7f3")  # → full state record
```

### Capture without recording (debugging/inspection)

```julia
state = capture.settings()
@show state  # inspect in REPL, nothing persisted
```

### Selective recording (only persist what changed)

```julia
s = capture.settings()
if s != last_settings_capture
    record.write(s)
end
```

### Manual annotation (recording without capture)

```julia
record.write("note", "Switched to optimizer B after divergence")
```

---

## Relationship to existing `@simos` surface

The current `@simos` commands map onto this model:

| Current command | Under the hood |
|---|---|
| `stage.blob(x)` | Prepare data for `capture.scope()` |
| `stage.inline(x)` | Prepare data for `capture.scope()` |
| `stage.meta(...)` | Prepare user-facet data |
| `scope.capture("label")` | `capture.full()` + `record.write()` + `record.tag()` |
| `session.commit("label")` | Persistence boundary — flush to tape |

The existing commands remain as the **high-level workflow API**. The capture/recording primitives are the **lower-level composable API** that powers them and is also available directly.

---

## Deduplication and efficiency

Recording primitives are content-addressed:

- `capture.environment()` returns the same data all session → `record.write()` returns the same ref, stored once
- `capture.source()` same within a session → one record, many references
- `capture.settings()` changes between scopes → new record only when content differs

The tape stores each unique state blob once. Captures reference them. This is the "record once, reference many" principle from note 566, now grounded in the capture/recording split.

---

## Design principles (updated from 566)

1. **Capture and recording are independent** — capture is pure observation; recording is explicit persistence
2. **Computation state is the unifying concept** — all sources provide facets of state at a point in time
3. **Primitives compose into workflows** — scope recording is one composition; provenance stamping is another; custom workflows use the same building blocks
4. **Auto-collection, explicit persistence** — collectors gather state passively; the user (or a workflow) decides what to persist
5. **Content-addressed deduplication** — same state → same ref, stored once
6. **Existing surface is preserved** — `@simos scope.capture` and friends remain as high-level conveniences
