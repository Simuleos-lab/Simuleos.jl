# 569 — Partial Captures & Flexible Recording Trees

**Date:** 2026-02-25
**Status:** Design discussion (refinement of 568)
**Predecessor:** 568-snapshot-record-independent-subsystems.md
**Scope:** correcting the capture model from "one complete snapshot" to partial source-level captures; correcting the recording model from fixed-shape records to arbitrary structured trees

---

## Evolution from 568

Note 568 established capture and recording as independent subsystems. But it still assumed:

- A capture produces a **complete snapshot** bundling all facets
- A record has a **fixed shape** (staged + meta + settings + source + env + execution)

Both assumptions are wrong. This note corrects them.

---

## Correction 1: Captures are partial

The capture system produces **partial snapshots from individual sources**. Each capture call targets one source and returns one facet of computation state.

```julia
s1 = capture(:settings)      # → settings facet only
s2 = capture(:scope, vars)   # → Julia variables only
s3 = capture(:source)        # → git hash only
s4 = capture(:environment)   # → Julia/OS info only
```

There is no privileged `capture(:full)` that bundles everything. A "full capture" is just a workflow choice — the workflow calls multiple captures and assembles them however it wants.

### Why this matters

- **Efficiency**: stable sources (git, env) are captured once. The workflow reuses them without re-capturing.
- **Flexibility**: different workflows need different facets. A provenance stamp might only need settings + source. A checkpoint might need everything. The capture system doesn't decide.
- **Composability**: partial captures are values. They can be stored, compared, passed around, merged — independently of each other.

---

## Correction 2: Records are arbitrary trees

The recording system accepts **any structured data**. A record is a tree — its shape is defined by the workflow, not by the recording system.

```
Record (tree, workflow-defined shape)
  ├── node: settings snapshot (captured fresh per scope)
  ├── node: scope variables (captured fresh per scope)
  ├── node: user metadata (attached by user)
  ├── ref → source record (captured once at session start, referenced)
  ├── ref → environment record (captured once at init, referenced)
  └── any other data the workflow wants to attach
```

The recording system provides:

- **Write**: serialize any data → content-addressed ref
- **Reference**: link records to other records
- **Read**: retrieve data by ref

It does NOT define:

- What fields a record must have
- What shape the tree takes
- What types of data are valid

A record can hold a partial snapshot, a full assembled tree, a manual note, a metric, a blob — anything.

---

## The three-layer architecture (corrected)

```
┌─────────────────────────────────────────┐
│  Workflows                              │
│  (compose captures + recording freely)  │
│                                         │
│  Scope recording workflow:              │
│    cap_s = capture(:settings)           │
│    cap_v = capture(:scope, locals)      │
│    tree = assemble(cap_s, cap_v,        │
│             ref_source, ref_env, meta)  │
│    record(tape, tree)                   │
│                                         │
│  Provenance stamp workflow:             │
│    cap_s = capture(:settings)           │
│    ref = record(tape, cap_s)            │
│    filename = "plot_$(ref.short).png"   │
│                                         │
│  Custom workflow:                       │
│    ... whatever the user needs ...      │
├─────────────────────────────────────────┤
│  Capture system          Recording sys  │
│  (partial snapshots)     (tree storage) │
│                                         │
│  capture(:source) → data  record(data)  │
│  capture(:settings) → ..  resolve(ref)  │
│  capture(:scope) → ...    tag(ref)      │
│  capture(:env) → ...                    │
├─────────────────────────────────────────┤
│  Sources / Collectors     Tape / Blobs  │
│  (pluggable)              (append-only) │
└─────────────────────────────────────────┘
```

The workflow layer is where structure is decided. The capture and recording layers are general-purpose tools that the workflow composes.

---

## How the current scope recording workflow maps

Today's `scope.capture` + `session.commit` is one specific workflow built from these primitives:

### Current flow (implicit)

```
stage.blob(x)           →  mark x for blob routing
stage.meta(step=1)      →  buffer metadata
scope.capture("label")  →  capture locals + globals + meta → SimuleosScope
                            (blob_write happens here as side effect)
session.commit("done")  →  bundle scopes + git metadata → ScopeCommit → tape
```

### Equivalent in new model (explicit)

```
# Capture phase (no side effects)
cap_vars = capture(:scope, locals;
    routing = CaptureConfig(blob=[x], inline=[params]))
cap_meta = capture(:meta, step=1, phase="warmup")
cap_settings = capture(:settings)   # auto-tracked accessed keys

# Assembly phase (workflow decides the shape)
snapshot = Dict(
    "label" => "label",
    "variables" => cap_vars,
    "meta" => cap_meta,
    "settings" => cap_settings,
    "source" => ref_source,        # recorded once, reused
    "environment" => ref_env,      # recorded once, reused
)

# Recording phase (side effects here)
ref = record(tape, snapshot)
```

The key difference: blob writes move from capture time to recording time. Capture is pure. Recording is where persistence happens.

---

## Incremental/accumulative capture patterns

Because captures are partial, workflows can build up structure incrementally:

### Accumulate across time

```julia
# At session start
ref_env = record(tape, capture(:environment))
ref_src = record(tape, capture(:source))

# At each scope (only capture what changed)
cap_settings = capture(:settings)    # access log since last capture
cap_vars = capture(:scope, locals)

# Assemble referencing stable records
tree = Dict(
    "variables" => cap_vars,
    "settings" => cap_settings,
    "env" => ref_env,           # reference, not copy
    "source" => ref_src,        # reference, not copy
)
record(tape, tree)
```

### Accumulate across sources

```julia
# Different sources captured at different moments
cap1 = capture(:settings)           # before computation
# ... computation runs ...
cap2 = capture(:scope, locals)      # after computation
cap3 = capture(:meta, elapsed=dt)   # timing info

# All composed into one tree
record(tape, Dict("pre" => cap1, "post" => cap2, "timing" => cap3))
```

### Selective capture

```julia
# Only what the workflow needs
ref = record(tape, capture(:settings))
savefig("plot_$(ref.short).png")
# No scope variables, no env, no git — just settings provenance
```

---

## Mapping to current codebase (refactoring implications)

| Current | Issue | New model |
|---|---|---|
| `SimuleosScope` bundles variables + metadata | Mixes computation facet with user facet | Separate partial captures |
| `ScopeCommit.metadata` holds git hash | Source context attached at commit, not scope | Source is a separate capture, recorded once, referenced |
| `blob_write` during `scope_capture` | Capture has side effects | Blob persistence deferred to recording |
| `ScopeStage` holds routing hints + captured scopes | Mixes capture config with capture output | `CaptureConfig` (routing) separate from capture results |
| `WorkSession` owns both stage and pending_commits | Conflates capture and recording state | Capture engine and recording engine are independent |
| `take_stage_commit!` bundles scopes into commit | Fixed bundling protocol | Workflow decides tree shape |

---

## Design principles (updated)

1. **Captures are partial** — each capture targets one source, returns one facet
2. **Records are arbitrary trees** — the recording system stores any structured data without imposing shape
3. **Workflows compose freely** — they call captures from whichever sources they need and assemble whatever tree structure makes sense
4. **Capture is pure, recording is persistence** — no side effects during capture; blob writes and tape appends happen at recording time
5. **Stable data is captured once, referenced many times** — workflows decide what's stable and what needs re-capturing
6. **The existing scope recording workflow is one composition** — not the only one, not privileged, just the first and most common
